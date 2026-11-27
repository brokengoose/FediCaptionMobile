// Copyright (c) 2026 brokengoose <brokengoose@users.noreply.github.com>
// SPDX-License-Identifier: MIT

import 'dart:convert';
import 'dart:io';

import 'package:fedicaption_mobile/models/composer_attachment.dart';
import 'package:fedicaption_mobile/models/mastodon_models.dart';
import 'package:fedicaption_mobile/services/mastodon_service.dart';
import 'package:fedicaption_mobile/state/composer_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('ComposerController', () {
    test(
      'counts body and enabled CW toward character limit and toggles canSubmit',
      () {
        final app = buildTestAppController();
        addTearDown(app.dispose);
        final composer = ComposerController(app: app);
        addTearDown(composer.dispose);

        expect(composer.canSubmit, isFalse);
        composer.textController.text = 'Hello Mastodon';
        expect(composer.usedCharacters, 14);
        expect(composer.canSubmit, isTrue);

        // Disabled CW does not count toward characters.
        composer.spoilerController.text = 'Hidden';
        expect(composer.usedCharacters, 14);

        // Enabling CW includes spoiler length in remaining characters.
        composer.toggleContentWarning(true);
        composer.spoilerController.text = 'Warning';
        expect(composer.usedCharacters, 'Hello Mastodon'.length + 7);
        expect(composer.hasUnsavedChanges, isTrue);

        // Exceeding server maxCharacters disables submission.
        composer.textController.text = 'x' * 600;
        expect(composer.isOverCharacterLimit, isTrue);
        expect(composer.canSubmit, isFalse);
      },
    );

    test('tracks hasUnsavedChanges across new, reply, and edit flows including loadEditSourceIfNeeded', () async {
      final mockClient = MockClient((req) async {
        if (req.url.path == '/api/v1/accounts/verify_credentials') {
          return http.Response(
            jsonEncode({'id': '1', 'username': 'alice', 'acct': 'alice'}),
            200,
          );
        }
        if (req.url.path == '/api/v2/instance') {
          return http.Response(
            jsonEncode({'configuration': <String, dynamic>{}}),
            200,
          );
        }
        if (req.url.path == '/api/v1/statuses/42/source') {
          return http.Response(
            jsonEncode({
              'id': '42',
              'text': 'Raw source body @alice',
              'spoiler_text': 'Raw CW',
            }),
            200,
          );
        }
        return http.Response('{}', 404);
      });
      final app = buildTestAppController(
        mastodonService: MastodonService(client: mockClient),
      );
      addTearDown(app.dispose);
      await app.loginWithAccessToken(
        rawInstanceUrl: 'mastodon.social',
        accessToken: 'tok',
      );

      // 1. Reply starts with mention prefilled and no unsaved changes yet.
      final parent = sampleStatus('10');
      final replyComposer = ComposerController(app: app, replyToStatus: parent);
      addTearDown(replyComposer.dispose);
      expect(replyComposer.hasUnsavedChanges, isFalse);
      replyComposer.textController.text = '@alice@example.social My reply';
      expect(replyComposer.hasUnsavedChanges, isTrue);

      // 2. Edit loads raw /source cleanly without triggering dirty state.
      final existing = sampleStatus(
        '42',
        contentHtml: '<p>HTML body</p>',
        spoilerText: 'Raw CW',
      );
      final editComposer = ComposerController(
        app: app,
        editingStatus: existing,
      );
      addTearDown(editComposer.dispose);
      await editComposer.loadEditSourceIfNeeded();
      expect(editComposer.textController.text, 'Raw source body @alice');
      expect(editComposer.hasUnsavedChanges, isFalse);

      editComposer.setVisibility(PostVisibility.unlisted);
      expect(editComposer.hasUnsavedChanges, isTrue);
    });

    test('addLocalMedia surfaces EXIF warning when decode fails, enforces limit, and publish retry reuses uploaded media ID', () async {
      var mediaUploadCount = 0;
      var statusPublishAttempts = 0;
      final mockClient = MockClient((req) async {
        if (req.url.path == '/api/v1/accounts/verify_credentials') {
          return http.Response(
            jsonEncode({'id': '1', 'username': 'alice', 'acct': 'alice'}),
            200,
          );
        }
        if (req.url.path == '/api/v2/instance') {
          return http.Response(
            jsonEncode({
              'configuration': {
                'statuses': {'max_media_attachments': 1},
              },
            }),
            200,
          );
        }
        if (req.url.path == '/api/v2/media') {
          mediaUploadCount++;
          return http.Response(
            jsonEncode({
              'id': 'remote-media-$mediaUploadCount',
              'type': 'image',
              'url': 'https://cdn.example/m.jpg',
            }),
            200,
          );
        }
        if (req.url.path == '/api/v1/statuses' && req.method == 'POST') {
          statusPublishAttempts++;
          if (statusPublishAttempts == 1) {
            return http.Response('{"error": "temporary outage"}', 503);
          }
          final body = jsonDecode(req.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode({
              'id': '999',
              'created_at': '2026-11-27T12:00:00Z',
              'account': {'id': '1', 'username': 'alice', 'acct': 'alice'},
              'content': '<p>${body['status']}</p>',
            }),
            200,
          );
        }
        return http.Response('{}', 404);
      });

      final app = buildTestAppController(
        mastodonService: MastodonService(client: mockClient),
      );
      addTearDown(app.dispose);
      await app.loginWithAccessToken(
        rawInstanceUrl: 'mastodon.social',
        accessToken: 'tok',
      );
      // Disable auto AI scan so addLocalMedia tests local optimization cleanly.
      await app.updateSettings(
        app.settings.copyWith(autoGenerate: false),
        autoRefreshModels: false,
      );

      final dir = await Directory.systemTemp.createTemp('fedicaption_cc_');
      addTearDown(() async {
        if (await dir.exists()) await dir.delete(recursive: true);
      });
      final undecodable = File('${dir.path}/shot.heic')
        ..writeAsBytesSync([0, 1, 2, 3, 4]);

      final composer = ComposerController(app: app);
      addTearDown(composer.dispose);
      composer.textController.text = 'Photo post';

      await composer.addLocalMedia(filePath: undecodable.path, isVideo: false);
      expect(composer.attachments, hasLength(1));
      expect(composer.attachments.single.metadataNotStripped, isTrue);

      // Max 1 media attachment per mocked instance limits.
      await composer.addLocalMedia(filePath: undecodable.path, isVideo: false);
      expect(composer.attachments, hasLength(1));
      expect(composer.errorMessage, isNotNull);

      composer.updateAttachmentAltText(
        composer.attachments.single.localId,
        'Mountain view',
      );
      expect(composer.attachments.single.status, AttachmentStatus.ready);

      // First publish fails after media upload succeeds.
      final firstAttempt = await composer.publishNow();
      expect(firstAttempt, isNull);
      expect(mediaUploadCount, 1);

      // Second publish reuses the already-uploaded media ID (no duplicate upload).
      final secondAttempt = await composer.publishNow();
      expect(secondAttempt?.id, '999');
      expect(mediaUploadCount, 1);
    });
  });
}
