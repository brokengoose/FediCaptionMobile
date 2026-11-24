// Copyright (c) 2026 brokengoose <brokengoose@users.noreply.github.com>
// SPDX-License-Identifier: MIT

import 'dart:io';

import 'package:edge_gen_ai/edge_gen_ai.dart';
import 'package:fedicaption_mobile/core/post_read_aloud_builder.dart';
import 'package:fedicaption_mobile/l10n/l10n.dart';
import 'package:fedicaption_mobile/models/mastodon_models.dart';
import 'package:fedicaption_mobile/services/on_device_ai_service.dart';
import 'package:fedicaption_mobile/services/translation_service.dart';
import 'package:fedicaption_mobile/services/tts_service.dart';
import 'package:fedicaption_mobile/state/app_controller.dart';
import 'package:fedicaption_mobile/ui/screens/thread_screen.dart';
import 'package:fedicaption_mobile/ui/widgets/status_card.dart';
import 'package:fedicaption_mobile/ui/widgets/status_header_parts.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'helpers/test_app.dart';

class _RecordingTtsService extends TtsService {
  _RecordingTtsService()
      : super(
          isLinuxOverride: true,
          linuxProcessStarter: (_, __) =>
              throw const ProcessException('spd-say', [], 'Disabled in test'),
        );

  final List<({String key, String text, String? languageName, double speechRate})>
      toggleCalls = [];
  int stopCalls = 0;

  bool _speaking = false;
  String? _currentKey;
  bool _testDisposed = false;

  @override
  bool get isSpeaking => _speaking;

  @override
  String? get activeKey => _currentKey;

  @override
  bool isSpeakingKey(String key) => _speaking && _currentKey == key;

  @override
  Future<void> toggleSpeak({
    required String key,
    required String text,
    String? languageName,
    double speechRate = 0.5,
  }) async {
    if (_testDisposed) return;
    toggleCalls.add((
      key: key,
      text: text,
      languageName: languageName,
      speechRate: speechRate,
    ));
    if (isSpeakingKey(key)) {
      await stop();
      return;
    }
    _speaking = true;
    _currentKey = key;
    notifyListeners();
  }

  @override
  Future<void> stop() async {
    stopCalls++;
    _speaking = false;
    _currentKey = null;
    if (!_testDisposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _testDisposed = true;
    super.dispose();
  }
}

class _FakeUnavailableOnDeviceAi extends OnDeviceAiService {
  @override
  Future<OnDeviceAiStatus> checkStatus() async => const OnDeviceAiStatus(
        promptAvailability: EdgeGenAIAvailability.unavailable,
        imageDescriptionAvailability: EdgeGenAIAvailability.unavailable,
        engineName: 'Apple Foundation Models',
      );
}

MastodonStatus _makeStatus({
  String id = 'st-1',
  String contentHtml = '<p>Hello Fediverse</p>',
  String spoilerText = '',
  String? language = 'en',
  List<MastodonMediaAttachment> mediaAttachments = const [],
  MastodonStatus? quotedStatus,
}) {
  return MastodonStatus(
    id: id,
    createdAt: DateTime.utc(2026, 11, 24, 9, 0),
    account: const MastodonAccount(
      id: 'u-1',
      username: 'alice',
      acct: 'alice@example.social',
      displayName: 'Alice',
      avatar: '',
    ),
    contentHtml: contentHtml,
    spoilerText: spoilerText,
    language: language,
    mediaAttachments: mediaAttachments,
    quotedStatus: quotedStatus,
  );
}

void main() {
  final l10n = AppLocalizationsEn();

  group('PostReadAloudBuilder', () {
    test('builds plain post, CW, and single image alt-text with sentence pauses',
        () {
      final status = _makeStatus(
        spoilerText: 'Bird photography',
        contentHtml: '<p>Spotted a cardinal at dawn</p>',
        mediaAttachments: const [
          MastodonMediaAttachment(
            id: 'm1',
            type: 'image',
            url: 'https://example.social/m1.jpg',
            description: 'A bright red cardinal perched on a snowy pine branch',
          ),
        ],
      );

      final result = PostReadAloudBuilder.build(status: status, l10n: l10n);
      expect(
        result,
        'Content warning: Bird photography. '
        'Spotted a cardinal at dawn. '
        'Image description: A bright red cardinal perched on a snowy pine branch.',
      );
    });

    test(
        'preserves 1-based attachment indices and skips uncaptioned attachments',
        () {
      final status = _makeStatus(
        contentHtml: '<p>Three clips from the trip!</p>',
        mediaAttachments: const [
          MastodonMediaAttachment(
            id: 'm1',
            type: 'image',
            url: 'https://example.social/m1.jpg',
            description: 'Train arriving at platform 2.',
          ),
          MastodonMediaAttachment(
            id: 'm2',
            type: 'image',
            url: 'https://example.social/m2.jpg',
            description: '   ',
          ),
          MastodonMediaAttachment(
            id: 'm3',
            type: 'video',
            url: 'https://example.social/m3.mp4',
            description: 'Rain splashing onto cobblestones',
          ),
        ],
      );

      final result = PostReadAloudBuilder.build(status: status, l10n: l10n);
      expect(
        result,
        'Three clips from the trip! '
        'Image 1 description: Train arriving at platform 2. '
        'Video 3 description: Rain splashing onto cobblestones.',
      );
    });

    test('applies AI alt-text lookup above translated and author alt-text', () {
      final status = _makeStatus(
        spoilerText: 'Spoiler original',
        contentHtml: '<p>Original text</p>',
        mediaAttachments: const [
          MastodonMediaAttachment(
            id: 'm1',
            type: 'image',
            url: 'https://example.social/m1.jpg',
            description: 'Author alt',
          ),
          MastodonMediaAttachment(
            id: 'm2',
            type: 'image',
            url: 'https://example.social/m2.jpg',
            description: 'Original second alt',
          ),
        ],
      );

      final result = PostReadAloudBuilder.build(
        status: status,
        l10n: l10n,
        bodyOverride: 'Translated body',
        spoilerOverride: 'Translated spoiler',
        translatedAltTexts: const {
          'm1': 'Translated first alt',
          'm2': 'Translated second alt',
        },
        aiAltTextLookup: (id) => id == 'm1' ? 'On-demand AI description' : null,
      );

      expect(
        result,
        'Content warning: Translated spoiler. '
        'Translated body. '
        'Image 1 description: On-demand AI description. '
        'Image 2 description: Translated second alt.',
      );
    });

    test('strips RE: quote URL from outer body and includes embedded quote', () {
      final quoted = MastodonStatus(
        id: 'q-1',
        createdAt: DateTime.utc(2026, 11, 23),
        account: const MastodonAccount(
          id: 'u-2',
          username: 'bob',
          acct: 'bob@example.social',
          displayName: 'Bob',
          avatar: '',
        ),
        spoilerText: 'Weather',
        contentHtml: '<p>Snow expected tonight</p>',
        mediaAttachments: const [
          MastodonMediaAttachment(
            id: 'qm-1',
            type: 'image',
            url: 'https://example.social/qm1.jpg',
            description: 'Radar map showing snowfall band.',
          ),
        ],
      );

      final outer = _makeStatus(
        contentHtml:
            '<p>RE: <a href="https://example.social/@bob/q-1">https://example.social/@bob/q-1</a></p>'
            '<p>Stay warm everyone</p>',
        quotedStatus: quoted,
      );

      final result = PostReadAloudBuilder.build(
        status: outer,
        l10n: l10n,
        embeddedQuote: quoted,
      );

      expect(result, isNot(contains('RE:')));
      expect(
        result,
        'Stay warm everyone. '
        'Quoted post by Bob. '
        'Content warning: Weather. '
        'Snow expected tonight. '
        'Image description: Radar map showing snowfall band.',
      );
    });

    test('returns empty string when post has no text and no alt-text', () {
      final status = _makeStatus(
        contentHtml: '',
        mediaAttachments: const [
          MastodonMediaAttachment(
            id: 'm1',
            type: 'image',
            url: 'https://example.social/m1.jpg',
          ),
        ],
      );

      expect(PostReadAloudBuilder.build(status: status, l10n: l10n), isEmpty);
    });
  });

  group('Top-of-post Read Aloud button widget tests', () {
    testWidgets(
      'ThreadScreen shows Read Aloud above focal author header; timeline card hides it',
      (tester) async {
        final tts = _RecordingTtsService();
        final app = AppController(
          ttsService: tts,
          onDeviceAiService: _FakeUnavailableOnDeviceAi(),
        );
        addTearDown(app.dispose);

        final status = _makeStatus(
          id: 'focal-1',
          language: 'en',
          contentHtml: '<p>Main post message</p>',
          mediaAttachments: const [
            MastodonMediaAttachment(
              id: 'm1',
              type: 'image',
              url: '',
              description: 'A wooden footbridge over a stream',
            ),
          ],
        );

        // Timeline card (enableReadAloud: false) must not render top Read Aloud FilledButton.
        await tester.pumpWidget(
          localizedTestApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: StatusCard(
                  status: status,
                  app: app,
                  onOpenProfile: (_) {},
                  onOpenThread: (_) {},
                  onReply: (_) {},
                  onToggleBoost: (_) async {},
                  onToggleFavorite: (_) async {},
                  onToggleBookmark: (_) async {},
                ),
              ),
            ),
          ),
        );
        expect(find.byType(FilledButton), findsNothing);

        // Opened individual post page (ThreadScreen) shows it above StatusAuthorHeader.
        await tester.pumpWidget(
          localizedTestApp(
            home: ThreadScreen(app: app, rootStatus: status),
          ),
        );
        await tester.pump();

        final topReadAloudFinder = find.byType(FilledButton);
        expect(topReadAloudFinder, findsOneWidget);
        expect(
          find.descendant(
            of: topReadAloudFinder,
            matching: find.text('Read Aloud'),
          ),
          findsOneWidget,
        );

        final buttonRect = tester.getRect(topReadAloudFinder);
        final headerRect = tester.getRect(find.byType(StatusAuthorHeader));
        expect(buttonRect.bottom, lessThanOrEqualTo(headerRect.top));

        // Tap to read post + alt-text aloud.
        await tester.tap(topReadAloudFinder);
        await tester.pump();

        expect(tts.toggleCalls, hasLength(1));
        expect(tts.toggleCalls.single.key, 'post_full_focal-1');
        expect(
          tts.toggleCalls.single.text,
          'Main post message. Image description: A wooden footbridge over a stream.',
        );
        expect(tts.toggleCalls.single.languageName, 'en');
        expect(tts.toggleCalls.single.speechRate, 0.5);
        expect(
          find.descendant(
            of: topReadAloudFinder,
            matching: find.text('Stop Reading'),
          ),
          findsOneWidget,
        );

        // Tap again to stop reading aloud.
        await tester.tap(topReadAloudFinder);
        await tester.pump();

        expect(tts.toggleCalls, hasLength(2));
        expect(tts.stopCalls, 1);
        expect(
          find.descendant(
            of: topReadAloudFinder,
            matching: find.text('Read Aloud'),
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'reads translated post and translated alt-text when translation is active',
      (tester) async {
        final tts = _RecordingTtsService();
        final fakeAi = _FakeUnavailableOnDeviceAi();
        final translation = TranslationService(
          onDeviceAi: fakeAi,
          platformOverride: TargetPlatform.macOS,
          isWebOverride: false,
          osLanguageProvider: () => 'en',
          appleSupportCheck: () async => true,
          appleTranslate: ({
            required text,
            required sourceLanguage,
            required targetLanguage,
          }) async {
            if (text.contains('Bonjour')) return 'Hello from Paris!';
            if (text.contains('chat')) return 'A white cat on a windowsill.';
            return text;
          },
        );
        final app = AppController(
          ttsService: tts,
          onDeviceAiService: fakeAi,
          translationService: translation,
        );
        addTearDown(app.dispose);

        final status = _makeStatus(
          id: 'fr-1',
          language: 'fr',
          contentHtml: '<p>Bonjour de Paris !</p>',
          mediaAttachments: const [
            MastodonMediaAttachment(
              id: 'm-fr-1',
              type: 'image',
              url: '',
              description: 'Un chat blanc sur un rebord de fenêtre.',
            ),
          ],
        );

        await tester.pumpWidget(
          localizedTestApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: StatusCard(
                  status: status,
                  app: app,
                  enableTranslationOffer: true,
                  enableReadAloud: true,
                  onOpenProfile: (_) {},
                  onOpenThread: (_) {},
                  onReply: (_) {},
                  onToggleBoost: (_) async {},
                  onToggleFavorite: (_) async {},
                  onToggleBookmark: (_) async {},
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Trigger translation from French to English.
        await tester.tap(find.text('Translate to English'));
        await tester.pumpAndSettle();

        // Now tap the top-of-post Read Aloud button.
        final topReadAloudFinder = find.byType(FilledButton);
        expect(topReadAloudFinder, findsOneWidget);
        await tester.tap(topReadAloudFinder);
        await tester.pump();

        expect(tts.toggleCalls, hasLength(1));
        expect(tts.toggleCalls.single.key, 'post_full_fr-1');
        expect(tts.toggleCalls.single.languageName, 'en');
        expect(
          tts.toggleCalls.single.text,
          'Hello from Paris! Image description: A white cat on a windowsill.',
        );
      },
    );

    testWidgets('stops reading aloud when ThreadScreen is popped',
        (tester) async {
      final tts = _RecordingTtsService();
      final app = AppController(
        ttsService: tts,
        onDeviceAiService: _FakeUnavailableOnDeviceAi(),
      );
      addTearDown(app.dispose);

      final status = _makeStatus(
        id: 'pop-1',
        contentHtml: '<p>Read this and navigate back.</p>',
      );

      await tester.pumpWidget(
        localizedTestApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => ThreadScreen(app: app, rootStatus: status),
                      ),
                    );
                  },
                  child: const Text('Open Post'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Post'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      await tester.tap(find.byType(FilledButton));
      await tester.pump();
      expect(tts.isSpeakingKey('post_full_pop-1'), isTrue);

      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(tts.stopCalls, greaterThanOrEqualTo(1));
      expect(tts.isSpeaking, isFalse);
    });

    testWidgets('ThreadScreen focal Read Aloud button renders cleanly in RTL',
        (tester) async {
      final tts = _RecordingTtsService();
      final app = AppController(
        ttsService: tts,
        onDeviceAiService: _FakeUnavailableOnDeviceAi(),
      );
      addTearDown(app.dispose);

      final status = _makeStatus(
        id: 'rtl-1',
        contentHtml: '<p>RTL layout verification post</p>',
        mediaAttachments: const [
          MastodonMediaAttachment(
            id: 'm1',
            type: 'image',
            url: '',
            description: 'Architectural archway in sunlight.',
          ),
        ],
      );

      await tester.pumpWidget(
        localizedTestApp(
          textDirection: TextDirection.rtl,
          home: ThreadScreen(app: app, rootStatus: status),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.byType(FilledButton), findsOneWidget);
    });
  });
}
