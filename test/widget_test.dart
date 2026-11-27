// Copyright (c) 2026 brokengoose <brokengoose@users.noreply.github.com>
// SPDX-License-Identifier: MIT

import 'dart:async';

import 'package:edge_gen_ai/edge_gen_ai.dart';
import 'package:fedicaption_mobile/app.dart';
import 'package:fedicaption_mobile/core/theme/app_theme.dart';
import 'package:fedicaption_mobile/models/ai_models.dart';
import 'package:fedicaption_mobile/models/app_settings.dart';
import 'package:fedicaption_mobile/models/bias_models.dart';
import 'package:fedicaption_mobile/models/mastodon_models.dart';
import 'package:fedicaption_mobile/models/update_info.dart';
import 'package:fedicaption_mobile/services/on_device_ai_service.dart';
import 'package:fedicaption_mobile/services/storage_service.dart';
import 'package:fedicaption_mobile/services/update_check_service.dart';
import 'package:fedicaption_mobile/state/app_controller.dart';
import 'package:fedicaption_mobile/ui/helpers/status_action_handler.dart';
import 'package:fedicaption_mobile/ui/screens/ai_setup_screen.dart';
import 'package:fedicaption_mobile/ui/screens/image_viewer_screen.dart';
import 'package:fedicaption_mobile/ui/screens/login_screen.dart';
import 'package:fedicaption_mobile/ui/widgets/bias_review_sheet.dart';
import 'package:fedicaption_mobile/ui/widgets/cached_network_image_provider.dart';
import 'package:fedicaption_mobile/ui/widgets/linkified_text.dart';
import 'package:fedicaption_mobile/ui/widgets/media_attachment_card.dart';
import 'package:fedicaption_mobile/ui/widgets/missing_alt_text_dialog.dart';
import 'package:fedicaption_mobile/ui/widgets/quoted_status_card.dart';
import 'package:fedicaption_mobile/ui/widgets/status_card.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

class _FakeOnDeviceAiService extends OnDeviceAiService {
  _FakeOnDeviceAiService({
    this.status = const OnDeviceAiStatus(
      promptAvailability: EdgeGenAIAvailability.available,
      imageDescriptionAvailability: EdgeGenAIAvailability.available,
      engineName: 'Apple Foundation Models',
    ),
    this.pendingCheck,
  });

  final OnDeviceAiStatus status;
  final Completer<OnDeviceAiStatus>? pendingCheck;

  @override
  Future<OnDeviceAiStatus> checkStatus() async {
    if (pendingCheck != null) {
      return pendingCheck!.future;
    }
    return status;
  }
}

class _InMemoryStorageService extends StorageService {
  AppSettings _settings = const AppSettings();
  AiCredentials _credentials = const AiCredentials();

  @override
  Future<AppSettings> loadSettings() async => _settings;

  @override
  Future<void> saveSettings(AppSettings settings) async {
    _settings = settings;
  }

  @override
  Future<AiCredentials> loadAiCredentials() async => _credentials;

  @override
  Future<void> saveAiCredentials(AiCredentials creds) async {
    _credentials = creds;
  }

  @override
  Future<MastodonSession?> loadSession() async => null;
}

class _NoOpUpdateCheckService extends UpdateCheckService {
  @override
  Future<UpdateInfo?> checkForUpdate({String currentVersion = ''}) async =>
      null;
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

      expect(controller.settings.activeProvider, AiProviderType.onDevice);
      expect(find.text('Set Up AI'), findsOneWidget);
      expect(find.text('Apple Foundation Models — Ready on Device'), findsOneWidget);
      expect(find.text('Re-Check Device'), findsOneWidget);
      expect(find.text('Use No AI (Set Up Later)'), findsOneWidget);
      expect(find.text('Save AI Settings & Continue'), findsOneWidget);
    });

    testWidgets('defaults to On-Device AI when model is downloadable', (tester) async {
      final controller = AppController(
        onDeviceAiService: _FakeOnDeviceAiService(
          status: const OnDeviceAiStatus(
            promptAvailability: EdgeGenAIAvailability.downloadable,
            imageDescriptionAvailability: EdgeGenAIAvailability.unavailable,
            engineName: 'Google Gemini Nano (ML Kit GenAI / AICore)',
          ),
        ),
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: AiSetupScreen(app: controller),
        ),
      );
      await tester.pumpAndSettle();

      expect(controller.settings.activeProvider, AiProviderType.onDevice);
      expect(find.text('Save AI Settings & Continue'), findsOneWidget);
      expect(find.text('Use No AI (Set Up Later)'), findsOneWidget);
    });

    testWidgets('defaults to No AI when on-device AI is unavailable', (tester) async {
      final pending = Completer<OnDeviceAiStatus>();
      final controller = AppController(
        onDeviceAiService: _FakeOnDeviceAiService(pendingCheck: pending),
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: AiSetupScreen(app: controller),
        ),
      );
      await tester.pump();

      expect(find.text('Checking on-device AI availability…'), findsOneWidget);

      pending.complete(
        const OnDeviceAiStatus(
          promptAvailability: EdgeGenAIAvailability.unavailable,
          imageDescriptionAvailability: EdgeGenAIAvailability.unavailable,
          engineName: 'On-Device AI',
        ),
      );
      await tester.pumpAndSettle();

      expect(controller.settings.activeProvider, AiProviderType.none);
      expect(find.text('No AI Selected'), findsOneWidget);
      expect(find.text('Continue with No AI'), findsOneWidget);
      expect(find.text('Use No AI (Set Up Later)'), findsNothing);
    });

    testWidgets('defaults to No AI when on-device AI is not yet ready', (tester) async {
      final controller = AppController(
        onDeviceAiService: _FakeOnDeviceAiService(
          status: const OnDeviceAiStatus(
            promptAvailability: EdgeGenAIAvailability.notYetReady,
            imageDescriptionAvailability: EdgeGenAIAvailability.notYetReady,
            engineName: 'Apple Foundation Models',
          ),
        ),
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: AiSetupScreen(app: controller),
        ),
      );
      await tester.pumpAndSettle();

      expect(controller.settings.activeProvider, AiProviderType.none);
      expect(find.text('No AI Selected'), findsOneWidget);
      expect(find.text('Continue with No AI'), findsOneWidget);
    });

    testWidgets(
        'FediCaptionApp shows AI setup first, then Mastodon login after completion',
        (tester) async {
      final controller = AppController(
        storageService: _InMemoryStorageService(),
        onDeviceAiService: _FakeOnDeviceAiService(),
        updateCheckService: _NoOpUpdateCheckService(),
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(FediCaptionApp(controller: controller));
      await tester.pumpAndSettle();

      expect(find.byType(AiSetupScreen), findsOneWidget);
      expect(find.byType(LoginScreen), findsNothing);

      await tester.ensureVisible(find.text('Save AI Settings & Continue'));
      await tester.tap(find.text('Save AI Settings & Continue'));
      await tester.pumpAndSettle();

      expect(controller.settings.aiSetupCompleted, isTrue);
      expect(find.byType(AiSetupScreen), findsNothing);
      expect(find.byType(LoginScreen), findsOneWidget);
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

  group('StatusCard embedded RE: quoted post', () {
    testWidgets('embeds original post window and strips leading RE: URL prefix', (tester) async {
      final controller = AppController(
        onDeviceAiService: _FakeOnDeviceAiService(),
      );
      addTearDown(controller.dispose);

      final original = MastodonStatus(
        id: '100',
        createdAt: DateTime.utc(2026, 11, 19, 10, 0),
        account: const MastodonAccount(
          id: '1',
          username: 'orig',
          acct: 'orig@example.social',
          displayName: 'Original Author',
          avatar: '',
        ),
        contentHtml: '<p>Original insightful Mastodon post.</p>',
        url: 'https://example.social/@orig/100',
      );

      final quotingPost = MastodonStatus(
        id: '200',
        createdAt: DateTime.utc(2026, 11, 19, 11, 0),
        account: const MastodonAccount(
          id: '2',
          username: 'commentator',
          acct: 'commentator@example.social',
          displayName: 'Commentator',
          avatar: '',
        ),
        contentHtml:
            '<p>RE: <a href="https://example.social/@orig/100">https://example.social/@orig/100</a></p>'
            '<p>Strongly agree with this!</p>',
        quotedStatus: original,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: StatusCard(
                status: quotingPost,
                app: controller,
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

      expect(find.byType(QuotedStatusCard), findsOneWidget);
      expect(find.text('Quoted Post'), findsOneWidget);
      expect(find.text('Original Author'), findsOneWidget);
      expect(find.textContaining('Original insightful Mastodon post.'), findsOneWidget);
      expect(find.textContaining('Strongly agree with this!'), findsOneWidget);
      expect(find.textContaining('RE: https://example.social/@orig/100'), findsNothing);

      // Quoted post window should render above the reply text.
      final quoteRect = tester.getRect(find.byType(QuotedStatusCard));
      final replyRect = tester.getRect(find.textContaining('Strongly agree with this!'));
      expect(quoteRect.bottom, lessThanOrEqualTo(replyRect.top));
    });

    testWidgets('QuotedStatusCard fallback exposes Retry button when onRetry is provided', (tester) async {
      final controller = AppController(
        onDeviceAiService: _FakeOnDeviceAiService(),
      );
      addTearDown(controller.dispose);
      var retried = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: QuotedStatusCard(
              app: controller,
              quoteUrl: 'https://example.social/@orig/404',
              onOpenProfile: (_) {},
              onOpenThread: (_) {},
              onRetry: () => retried = true,
            ),
          ),
        ),
      );

      expect(find.text('Quoted post could not be loaded in-app'), findsOneWidget);
      await tester.tap(find.text('Retry'));
      expect(retried, isTrue);
    });
  });

  group('StatusActionHandler delete confirmation', () {
    testWidgets('prompts before deleting and returns false when user cancels', (tester) async {
      final controller = AppController(
        onDeviceAiService: _FakeOnDeviceAiService(),
      );
      addTearDown(controller.dispose);
      final handler = StatusActionHandler(app: controller);
      bool? deleteOutcome;

      final sampleStatus = MastodonStatus(
        id: '555',
        createdAt: DateTime.utc(2026, 11, 20),
        account: const MastodonAccount(
          id: '1',
          username: 'tester',
          acct: 'tester',
          displayName: 'Tester',
          avatar: '',
        ),
        contentHtml: '<p>Test post</p>',
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  deleteOutcome = await handler.confirmAndDelete(
                    context,
                    sampleStatus,
                  );
                },
                child: const Text('Trigger Delete'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Trigger Delete'));
      await tester.pumpAndSettle();

      expect(find.text('Delete Post?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(deleteOutcome, isFalse);
    });
  });

  group('MediaAttachmentCard full-screen image viewer', () {
    testWidgets('tapping an image opens ImageViewerScreen scaled to fit screen', (tester) async {
      final controller = AppController(
        onDeviceAiService: _FakeOnDeviceAiService(),
      );
      addTearDown(controller.dispose);

      const attachment = MastodonMediaAttachment(
        id: 'img_1',
        type: 'image',
        url: 'https://example.social/media/full.jpg',
        previewUrl: 'https://example.social/media/preview.jpg',
        description: 'A tall sunset photograph over mountains.',
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: MediaAttachmentCard(
                attachment: attachment,
                app: controller,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.broken_image));
      await tester.pumpAndSettle();

      expect(find.byType(ImageViewerScreen), findsOneWidget);
      expect(find.text('Full Image'), findsOneWidget);

      final fullImage = tester.widget<Image>(
        find.descendant(
          of: find.byType(ImageViewerScreen),
          matching: find.byType(Image),
        ),
      );
      expect(fullImage.fit, BoxFit.contain);
      expect(
        (fullImage.image as DiskCachedNetworkImage).url,
        'https://example.social/media/full.jpg',
      );

      await tester.tap(find.byTooltip('Close full-screen image'));
      await tester.pumpAndSettle();
      expect(find.byType(ImageViewerScreen), findsNothing);
    });

    testWidgets('long-pressing full-screen image triggers share menu', (tester) async {
      String? sharedUrl;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: ImageViewerScreen(
            imageUrl: 'https://example.social/media/full.jpg',
            altText: 'Sunset photo',
            onShareImage: (url, _) async => sharedUrl = url,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.longPress(find.byType(InteractiveViewer));
      await tester.pumpAndSettle();
      expect(sharedUrl, 'https://example.social/media/full.jpg');

      // Also verify the accessible AppBar share button triggers sharing.
      sharedUrl = null;
      await tester.tap(find.byTooltip('Share or save image'));
      await tester.pumpAndSettle();
      expect(sharedUrl, 'https://example.social/media/full.jpg');
    });
  });
}
