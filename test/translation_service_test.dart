// Copyright (c) 2026 brokengoose <brokengoose@users.noreply.github.com>
// SPDX-License-Identifier: MIT

import 'dart:convert';

import 'package:edge_gen_ai/edge_gen_ai.dart';
import 'package:fedicaption_mobile/core/theme/app_theme.dart';
import 'package:fedicaption_mobile/models/ai_models.dart';
import 'package:fedicaption_mobile/models/app_settings.dart';
import 'package:fedicaption_mobile/models/mastodon_models.dart';
import 'package:fedicaption_mobile/services/ai_provider_service.dart';
import 'package:fedicaption_mobile/services/mastodon_service.dart';
import 'package:fedicaption_mobile/services/on_device_ai_service.dart';
import 'package:fedicaption_mobile/services/storage_service.dart';
import 'package:fedicaption_mobile/services/translation_service.dart';
import 'package:fedicaption_mobile/state/app_controller.dart';
import 'package:fedicaption_mobile/ui/widgets/status_card.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:material_ui/material_ui.dart';

class _InMemoryStorageService extends StorageService {
  AppSettings _settings = const AppSettings();
  AiCredentials _creds = const AiCredentials();

  @override
  Future<AppSettings> loadSettings() async => _settings;

  @override
  Future<void> saveSettings(AppSettings settings) async {
    _settings = settings;
  }

  @override
  Future<AiCredentials> loadAiCredentials() async => _creds;

  @override
  Future<void> saveAiCredentials(AiCredentials creds) async {
    _creds = creds;
  }
}

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
      expect(
        TranslationService.detectScriptLanguage('Привет мир сегодня'),
        'ru',
      );
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
        appleTranslate:
            ({
              required text,
              required sourceLanguage,
              required targetLanguage,
            }) async {
              appleCalls++;
              return 'Apple fallback';
            },
        mlKitTranslate:
            ({
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

    test('falls back to Apple Translation on macOS when on-device AI is unavailable', () async {
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
        }) async => 'Good morning from Paris',
      );

      final result = await service.translatePost(
        text: 'Bonjour de Paris',
        sourceLanguage: 'fr',
      );

      expect(result.translatedText, 'Good morning from Paris');
      expect(result.engineName, 'Apple Translation');
      expect(fakeAi.runPromptCalls, 0);
    });

    test(
      'falls back to ML Kit Translation on Android when on-device AI fails',
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
          }) async => 'Hello from Berlin',
        );

        final result = await service.translatePost(
          text: 'Hallo aus Berlin',
          sourceLanguage: 'de',
        );

        expect(result.translatedText, 'Hello from Berlin');
        expect(result.engineName, 'ML Kit Translation');
        expect(fakeAi.runPromptCalls, 1);
      },
    );

    test(
      'falls back from Apple Translation to ML Kit on iOS if Apple fails',
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
          appleTranslate:
              ({
                required text,
                required sourceLanguage,
                required targetLanguage,
              }) async => throw StateError(
                'Language pair unsupported by Apple Translation',
              ),
          mlKitTranslate: ({
            required text,
            required sourceLanguage,
            required targetLanguage,
          }) async => 'Translated via ML Kit',
        );

        final result = await service.translatePost(
          text: 'Witaj świecie',
          sourceLanguage: 'pl',
        );

        expect(result.translatedText, 'Translated via ML Kit');
        expect(result.engineName, 'ML Kit Translation');
      },
    );
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
          appleTranslate:
              ({
                required text,
                required sourceLanguage,
                required targetLanguage,
              }) async {
                if (text.contains('Lyon')) return 'Hello from Lyon!';
                if (text.contains('chat')) {
                  return 'A black cat sleeping in the sun.';
                }
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

  group('TranslationService Linux/Windows AI + Mastodon backends', () {
    const linuxUnavailableAi = OnDeviceAiStatus(
      promptAvailability: EdgeGenAIAvailability.unavailable,
      imageDescriptionAvailability: EdgeGenAIAvailability.unavailable,
      engineName: 'Unavailable',
    );
    const mastodonSession = MastodonSession(
      instanceUrl: 'https://infosec.exchange',
      accessToken: 'tok-1',
    );

    test('isTranslationSupported checks configured AI and Mastodon server translation on Linux', () async {
      final fakeAi = _FakeOnDeviceAiService(status: linuxUnavailableAi);
      final aiService = AiProviderService(
        client: MockClient((_) async => http.Response('{}', 200)),
        onDeviceAiService: fakeAi,
      );
      final mastodonService = MastodonService(
        client: MockClient((_) async => http.Response('{}', 200)),
      );
      final translation = TranslationService(
        onDeviceAi: fakeAi,
        aiProvider: aiService,
        mastodon: mastodonService,
        platformOverride: TargetPlatform.linux,
        isWebOverride: false,
      );

      expect(
        await translation.isTranslationSupported(
          settings: const AppSettings(activeProvider: AiProviderType.none),
          credentials: const AiCredentials(),
          session: mastodonSession,
          instanceLimits: const InstanceLimits(),
        ),
        isFalse,
      );

      expect(
        await translation.isTranslationSupported(
          settings: const AppSettings(activeProvider: AiProviderType.gemini),
          credentials: const AiCredentials(geminiApiKey: 'gem-123'),
          session: mastodonSession,
          instanceLimits: const InstanceLimits(),
        ),
        isTrue,
      );

      expect(
        await translation.isTranslationSupported(
          settings: const AppSettings(activeProvider: AiProviderType.local),
          credentials: const AiCredentials(),
        ),
        isTrue,
      );

      expect(
        await translation.isTranslationSupported(
          settings: const AppSettings(activeProvider: AiProviderType.none),
          credentials: const AiCredentials(),
          session: mastodonSession,
          instanceLimits: const InstanceLimits(translationEnabled: true),
        ),
        isTrue,
      );
    });

    test('prefers configured AI provider over Mastodon server and translates body, spoiler, and alt-text', () async {
      final fakeAi = _FakeOnDeviceAiService(status: linuxUnavailableAi);
      var aiCalls = 0;
      var mastodonCalls = 0;

      final aiService = AiProviderService(
        onDeviceAiService: fakeAi,
        client: MockClient((req) async {
          aiCalls++;
          expect(
            req.url.toString(),
            contains('generativelanguage.googleapis.com'),
          );
          return http.Response(
            jsonEncode({
              'candidates': [
                {
                  'content': {
                    'parts': [
                      {
                        'text': '```json\n{"body": "Hello from Berlin", "spoiler": "Transit update", "alt_0": "A yellow subway train"}\n```',
                      },
                    ],
                  },
                },
              ],
            }),
            200,
          );
        }),
      );
      final mastodonService = MastodonService(
        client: MockClient((_) async {
          mastodonCalls++;
          return http.Response('{}', 200);
        }),
      );

      final translation = TranslationService(
        onDeviceAi: fakeAi,
        aiProvider: aiService,
        mastodon: mastodonService,
        platformOverride: TargetPlatform.linux,
        isWebOverride: false,
        osLanguageProvider: () => 'en',
      );

      final result = await translation.translatePost(
        text: 'Hallo aus Berlin',
        spoilerText: 'Verkehrsupdate',
        altTexts: {'att-1': 'Eine gelbe U-Bahn'},
        sourceLanguage: 'de',
        statusId: 'st-42',
        settings: const AppSettings(activeProvider: AiProviderType.gemini),
        credentials: const AiCredentials(geminiApiKey: 'gem-123'),
        session: mastodonSession,
        instanceLimits: const InstanceLimits(translationEnabled: true),
      );

      expect(aiCalls, 1);
      expect(mastodonCalls, 0);
      expect(result.engineName, 'Google Gemini');
      expect(result.translatedText, 'Hello from Berlin');
      expect(result.translatedSpoiler, 'Transit update');
      expect(result.translatedAltTexts, {'att-1': 'A yellow subway train'});
    });

    test('falls back to Mastodon /api/v1/statuses/:id/translate when configured AI fails', () async {
      final fakeAi = _FakeOnDeviceAiService(status: linuxUnavailableAi);
      var aiCalls = 0;
      var mastodonCalls = 0;

      final aiService = AiProviderService(
        onDeviceAiService: fakeAi,
        client: MockClient((_) async {
          aiCalls++;
          return http.Response('Connection refused', 503);
        }),
      );
      final mastodonService = MastodonService(
        client: MockClient((req) async {
          mastodonCalls++;
          expect(
            req.url.toString(),
            'https://infosec.exchange/api/v1/statuses/st-99/translate',
          );
          expect(jsonDecode(req.body), {'lang': 'en'});
          return http.Response(
            jsonEncode({
              'content': '<p>Good evening everyone</p>',
              'spoiler_text': 'Food photo',
              'detected_source_language': 'ja',
              'provider': 'DeepL.com',
              'media_attachments': [
                {'id': 'm-7', 'description': 'A bowl of ramen'},
              ],
            }),
            200,
          );
        }),
      );

      final translation = TranslationService(
        onDeviceAi: fakeAi,
        aiProvider: aiService,
        mastodon: mastodonService,
        platformOverride: TargetPlatform.linux,
        isWebOverride: false,
        osLanguageProvider: () => 'en',
      );

      final result = await translation.translatePost(
        text: 'こんばんは',
        spoilerText: '飯テロ',
        altTexts: {'m-7': 'ラーメン'},
        sourceLanguage: 'ja',
        statusId: 'st-99',
        settings: const AppSettings(activeProvider: AiProviderType.local),
        credentials: const AiCredentials(),
        session: mastodonSession,
        instanceLimits: const InstanceLimits(translationEnabled: true),
      );

      expect(aiCalls, greaterThanOrEqualTo(1));
      expect(mastodonCalls, 1);
      expect(result.engineName, 'Mastodon (DeepL.com)');
      expect(result.translatedText, 'Good evening everyone');
      expect(result.translatedSpoiler, 'Food photo');
      expect(result.translatedAltTexts, {'m-7': 'A bowl of ramen'});
    });

    test('translates directly via Mastodon server when no AI provider is configured', () async {
      final fakeAi = _FakeOnDeviceAiService(status: linuxUnavailableAi);
      final mastodonService = MastodonService(
        client: MockClient((req) async {
          expect(
            req.url.toString(),
            'https://infosec.exchange/api/v1/statuses/st-100/translate',
          );
          return http.Response(
            jsonEncode({
              'content': '<p>Welcome to Mastodon</p>',
              'spoiler_text': '',
              'detected_source_language': 'fr',
              'provider': 'LibreTranslate',
              'media_attachments': <Object?>[],
            }),
            200,
          );
        }),
      );

      final translation = TranslationService(
        onDeviceAi: fakeAi,
        mastodon: mastodonService,
        platformOverride: TargetPlatform.windows,
        isWebOverride: false,
        osLanguageProvider: () => 'en',
      );

      final result = await translation.translatePost(
        text: 'Bienvenue sur Mastodon',
        sourceLanguage: 'fr',
        statusId: 'st-100',
        settings: const AppSettings(activeProvider: AiProviderType.none),
        credentials: const AiCredentials(),
        session: mastodonSession,
        instanceLimits: const InstanceLimits(translationEnabled: true),
      );

      expect(result.engineName, 'Mastodon (LibreTranslate)');
      expect(result.translatedText, 'Welcome to Mastodon');
    });

    testWidgets(
      'StatusCard shows translation offer on Linux using configured AI provider',
      (tester) async {
        final fakeAi = _FakeOnDeviceAiService(status: linuxUnavailableAi);
        final aiService = AiProviderService(
          onDeviceAiService: fakeAi,
          client: MockClient((_) async {
            return http.Response(
              jsonEncode({
                'candidates': [
                  {
                    'content': {
                      'parts': [
                        {
                          'text': '{"body": "Hello from Marseille!", "alt_0": "Boats moored in the old port."}',
                        },
                      ],
                    },
                  },
                ],
              }),
              200,
            );
          }),
        );
        final mastodonService = MastodonService(
          client: MockClient((_) async => http.Response('{}', 200)),
        );
        final translation = TranslationService(
          onDeviceAi: fakeAi,
          aiProvider: aiService,
          mastodon: mastodonService,
          platformOverride: TargetPlatform.linux,
          isWebOverride: false,
          osLanguageProvider: () => 'en',
        );
        final storage = _InMemoryStorageService();
        final app = AppController(
          storageService: storage,
          mastodonService: mastodonService,
          aiProviderService: aiService,
          onDeviceAiService: fakeAi,
          translationService: translation,
        );
        addTearDown(app.dispose);

        await app.updateSettings(
          const AppSettings(activeProvider: AiProviderType.gemini),
          autoRefreshModels: false,
        );
        await app.updateCredentials(
          const AiCredentials(geminiApiKey: 'test-gemini-key'),
        );

        final status = MastodonStatus(
          id: 'st-fr',
          createdAt: DateTime.now().subtract(const Duration(minutes: 2)),
          account: const MastodonAccount(
            id: 'u-1',
            username: 'jean',
            acct: 'jean@mamot.fr',
            displayName: 'Jean',
            avatar: '',
          ),
          contentHtml: '<p>Bonjour de Marseille !</p>',
          language: 'fr',
          mediaAttachments: const [
            MastodonMediaAttachment(
              id: 'med-1',
              type: 'image',
              url: '',
              description: 'Des bateaux dans le vieux port.',
            ),
          ],
        );

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light(),
            home: Scaffold(
              body: SingleChildScrollView(
                child: StatusCard(
                  status: status,
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

        await tester.tap(find.text('Translate to English'));
        await tester.pumpAndSettle();

        expect(
          find.text('Translated from French via Google Gemini'),
          findsOneWidget,
        );
        expect(find.textContaining('Hello from Marseille!'), findsOneWidget);
        expect(
          find.textContaining('Boats moored in the old port.'),
          findsOneWidget,
        );

        await tester.tap(find.text('Show Original'));
        await tester.pumpAndSettle();

        expect(find.textContaining('Bonjour de Marseille !'), findsOneWidget);
        expect(
          find.textContaining('Des bateaux dans le vieux port.'),
          findsOneWidget,
        );
      },
    );
  });
}
