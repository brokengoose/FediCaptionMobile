// Copyright (c) 2026 brokengoose <brokengoose@users.noreply.github.com>
// SPDX-License-Identifier: MIT

import 'package:edge_gen_ai/edge_gen_ai.dart';
import 'package:fedicaption_mobile/core/theme/app_theme.dart';
import 'package:fedicaption_mobile/models/mastodon_models.dart';
import 'package:fedicaption_mobile/services/on_device_ai_service.dart';
import 'package:fedicaption_mobile/services/translation_service.dart';
import 'package:fedicaption_mobile/state/app_controller.dart';
import 'package:fedicaption_mobile/ui/widgets/status_card.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

class _FakeOnDeviceAiService extends OnDeviceAiService {
  _FakeOnDeviceAiService({
    required this.status,
    this.promptResponse,
    this.shouldThrow = false,
  });

  final OnDeviceAiStatus status;
  final String? promptResponse;
  final bool shouldThrow;
  int runPromptCalls = 0;

  @override
  Future<OnDeviceAiStatus> checkStatus() async => status;

  @override
  Future<String> runPrompt({
    required String systemPrompt,
    required String userPrompt,
    Uint8List? imageBytes,
  }) async {
    runPromptCalls++;
    if (shouldThrow) {
      throw StateError('Simulated on-device AI failure');
    }
    return promptResponse ?? '';
  }
}

void main() {
  group('TranslationService helpers', () {
    test('normalizeLanguageCode extracts lowercase primary subtag', () {
      expect(TranslationService.normalizeLanguageCode('en-US'), 'en');
      expect(TranslationService.normalizeLanguageCode('pt_BR'), 'pt');
      expect(TranslationService.normalizeLanguageCode('nb-NO'), 'no');
      expect(TranslationService.normalizeLanguageCode('und'), isNull);
      expect(TranslationService.normalizeLanguageCode(''), isNull);
      expect(TranslationService.normalizeLanguageCode(null), isNull);
    });

    test('detectScriptLanguage detects non-Latin scripts offline', () {
      expect(TranslationService.detectScriptLanguage('こんにちは世界'), 'ja');
      expect(TranslationService.detectScriptLanguage('안녕하세요 반갑습니다'), 'ko');
      expect(TranslationService.detectScriptLanguage('Привет мир сегодня'), 'ru');
      expect(TranslationService.detectScriptLanguage('Hello world'), isNull);
    });
  });

  group('TranslationService fallback priority', () {
    test('uses on-device AI first when prompt engine is ready', () async {
      final fakeAi = _FakeOnDeviceAiService(
        status: const OnDeviceAiStatus(
          promptAvailability: EdgeGenAIAvailability.available,
          imageDescriptionAvailability: EdgeGenAIAvailability.unavailable,
          engineName: 'Apple Foundation Models',
        ),
        promptResponse: 'Hello everyone!',
      );
      var appleCalls = 0;
      var mlKitCalls = 0;

      final service = TranslationService(
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
          appleCalls++;
          return 'Apple fallback';
        },
        mlKitTranslate: ({
          required text,
          required sourceLanguage,
          required targetLanguage,
        }) async {
          mlKitCalls++;
          return 'ML Kit fallback';
        },
      );

      final result = await service.translatePost(
        text: 'Bonjour tout le monde !',
        sourceLanguage: 'fr',
      );

      expect(result.translatedText, 'Hello everyone!');
      expect(result.engineName, 'Apple Foundation Models');
      expect(fakeAi.runPromptCalls, 1);
      expect(appleCalls, 0);
      expect(mlKitCalls, 0);
    });

    test('falls back to Apple Translation on macOS when on-device AI is unavailable',
        () async {
      final fakeAi = _FakeOnDeviceAiService(
        status: const OnDeviceAiStatus(
          promptAvailability: EdgeGenAIAvailability.unavailable,
          imageDescriptionAvailability: EdgeGenAIAvailability.unavailable,
          engineName: 'Apple Foundation Models',
        ),
      );

      final service = TranslationService(
        onDeviceAi: fakeAi,
        platformOverride: TargetPlatform.macOS,
        isWebOverride: false,
        osLanguageProvider: () => 'en',
        appleSupportCheck: () async => true,
        appleTranslate: ({
          required text,
          required sourceLanguage,
          required targetLanguage,
        }) async =>
            'Good morning from Paris',
      );

      final result = await service.translatePost(
        text: 'Bonjour de Paris',
        sourceLanguage: 'fr',
      );

      expect(result.translatedText, 'Good morning from Paris');
      expect(result.engineName, 'Apple Translation');
      expect(fakeAi.runPromptCalls, 0);
    });

    test('falls back to ML Kit Translation on Android when on-device AI fails',
        () async {
      final fakeAi = _FakeOnDeviceAiService(
        status: const OnDeviceAiStatus(
          promptAvailability: EdgeGenAIAvailability.available,
          imageDescriptionAvailability: EdgeGenAIAvailability.unavailable,
          engineName: 'Google Gemini Nano',
        ),
        shouldThrow: true,
      );

      final service = TranslationService(
        onDeviceAi: fakeAi,
        platformOverride: TargetPlatform.android,
        isWebOverride: false,
        osLanguageProvider: () => 'en',
        mlKitTranslate: ({
          required text,
          required sourceLanguage,
          required targetLanguage,
        }) async =>
            'Hello from Berlin',
      );

      final result = await service.translatePost(
        text: 'Hallo aus Berlin',
        sourceLanguage: 'de',
      );

      expect(result.translatedText, 'Hello from Berlin');
      expect(result.engineName, 'ML Kit Translation');
      expect(fakeAi.runPromptCalls, 1);
    });

    test('falls back from Apple Translation to ML Kit on iOS if Apple fails',
        () async {
      final fakeAi = _FakeOnDeviceAiService(
        status: const OnDeviceAiStatus(
          promptAvailability: EdgeGenAIAvailability.unavailable,
          imageDescriptionAvailability: EdgeGenAIAvailability.unavailable,
          engineName: 'Apple Foundation Models',
        ),
      );

      final service = TranslationService(
        onDeviceAi: fakeAi,
        platformOverride: TargetPlatform.iOS,
        isWebOverride: false,
        osLanguageProvider: () => 'en',
        appleSupportCheck: () async => true,
        appleTranslate: ({
          required text,
          required sourceLanguage,
          required targetLanguage,
        }) async =>
            throw StateError('Language pair unsupported by Apple Translation'),
        mlKitTranslate: ({
          required text,
          required sourceLanguage,
          required targetLanguage,
        }) async =>
            'Translated via ML Kit',
      );

      final result = await service.translatePost(
        text: 'Witaj świecie',
        sourceLanguage: 'pl',
      );

      expect(result.translatedText, 'Translated via ML Kit');
      expect(result.engineName, 'ML Kit Translation');
    });
  });

  group('StatusCard top-of-post translation offer', () {
    MastodonStatus makeStatus({
      required String language,
      required String contentHtml,
      List<MastodonMediaAttachment> mediaAttachments = const [],
    }) {
      return MastodonStatus(
        id: 'st-1',
        createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
        account: const MastodonAccount(
          id: 'u-1',
          username: 'claire',
          acct: 'claire@mastodon.social',
          displayName: 'Claire',
          avatar: '',
        ),
        contentHtml: contentHtml,
        language: language,
        mediaAttachments: mediaAttachments,
      );
    }

    testWidgets(
      'offers translation at top of post when language differs from OS, translates alt-text, and toggles original',
      (tester) async {
        final fakeAi = _FakeOnDeviceAiService(
          status: const OnDeviceAiStatus(
            promptAvailability: EdgeGenAIAvailability.unavailable,
            imageDescriptionAvailability: EdgeGenAIAvailability.unavailable,
            engineName: 'Apple Foundation Models',
          ),
        );
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
            if (text.contains('Lyon')) return 'Hello from Lyon!';
            if (text.contains('chat')) return 'A black cat sleeping in the sun.';
            return text;
          },
        );
        final app = AppController(
          onDeviceAiService: fakeAi,
          translationService: translation,
        );
        addTearDown(app.dispose);

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light(),
            home: Scaffold(
              body: SingleChildScrollView(
                child: StatusCard(
                  status: makeStatus(
                    language: 'fr',
                    contentHtml: '<p>Bonjour de Lyon !</p>',
                    mediaAttachments: const [
                      MastodonMediaAttachment(
                        id: 'media-1',
                        type: 'image',
                        url: '',
                        previewUrl: '',
                        description: 'Un chat noir qui dort au soleil.',
                      ),
                    ],
                  ),
                  app: app,
                  enableTranslationOffer: true,
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

        expect(find.text('Written in French'), findsOneWidget);
        expect(find.text('Translate to English'), findsOneWidget);
        expect(
          find.textContaining('Un chat noir qui dort au soleil.'),
          findsOneWidget,
        );

        await tester.tap(find.text('Translate to English'));
        await tester.pumpAndSettle();

        expect(
          find.text('Translated from French via Apple Translation'),
          findsOneWidget,
        );
        expect(find.text('Show Original'), findsOneWidget);
        expect(find.textContaining('Hello from Lyon!'), findsOneWidget);
        expect(
          find.textContaining('A black cat sleeping in the sun.'),
          findsOneWidget,
        );

        await tester.tap(find.text('Show Original'));
        await tester.pumpAndSettle();

        expect(find.text('Show Translation'), findsOneWidget);
        expect(find.textContaining('Bonjour de Lyon !'), findsOneWidget);
        expect(
          find.textContaining('Un chat noir qui dort au soleil.'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'does not show translation banner when post language matches OS language',
      (tester) async {
        final fakeAi = _FakeOnDeviceAiService(
          status: const OnDeviceAiStatus(
            promptAvailability: EdgeGenAIAvailability.available,
            imageDescriptionAvailability: EdgeGenAIAvailability.unavailable,
            engineName: 'Apple Foundation Models',
          ),
        );
        final translation = TranslationService(
          onDeviceAi: fakeAi,
          platformOverride: TargetPlatform.macOS,
          isWebOverride: false,
          osLanguageProvider: () => 'en',
          appleSupportCheck: () async => true,
        );
        final app = AppController(
          onDeviceAiService: fakeAi,
          translationService: translation,
        );
        addTearDown(app.dispose);

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light(),
            home: Scaffold(
              body: SingleChildScrollView(
                child: StatusCard(
                  status: makeStatus(
                    language: 'en',
                    contentHtml: '<p>Already in English!</p>',
                  ),
                  app: app,
                  enableTranslationOffer: true,
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

        expect(find.textContaining('Translate to'), findsNothing);
        expect(find.textContaining('Written in'), findsNothing);
      },
    );
  });
}
