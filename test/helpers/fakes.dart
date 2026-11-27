// Copyright (c) 2026 brokengoose <brokengoose@users.noreply.github.com>
// SPDX-License-Identifier: MIT

import 'package:fedicaption_mobile/models/mastodon_models.dart';
import 'package:fedicaption_mobile/models/update_info.dart';
import 'package:fedicaption_mobile/services/ai_provider_service.dart';
import 'package:fedicaption_mobile/services/mastodon_service.dart';
import 'package:fedicaption_mobile/services/on_device_ai_service.dart';
import 'package:fedicaption_mobile/services/storage_service.dart';
import 'package:fedicaption_mobile/services/tts_service.dart';
import 'package:fedicaption_mobile/services/update_check_service.dart';
import 'package:fedicaption_mobile/state/app_controller.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';

class InMemorySecureStorage extends Fake implements FlutterSecureStorage {
  final Map<String, String> values = {};

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
    return values[key];
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
    if (value == null) {
      values.remove(key);
    } else {
      values[key] = value;
    }
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
    values.remove(key);
  }
}

class StubOnDeviceAiService extends OnDeviceAiService {
  StubOnDeviceAiService([OnDeviceAiStatus? status])
    : _status = status ?? OnDeviceAiStatus.unavailableForCurrentPlatform();

  final OnDeviceAiStatus _status;

  @override
  Future<OnDeviceAiStatus> checkStatus() async => _status;
}

class NoOpUpdateCheckService extends UpdateCheckService {
  @override
  Future<UpdateInfo?> checkForUpdate({String currentVersion = ''}) async =>
      null;
}

class StubTtsService extends TtsService {
  StubTtsService() : super(isLinuxOverride: true);
}

MastodonAccount sampleAccount({
  String id = '1',
  String username = 'alice',
  String acct = 'alice@example.social',
  String displayName = 'Alice',
}) {
  return MastodonAccount(
    id: id,
    username: username,
    acct: acct,
    displayName: displayName,
    avatar: '',
  );
}

MastodonStatus sampleStatus(
  String id, {
  String contentHtml = '<p>Hello world</p>',
  String spoilerText = '',
  MastodonAccount? account,
  DateTime? createdAt,
}) {
  return MastodonStatus(
    id: id,
    createdAt: createdAt ?? DateTime.utc(2026, 11, 27, 10),
    account: account ?? sampleAccount(),
    contentHtml: contentHtml,
    spoilerText: spoilerText,
  );
}

AppController buildTestAppController({
  StorageService? storageService,
  MastodonService? mastodonService,
  AiProviderService? aiProviderService,
  OnDeviceAiService? onDeviceAiService,
  UpdateCheckService? updateCheckService,
  TtsService? ttsService,
  MockClient? mastodonMockClient,
}) {
  final storage =
      storageService ??
      StorageService(
        secureStorage: InMemorySecureStorage(),
        enableLinuxKeyringFallback: false,
      );
  final mastodon =
      mastodonService ??
      (mastodonMockClient != null
          ? MastodonService(client: mastodonMockClient)
          : MastodonService());
  final onDevice = onDeviceAiService ?? StubOnDeviceAiService();
  return AppController(
    storageService: storage,
    mastodonService: mastodon,
    aiProviderService: aiProviderService,
    onDeviceAiService: onDevice,
    updateCheckService: updateCheckService ?? NoOpUpdateCheckService(),
    ttsService: ttsService ?? StubTtsService(),
  );
}
