// Copyright (c) 2026 brokengoose <brokengoose@users.noreply.github.com>
// SPDX-License-Identifier: MIT

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_settings.dart';
import '../models/mastodon_models.dart';
import 'mastodon_service.dart';

/// Manages secure storage of tokens/API keys (iOS Keychain / Android Keystore;
/// sandboxed per-app preferences on macOS to avoid ad-hoc Keychain prompt loops)
/// and non-sensitive user preferences.
class StorageService {
  StorageService({
    FlutterSecureStorage? secureStorage,
  })  : _hasCustomSecureStorage = secureStorage != null,
        _secureStorage = secureStorage ??
            const FlutterSecureStorage(
              iOptions: IOSOptions(
                accessibility: KeychainAccessibility.first_unlock_this_device,
              ),
            );

  final bool _hasCustomSecureStorage;
  final FlutterSecureStorage _secureStorage;

  bool get _useMacOsSandboxedPrefs =>
      !_hasCustomSecureStorage &&
      !kIsWeb &&
      defaultTargetPlatform == TargetPlatform.macOS;

  Future<String?> _readSecret(String key) async {
    if (_useMacOsSandboxedPrefs) {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('macos_secret_$key');
    }
    return _secureStorage.read(key: key);
  }

  Future<void> _writeSecret(String key, String value) async {
    if (_useMacOsSandboxedPrefs) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('macos_secret_$key', value);
      return;
    }
    await _secureStorage.write(key: key, value: value);
  }

  Future<void> _deleteSecret(String key) async {
    if (_useMacOsSandboxedPrefs) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('macos_secret_$key');
      return;
    }
    await _secureStorage.delete(key: key);
  }

  static const String _keySettings = 'fedicaption_settings_v1';
  static const String _keyInstanceUrl = 'mastodon_instance_url';
  static const String _keyAccessToken = 'mastodon_access_token';
  static const String _keyGeminiKey = 'ai_key_gemini';
  static const String _keyOpenAiKey = 'ai_key_openai';
  static const String _keyAnthropicKey = 'ai_key_anthropic';
  static const String _keyLocalKey = 'ai_key_local';
  static const String _keyDismissedVersion = 'dismissed_update_version';
  static const String _keyOAuthAppsPrefix = 'oauth_app_creds_v1_';
  static const String _keyInstanceLimitsPrefix = 'instance_limits_v1_';
  static const Duration _instanceLimitsTtl = Duration(hours: 24);

  Future<AppSettings> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keySettings);
    if (raw == null || raw.isEmpty) {
      return const AppSettings();
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return AppSettings.fromJson(decoded);
      }
    } catch (_) {
      // Return defaults if stored JSON is corrupted.
    }
    return const AppSettings();
  }

  Future<void> saveSettings(AppSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keySettings, jsonEncode(settings.toJson()));
  }

  Future<MastodonSession?> loadSession() async {
    final instanceUrl = await _readSecret(_keyInstanceUrl);
    final accessToken = await _readSecret(_keyAccessToken);
    if (instanceUrl == null ||
        instanceUrl.isEmpty ||
        accessToken == null ||
        accessToken.isEmpty) {
      return null;
    }
    return MastodonSession(
      instanceUrl: instanceUrl,
      accessToken: accessToken,
    );
  }

  Future<void> saveSession(MastodonSession session) async {
    await _writeSecret(_keyInstanceUrl, session.instanceUrl);
    await _writeSecret(_keyAccessToken, session.accessToken);
  }

  Future<void> clearSession() async {
    await _deleteSecret(_keyInstanceUrl);
    await _deleteSecret(_keyAccessToken);
  }

  Future<AiCredentials> loadAiCredentials() async {
    final gemini = await _readSecret(_keyGeminiKey) ?? '';
    final openAi = await _readSecret(_keyOpenAiKey) ?? '';
    final anthropic = await _readSecret(_keyAnthropicKey) ?? '';
    final local = await _readSecret(_keyLocalKey) ?? '';
    return AiCredentials(
      geminiApiKey: gemini,
      openAiApiKey: openAi,
      anthropicApiKey: anthropic,
      localApiKey: local,
    );
  }

  Future<void> saveAiCredentials(AiCredentials creds) async {
    await _writeSecret(_keyGeminiKey, creds.geminiApiKey);
    await _writeSecret(_keyOpenAiKey, creds.openAiApiKey);
    await _writeSecret(_keyAnthropicKey, creds.anthropicApiKey);
    await _writeSecret(_keyLocalKey, creds.localApiKey);
  }

  Future<String?> loadDismissedUpdateVersion() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyDismissedVersion);
  }

  Future<void> saveDismissedUpdateVersion(String version) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyDismissedVersion, version);
  }

  /// Loads cached OAuth `client_id` + `client_secret` for [instanceUrl] so
  /// re-authenticating reuses the existing registered Mastodon application
  /// instead of creating duplicate rows in the server's `oauth_applications` table.
  Future<OAuthAppCredentials?> loadOAuthAppCredentials(
    String instanceUrl, {
    String redirectUri = '',
  }) async {
    final key = _instanceKey(
      _keyOAuthAppsPrefix,
      redirectUri.isEmpty ? instanceUrl : '$instanceUrl|$redirectUri',
    );
    final raw = await _readSecret(key);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        final clientId = (decoded['client_id'] as String?) ?? '';
        final clientSecret = (decoded['client_secret'] as String?) ?? '';
        if (clientId.isNotEmpty && clientSecret.isNotEmpty) {
          return OAuthAppCredentials(
            clientId: clientId,
            clientSecret: clientSecret,
          );
        }
      }
    } catch (_) {
      // Ignore corrupted cache entry.
    }
    return null;
  }

  Future<void> saveOAuthAppCredentials(
    String instanceUrl,
    OAuthAppCredentials creds, {
    String redirectUri = '',
  }) async {
    if (creds.clientId.isEmpty || creds.clientSecret.isEmpty) return;
    final key = _instanceKey(
      _keyOAuthAppsPrefix,
      redirectUri.isEmpty ? instanceUrl : '$instanceUrl|$redirectUri',
    );
    await _writeSecret(
      key,
      jsonEncode({
        'client_id': creds.clientId,
        'client_secret': creds.clientSecret,
      }),
    );
  }

  Future<void> clearOAuthAppCredentials(
    String instanceUrl, {
    String redirectUri = '',
  }) async {
    final key = _instanceKey(
      _keyOAuthAppsPrefix,
      redirectUri.isEmpty ? instanceUrl : '$instanceUrl|$redirectUri',
    );
    await _deleteSecret(key);
  }

  /// Loads cached [InstanceLimits] for [instanceUrl] if fetched within 24 hours,
  /// avoiding redundant `/api/v2/instance` calls on every app cold start.
  Future<InstanceLimits?> loadCachedInstanceLimits(String instanceUrl) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _instanceKey(_keyInstanceLimitsPrefix, instanceUrl);
    final raw = prefs.getString(key);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      final fetchedMs = (decoded['fetched_at_ms'] as num?)?.toInt() ?? 0;
      if (fetchedMs <= 0) return null;
      final age = DateTime.now()
          .difference(DateTime.fromMillisecondsSinceEpoch(fetchedMs));
      if (age > _instanceLimitsTtl) return null;
      return InstanceLimits(
        maxCharacters: (decoded['max_characters'] as num?)?.toInt() ?? 500,
        maxMediaAttachments:
            (decoded['max_media_attachments'] as num?)?.toInt() ?? 4,
        altTextLimit: (decoded['alt_text_limit'] as num?)?.toInt() ?? 1500,
        instanceTitle: (decoded['instance_title'] as String?) ?? '',
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> saveCachedInstanceLimits(
    String instanceUrl,
    InstanceLimits limits,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _instanceKey(_keyInstanceLimitsPrefix, instanceUrl);
    await prefs.setString(
      key,
      jsonEncode({
        'fetched_at_ms': DateTime.now().millisecondsSinceEpoch,
        'max_characters': limits.maxCharacters,
        'max_media_attachments': limits.maxMediaAttachments,
        'alt_text_limit': limits.altTextLimit,
        'instance_title': limits.instanceTitle,
      }),
    );
  }

  static String _instanceKey(String prefix, String instanceUrl) {
    final normalized = MastodonService.normalizeInstanceUrl(instanceUrl)
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]'), '_');
    return '$prefix$normalized';
  }
}
