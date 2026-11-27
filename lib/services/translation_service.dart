// Copyright (c) 2026 brokengoose <brokengoose@users.noreply.github.com>
// SPDX-License-Identifier: MIT

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart';

import '../core/language/language_registry.dart';
import '../models/ai_models.dart';
import '../models/app_settings.dart';
import '../models/mastodon_models.dart';
import 'ai_provider_service.dart';
import 'mastodon_service.dart';
import 'on_device_ai_service.dart';

/// Result of translating a Mastodon post (including optional Content Warning
/// and media alt-text descriptions).
class PostTranslationResult {
  const PostTranslationResult({
    required this.translatedText,
    this.translatedSpoiler,
    this.translatedAltTexts = const {},
    required this.sourceLanguage,
    required this.targetLanguage,
    required this.engineName,
  });

  final String translatedText;
  final String? translatedSpoiler;

  /// Map of `MastodonMediaAttachment.id` -> translated alt-text.
  final Map<String, String> translatedAltTexts;

  final String sourceLanguage;
  final String targetLanguage;
  final String engineName;
}

/// Callback type for invoking Apple's native Translation framework.
typedef AppleTranslateCallback = Future<String> Function({
  required String text,
  required String sourceLanguage,
  required String targetLanguage,
});

/// Callback type for invoking Google ML Kit on-device translation.
typedef MlKitTranslateCallback = Future<String> Function({
  required String text,
  required String sourceLanguage,
  required String targetLanguage,
});

/// Callback type for checking Apple Translation availability.
typedef AppleSupportCheckCallback = Future<bool> Function();

/// Callback type for detecting a text's language via native OS APIs.
typedef NativeLanguageDetectCallback = Future<String?> Function(String text);

/// Post translation service prioritizing built-in OS on-device AI
/// (Apple Foundation Models / Google Gemini Nano), with automatic fallback to:
/// - Apple's `Translation` framework on iOS 18+ and macOS 15+
/// - `google_mlkit_translation` on Android (and iOS fallback when needed)
/// - The user's configured AI provider (Gemini / OpenAI / Anthropic / Local AI)
/// - Mastodon's built-in server translation API (`POST /api/v1/statuses/:id/translate`)
class TranslationService {
  TranslationService({
    required this._onDeviceAi,
    this._aiProvider,
    this._mastodon,
    this._platformOverride,
    this._isWebOverride,
    this._osLanguageProvider,
    this._appleSupportCheck,
    this._nativeLanguageDetect,
    this._appleTranslate,
    this._mlKitTranslate,
  });

  static const MethodChannel _appleChannel = MethodChannel(
    'io.github.brokengoose.fedicaption/apple_translation',
  );

  final OnDeviceAiService _onDeviceAi;
  final AiProviderService? _aiProvider;
  final MastodonService? _mastodon;
  final TargetPlatform? _platformOverride;
  final bool? _isWebOverride;
  final String Function()? _osLanguageProvider;
  final AppleSupportCheckCallback? _appleSupportCheck;
  final NativeLanguageDetectCallback? _nativeLanguageDetect;
  final AppleTranslateCallback? _appleTranslate;
  final MlKitTranslateCallback? _mlKitTranslate;

  bool? _cachedAppleSupported;

  bool get _isWeb => _isWebOverride ?? kIsWeb;
  TargetPlatform get _platform => _platformOverride ?? defaultTargetPlatform;
  bool get _isApplePlatform =>
      !_isWeb &&
      (_platform == TargetPlatform.iOS || _platform == TargetPlatform.macOS);
  bool get _isAndroid => !_isWeb && _platform == TargetPlatform.android;
  bool get _isIos => !_isWeb && _platform == TargetPlatform.iOS;

  /// Returns the normalized primary ISO 639-1 language code of the user's OS
  /// (e.g. `'en'`, `'es'`, `'fr'`, `'ja'`).
  String currentOsLanguageCode() {
    final override = _osLanguageProvider?.call();
    if (override != null && override.trim().isNotEmpty) {
      return normalizeLanguageCode(override) ?? 'en';
    }
    final locale = PlatformDispatcher.instance.locale;
    return normalizeLanguageCode(locale.languageCode) ?? 'en';
  }

  /// Normalizes a BCP-47 / ISO 639 language tag (e.g. `'en-US'`, `'pt_BR'`)
  /// into its lowercase primary subtag (`'en'`, `'pt'`), or `null` if invalid.
  static String? normalizeLanguageCode(String? raw) =>
      LanguageRegistry.normalizeCode(raw);

  /// Returns a human-readable display name for an ISO 639-1 language code.
  static String languageDisplayName(String code) =>
      LanguageRegistry.englishNameFor(code);

  /// Returns `true` when [settings] and [credentials] specify an external or
  /// local-network AI provider ready for text translation.
  static bool hasConfiguredAiProvider(
    AppSettings? settings,
    AiCredentials? credentials,
  ) {
    if (settings == null || credentials == null) return false;
    switch (settings.activeProvider) {
      case AiProviderType.gemini:
        return credentials.geminiApiKey.trim().isNotEmpty;
      case AiProviderType.openai:
        final base = settings.openAiBaseUrl.trim();
        return credentials.openAiApiKey.trim().isNotEmpty ||
            (base.isNotEmpty && !base.contains('api.openai.com'));
      case AiProviderType.anthropic:
        return credentials.anthropicApiKey.trim().isNotEmpty;
      case AiProviderType.local:
        return settings.localBaseUrl.trim().isNotEmpty &&
            settings.localModel.trim().isNotEmpty;
      case AiProviderType.onDevice:
      case AiProviderType.none:
        return false;
    }
  }

  static String _configuredAiEngineName(AppSettings settings) {
    switch (settings.activeProvider) {
      case AiProviderType.gemini:
        return 'Google Gemini';
      case AiProviderType.openai:
        final base = settings.openAiBaseUrl.trim();
        return (base.isNotEmpty && !base.contains('api.openai.com'))
            ? 'OpenAI-Compatible'
            : 'OpenAI';
      case AiProviderType.anthropic:
        return 'Anthropic Claude';
      case AiProviderType.local:
        return 'Local AI (${settings.localModel.trim()})';
      case AiProviderType.onDevice:
      case AiProviderType.none:
        return settings.activeProvider.displayName;
    }
  }

  /// Returns `true` when any translation backend is available (on-device OS AI,
  /// Apple Translation, Google ML Kit, a configured AI provider, or the
  /// connected Mastodon server's translation API).
  Future<bool> isTranslationSupported({
    AppSettings? settings,
    AiCredentials? credentials,
    MastodonSession? session,
    InstanceLimits? instanceLimits,
  }) async {
    if (_isWeb) return false;
    if (_isAndroid || _isIos) return true;

    if (_platform == TargetPlatform.macOS &&
        await _isAppleTranslationSupported()) {
      return true;
    }

    try {
      final aiStatus = await _onDeviceAi.checkStatus();
      final onDeviceReady = _platform == TargetPlatform.macOS
          ? (aiStatus.isPromptReady || aiStatus.isPromptDownloadable)
          : aiStatus.isPromptReady;
      if (onDeviceReady) return true;
    } catch (_) {
      // Fall through to configured AI / Mastodon server checks.
    }

    if (_aiProvider != null && hasConfiguredAiProvider(settings, credentials)) {
      return true;
    }
    if (_mastodon != null &&
        session != null &&
        (instanceLimits?.translationEnabled ?? false)) {
      return true;
    }
    return false;
  }

  /// Determines the post's language code from Mastodon's [declaredLanguage]
  /// field first, falling back to native offline language detection (`NLLanguageRecognizer`
  /// on iOS/macOS) or Unicode script heuristics when the post has no language tag.
  Future<String?> detectPostLanguage({
    String? declaredLanguage,
    required String plainText,
  }) async {
    final declared = normalizeLanguageCode(declaredLanguage);
    if (declared != null) return declared;

    final cleaned = _stripUrlsAndMentions(plainText);
    if (cleaned.length < 4) return null;

    if (_nativeLanguageDetect != null) {
      final detected = normalizeLanguageCode(await _nativeLanguageDetect(cleaned));
      if (detected != null) return detected;
    } else if (_isApplePlatform) {
      try {
        final raw = await _appleChannel.invokeMethod<String>(
          'detectLanguage',
          {'text': cleaned},
        );
        final detected = normalizeLanguageCode(raw);
        if (detected != null) return detected;
      } catch (_) {
        // Fall through to script heuristic.
      }
    }

    return detectScriptLanguage(cleaned);
  }

  /// Translates [text] (plus optional [spoilerText] and media [altTexts]) from
  /// [sourceLanguage] to [targetLanguage] using:
  /// 1. On-Device AI (`Apple Foundation Models` / `Google Gemini Nano`) when ready
  /// 2. Apple's `Translation` framework on iOS 18+ and macOS 15+
  /// 3. `google_mlkit_translation` on Android (and iOS fallback)
  /// 4. Configured AI provider (Gemini, OpenAI, Anthropic, or Local AI / Ollama)
  /// 5. Connected Mastodon server's `POST /api/v1/statuses/:id/translate` API
  Future<PostTranslationResult> translatePost({
    required String text,
    String? spoilerText,
    Map<String, String> altTexts = const {},
    required String sourceLanguage,
    String? targetLanguage,
    String? statusId,
    AppSettings? settings,
    AiCredentials? credentials,
    MastodonSession? session,
    InstanceLimits? instanceLimits,
  }) async {
    final src = normalizeLanguageCode(sourceLanguage) ?? sourceLanguage.trim();
    final tgt = normalizeLanguageCode(targetLanguage) ?? currentOsLanguageCode();
    final trimmedText = text.trim();
    final trimmedSpoiler = (spoilerText ?? '').trim();
    final cleanedAlts = <String, String>{
      for (final entry in altTexts.entries)
        if (entry.value.trim().isNotEmpty) entry.key: entry.value.trim(),
    };

    if (trimmedText.isEmpty && trimmedSpoiler.isEmpty && cleanedAlts.isEmpty) {
      throw StateError('There is no text to translate in this post.');
    }

    // 1. Primary on mobile/Apple: OS On-device AI when ready.
    try {
      final aiStatus = await _onDeviceAi.checkStatus();
      if (aiStatus.isPromptReady) {
        return await _translateFieldsWithRunner(
          text: trimmedText,
          spoilerText: trimmedSpoiler,
          altTexts: cleanedAlts,
          sourceLanguage: src,
          targetLanguage: tgt,
          engineName: aiStatus.engineName,
          translateField: (input) => _translateWithOnDeviceAi(
            text: input,
            sourceLanguage: src,
            targetLanguage: tgt,
          ),
        );
      }
    } catch (_) {
      // Fall through to dedicated native translation frameworks or configured backends.
    }

    // 2. Fallback on iOS & macOS: Apple's Translation framework.
    Object? appleError;
    if (_isApplePlatform && await _isAppleTranslationSupported()) {
      try {
        return await _translateFieldsWithRunner(
          text: trimmedText,
          spoilerText: trimmedSpoiler,
          altTexts: cleanedAlts,
          sourceLanguage: src,
          targetLanguage: tgt,
          engineName: 'Apple Translation',
          translateField: (input) => _runAppleTranslate(
            text: input,
            sourceLanguage: src,
            targetLanguage: tgt,
          ),
        );
      } catch (e) {
        appleError = e;
      }
    }

    // 3. Fallback on Android (and iOS if Apple Translation was unavailable/failed):
    //    google_mlkit_translation.
    Object? mlKitError;
    if (_isAndroid || _isIos) {
      try {
        return await _translateFieldsWithRunner(
          text: trimmedText,
          spoilerText: trimmedSpoiler,
          altTexts: cleanedAlts,
          sourceLanguage: src,
          targetLanguage: tgt,
          engineName: 'ML Kit Translation',
          translateField: (input) => _runMlKitTranslate(
            text: input,
            sourceLanguage: src,
            targetLanguage: tgt,
          ),
        );
      } catch (e) {
        mlKitError = e;
      }
    }

    // 4. Preferred desktop backend (and extra fallback): user's configured AI provider.
    Object? configuredAiError;
    if (_aiProvider != null && hasConfiguredAiProvider(settings, credentials)) {
      try {
        return await _translateWithConfiguredAi(
          settings: settings!,
          credentials: credentials!,
          text: trimmedText,
          spoilerText: trimmedSpoiler,
          altTexts: cleanedAlts,
          sourceLanguage: src,
          targetLanguage: tgt,
        );
      } catch (e) {
        configuredAiError = e;
      }
    }

    // 5. Final fallback: Mastodon server POST /api/v1/statuses/:id/translate.
    Object? mastodonError;
    final cleanStatusId = (statusId ?? '').trim();
    if (_mastodon != null &&
        session != null &&
        cleanStatusId.isNotEmpty &&
        (instanceLimits?.translationEnabled ?? false)) {
      try {
        return await _translateWithMastodonServer(
          session: session,
          statusId: cleanStatusId,
          sourceLanguage: src,
          targetLanguage: tgt,
        );
      } catch (e) {
        mastodonError = e;
      }
    }

    final failure = configuredAiError ?? mastodonError ?? mlKitError ?? appleError;
    if (failure != null) {
      throw StateError(_formatFriendlyError(failure));
    }
    throw StateError(
      'Translation is not supported on this device. Configure an AI provider in Settings or use a Mastodon server with translation enabled.',
    );
  }

  Future<PostTranslationResult> _translateFieldsWithRunner({
    required String text,
    required String spoilerText,
    required Map<String, String> altTexts,
    required String sourceLanguage,
    required String targetLanguage,
    required String engineName,
    required Future<String> Function(String input) translateField,
  }) async {
    final translatedBody = text.isEmpty ? '' : await translateField(text);
    final translatedCw =
        spoilerText.isEmpty ? null : await translateField(spoilerText);
    final translatedAlts = <String, String>{};
    for (final entry in altTexts.entries) {
      translatedAlts[entry.key] = await translateField(entry.value);
    }
    return PostTranslationResult(
      translatedText: translatedBody,
      translatedSpoiler: translatedCw,
      translatedAltTexts: translatedAlts,
      sourceLanguage: sourceLanguage,
      targetLanguage: targetLanguage,
      engineName: engineName,
    );
  }

  Future<bool> _isAppleTranslationSupported() async {
    if (_cachedAppleSupported != null) return _cachedAppleSupported!;
    if (_appleSupportCheck != null) {
      _cachedAppleSupported = await _appleSupportCheck();
      return _cachedAppleSupported!;
    }
    if (!_isApplePlatform) return false;
    try {
      final res = await _appleChannel.invokeMethod<bool>('isSupported');
      _cachedAppleSupported = res ?? false;
      return _cachedAppleSupported!;
    } catch (_) {
      _cachedAppleSupported = false;
      return false;
    }
  }

  String _buildTranslationSystemPrompt(String srcName, String tgtName) {
    return 'You are a precise translator. Translate the user\'s social media post from $srcName into $tgtName. '
        'Preserve meaning, tone, @mentions, #hashtags, URLs, and line breaks. '
        'Return ONLY the translated text with no preamble, notes, or surrounding quotation marks.';
  }

  Future<String> _translateWithOnDeviceAi({
    required String text,
    required String sourceLanguage,
    required String targetLanguage,
  }) async {
    final srcName = languageDisplayName(sourceLanguage);
    final tgtName = languageDisplayName(targetLanguage);
    final raw = await _onDeviceAi.runPrompt(
      systemPrompt: _buildTranslationSystemPrompt(srcName, tgtName),
      userPrompt: text,
    );
    return _stripWrappingQuotes(raw.trim());
  }

  Future<String> _runConfiguredAiSinglePrompt({
    required AppSettings settings,
    required AiCredentials credentials,
    required String srcName,
    required String tgtName,
    required String input,
  }) async {
    final raw = await _aiProvider!.runMultimodalPrompt(
      settings: settings,
      credentials: credentials,
      systemPrompt: _buildTranslationSystemPrompt(srcName, tgtName),
      userPrompt: input,
    );
    final cleaned = _stripWrappingQuotes(raw.trim());
    if (cleaned.isEmpty) {
      throw StateError('AI provider returned an empty translation.');
    }
    return cleaned;
  }

  Future<PostTranslationResult> _translateWithConfiguredAi({
    required AppSettings settings,
    required AiCredentials credentials,
    required String text,
    required String spoilerText,
    required Map<String, String> altTexts,
    required String sourceLanguage,
    required String targetLanguage,
  }) async {
    final srcName = languageDisplayName(sourceLanguage);
    final tgtName = languageDisplayName(targetLanguage);
    final engineName = _configuredAiEngineName(settings);

    final fields = <String, String>{};
    if (text.isNotEmpty) fields['body'] = text;
    if (spoilerText.isNotEmpty) fields['spoiler'] = spoilerText;
    final altKeyToMediaId = <String, String>{};
    var altIdx = 0;
    for (final entry in altTexts.entries) {
      final jsonKey = 'alt_${altIdx++}';
      fields[jsonKey] = entry.value;
      altKeyToMediaId[jsonKey] = entry.key;
    }

    if (fields.length == 1) {
      return _translateFieldsWithRunner(
        text: text,
        spoilerText: spoilerText,
        altTexts: altTexts,
        sourceLanguage: sourceLanguage,
        targetLanguage: targetLanguage,
        engineName: engineName,
        translateField: (input) => _runConfiguredAiSinglePrompt(
          settings: settings,
          credentials: credentials,
          srcName: srcName,
          tgtName: tgtName,
          input: input,
        ),
      );
    }

    final raw = await _aiProvider!.runMultimodalPrompt(
      settings: settings,
      credentials: credentials,
      systemPrompt:
          'You are a precise translator. Translate every string value in the provided JSON object from $srcName into $tgtName. '
          'Preserve meaning, tone, @mentions, #hashtags, URLs, and line breaks. '
          'Return ONLY a valid JSON object containing the exact same keys (${fields.keys.join(', ')}) with their translated string values.',
      userPrompt: jsonEncode(fields),
      expectJson: true,
    );

    final decoded = _tryDecodeJsonObject(raw) ?? const <String, dynamic>{};
    final resolved = <String, String>{};
    for (final entry in fields.entries) {
      final candidate = decoded[entry.key];
      if (candidate is String && candidate.trim().isNotEmpty) {
        resolved[entry.key] = _stripWrappingQuotes(candidate.trim());
      } else {
        resolved[entry.key] = await _runConfiguredAiSinglePrompt(
          settings: settings,
          credentials: credentials,
          srcName: srcName,
          tgtName: tgtName,
          input: entry.value,
        );
      }
    }

    return PostTranslationResult(
      translatedText: resolved['body'] ?? '',
      translatedSpoiler: spoilerText.isEmpty ? null : resolved['spoiler'],
      translatedAltTexts: {
        for (final pair in altKeyToMediaId.entries)
          pair.value: resolved[pair.key] ?? '',
      },
      sourceLanguage: sourceLanguage,
      targetLanguage: targetLanguage,
      engineName: engineName,
    );
  }

  Future<PostTranslationResult> _translateWithMastodonServer({
    required MastodonSession session,
    required String statusId,
    required String sourceLanguage,
    required String targetLanguage,
  }) async {
    final res = await _mastodon!.translateStatus(
      instanceUrl: session.instanceUrl,
      accessToken: session.accessToken,
      statusId: statusId,
      targetLanguage: targetLanguage,
    );
    final translatedBody = res.plainContent;
    final translatedCw =
        res.spoilerText.trim().isEmpty ? null : res.spoilerText.trim();
    final translatedAlts = res.mediaDescriptions;
    if (translatedBody.isEmpty &&
        translatedCw == null &&
        translatedAlts.isEmpty) {
      throw StateError('Mastodon translation returned an empty response.');
    }
    final detectedSrc =
        normalizeLanguageCode(res.detectedSourceLanguage) ?? sourceLanguage;
    final provider = res.provider.trim();
    return PostTranslationResult(
      translatedText: translatedBody,
      translatedSpoiler: translatedCw,
      translatedAltTexts: translatedAlts,
      sourceLanguage: detectedSrc,
      targetLanguage: targetLanguage,
      engineName: provider.isNotEmpty ? 'Mastodon ($provider)' : 'Mastodon',
    );
  }

  static Map<String, dynamic>? _tryDecodeJsonObject(String raw) {
    var trimmed = raw.trim();
    if (trimmed.startsWith('```')) {
      trimmed = trimmed
          .replaceFirst(RegExp(r'^```(?:json)?\s*', caseSensitive: false), '')
          .replaceFirst(RegExp(r'\s*```$'), '')
          .trim();
    }
    final start = trimmed.indexOf('{');
    final end = trimmed.lastIndexOf('}');
    if (start == -1 || end <= start) return null;
    try {
      final decoded = jsonDecode(trimmed.substring(start, end + 1));
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  Future<String> _runAppleTranslate({
    required String text,
    required String sourceLanguage,
    required String targetLanguage,
  }) async {
    if (_appleTranslate != null) {
      return _appleTranslate(
        text: text,
        sourceLanguage: sourceLanguage,
        targetLanguage: targetLanguage,
      );
    }
    final translated = await _appleChannel.invokeMethod<String>(
      'translate',
      {
        'text': text,
        'sourceLanguage': sourceLanguage,
        'targetLanguage': targetLanguage,
      },
    );
    if (translated == null || translated.trim().isEmpty) {
      throw StateError('Apple Translation returned an empty response.');
    }
    return translated.trim();
  }

  Future<String> _runMlKitTranslate({
    required String text,
    required String sourceLanguage,
    required String targetLanguage,
  }) async {
    if (_mlKitTranslate != null) {
      return _mlKitTranslate(
        text: text,
        sourceLanguage: sourceLanguage,
        targetLanguage: targetLanguage,
      );
    }

    final srcLang = _toMlKitLanguage(sourceLanguage);
    final tgtLang = _toMlKitLanguage(targetLanguage);
    if (srcLang == null || tgtLang == null) {
      throw StateError(
        'ML Kit on-device translation does not support '
        '${languageDisplayName(sourceLanguage)} → ${languageDisplayName(targetLanguage)}.',
      );
    }

    final modelManager = OnDeviceTranslatorModelManager();
    for (final lang in [srcLang, tgtLang]) {
      final downloaded = await modelManager.isModelDownloaded(lang.bcpCode);
      if (!downloaded) {
        final ok = await modelManager.downloadModel(
          lang.bcpCode,
          isWifiRequired: false,
        );
        if (!ok) {
          throw StateError(
            'Could not download the offline ${languageDisplayName(lang.bcpCode)} translation model.',
          );
        }
      }
    }

    final translator = OnDeviceTranslator(
      sourceLanguage: srcLang,
      targetLanguage: tgtLang,
    );
    try {
      final translated = await translator.translateText(text);
      if (translated.trim().isEmpty) {
        throw StateError('ML Kit Translation returned an empty response.');
      }
      return translated.trim();
    } finally {
      await translator.close();
    }
  }

  static TranslateLanguage? _toMlKitLanguage(String bcpCode) {
    for (final lang in TranslateLanguage.values) {
      if (lang.bcpCode == bcpCode) return lang;
    }
    return null;
  }

  static String _stripUrlsAndMentions(String input) {
    return input
        .replaceAll(RegExp(r'https?://\S+'), ' ')
        .replaceAll(RegExp(r'@[A-Za-z0-9_.\-@]+'), ' ')
        .replaceAll(RegExp(r'#[\p{L}\p{N}_]+', unicode: true), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static String _stripWrappingQuotes(String input) {
    if (input.length >= 2 &&
        ((input.startsWith('"') && input.endsWith('"')) ||
            (input.startsWith('“') && input.endsWith('”')))) {
      return input.substring(1, input.length - 1).trim();
    }
    return input;
  }

  static String _formatFriendlyError(Object error) {
    if (error is PlatformException) {
      return error.message ?? error.code;
    }
    final raw = error.toString();
    if (raw.startsWith('Bad state: ')) {
      return raw.substring('Bad state: '.length);
    }
    return raw;
  }

  /// Lightweight Unicode script heuristic used only when a post has no
  /// `language` tag and native language identification is unavailable.
  static String? detectScriptLanguage(String text) =>
      LanguageRegistry.detectScriptLanguage(text);
}
