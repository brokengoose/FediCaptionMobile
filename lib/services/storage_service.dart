// Copyright (c) 2026 brokengoose <brokengoose@users.noreply.github.com>
// SPDX-License-Identifier: MIT

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_settings.dart';

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
}
