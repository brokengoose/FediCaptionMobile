// Copyright (c) 2026 brokengoose <brokengoose@users.noreply.github.com>
// SPDX-License-Identifier: MIT

import 'dart:ui';

import '../core/constants.dart';
import 'ai_models.dart';
import 'mastodon_models.dart';

/// Shared policy mode for both Accessibility Rules (alt-text) and Bias Rules.
enum PolicyMode {
  warn('warn'),
  require('require'),
  off('off');

  const PolicyMode(this.id);

  final String id;

  static PolicyMode fromId(String? id) {
    return PolicyMode.values.firstWhere(
      (e) => e.id == id,
      orElse: () => PolicyMode.warn,
    );
  }
}

/// User theme choice. Defaults to [system] which automatically detects OS
/// Light Mode, Dark Mode, and High Contrast / Increased Contrast settings.
enum ThemePreference {
  system('system'),
  dark('dark'),
  light('light'),
  highContrast('high_contrast');

  const ThemePreference(this.id);

  final String id;

  static ThemePreference fromId(String? id) {
    return ThemePreference.values.firstWhere(
      (e) => e.id == id,
      orElse: () => ThemePreference.system,
    );
  }
}

/// Non-secret user settings persisted via SharedPreferences.
class AppSettings {
  const AppSettings({
    this.activeProvider = AiProviderType.onDevice,
    this.onDeviceModel = 'on-device-auto',
    this.geminiModel = 'gemini-2.5-flash',
    this.openAiModel = 'gpt-4o-mini',
    this.openAiBaseUrl = AppConstants.openAiDefaultBaseUrl,
    this.anthropicModel = 'claude-sonnet-4-20250514',
    this.localModel = 'llama3.2-vision',
    this.localBaseUrl = AppConstants.localDefaultBaseUrl,
    this.defaultDetailLevel = CaptionDetailLevel.descriptive,
    this.videoKeyframeCount = 4,
    this.autoGenerate = true,
    this.includePostContext = true,
    this.language = 'English',
    this.customInstructions = '',
    this.altTextPolicy = PolicyMode.warn,
    this.biasPolicy = PolicyMode.warn,
    this.themePreference = ThemePreference.system,
    this.aiSetupCompleted = false,
    this.ttsSpeechRate = 0.5,
    this.appLocale,
  });

  final AiProviderType activeProvider;
  final String onDeviceModel;
  final String geminiModel;
  final String openAiModel;
  final String openAiBaseUrl;
  final String anthropicModel;
  final String localModel;
  final String localBaseUrl;
  final CaptionDetailLevel defaultDetailLevel;
  final int videoKeyframeCount;
  final bool autoGenerate;
  final bool includePostContext;
  final String language;
  final String customInstructions;
  final PolicyMode altTextPolicy;
  final PolicyMode biasPolicy;
  final ThemePreference themePreference;
  final bool aiSetupCompleted;
  final double ttsSpeechRate;

  /// Optional BCP-47 UI locale override (e.g. `'en'`, `'es'`, `'pt_BR'`).
  /// When `null`, FediCaption follows the operating system locale.
  final String? appLocale;

  /// Parses [appLocale] into a Flutter [Locale], or `null` if unset/invalid.
  Locale? get resolvedAppLocale {
    final raw = appLocale?.trim();
    if (raw == null || raw.isEmpty) return null;
    final parts = raw
        .split(RegExp(r'[-_]'))
        .where((p) => p.trim().isNotEmpty)
        .toList();
    if (parts.isEmpty) return null;
    final languageCode = parts[0].toLowerCase();
    if (!RegExp(r'^[a-z]{2,3}$').hasMatch(languageCode)) return null;
    if (parts.length == 1) {
      return Locale(languageCode);
    }
    if (parts.length == 2) {
      final second = parts[1];
      if (second.length == 4) {
        return Locale.fromSubtags(
          languageCode: languageCode,
          scriptCode:
              second[0].toUpperCase() + second.substring(1).toLowerCase(),
        );
      }
      return Locale(languageCode, second.toUpperCase());
    }
    return Locale.fromSubtags(
      languageCode: languageCode,
      scriptCode:
          parts[1][0].toUpperCase() + parts[1].substring(1).toLowerCase(),
      countryCode: parts[2].toUpperCase(),
    );
  }

  bool get isAiEnabled => activeProvider != AiProviderType.none;

  String modelForProvider(AiProviderType provider) {
    switch (provider) {
      case AiProviderType.onDevice:
        return onDeviceModel;
      case AiProviderType.gemini:
        return geminiModel;
      case AiProviderType.openai:
        return openAiModel;
      case AiProviderType.anthropic:
        return anthropicModel;
      case AiProviderType.local:
        return localModel;
      case AiProviderType.none:
        return '';
    }
  }

  String get activeModel => modelForProvider(activeProvider);

  AppSettings withModelForProvider(AiProviderType provider, String model) {
    switch (provider) {
      case AiProviderType.onDevice:
        return copyWith(onDeviceModel: model);
      case AiProviderType.gemini:
        return copyWith(geminiModel: model);
      case AiProviderType.openai:
        return copyWith(openAiModel: model);
      case AiProviderType.anthropic:
        return copyWith(anthropicModel: model);
      case AiProviderType.local:
        return copyWith(localModel: model);
      case AiProviderType.none:
        return this;
    }
  }

  AppSettings copyWith({
    AiProviderType? activeProvider,
    String? onDeviceModel,
    String? geminiModel,
    String? openAiModel,
    String? openAiBaseUrl,
    String? anthropicModel,
    String? localModel,
    String? localBaseUrl,
    CaptionDetailLevel? defaultDetailLevel,
    int? videoKeyframeCount,
    bool? autoGenerate,
    bool? includePostContext,
    String? language,
    String? customInstructions,
    PolicyMode? altTextPolicy,
    PolicyMode? biasPolicy,
    ThemePreference? themePreference,
    bool? aiSetupCompleted,
    double? ttsSpeechRate,
    String? appLocale,
    bool clearAppLocale = false,
  }) {
    return AppSettings(
      activeProvider: activeProvider ?? this.activeProvider,
      onDeviceModel: onDeviceModel ?? this.onDeviceModel,
      geminiModel: geminiModel ?? this.geminiModel,
      openAiModel: openAiModel ?? this.openAiModel,
      openAiBaseUrl: openAiBaseUrl ?? this.openAiBaseUrl,
      anthropicModel: anthropicModel ?? this.anthropicModel,
      localModel: localModel ?? this.localModel,
      localBaseUrl: localBaseUrl ?? this.localBaseUrl,
      defaultDetailLevel: defaultDetailLevel ?? this.defaultDetailLevel,
      videoKeyframeCount: videoKeyframeCount ?? this.videoKeyframeCount,
      autoGenerate: autoGenerate ?? this.autoGenerate,
      includePostContext: includePostContext ?? this.includePostContext,
      language: language ?? this.language,
      customInstructions: customInstructions ?? this.customInstructions,
      altTextPolicy: altTextPolicy ?? this.altTextPolicy,
      biasPolicy: biasPolicy ?? this.biasPolicy,
      themePreference: themePreference ?? this.themePreference,
      aiSetupCompleted: aiSetupCompleted ?? this.aiSetupCompleted,
      ttsSpeechRate: ttsSpeechRate ?? this.ttsSpeechRate,
      appLocale: clearAppLocale ? null : (appLocale ?? this.appLocale),
    );
  }

  Map<String, dynamic> toJson() => {
    'activeProvider': activeProvider.id,
    'onDeviceModel': onDeviceModel,
    'geminiModel': geminiModel,
    'openAiModel': openAiModel,
    'openAiBaseUrl': openAiBaseUrl,
    'anthropicModel': anthropicModel,
    'localModel': localModel,
    'localBaseUrl': localBaseUrl,
    'defaultDetailLevel': defaultDetailLevel.id,
    'videoKeyframeCount': videoKeyframeCount,
    'autoGenerate': autoGenerate,
    'includePostContext': includePostContext,
    'language': language,
    'customInstructions': customInstructions,
    'altTextPolicy': altTextPolicy.id,
    'biasPolicy': biasPolicy.id,
    'themePreference': themePreference.id,
    'aiSetupCompleted': aiSetupCompleted,
    'ttsSpeechRate': ttsSpeechRate,
    'appLocale': appLocale,
  };

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    final keyframeCount = json['videoKeyframeCount'] as int? ?? 4;
    final rawRate = (json['ttsSpeechRate'] as num?)?.toDouble() ?? 0.5;
    final rawLocalModel = (json['localModel'] as String?) ?? 'llama3.2-vision';
    // Migrate legacy 'on-device-fallback' selection (removed from Local LAN list).
    final normalizedLocalModel = rawLocalModel == 'on-device-fallback'
        ? 'llama3.2-vision'
        : rawLocalModel;
    final rawAppLocale = (json['appLocale'] as String?)?.trim();
    return AppSettings(
      activeProvider: AiProviderType.fromId(json['activeProvider'] as String?),
      onDeviceModel: (json['onDeviceModel'] as String?) ?? 'on-device-auto',
      geminiModel: (json['geminiModel'] as String?) ?? 'gemini-2.5-flash',
      openAiModel: (json['openAiModel'] as String?) ?? 'gpt-4o-mini',
      openAiBaseUrl:
          (json['openAiBaseUrl'] as String?) ??
          AppConstants.openAiDefaultBaseUrl,
      anthropicModel:
          (json['anthropicModel'] as String?) ?? 'claude-sonnet-4-20250514',
      localModel: normalizedLocalModel,
      localBaseUrl:
          (json['localBaseUrl'] as String?) ?? AppConstants.localDefaultBaseUrl,
      defaultDetailLevel: CaptionDetailLevel.fromId(
        json['defaultDetailLevel'] as String?,
      ),
      videoKeyframeCount:
          (keyframeCount == 3 || keyframeCount == 4 || keyframeCount == 6)
          ? keyframeCount
          : 4,
      autoGenerate: json['autoGenerate'] as bool? ?? true,
      includePostContext: json['includePostContext'] as bool? ?? true,
      language: (json['language'] as String?) ?? 'English',
      customInstructions: (json['customInstructions'] as String?) ?? '',
      altTextPolicy: PolicyMode.fromId(json['altTextPolicy'] as String?),
      biasPolicy: PolicyMode.fromId(json['biasPolicy'] as String?),
      themePreference: ThemePreference.fromId(
        json['themePreference'] as String?,
      ),
      aiSetupCompleted: json['aiSetupCompleted'] as bool? ?? false,
      ttsSpeechRate: rawRate.clamp(0.25, 1.0),
      appLocale: (rawAppLocale == null || rawAppLocale.isEmpty)
          ? null
          : rawAppLocale,
    );
  }
}

/// Sensitive AI API keys stored strictly in platform secure storage (Keychain / Keystore).
class AiCredentials {
  const AiCredentials({
    this.geminiApiKey = '',
    this.openAiApiKey = '',
    this.anthropicApiKey = '',
    this.localApiKey = '',
  });

  final String geminiApiKey;
  final String openAiApiKey;
  final String anthropicApiKey;
  final String localApiKey;

  String apiKeyFor(AiProviderType provider) {
    switch (provider) {
      case AiProviderType.onDevice:
        return '';
      case AiProviderType.gemini:
        return geminiApiKey;
      case AiProviderType.openai:
        return openAiApiKey;
      case AiProviderType.anthropic:
        return anthropicApiKey;
      case AiProviderType.local:
        return localApiKey;
      case AiProviderType.none:
        return '';
    }
  }

  AiCredentials copyWith({
    String? geminiApiKey,
    String? openAiApiKey,
    String? anthropicApiKey,
    String? localApiKey,
  }) {
    return AiCredentials(
      geminiApiKey: geminiApiKey ?? this.geminiApiKey,
      openAiApiKey: openAiApiKey ?? this.openAiApiKey,
      anthropicApiKey: anthropicApiKey ?? this.anthropicApiKey,
      localApiKey: localApiKey ?? this.localApiKey,
    );
  }
}

/// Stored Mastodon account credentials.
class MastodonSession {
  const MastodonSession({required this.instanceUrl, required this.accessToken});

  final String instanceUrl;
  final String accessToken;
}

/// Persisted Mastodon account metadata paired with a securely stored OAuth/API token.
class StoredAccount {
  const StoredAccount({
    required this.key,
    required this.instanceUrl,
    required this.accessToken,
    required this.accountId,
    required this.username,
    required this.acct,
    required this.displayName,
    this.avatar = '',
  });

  final String key;
  final String instanceUrl;
  final String accessToken;
  final String accountId;
  final String username;
  final String acct;
  final String displayName;
  final String avatar;

  String get instanceHost {
    final parsed = Uri.tryParse(instanceUrl);
    if (parsed != null && parsed.host.isNotEmpty) {
      return parsed.host.toLowerCase();
    }
    return instanceUrl
        .trim()
        .replaceFirst(RegExp(r'^https?://', caseSensitive: false), '')
        .split('/')
        .first
        .toLowerCase();
  }

  /// Canonical `@username@server` handle so identically named accounts on
  /// different Mastodon servers are always clearly distinguishable.
  String get fullHandle {
    final cleanAcct = acct.trim().replaceFirst(RegExp(r'^@+'), '');
    if (cleanAcct.contains('@')) {
      return '@$cleanAcct';
    }
    final user = cleanAcct.isNotEmpty ? cleanAcct : username.trim();
    final host = instanceHost;
    return host.isNotEmpty ? '@$user@$host' : '@$user';
  }

  String get effectiveDisplayName =>
      displayName.trim().isNotEmpty ? displayName.trim() : username;

  MastodonSession get session =>
      MastodonSession(instanceUrl: instanceUrl, accessToken: accessToken);

  static String buildKey(String instanceUrl, String accountId) {
    final cleanUrl = instanceUrl
        .trim()
        .replaceAll(RegExp(r'/+$'), '')
        .toLowerCase();
    return '$cleanUrl::${accountId.trim()}';
  }

  factory StoredAccount.fromSessionAndAccount({
    required MastodonSession session,
    required MastodonAccount account,
  }) {
    final cleanInstance = session.instanceUrl.trim().replaceAll(
      RegExp(r'/+$'),
      '',
    );
    return StoredAccount(
      key: buildKey(cleanInstance, account.id),
      instanceUrl: cleanInstance,
      accessToken: session.accessToken,
      accountId: account.id,
      username: account.username,
      acct: account.acct,
      displayName: account.displayName,
      avatar: account.avatar,
    );
  }

  StoredAccount copyWith({
    String? accessToken,
    String? username,
    String? acct,
    String? displayName,
    String? avatar,
  }) {
    return StoredAccount(
      key: key,
      instanceUrl: instanceUrl,
      accessToken: accessToken ?? this.accessToken,
      accountId: accountId,
      username: username ?? this.username,
      acct: acct ?? this.acct,
      displayName: displayName ?? this.displayName,
      avatar: avatar ?? this.avatar,
    );
  }

  /// Serializes only non-secret account metadata for SharedPreferences.
  /// The access token is stored separately in platform secure storage.
  Map<String, dynamic> toMetadataJson() => {
    'key': key,
    'instanceUrl': instanceUrl,
    'accountId': accountId,
    'username': username,
    'acct': acct,
    'displayName': displayName,
    'avatar': avatar,
  };

  static StoredAccount? fromMetadataJson(
    Map<String, dynamic> json, {
    required String accessToken,
  }) {
    final instanceUrl = (json['instanceUrl'] as String?)?.trim() ?? '';
    final accountId = (json['accountId'] as String?)?.trim() ?? '';
    if (instanceUrl.isEmpty || accountId.isEmpty || accessToken.isEmpty) {
      return null;
    }
    final key = (json['key'] as String?)?.trim();
    return StoredAccount(
      key: (key != null && key.isNotEmpty)
          ? key
          : buildKey(instanceUrl, accountId),
      instanceUrl: instanceUrl,
      accessToken: accessToken,
      accountId: accountId,
      username: (json['username'] as String?) ?? '',
      acct: (json['acct'] as String?) ?? '',
      displayName: (json['displayName'] as String?) ?? '',
      avatar: (json['avatar'] as String?) ?? '',
    );
  }
}
