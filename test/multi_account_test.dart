// Copyright (c) 2026 brokengoose <brokengoose@users.noreply.github.com>
// SPDX-License-Identifier: MIT

import 'dart:convert';

import 'package:fedicaption_mobile/models/app_settings.dart';
import 'package:fedicaption_mobile/models/mastodon_models.dart';
import 'package:fedicaption_mobile/models/update_info.dart';
import 'package:fedicaption_mobile/services/mastodon_service.dart';
import 'package:fedicaption_mobile/services/on_device_ai_service.dart';
import 'package:fedicaption_mobile/services/storage_service.dart';
import 'package:fedicaption_mobile/services/tts_service.dart';
import 'package:fedicaption_mobile/services/update_check_service.dart';
import 'package:fedicaption_mobile/state/app_controller.dart';
import 'package:fedicaption_mobile/ui/screens/home_shell.dart';
import 'package:fedicaption_mobile/ui/widgets/account_switcher_sheet.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/test_app.dart';

class _InMemorySecureStorage extends Fake implements FlutterSecureStorage {
  final Map<String, String> _values = {};

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
    return _values[key];
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
      _values.remove(key);
    } else {
      _values[key] = value;
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
    _values.remove(key);
  }
}

class _FakeMastodonService extends MastodonService {
  final Map<String, MastodonAccount> accountsByCreds = {};
  final Map<String, InstanceLimits> limitsByInstance = {};
  final Map<String, List<MastodonStatus>> homeFeedByToken = {};

  static String _credKey(String instanceUrl, String accessToken) =>
      '${MastodonService.normalizeInstanceUrl(instanceUrl)}|$accessToken';

  void registerAccount({
    required String instanceUrl,
    required String accessToken,
    required MastodonAccount account,
    InstanceLimits limits = const InstanceLimits(),
    List<MastodonStatus> homeStatuses = const [],
  }) {
    final norm = MastodonService.normalizeInstanceUrl(instanceUrl);
    accountsByCreds[_credKey(norm, accessToken)] = account;
    limitsByInstance[norm] = limits;
    homeFeedByToken[accessToken] = homeStatuses;
  }

  /// When set, every verifyCredentials call throws this (simulates offline).
  Object? verifyError;

  /// When true, fetchInstanceLimits reports failure (`null`).
  bool failInstanceLimits = false;

  @override
  Future<MastodonAccount> verifyCredentials({
    required String instanceUrl,
    required String accessToken,
  }) async {
    if (verifyError != null) throw verifyError!;
    final account = accountsByCreds[_credKey(instanceUrl, accessToken)];
    if (account == null) {
      throw const MastodonApiException('Invalid token', statusCode: 401);
    }
    return account;
  }

  @override
  Future<InstanceLimits?> fetchInstanceLimits({
    required String instanceUrl,
    String? accessToken,
  }) async {
    if (failInstanceLimits) return null;
    final norm = MastodonService.normalizeInstanceUrl(instanceUrl);
    return limitsByInstance[norm] ?? const InstanceLimits();
  }

  @override
  Future<List<MastodonStatus>> fetchTimeline({
    required String instanceUrl,
    required String accessToken,
    required TimelineType type,
    required String currentUserId,
    String? maxId,
    String? sinceId,
    int limit = 25,
  }) async {
    return homeFeedByToken[accessToken] ?? const [];
  }
}

class _StubOnDeviceAiService extends OnDeviceAiService {
  @override
  Future<OnDeviceAiStatus> checkStatus() async =>
      OnDeviceAiStatus.unavailableForCurrentPlatform();
}

class _NoOpUpdateCheckService extends UpdateCheckService {
  @override
  Future<UpdateInfo?> checkForUpdate({String currentVersion = ''}) async =>
      null;
}

class _StubTtsService extends TtsService {
  _StubTtsService() : super(isLinuxOverride: true);
}

MastodonStatus _samplePost(String id, String text, MastodonAccount author) {
  return MastodonStatus(
    id: id,
    createdAt: DateTime.utc(2026, 11, 27, 8),
    account: author,
    contentHtml: '<p>$text</p>',
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Multi-account support', () {
    test('StorageService persists multiple accounts with tokens kept strictly in secure storage', () async {
      final secure = _InMemorySecureStorage();
      final storage = StorageService(
        secureStorage: secure,
        enableLinuxKeyringFallback: false,
      );

      final alice = StoredAccount(
        key: StoredAccount.buildKey('https://mastodon.social', '1'),
        instanceUrl: 'https://mastodon.social',
        accessToken: 'alice-secret-token',
        accountId: '1',
        username: 'alice',
        acct: 'alice',
        displayName: 'Alice',
      );
      final bob = StoredAccount(
        key: StoredAccount.buildKey('https://infosec.exchange', '2'),
        instanceUrl: 'https://infosec.exchange',
        accessToken: 'bob-secret-token',
        accountId: '2',
        username: 'bob',
        acct: 'bob',
        displayName: 'Bob',
      );

      await storage.saveAccount(alice);
      await storage.saveAccount(bob);

      final loaded = await storage.loadAccounts();
      expect(loaded, hasLength(2));
      expect(loaded[0].fullHandle, '@alice@mastodon.social');
      expect(loaded[0].accessToken, 'alice-secret-token');
      expect(loaded[1].fullHandle, '@bob@infosec.exchange');
      expect(loaded[1].accessToken, 'bob-secret-token');
      expect(await storage.loadActiveAccountKey(), bob.key);

      // Verify tokens are NOT stored in plain SharedPreferences JSON metadata.
      final prefs = await SharedPreferences.getInstance();
      final rawMeta = prefs.getString('fedicaption_accounts_v1') ?? '';
      expect(rawMeta.contains('alice-secret-token'), isFalse);
      expect(rawMeta.contains('bob-secret-token'), isFalse);
      expect(jsonDecode(rawMeta), hasLength(2));

      // Removing active account promotes remaining account cleanly.
      await storage.removeAccount(bob.key);
      expect(await storage.loadAccounts(), hasLength(1));
      expect(await storage.loadActiveAccountKey(), alice.key);
    });

    test('AppController supports multiple servers, switching, logout failover, and legacy migration', () async {
      final secure = _InMemorySecureStorage();
      final storage = StorageService(
        secureStorage: secure,
        enableLinuxKeyringFallback: false,
      );
      final mastodon = _FakeMastodonService();

      const aliceAccount = MastodonAccount(
        id: '10',
        username: 'alice',
        acct: 'alice',
        displayName: 'Alice Social',
        avatar: '',
      );
      const bobAccount = MastodonAccount(
        id: '20',
        username: 'bob',
        acct: 'bob',
        displayName: 'Bob Infosec',
        avatar: '',
      );

      mastodon.registerAccount(
        instanceUrl: 'https://mastodon.social',
        accessToken: 'tok-alice',
        account: aliceAccount,
      );
      mastodon.registerAccount(
        instanceUrl: 'https://infosec.exchange',
        accessToken: 'tok-bob',
        account: bobAccount,
        limits: const InstanceLimits(maxCharacters: 11000),
      );

      final controller = AppController(
        storageService: storage,
        mastodonService: mastodon,
        onDeviceAiService: _StubOnDeviceAiService(),
        updateCheckService: _NoOpUpdateCheckService(),
      );
      addTearDown(controller.dispose);

      expect(
        await controller.loginWithAccessToken(
          rawInstanceUrl: 'mastodon.social',
          accessToken: 'tok-alice',
        ),
        isTrue,
      );
      expect(controller.hasMultipleAccounts, isFalse);
      expect(controller.activeAccountFullHandle, '@alice@mastodon.social');
      expect(controller.instanceLimits.maxCharacters, 500);

      // Seed timeline cache for Alice, then sign into Bob on a second server.
      controller.timelineCache.putTimeline(TimelineType.home, [
        _samplePost('1', 'Alice post', aliceAccount),
      ], hasMore: false);
      expect(
        await controller.loginWithAccessToken(
          rawInstanceUrl: 'infosec.exchange',
          accessToken: 'tok-bob',
        ),
        isTrue,
      );

      expect(controller.accounts, hasLength(2));
      expect(controller.hasMultipleAccounts, isTrue);
      expect(controller.activeAccountFullHandle, '@bob@infosec.exchange');
      expect(controller.instanceLimits.maxCharacters, 11000);
      expect(controller.timelineCache.timelineFor(TimelineType.home), isNull);

      // Switch back to Alice -> verifies credentials, clears caches, updates active handle & limits.
      controller.timelineCache.putTimeline(TimelineType.home, [
        _samplePost('2', 'Bob post', bobAccount),
      ], hasMore: false);
      final aliceKey = controller.accounts.first.key;
      expect(await controller.switchAccount(aliceKey), isTrue);
      expect(controller.activeAccountFullHandle, '@alice@mastodon.social');
      expect(controller.instanceLimits.maxCharacters, 500);
      expect(controller.timelineCache.timelineFor(TimelineType.home), isNull);

      // Signing out of active account auto-switches to remaining account Bob.
      await controller.logout();
      expect(controller.isAuthenticated, isTrue);
      expect(controller.hasMultipleAccounts, isFalse);
      expect(controller.activeAccountFullHandle, '@bob@infosec.exchange');

      // Signing out of last remaining account signs out cleanly.
      await controller.logout();
      expect(controller.isAuthenticated, isFalse);
      expect(controller.accounts, isEmpty);

      // Legacy single-session migration on initialize.
      await storage.saveSession(
        const MastodonSession(
          instanceUrl: 'https://mastodon.social',
          accessToken: 'tok-alice',
        ),
      );
      final migratedController = AppController(
        storageService: storage,
        mastodonService: mastodon,
        onDeviceAiService: _StubOnDeviceAiService(),
        updateCheckService: _NoOpUpdateCheckService(),
      );
      addTearDown(migratedController.dispose);
      await migratedController.initialize();
      expect(migratedController.isAuthenticated, isTrue);
      expect(migratedController.accounts, hasLength(1));
      expect(
        migratedController.activeAccountFullHandle,
        '@alice@mastodon.social',
      );
    });

    testWidgets(
      'HomeShell highlights active account when multiple logins exist and AccountSwitcherSheet switches servers cleanly',
      (tester) async {
        final secure = _InMemorySecureStorage();
        final storage = StorageService(
          secureStorage: secure,
          enableLinuxKeyringFallback: false,
        );
        final mastodon = _FakeMastodonService();

        const aliceAccount = MastodonAccount(
          id: '10',
          username: 'alice',
          acct: 'alice',
          displayName: 'Alice Social',
          avatar: '',
        );
        const bobAccount = MastodonAccount(
          id: '20',
          username: 'bob',
          acct: 'bob',
          displayName: 'Bob Infosec',
          avatar: '',
        );

        mastodon.registerAccount(
          instanceUrl: 'https://mastodon.social',
          accessToken: 'tok-alice',
          account: aliceAccount,
          homeStatuses: [
            _samplePost('a1', 'Hello from mastodon.social', aliceAccount),
          ],
        );
        mastodon.registerAccount(
          instanceUrl: 'https://infosec.exchange',
          accessToken: 'tok-bob',
          account: bobAccount,
          homeStatuses: [
            _samplePost('b1', 'Hello from infosec.exchange', bobAccount),
          ],
        );

        final app = AppController(
          storageService: storage,
          mastodonService: mastodon,
          onDeviceAiService: _StubOnDeviceAiService(),
          updateCheckService: _NoOpUpdateCheckService(),
          ttsService: _StubTtsService(),
        );
        addTearDown(app.dispose);

        await tester.runAsync(() async {
          await app.loginWithAccessToken(
            rawInstanceUrl: 'mastodon.social',
            accessToken: 'tok-alice',
          );
          await app.loginWithAccessToken(
            rawInstanceUrl: 'infosec.exchange',
            accessToken: 'tok-bob',
          );
          await app.switchAccount(app.accounts.first.key);
        });

        tester.view.devicePixelRatio = 1.0;
        tester.view.physicalSize = const Size(1200, 800);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(localizedTestApp(home: HomeShell(app: app)));
        await tester.pumpAndSettle();

        // Active account header and switcher chip show Alice on mastodon.social.
        expect(find.text('@alice@mastodon.social'), findsAtLeastNWidgets(2));
        expect(
          find.textContaining('Hello from mastodon.social', findRichText: true),
          findsOneWidget,
        );

        // Open account switcher sheet from AppBar switcher button.
        await tester.tap(find.byIcon(Icons.unfold_more));
        await tester.pumpAndSettle();

        final sheetFinder = find.byType(AccountSwitcherSheet);
        expect(sheetFinder, findsOneWidget);
        expect(
          find.descendant(of: sheetFinder, matching: find.text('Active')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: sheetFinder, matching: find.text('Alice Social')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: sheetFinder, matching: find.text('Bob Infosec')),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: sheetFinder,
            matching: find.text('@bob@infosec.exchange'),
          ),
          findsOneWidget,
        );

        // Switch to Bob on infosec.exchange.
        await tester.tap(
          find.descendant(of: sheetFinder, matching: find.text('Bob Infosec')),
        );
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pumpAndSettle();

        expect(find.byType(AccountSwitcherSheet), findsNothing);
        expect(app.activeAccountFullHandle, '@bob@infosec.exchange');
        expect(
          find.textContaining(
            'Hello from infosec.exchange',
            findRichText: true,
          ),
          findsOneWidget,
        );
        expect(find.text('@bob@infosec.exchange'), findsAtLeastNWidgets(2));
      },
    );
  });

  group('Startup resilience', () {
    const alice = MastodonAccount(
      id: '10',
      username: 'alice',
      acct: 'alice',
      displayName: 'Alice Social',
      avatar: '',
    );

    Future<(StorageService, _FakeMastodonService)> seedSignedIn() async {
      final storage = StorageService(
        secureStorage: _InMemorySecureStorage(),
        enableLinuxKeyringFallback: false,
      );
      final mastodon = _FakeMastodonService()
        ..registerAccount(
          instanceUrl: 'https://mastodon.social',
          accessToken: 'tok-alice',
          account: alice,
        );
      await storage.saveAccount(
        StoredAccount.fromSessionAndAccount(
          session: const MastodonSession(
            instanceUrl: 'https://mastodon.social',
            accessToken: 'tok-alice',
          ),
          account: alice,
        ),
      );
      return (storage, mastodon);
    }

    AppController build(StorageService storage, MastodonService mastodon) {
      final c = AppController(
        storageService: storage,
        mastodonService: mastodon,
        onDeviceAiService: _StubOnDeviceAiService(),
        updateCheckService: _NoOpUpdateCheckService(),
      );
      addTearDown(c.dispose);
      return c;
    }

    test(
      'network failure at launch keeps the stored account signed in',
      () async {
        final (storage, mastodon) = await seedSignedIn();
        mastodon.verifyError = Exception(
          'SocketException: Network unreachable',
        );

        final app = build(storage, mastodon);
        await app.initialize();

        expect(app.isAuthenticated, isTrue);
        expect(app.authError, isNull);
        expect(app.activeAccountFullHandle, '@alice@mastodon.social');
      },
    );

    test('401 at launch is still treated as an expired session', () async {
      final (storage, mastodon) = await seedSignedIn();
      mastodon.verifyError = const MastodonApiException(
        'The access token is invalid',
        statusCode: 401,
      );

      final app = build(storage, mastodon);
      await app.initialize();

      expect(app.isAuthenticated, isFalse);
      expect(app.authError, isNotNull);
    });

    test('failed instance-limits fetch is not cached', () async {
      final (storage, mastodon) = await seedSignedIn();
      mastodon.failInstanceLimits = true;

      final app = build(storage, mastodon);
      await app.initialize();

      expect(app.isAuthenticated, isTrue);
      expect(
        await storage.loadCachedInstanceLimits('https://mastodon.social'),
        isNull,
      );
    });
  });
}
