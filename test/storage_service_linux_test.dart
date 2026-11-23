// Copyright (c) 2026 brokengoose <brokengoose@users.noreply.github.com>
// SPDX-License-Identifier: MIT

import 'package:fedicaption_mobile/models/app_settings.dart';
import 'package:fedicaption_mobile/services/storage_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FailingSecureStorage extends Fake implements FlutterSecureStorage {
  PlatformException _error() => PlatformException(
        code: 'libsecret_unavailable',
        message: 'No Secret Service daemon running',
      );

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    throw _error();
  }

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    throw _error();
  }

  @override
  Future<void> delete({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    throw _error();
  }
}

void main() {
  group('StorageService Linux keyring fallback', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test(
      'saves, loads, and clears MastodonSession and AiCredentials when libsecret throws',
      () async {
        final storage = StorageService(
          secureStorage: _FailingSecureStorage(),
          enableLinuxKeyringFallback: true,
        );

        expect(await storage.loadSession(), isNull);

        const session = MastodonSession(
          instanceUrl: 'https://infosec.exchange',
          accessToken: 'secret-token-123',
        );
        await storage.saveSession(session);

        final loadedSession = await storage.loadSession();
        expect(loadedSession?.instanceUrl, 'https://infosec.exchange');
        expect(loadedSession?.accessToken, 'secret-token-123');

        const creds = AiCredentials(
          geminiApiKey: 'gem-key',
          openAiApiKey: 'oai-key',
          anthropicApiKey: 'ant-key',
          localApiKey: 'loc-key',
        );
        await storage.saveAiCredentials(creds);

        final loadedCreds = await storage.loadAiCredentials();
        expect(loadedCreds.geminiApiKey, 'gem-key');
        expect(loadedCreds.openAiApiKey, 'oai-key');
        expect(loadedCreds.anthropicApiKey, 'ant-key');
        expect(loadedCreds.localApiKey, 'loc-key');

        await storage.clearSession();
        expect(await storage.loadSession(), isNull);

        // AI credentials remain intact after session clear.
        final credsAfterSessionClear = await storage.loadAiCredentials();
        expect(credsAfterSessionClear.geminiApiKey, 'gem-key');
      },
    );
  });
}
