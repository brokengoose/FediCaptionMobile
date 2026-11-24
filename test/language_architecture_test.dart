// Copyright (c) 2026 brokengoose <brokengoose@users.noreply.github.com>
// SPDX-License-Identifier: MIT

import 'package:fedicaption_mobile/core/constants.dart';
import 'package:fedicaption_mobile/core/language/bias_language_pack.dart';
import 'package:fedicaption_mobile/core/language/caption_language_pack.dart';
import 'package:fedicaption_mobile/core/language/language_pack_registry.dart';
import 'package:fedicaption_mobile/core/language/language_registry.dart';
import 'package:fedicaption_mobile/core/time_utils.dart';
import 'package:fedicaption_mobile/l10n/l10n.dart';
import 'package:fedicaption_mobile/l10n/model_localizations.dart';
import 'package:fedicaption_mobile/models/ai_models.dart';
import 'package:fedicaption_mobile/models/app_settings.dart';
import 'package:fedicaption_mobile/models/bias_models.dart';
import 'package:fedicaption_mobile/models/mastodon_models.dart';
import 'package:fedicaption_mobile/services/ai/ai_prompt_builder.dart';
import 'package:fedicaption_mobile/services/ai_provider_service.dart';
import 'package:fedicaption_mobile/services/bias_check_service.dart';
import 'package:fedicaption_mobile/services/caption_formatter.dart';
import 'package:fedicaption_mobile/services/link_preview_fetcher.dart';
import 'package:fedicaption_mobile/services/local_bias_heuristics.dart';
import 'package:fedicaption_mobile/services/mastodon_service.dart';
import 'package:fedicaption_mobile/ui/helpers/keyboard_shortcuts.dart';
import 'package:fedicaption_mobile/ui/widgets/bias_review_sheet.dart';
import 'package:fedicaption_mobile/ui/widgets/missing_alt_text_dialog.dart';
import 'package:fedicaption_mobile/ui/widgets/post_translation_banner.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'helpers/test_app.dart';

class _FakeBiasAiProviderService extends AiProviderService {
  String? lastSystemPrompt;
  String? lastUserPrompt;
  String responseJson =
      '{"has_bias": false, "summary": "Sin sesgos detectados.", "findings": [], "suggested_alternate_wording": null}';

  @override
  Future<String> runMultimodalPrompt({
    required AppSettings settings,
    required AiCredentials credentials,
    required String systemPrompt,
    required String userPrompt,
    List<MediaBinaryPayload> media = const [],
    bool expectJson = false,
  }) async {
    lastSystemPrompt = systemPrompt;
    lastUserPrompt = userPrompt;
    return responseJson;
  }
}

void main() {
  group('LanguageRegistry', () {
    test('normalizes BCP-47 tags and filters invalid values', () {
      expect(LanguageRegistry.normalizeCode('en-US'), 'en');
      expect(LanguageRegistry.normalizeCode('pt_BR'), 'pt');
      expect(LanguageRegistry.normalizeCode('nb-NO'), 'no');
      expect(LanguageRegistry.normalizeCode('nn-NO'), 'no');
      expect(LanguageRegistry.normalizeCode('zh-Hans'), 'zh');
      expect(LanguageRegistry.normalizeCode('und'), isNull);
      expect(LanguageRegistry.normalizeCode('unknown'), isNull);
      expect(LanguageRegistry.normalizeCode('   '), isNull);
      expect(LanguageRegistry.normalizeCode(null), isNull);
    });

    test('resolves by code, English name, native endonym, and aliases', () {
      expect(LanguageRegistry.resolveCode('es'), 'es');
      expect(LanguageRegistry.resolveCode('Spanish'), 'es');
      expect(LanguageRegistry.resolveCode('Español'), 'es');
      expect(LanguageRegistry.resolveCode('espanol'), 'es');
      expect(LanguageRegistry.resolveCode('日本語'), 'ja');
      expect(LanguageRegistry.resolveCode('Mandarin'), 'zh');
      expect(LanguageRegistry.resolveCode('filipino'), 'tl');
      expect(LanguageRegistry.resolveCode('bokmal'), 'no');

      expect(LanguageRegistry.englishNameFor('es'), 'Spanish');
      expect(LanguageRegistry.nativeNameFor('ja'), '日本語');
    });

    test('resolves TTS locales with defaults and explicit regional subtags', () {
      expect(LanguageRegistry.resolveTtsLocale('en'), 'en-US');
      expect(LanguageRegistry.resolveTtsLocale('ja'), 'ja-JP');
      expect(LanguageRegistry.resolveTtsLocale('Spanish'), 'es-ES');
      expect(LanguageRegistry.resolveTtsLocale('es-MX'), 'es-MX');
      expect(LanguageRegistry.resolveTtsLocale('pt_BR'), 'pt-BR');
      expect(LanguageRegistry.resolveTtsLocale(''), isNull);

      expect(LanguageRegistry.resolveLinuxTtsCode('pt-BR'), 'pt');
      expect(LanguageRegistry.resolveLinuxTtsCode('zh-CN'), 'zh');
      expect(LanguageRegistry.resolveLinuxTtsCode('en-US'), 'en');
      expect(LanguageRegistry.resolveLinuxTtsCode('Portuguese'), 'pt');
      expect(LanguageRegistry.resolveLinuxTtsCode(''), isNull);
    });

    test('tracks word spacing and letter case metadata accurately', () {
      final en = LanguageRegistry.resolve('en')!;
      final ja = LanguageRegistry.resolve('ja')!;
      final zh = LanguageRegistry.resolve('zh')!;
      final th = LanguageRegistry.resolve('th')!;
      final ar = LanguageRegistry.resolve('ar')!;

      expect(en.usesWordSpaces, isTrue);
      expect(en.hasLetterCase, isTrue);

      expect(ja.usesWordSpaces, isFalse);
      expect(ja.hasLetterCase, isFalse);
      expect(zh.usesWordSpaces, isFalse);
      expect(zh.hasLetterCase, isFalse);
      expect(th.usesWordSpaces, isFalse);
      expect(th.hasLetterCase, isFalse);

      expect(ar.usesWordSpaces, isTrue);
      expect(ar.hasLetterCase, isFalse);
    });

    test('detects non-Latin scripts offline and leaves Latin text null', () {
      expect(LanguageRegistry.detectScriptLanguage('こんにちは世界'), 'ja');
      expect(LanguageRegistry.detectScriptLanguage('안녕하세요 세계'), 'ko');
      expect(LanguageRegistry.detectScriptLanguage('这是一段中文测试'), 'zh');
      expect(LanguageRegistry.detectScriptLanguage('Привет мир как дела'), 'ru');
      expect(LanguageRegistry.detectScriptLanguage('Καλημέρα κόσμε'), 'el');
      expect(
        LanguageRegistry.detectScriptLanguage('مرحبا بكم في هذا العالم'),
        'ar',
      );
      expect(LanguageRegistry.detectScriptLanguage('שלום עולם טוב'), 'he');
      expect(
        LanguageRegistry.detectScriptLanguage('नमस्ते दुनिया यह परीक्षण है'),
        'hi',
      );
      expect(LanguageRegistry.detectScriptLanguage('สวัสดีชาวโลกทดสอบ'), 'th');
      expect(
        LanguageRegistry.detectScriptLanguage('Hello world in Latin script'),
        isNull,
      );
    });
  });

  group('CaptionLanguagePack & LanguagePackRegistry', () {
    test('uses AppConstants.aiCaptionPrefix for default English pack', () {
      final pack = LanguagePackRegistry.captionPackFor('en');
      expect(pack.captionPrefix, AppConstants.aiCaptionPrefix);
      expect(
        CaptionFormatter.format('"Image of a calm lake."'),
        'AI generated description: A calm lake.',
      );
    });

    test('never unregisters default English pack', () {
      LanguagePackRegistry.unregister('en');
      expect(LanguagePackRegistry.registeredLanguageCodes, contains('en'));
      expect(
        LanguagePackRegistry.captionPackFor('en').captionPrefix,
        AppConstants.aiCaptionPrefix,
      );
    });

    test('applies custom registered caption pack in formatter and prompt builder',
        () {
      const spanishPrefix = 'Descripción generada por IA: ';
      LanguagePackRegistry.register(
        AppLanguagePack(
          languageCode: 'es',
          caption: CaptionLanguagePack(
            languageCode: 'es',
            captionPrefix: spanishPrefix,
            redundantPrefixPatterns: [
              RegExp(
                r'^descripci[oó]n\s+generada\s+por\s+ia\s*:\s*',
                caseSensitive: false,
              ),
              RegExp(r'^foto\s+de\s+', caseSensitive: false),
            ],
            forbiddenPrefixExamples: const [
              'Foto de',
              'Descripción generada por IA:',
            ],
          ),
        ),
      );
      addTearDown(() => LanguagePackRegistry.unregister('es'));

      final formatted = CaptionFormatter.format(
        '«Foto de un gato dormido»',
        language: 'es',
      );
      expect(formatted, 'Descripción generada por IA: Un gato dormido');

      const maxLen = 100;
      final prompt = AiPromptBuilder.buildAltTextPrompt(
        isVideo: false,
        isInlineVideo: false,
        frameCount: 0,
        detailLevel: CaptionDetailLevel.descriptive,
        language: 'Spanish',
        maxLength: maxLen,
      );
      const expectedBudget = maxLen - spanishPrefix.length;
      expect(prompt, contains('Spanish'));
      expect(prompt, contains('$expectedBudget characters'));
      expect(prompt, contains('"Foto de"'));
    });

    test('handles non-spaced scripts without losing capitalization or UTF-16 safety',
        () {
      final formatted = CaptionFormatter.format(
        '東京駅の赤いレンガ造りの駅舎の前に立つ人々の風景です',
        language: 'ja',
        maxLength: 40,
      );
      expect(formatted.length, 40);
      expect(formatted.endsWith('…'), isTrue);
      expect(formatted.startsWith(AppConstants.aiCaptionPrefix), isTrue);

      final directNoCase = CaptionFormatter.format(
        'lowercase start with café',
        pack: const CaptionLanguagePack(
          languageCode: 'ja',
          captionPrefix: '説明: ',
          capitalizeFirstLetter: false,
          usesWordSpaces: false,
        ),
      );
      expect(directNoCase, '説明: lowercase start with café');
    });
  });

  group('BiasLanguagePack & BiasCheckService', () {
    test('does not fire English rules on non-English drafts without a pack',
        () {
      final result = LocalBiasHeuristics.evaluate(
        input: const BiasCheckInput(
          postText: 'History of mankind and businessmen',
        ),
        languageCode: 'fr',
      );
      expect(result.hasBias, isFalse);
      expect(result.findings, isEmpty);
    });

    test('applies registered custom BiasLanguagePack and custom labels', () {
      LanguagePackRegistry.register(
        AppLanguagePack(
          languageCode: 'es',
          caption: const CaptionLanguagePack(
            languageCode: 'es',
            captionPrefix: 'Descripción generada por IA: ',
          ),
          bias: BiasLanguagePack(
            languageCode: 'es',
            rules: [
              BiasHeuristicRule(
                pattern: RegExp(
                  r'\bhombre de negocios\b',
                  caseSensitive: false,
                ),
                replacement: 'persona de negocios',
                category: BiasCategory.implicitGender,
                biasType: 'Sesgo de género',
                explanation: 'Prefiera una expresión neutral en género.',
              ),
            ],
            promptBiasExamples: const ['hombre de negocios'],
          ),
        ),
      );
      addTearDown(() => LanguagePackRegistry.unregister('es'));

      final spanishLabels = BiasComponentLabels(
        postText: 'Texto de la publicación',
        contentWarning: 'Advertencia de contenido',
        attachmentLabel: (i) => 'Adjunto $i',
        linkLabel: (url) => 'Enlace ($url)',
        referencedMessageLabel: (handle) => 'Mensaje citado (@$handle)',
        cleanSummary: 'No se detectaron sesgos.',
        localCleanSummary: 'Sin sesgos locales.',
        findingsSummary: (checked, count) =>
            'Revisado $checked: $count hallazgo(s).',
        aiFallbackBiasSummary: (checked) => 'Sesgo detectado en $checked.',
        aiFallbackCleanSummary: 'No se detectaron sesgos.',
      );

      final result = LocalBiasHeuristics.evaluate(
        input: const BiasCheckInput(
          postText: 'Hombre de negocios hablando en público.',
        ),
        languageCode: 'es',
        labels: spanishLabels,
      );

      expect(result.hasBias, isTrue);
      expect(result.findings, hasLength(1));
      expect(result.findings.first.location, 'Texto de la publicación');
      expect(result.findings.first.biasType, 'Sesgo de género');
      expect(
        result.suggestedAlternateWording,
        'Persona de negocios hablando en público.',
      );
      expect(result.summary, contains('Texto de la publicación'));
    });

    test('BiasCheckService instructs AI in responseLanguageCode when non-English',
        () async {
      final fakeAi = _FakeBiasAiProviderService();
      final fetcher = LinkPreviewFetcher();
      final mastodon = MastodonService();
      addTearDown(() {
        fakeAi.dispose();
        mastodon.dispose();
      });

      final service = BiasCheckService(
        aiProviderService: fakeAi,
        linkPreviewFetcher: fetcher,
        mastodonService: mastodon,
      );

      final result = await service.checkDraft(
        input: const BiasCheckInput(postText: 'A neutral community announcement.'),
        settings: const AppSettings(activeProvider: AiProviderType.gemini),
        credentials: const AiCredentials(geminiApiKey: 'test-key'),
        contentLanguageCode: 'en',
        responseLanguageCode: 'es',
      );

      expect(result.hasBias, isFalse);
      expect(fakeAi.lastSystemPrompt, contains('Spanish'));
      expect(fakeAi.lastUserPrompt, contains('Spanish'));
      expect(
        fakeAi.lastSystemPrompt,
        contains('suggested_alternate_wording'),
      );
      expect(
        fakeAi.lastUserPrompt,
        contains('same language as the post text'),
      );
    });
  });

  group('AppSettings.appLocale', () {
    test('round-trips through JSON and defaults legacy JSON to null', () {
      const configured = AppSettings(appLocale: 'pt_BR');
      final decoded = AppSettings.fromJson(configured.toJson());
      expect(decoded.appLocale, 'pt_BR');
      expect(decoded.resolvedAppLocale, const Locale('pt', 'BR'));

      final legacy = AppSettings.fromJson(const {'language': 'English'});
      expect(legacy.appLocale, isNull);
      expect(legacy.resolvedAppLocale, isNull);
    });

    test('parses single, region, and script subtags and supports clearAppLocale',
        () {
      expect(
        const AppSettings(appLocale: 'es').resolvedAppLocale,
        const Locale('es'),
      );
      expect(
        const AppSettings(appLocale: 'es-MX').resolvedAppLocale,
        const Locale('es', 'MX'),
      );
      expect(
        const AppSettings(appLocale: 'zh-Hant-TW').resolvedAppLocale,
        const Locale.fromSubtags(
          languageCode: 'zh',
          scriptCode: 'Hant',
          countryCode: 'TW',
        ),
      );
      expect(const AppSettings(appLocale: '').resolvedAppLocale, isNull);
      expect(const AppSettings(appLocale: '1234').resolvedAppLocale, isNull);

      const initial = AppSettings(appLocale: 'es');
      expect(initial.copyWith(clearAppLocale: true).appLocale, isNull);
    });
  });

  group('Localization helpers, TimeUtils & Notifications', () {
    test('resolveSupportedLocale, resolveAppLocalizations & resolveTextDirection',
        () {
      expect(
        resolveSupportedLocale(const Locale('xx')),
        const Locale('en'),
      );
      final enL10n = resolveAppLocalizations(const Locale('en'));
      expect(enL10n.commonCancel, 'Cancel');

      expect(resolveTextDirection(const Locale('en')), TextDirection.ltr);
      expect(resolveTextDirection(const Locale('ar')), TextDirection.rtl);
      expect(resolveTextDirection(const Locale('he')), TextDirection.rtl);
    });

    test('TimeUtils formats compact and accessible relative times cleanly', () {
      final l10n = AppLocalizationsEn();
      final now = DateTime.utc(2026, 6, 15, 12, 0, 0);

      expect(
        TimeUtils.formatRelativeCompact(
          now.subtract(const Duration(seconds: 20)),
          now: now,
          l10n: l10n,
        ),
        'now',
      );
      expect(
        TimeUtils.formatRelativeCompact(
          now.subtract(const Duration(minutes: 5)),
          now: now,
          l10n: l10n,
        ),
        '5m',
      );
      expect(
        TimeUtils.formatRelativeCompact(
          now.subtract(const Duration(hours: 3)),
          now: now,
          l10n: l10n,
        ),
        '3h',
      );
      expect(
        TimeUtils.formatRelativeCompact(
          now.subtract(const Duration(days: 4)),
          now: now,
          l10n: l10n,
        ),
        '4d',
      );
      expect(
        TimeUtils.formatRelativeCompact(
          now.subtract(const Duration(days: 65)),
          now: now,
          l10n: l10n,
        ),
        '2mo',
      );
      expect(
        TimeUtils.formatRelativeCompact(
          now.subtract(const Duration(days: 740)),
          now: now,
          l10n: l10n,
        ),
        '2y',
      );

      expect(
        TimeUtils.formatRelativeAccessible(
          now.subtract(const Duration(seconds: 15)),
          now: now,
          l10n: l10n,
        ),
        'just now',
      );
      expect(
        TimeUtils.formatRelativeAccessible(
          now.subtract(const Duration(minutes: 1)),
          now: now,
          l10n: l10n,
        ),
        '1 minute ago',
      );
      expect(
        TimeUtils.formatRelativeAccessible(
          now.subtract(const Duration(hours: 2)),
          now: now,
          l10n: l10n,
        ),
        '2 hours ago',
      );
      expect(
        TimeUtils.formatRelativeAccessible(
          now.subtract(const Duration(days: 1)),
          now: now,
          l10n: l10n,
        ),
        '1 day ago',
      );
      expect(
        TimeUtils.formatRelativeAccessible(
          DateTime(2025, 5, 1, 12, 0),
          now: now,
          l10n: l10n,
        ),
        '2025-05-01',
      );
    });

    test('MastodonNotificationL10n produces full-sentence summaries', () {
      final l10n = AppLocalizationsEn();
      const account = MastodonAccount(
        id: '1',
        username: 'alice',
        acct: 'alice',
        displayName: 'Alice',
        avatar: '',
      );

      final mention = MastodonNotification(
        id: 'n1',
        type: 'mention',
        createdAt: DateTime.utc(2026, 6, 15),
        account: account,
      );
      final poll = MastodonNotification(
        id: 'n2',
        type: 'poll',
        createdAt: DateTime.utc(2026, 6, 15),
        account: account,
      );
      final unknown = MastodonNotification(
        id: 'n3',
        type: 'custom_event',
        createdAt: DateTime.utc(2026, 6, 15),
        account: account,
      );

      expect(mention.localizedSummary(l10n), 'Alice mentioned you');
      expect(
        poll.localizedSummary(l10n),
        'Alice: a poll you participated in has ended',
      );
      expect(unknown.localizedSummary(l10n), 'Alice (custom_event)');
    });
  });

  group('Localized & RTL Widget Tests', () {
    testWidgets('MissingAltTextDialog uses singular/plural ICU forms and policy',
        (tester) async {
      await tester.pumpWidget(
        localizedTestApp(
          home: const Scaffold(
            body: MissingAltTextDialog(
              missingCount: 1,
              policy: PolicyMode.warn,
            ),
          ),
        ),
      );
      expect(
        find.textContaining('1 media attachment is missing'),
        findsOneWidget,
      );
      expect(find.text('Post Anyway'), findsOneWidget);

      await tester.pumpWidget(
        localizedTestApp(
          home: const Scaffold(
            body: MissingAltTextDialog(
              missingCount: 2,
              policy: PolicyMode.require,
            ),
          ),
        ),
      );
      expect(
        find.textContaining('2 media attachments are missing'),
        findsOneWidget,
      );
      expect(find.text('Post Anyway'), findsNothing);
    });

    testWidgets('PostTranslationBanner renders cleanly in LTR and RTL',
        (tester) async {
      for (final direction in [TextDirection.ltr, TextDirection.rtl]) {
        await tester.pumpWidget(
          localizedTestApp(
            textDirection: direction,
            home: Scaffold(
              body: PostTranslationBanner(
                sourceLanguageCode: 'ja',
                targetLanguageCode: 'en',
                isTranslating: false,
                showingTranslation: false,
                onTranslate: () {},
                onToggleOriginal: () {},
              ),
            ),
          ),
        );
        expect(tester.takeException(), isNull);
        expect(find.text('Written in Japanese'), findsOneWidget);
        expect(find.text('Translate to English'), findsOneWidget);
      }
    });

    testWidgets('BiasReviewSheet renders cleanly in LTR and RTL',
        (tester) async {
      const sampleResult = BiasCheckResult(
        hasBias: true,
        summary: 'Checked Post Text and found 1 potential bias issue.',
        checkedComponents: ['Post Text'],
        findings: [
          BiasFinding(
            location: 'Post Text',
            biasType: 'Implicit Gender Bias',
            explanation: 'Use gender-neutral terminology where possible.',
            excerpt: 'mankind',
          ),
        ],
        suggestedAlternateWording: 'A win for humanity.',
        usedLocalFallback: true,
      );

      for (final direction in [TextDirection.ltr, TextDirection.rtl]) {
        await tester.pumpWidget(
          localizedTestApp(
            textDirection: direction,
            home: const Scaffold(
              body: BiasReviewSheet(
                result: sampleResult,
                policy: PolicyMode.warn,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('Pre-Post Racial & Gender Bias Review'), findsOneWidget);
        expect(find.text('Suggested Alternate Wording'), findsOneWidget);
      }
    });

    testWidgets('KeyboardShortcutsDialog renders sections and closes cleanly',
        (tester) async {
      await tester.pumpWidget(
        localizedTestApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => KeyboardShortcutsDialog.show(context),
                  child: const Text('Show Shortcuts'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Shortcuts'));
      await tester.pumpAndSettle();

      expect(find.text('Keyboard Shortcuts'), findsOneWidget);
      expect(find.text('Post Navigation'), findsOneWidget);
      expect(find.text('Switch Timelines'), findsOneWidget);

      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      expect(find.text('Keyboard Shortcuts'), findsNothing);
    });
  });
}
