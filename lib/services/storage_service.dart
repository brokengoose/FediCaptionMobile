// Copyright (c) 2026 brokengoose <brokengoose@users.noreply.github.com>
// SPDX-License-Identifier: MIT

import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_settings.dart';

/// Manages secure storage of tokens/API keys (iOS Keychain / Android Keystore)
/// and non-sensitive user preferences.
class StorageService {
  StorageService({
    FlutterSecureStorage? secureStorage,
  }) : _secureStorage = secureStorage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
              iOptions: IOSOptions(
                accessibility: KeychainAccessibility.first_unlock_this_device,
              ),
            );

  final FlutterSecureStorage _secureStorage;

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
    final instanceUrl = await _secureStorage.read(key: _keyInstanceUrl);
    final accessToken = await _secureStorage.read(key: _keyAccessToken);
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
    await _secureStorage.write(key: _keyInstanceUrl, value: session.instanceUrl);
    await _secureStorage.write(key: _keyAccessToken, value: session.accessToken);
  }

  Future<void> clearSession() async {
    await _secureStorage.delete(key: _keyInstanceUrl);
    await _secureStorage.delete(key: _keyAccessToken);
  }

  Future<AiCredentials> loadAiCredentials() async {
    final gemini = await _secureStorage.read(key: _keyGeminiKey) ?? '';
    final openAi = await _secureStorage.read(key: _keyOpenAiKey) ?? '';
    final anthropic = await _secureStorage.read(key: _keyAnthropicKey) ?? '';
    final local = await _secureStorage.read(key: _keyLocalKey) ?? '';
    return AiCredentials(
      geminiApiKey: gemini,
      openAiApiKey: openAi,
      anthropicApiKey: anthropic,
      localApiKey: local,
    );
  }

  Future<void> saveAiCredentials(AiCredentials creds) async {
    await _secureStorage.write(key: _keyGeminiKey, value: creds.geminiApiKey);
    await _secureStorage.write(key: _keyOpenAiKey, value: creds.openAiApiKey);
    await _secureStorage.write(
      key: _keyAnthropicKey,
      value: creds.anthropicApiKey,
    );
    await _secureStorage.write(key: _keyLocalKey, value: creds.localApiKey);
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
