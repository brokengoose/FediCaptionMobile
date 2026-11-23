// Copyright (c) 2026 brokengoose <brokengoose@users.noreply.github.com>
// SPDX-License-Identifier: MIT

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart';

import 'on_device_ai_service.dart';

/// Result of translating a Mastodon post (and optional Content Warning).
class PostTranslationResult {
  const PostTranslationResult({
    required this.translatedText,
    this.translatedSpoiler,
    required this.sourceLanguage,
    required this.targetLanguage,
    required this.engineName,
  });

  final String translatedText;
  final String? translatedSpoiler;
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

/// On-device post translation service prioritizing built-in OS on-device AI
/// (Apple Foundation Models / Google Gemini Nano), with automatic fallback to:
/// - Apple's `Translation` framework on iOS 18+ and macOS 15+
/// - `google_mlkit_translation` on Android (and iOS fallback when needed)
class TranslationService {
  TranslationService({
    required OnDeviceAiService onDeviceAi,
    TargetPlatform? platformOverride,
    bool? isWebOverride,
    String Function()? osLanguageProvider,
    AppleSupportCheckCallback? appleSupportCheck,
    NativeLanguageDetectCallback? nativeLanguageDetect,
    AppleTranslateCallback? appleTranslate,
    MlKitTranslateCallback? mlKitTranslate,
  })  : _onDeviceAi = onDeviceAi,
        _platformOverride = platformOverride,
        _isWebOverride = isWebOverride,
        _osLanguageProvider = osLanguageProvider,
        _appleSupportCheck = appleSupportCheck,
        _nativeLanguageDetect = nativeLanguageDetect,
        _appleTranslate = appleTranslate,
        _mlKitTranslate = mlKitTranslate;

  static const MethodChannel _appleChannel = MethodChannel(
    'io.github.brokengoose.fedicaption/apple_translation',
  );

  final OnDeviceAiService _onDeviceAi;
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
  static String? normalizeLanguageCode(String? raw) {
    if (raw == null) return null;
    final trimmed = raw.trim().toLowerCase();
    if (trimmed.isEmpty || trimmed == 'und' || trimmed == 'unknown') {
      return null;
    }
    final primary = trimmed.split(RegExp(r'[-_]')).first;
    if (primary.length < 2 || primary.length > 3) return null;
    if (!RegExp(r'^[a-z]{2,3}$').hasMatch(primary)) return null;
    // Normalize Norwegian Bokmål / Nynorsk to 'no' for matching consistency.
    if (primary == 'nb' || primary == 'nn') return 'no';
    return primary;
  }

  /// Returns a human-readable display name for an ISO 639-1 language code.
  static String languageDisplayName(String code) {
    final normalized = normalizeLanguageCode(code) ?? code.trim().toLowerCase();
    return _languageNames[normalized] ?? normalized.toUpperCase();
  }

  /// Returns `true` when the current platform supports on-device translation
  /// via on-device AI, Apple's Translation framework, or Google ML Kit.
  Future<bool> isTranslationSupported() async {
    if (_isWeb) return false;
    if (_isAndroid || _isIos) return true;

    if (_platform == TargetPlatform.macOS) {
      if (await _isAppleTranslationSupported()) return true;
      try {
        final aiStatus = await _onDeviceAi.checkStatus();
        return aiStatus.isPromptReady || aiStatus.isPromptDownloadable;
      } catch (_) {
        return false;
      }
    }

    try {
      final aiStatus = await _onDeviceAi.checkStatus();
      return aiStatus.isPromptReady;
    } catch (_) {
      return false;
    }
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

  /// Translates [text] (and optional [spoilerText]) from [sourceLanguage] to
  /// [targetLanguage] using:
  /// 1. On-Device AI (`Apple Foundation Models` / `Google Gemini Nano`) when ready
  /// 2. Apple's `Translation` framework on iOS 18+ and macOS 15+
  /// 3. `google_mlkit_translation` on Android (and iOS fallback)
  Future<PostTranslationResult> translatePost({
    required String text,
    String? spoilerText,
    required String sourceLanguage,
    String? targetLanguage,
  }) async {
    final src = normalizeLanguageCode(sourceLanguage) ?? sourceLanguage.trim();
    final tgt = normalizeLanguageCode(targetLanguage) ?? currentOsLanguageCode();
    final trimmedText = text.trim();
    final trimmedSpoiler = (spoilerText ?? '').trim();

    if (trimmedText.isEmpty && trimmedSpoiler.isEmpty) {
      throw StateError('There is no text to translate in this post.');
    }

    // 1. Primary: On-device AI (Apple Foundation Models / Gemini Nano) when ready.
    try {
      final aiStatus = await _onDeviceAi.checkStatus();
      if (aiStatus.isPromptReady) {
        final translatedBody = trimmedText.isEmpty
            ? ''
            : await _translateWithOnDeviceAi(
                text: trimmedText,
                sourceLanguage: src,
                targetLanguage: tgt,
              );
        final translatedCw = trimmedSpoiler.isEmpty
            ? null
            : await _translateWithOnDeviceAi(
                text: trimmedSpoiler,
                sourceLanguage: src,
                targetLanguage: tgt,
              );
        return PostTranslationResult(
          translatedText: translatedBody,
          translatedSpoiler: translatedCw,
          sourceLanguage: src,
          targetLanguage: tgt,
          engineName: aiStatus.engineName,
        );
      }
    } catch (_) {
      // Fall through to dedicated native on-device translation frameworks.
    }

    // 2. Fallback on iOS & macOS: Apple's Translation framework.
    Object? appleError;
    if (_isApplePlatform) {
      final supported = await _isAppleTranslationSupported();
      if (supported) {
        try {
          final translatedBody = trimmedText.isEmpty
              ? ''
              : await _runAppleTranslate(
                  text: trimmedText,
                  sourceLanguage: src,
                  targetLanguage: tgt,
                );
          final translatedCw = trimmedSpoiler.isEmpty
              ? null
              : await _runAppleTranslate(
                  text: trimmedSpoiler,
                  sourceLanguage: src,
                  targetLanguage: tgt,
                );
          return PostTranslationResult(
            translatedText: translatedBody,
            translatedSpoiler: translatedCw,
            sourceLanguage: src,
            targetLanguage: tgt,
            engineName: 'Apple Translation',
          );
        } catch (e) {
          appleError = e;
          // On macOS there is no ML Kit fallback; on iOS fall through to ML Kit.
          if (!_isIos) {
            throw StateError(_formatFriendlyError(e));
          }
        }
      }
    }

    // 3. Fallback on Android (and iOS if Apple Translation was unavailable/unsupported):
    //    google_mlkit_translation.
    if (_isAndroid || _isIos) {
      try {
        final translatedBody = trimmedText.isEmpty
            ? ''
            : await _runMlKitTranslate(
                text: trimmedText,
                sourceLanguage: src,
                targetLanguage: tgt,
              );
        final translatedCw = trimmedSpoiler.isEmpty
            ? null
            : await _runMlKitTranslate(
                text: trimmedSpoiler,
                sourceLanguage: src,
                targetLanguage: tgt,
              );
        return PostTranslationResult(
          translatedText: translatedBody,
          translatedSpoiler: translatedCw,
          sourceLanguage: src,
          targetLanguage: tgt,
          engineName: 'ML Kit Translation',
        );
      } catch (e) {
        throw StateError(_formatFriendlyError(e));
      }
    }

    if (appleError != null) {
      throw StateError(_formatFriendlyError(appleError));
    }
    throw StateError(
      'On-device translation is not supported on this device.',
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

  Future<String> _translateWithOnDeviceAi({
    required String text,
    required String sourceLanguage,
    required String targetLanguage,
  }) async {
    final srcName = languageDisplayName(sourceLanguage);
    final tgtName = languageDisplayName(targetLanguage);
    final raw = await _onDeviceAi.runPrompt(
      systemPrompt:
          'You are a precise translator. Translate the user\'s social media post from $srcName into $tgtName. '
          'Preserve meaning, tone, @mentions, #hashtags, URLs, and line breaks. '
          'Return ONLY the translated text with no preamble, notes, or surrounding quotation marks.',
      userPrompt: text,
    );
    return _stripWrappingQuotes(raw.trim());
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
        .replaceAll(RegExp(r'#[A-Za-z0-9_]+'), ' ')
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
  static String? detectScriptLanguage(String text) {
    var hiraganaKatakana = 0;
    var hangul = 0;
    var cjk = 0;
    var cyrillic = 0;
    var greek = 0;
    var arabic = 0;
    var hebrew = 0;
    var devanagari = 0;
    var thai = 0;

    for (final rune in text.runes) {
      if ((rune >= 0x3040 && rune <= 0x30FF)) {
        hiraganaKatakana++;
      } else if (rune >= 0xAC00 && rune <= 0xD7AF) {
        hangul++;
      } else if (rune >= 0x4E00 && rune <= 0x9FFF) {
        cjk++;
      } else if (rune >= 0x0400 && rune <= 0x04FF) {
        cyrillic++;
      } else if (rune >= 0x0370 && rune <= 0x03FF) {
        greek++;
      } else if (rune >= 0x0600 && rune <= 0x06FF) {
        arabic++;
      } else if (rune >= 0x0590 && rune <= 0x05FF) {
        hebrew++;
      } else if (rune >= 0x0900 && rune <= 0x097F) {
        devanagari++;
      } else if (rune >= 0x0E00 && rune <= 0x0E7F) {
        thai++;
      }
    }

    if (hiraganaKatakana >= 2) return 'ja';
    if (hangul >= 2) return 'ko';
    if (cjk >= 3) return 'zh';
    if (cyrillic >= 4) return 'ru';
    if (greek >= 4) return 'el';
    if (arabic >= 4) return 'ar';
    if (hebrew >= 4) return 'he';
    if (devanagari >= 4) return 'hi';
    if (thai >= 4) return 'th';
    return null;
  }

  static const Map<String, String> _languageNames = {
    'af': 'Afrikaans',
    'ar': 'Arabic',
    'bg': 'Bulgarian',
    'bn': 'Bengali',
    'ca': 'Catalan',
    'cs': 'Czech',
    'cy': 'Welsh',
    'da': 'Danish',
    'de': 'German',
    'el': 'Greek',
    'en': 'English',
    'eo': 'Esperanto',
    'es': 'Spanish',
    'et': 'Estonian',
    'eu': 'Basque',
    'fa': 'Persian',
    'fi': 'Finnish',
    'fr': 'French',
    'ga': 'Irish',
    'gl': 'Galician',
    'he': 'Hebrew',
    'hi': 'Hindi',
    'hr': 'Croatian',
    'hu': 'Hungarian',
    'id': 'Indonesian',
    'is': 'Icelandic',
    'it': 'Italian',
    'ja': 'Japanese',
    'ko': 'Korean',
    'lt': 'Lithuanian',
    'lv': 'Latvian',
    'ms': 'Malay',
    'nl': 'Dutch',
    'no': 'Norwegian',
    'pl': 'Polish',
    'pt': 'Portuguese',
    'ro': 'Romanian',
    'ru': 'Russian',
    'sk': 'Slovak',
    'sl': 'Slovenian',
    'sr': 'Serbian',
    'sv': 'Swedish',
    'sw': 'Swahili',
    'ta': 'Tamil',
    'te': 'Telugu',
    'th': 'Thai',
    'tl': 'Tagalog',
    'tr': 'Turkish',
    'uk': 'Ukrainian',
    'ur': 'Urdu',
    'vi': 'Vietnamese',
    'zh': 'Chinese',
  };
}
