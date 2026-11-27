// Copyright (c) 2026 brokengoose <brokengoose@users.noreply.github.com>
// SPDX-License-Identifier: MIT

import 'dart:io';

import 'package:fedicaption_mobile/models/composer_attachment.dart';
import 'package:fedicaption_mobile/models/mastodon_models.dart';
import 'package:fedicaption_mobile/services/image_upload_optimizer.dart';
import 'package:fedicaption_mobile/services/tts_service.dart';
import 'package:fedicaption_mobile/state/app_controller.dart';
import 'package:fedicaption_mobile/ui/screens/composer_screen.dart';
import 'package:fedicaption_mobile/ui/widgets/composer_attachment_tile.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:material_ui/material_ui.dart';

import 'helpers/test_app.dart';

void main() {
  group('Composer discard guard (B19)', () {
    testWidgets(
      'clean draft and unedited reply pop immediately without confirmation',
      (tester) async {
        final app = AppController();
        addTearDown(app.dispose);

        final parent = MastodonStatus(
          id: 'p1',
          createdAt: DateTime.utc(2026, 11, 27),
          account: const MastodonAccount(
            id: 'a1',
            username: 'alice',
            acct: 'alice@example.social',
            displayName: 'Alice',
            avatar: '',
          ),
          contentHtml: '<p>Hello</p>',
        );

        await tester.pumpWidget(
          localizedTestApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: FilledButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          ComposerScreen(app: app, replyToStatus: parent),
                    ),
                  ),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        expect(find.byType(ComposerScreen), findsOneWidget);

        await tester.pageBack();
        await tester.pumpAndSettle();

        expect(find.text('Discard draft?'), findsNothing);
        expect(find.byType(ComposerScreen), findsNothing);
      },
    );

    testWidgets(
      'Back and Esc prompt to confirm discarding unsaved draft text',
      (tester) async {
        final app = AppController();
        addTearDown(app.dispose);

        await tester.pumpWidget(
          localizedTestApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: FilledButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => ComposerScreen(app: app),
                    ),
                  ),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        await tester.enterText(find.byType(TextField).first, 'Draft message');
        await tester.pumpAndSettle();

        // Esc should trigger PopScope confirmation and stay when cancelled.
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();

        expect(find.text('Discard draft?'), findsOneWidget);
        await tester.tap(find.text('Keep Editing'));
        await tester.pumpAndSettle();
        expect(find.byType(ComposerScreen), findsOneWidget);

        // Back button also prompts; confirming discards the draft and pops.
        await tester.pageBack();
        await tester.pumpAndSettle();
        expect(find.text('Discard draft?'), findsOneWidget);

        await tester.tap(find.text('Discard'));
        await tester.pumpAndSettle();
        expect(find.byType(ComposerScreen), findsNothing);
      },
    );
  });

  group('ImageUploadOptimizer & metadata warning (S3)', () {
    test('distinguishes optimized images, animated GIFs, and decode failures in isolate', () async {
      final dir = await Directory.systemTemp.createTemp('fedicaption_s3_');
      addTearDown(() async {
        if (await dir.exists()) await dir.delete(recursive: true);
      });

      const optimizer = ImageUploadOptimizer();

      // 1. Valid PNG -> optimized temp file with metadata stripped.
      final validPng = img.Image(width: 4, height: 4);
      final pngFile = File('${dir.path}/sample.png')
        ..writeAsBytesSync(img.encodePng(validPng));
      final optResult = await optimizer.optimizeFile(
        pngFile.path,
        fallbackMimeType: 'image/png',
      );
      expect(optResult.status, ImageOptimizationStatus.optimized);
      expect(optResult.metadataStripped, isTrue);
      expect(optResult.decodeFailed, isFalse);
      expect(optResult.isTempFile, isTrue);
      if (File(optResult.filePath).existsSync()) {
        File(optResult.filePath).deleteSync();
      }

      // 2. Multi-frame animated GIF -> preserved untouched, no failure warning.
      final frame1 = img.Image(width: 2, height: 2);
      final frame2 = img.Image(width: 2, height: 2);
      frame1.addFrame(frame2);
      final gifBytes = img.GifEncoder().encode(frame1);
      final gifFile = File('${dir.path}/anim.gif')..writeAsBytesSync(gifBytes);
      final gifResult = await optimizer.optimizeFile(
        gifFile.path,
        fallbackMimeType: 'image/gif',
      );
      expect(gifResult.status, ImageOptimizationStatus.preservedAnimated);
      expect(gifResult.decodeFailed, isFalse);
      expect(gifResult.isTempFile, isFalse);

      // 3. Undecodable bytes (e.g. HEIC) -> reports decodeFailed so UI warns.
      final heicFile = File('${dir.path}/photo.heic')
        ..writeAsBytesSync([0, 1, 2, 3, 4, 5, 6, 7]);
      final failResult = await optimizer.optimizeFile(
        heicFile.path,
        fallbackMimeType: 'image/heic',
      );
      expect(failResult.status, ImageOptimizationStatus.decodeFailed);
      expect(failResult.decodeFailed, isTrue);
      expect(failResult.metadataStripped, isFalse);
      expect(failResult.isTempFile, isFalse);
    });

    testWidgets(
      'ComposerAttachmentTile shows warning when metadata could not be stripped',
      (tester) async {
        final tts = TtsService(isLinuxOverride: true);
        await tester.pumpWidget(
          localizedTestApp(
            home: Scaffold(
              body: Column(
                children: [
                  ComposerAttachmentTile(
                    index: 0,
                    attachment: const ComposerAttachment(
                      localId: 'att_warn',
                      isVideo: false,
                      mimeType: 'image/heic',
                      metadataNotStripped: true,
                    ),
                    maxAltTextLength: 1500,
                    language: 'en',
                    tts: tts,
                    aiEnabled: false,
                    onAltTextChanged: (_) {},
                    onDetailLevelChanged: (_) {},
                    onRescan: () {},
                    onRemove: () {},
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.textContaining('EXIF/location metadata could not be stripped'),
          findsOneWidget,
        );
      },
    );
  });
}
