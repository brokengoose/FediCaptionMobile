// Copyright (c) 2026 brokengoose <brokengoose@users.noreply.github.com>
// SPDX-License-Identifier: MIT

import 'package:edge_gen_ai/edge_gen_ai.dart';
import 'package:fedicaption_mobile/core/theme/app_theme.dart';
import 'package:fedicaption_mobile/models/app_settings.dart';
import 'package:fedicaption_mobile/models/bias_models.dart';
import 'package:fedicaption_mobile/models/mastodon_models.dart';
import 'package:fedicaption_mobile/services/on_device_ai_service.dart';
import 'package:fedicaption_mobile/state/app_controller.dart';
import 'package:fedicaption_mobile/ui/screens/ai_setup_screen.dart';
import 'package:fedicaption_mobile/ui/widgets/bias_review_sheet.dart';
import 'package:fedicaption_mobile/ui/widgets/linkified_text.dart';
import 'package:fedicaption_mobile/ui/widgets/missing_alt_text_dialog.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

class _FakeOnDeviceAiService extends OnDeviceAiService {
  @override
  Future<OnDeviceAiStatus> checkStatus() async {
    return const OnDeviceAiStatus(
      promptAvailability: EdgeGenAIAvailability.available,
      imageDescriptionAvailability: EdgeGenAIAvailability.available,
      engineName: 'Apple Foundation Models',
    );
  }
}

void main() {
  const sampleResult = BiasCheckResult(
    hasBias: true,
    summary: 'Checked Post Text and found 1 potential gender bias issue.',
    checkedComponents: ['Post Text'],
    findings: [
      BiasFinding(
        location: 'Post Text',
        biasType: 'Implicit Gender Bias',
        explanation: '"hey guys" uses a male-default plural; consider "hey everyone".',
        excerpt: 'Hey guys',
      ),
    ],
    suggestedAlternateWording: 'Hey everyone, welcome to the community!',
  );

  group('BiasReviewSheet policy behavior', () {
    testWidgets('shows Publish Anyway and suggestion buttons when policy is warn', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(
            body: BiasReviewSheet(
              result: sampleResult,
              policy: PolicyMode.warn,
            ),
          ),
        ),
      );

      expect(find.text('Pre-Post Racial & Gender Bias Review'), findsOneWidget);
      expect(find.text('Post Text'), findsOneWidget);
      expect(find.text('Implicit Gender Bias'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('Publish Anyway'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Use Suggested Wording in Composer'), findsOneWidget);
      expect(find.text('Use Suggested Wording & Publish Now'), findsOneWidget);
      expect(find.text('Publish Anyway'), findsOneWidget);
    });

    testWidgets('hides Publish Anyway when policy is require', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.highContrast(),
          home: const Scaffold(
            body: BiasReviewSheet(
              result: sampleResult,
              policy: PolicyMode.require,
            ),
          ),
        ),
      );

      await tester.scrollUntilVisible(
        find.text('Return to Composer to Edit'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Publish Anyway'), findsNothing);
      expect(find.text('Use Suggested Wording & Publish Now'), findsOneWidget);
    });
  });

  group('MissingAltTextDialog policy behavior', () {
    testWidgets('shows Post Anyway when policy is warn and hides it when require', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark(),
          home: const Scaffold(
            body: MissingAltTextDialog(
              missingCount: 2,
              policy: PolicyMode.warn,
            ),
          ),
        ),
      );

      expect(find.text('Auto-Generate Missing Alt-Text with AI'), findsOneWidget);
      expect(find.text('Post Anyway'), findsOneWidget);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark(),
          home: const Scaffold(
            body: MissingAltTextDialog(
              missingCount: 2,
              policy: PolicyMode.require,
            ),
          ),
        ),
      );

      expect(find.text('Auto-Generate Missing Alt-Text with AI'), findsOneWidget);
      expect(find.text('Post Anyway'), findsNothing);
    });

    testWidgets('hides AI auto-generate button when aiEnabled is false (No AI)', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(
            body: MissingAltTextDialog(
              missingCount: 1,
              policy: PolicyMode.warn,
              aiEnabled: false,
            ),
          ),
        ),
      );

      expect(find.text('Auto-Generate Missing Alt-Text with AI'), findsNothing);
      expect(find.text('Edit in Composer'), findsOneWidget);
      expect(find.text('Post Anyway'), findsOneWidget);
    });
  });

  group('AiSetupScreen onboarding', () {
    testWidgets('defaults to On-Device AI status card and offers No AI option', (tester) async {
      final controller = AppController(
        onDeviceAiService: _FakeOnDeviceAiService(),
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: AiSetupScreen(app: controller),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Set Up AI'), findsOneWidget);
      expect(find.text('Apple Foundation Models — Ready on Device'), findsOneWidget);
      expect(find.text('Re-Check Device'), findsOneWidget);
      expect(find.text('Use No AI (Set Up Later)'), findsOneWidget);
      expect(find.text('Save AI Settings & Continue'), findsOneWidget);
    });
  });

  group('LinkifiedText clickable URLs', () {
    testWidgets('opens full href when tapping Mastodon shortened HTML link', (tester) async {
      String? tappedUrl;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: LinkifiedText.html(
              '<p>Visit <a href="https://example.org/long/article/path">'
              '<span class="invisible">https://</span>'
              '<span class="ellipsis">example.org/long/ar</span>'
              '<span class="invisible">ticle/path</span></a></p>',
              onTapUrl: (url) async => tappedUrl = url,
            ),
          ),
        ),
      );

      final richTextFinder = find.byType(RichText);
      expect(richTextFinder, findsOneWidget);
      final richText = tester.widget<RichText>(richTextFinder);
      final rootSpan = richText.text as TextSpan;

      TextSpan? linkSpan;
      rootSpan.visitChildren((span) {
        if (span is TextSpan && span.recognizer != null) {
          linkSpan = span;
          return false;
        }
        return true;
      });

      expect(linkSpan, isNotNull);
      expect(linkSpan!.text, 'example.org/long/ar…');
      (linkSpan!.recognizer as dynamic).onTap();
      expect(tappedUrl, 'https://example.org/long/article/path');
    });

    testWidgets('makes bare URLs in plain text clickable without trailing punctuation', (tester) async {
      String? tappedUrl;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: LinkifiedText.plain(
              'See https://github.com/brokengoose/FediCaptionMobile.',
              onTapUrl: (url) async => tappedUrl = url,
            ),
          ),
        ),
      );

      final richText = tester.widget<RichText>(find.byType(RichText));
      final rootSpan = richText.text as TextSpan;

      TextSpan? linkSpan;
      rootSpan.visitChildren((span) {
        if (span is TextSpan && span.recognizer != null) {
          linkSpan = span;
          return false;
        }
        return true;
      });

      expect(linkSpan, isNotNull);
      expect(linkSpan!.text, 'https://github.com/brokengoose/FediCaptionMobile');
      (linkSpan!.recognizer as dynamic).onTap();
      expect(tappedUrl, 'https://github.com/brokengoose/FediCaptionMobile');
    });

    testWidgets('invokes onTapMention for Mastodon mention anchors', (tester) async {
      MastodonMention? tappedMention;
      const alice = MastodonMention(
        id: '42',
        username: 'alice',
        acct: 'alice@example.social',
        url: 'https://example.social/@alice',
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: LinkifiedText.html(
              '<p>Hi <a class="u-url mention" href="https://example.social/@alice">@alice</a>!</p>',
              mentions: const [alice],
              onTapMention: (m) => tappedMention = m,
            ),
          ),
        ),
      );

      final richText = tester.widget<RichText>(find.byType(RichText));
      final rootSpan = richText.text as TextSpan;

      TextSpan? mentionSpan;
      rootSpan.visitChildren((span) {
        if (span is TextSpan && span.recognizer != null) {
          mentionSpan = span;
          return false;
        }
        return true;
      });

      expect(mentionSpan, isNotNull);
      (mentionSpan!.recognizer as dynamic).onTap();
      expect(tappedMention?.id, '42');
    });
  });
}
