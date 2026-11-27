// Copyright (c) 2026 brokengoose <brokengoose@users.noreply.github.com>
// SPDX-License-Identifier: MIT

import 'dart:convert';
import 'dart:io';

import 'package:fedicaption_mobile/core/constants.dart';
import 'package:fedicaption_mobile/models/mastodon_models.dart';
import 'package:fedicaption_mobile/services/mastodon_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('MastodonService', () {
    test(
      'OAuth app registration sends GitHub repository URL as website',
      () async {
        late Map<String, dynamic> sentBody;
        final mockClient = MockClient((request) async {
          expect(request.url.toString(), 'https://mastodon.social/api/v1/apps');
          sentBody = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode({'client_id': 'cid_123', 'client_secret': 'csec_456'}),
            200,
          );
        });

        final service = MastodonService(client: mockClient);
        final creds = await service.registerOAuthApp('mastodon.social');

        expect(creds.clientId, 'cid_123');
        expect(sentBody['website'], AppConstants.repositoryUrl);
        expect(sentBody['website'], isNot(contains('joinmastodon.org')));
        expect(sentBody['redirect_uris'], AppConstants.oauthRedirectUri);
      },
    );

    test(
      'editStatus sends PUT with media_attributes containing updated alt-text',
      () async {
        late Map<String, dynamic> sentBody;
        final mockClient = MockClient((request) async {
          expect(request.method, 'PUT');
          expect(
            request.url.toString(),
            'https://mastodon.social/api/v1/statuses/999',
          );
          sentBody = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode({
              'id': '999',
              'created_at': '2026-11-18T12:00:00.000Z',
              'content': '<p>Updated text</p>',
              'account': {
                'id': '1',
                'username': 'brokengoose',
                'acct': 'brokengoose',
                'display_name': 'brokengoose',
                'avatar': '',
              },
            }),
            200,
          );
        });

        final service = MastodonService(client: mockClient);
        await service.editStatus(
          instanceUrl: 'https://mastodon.social',
          accessToken: 'tok',
          statusId: '999',
          statusText: 'Updated text',
          mediaIds: const ['media_1'],
          mediaAttributes: const [
            {
              'id': 'media_1',
              'description': 'AI generated description: Updated alt text.',
            },
          ],
        );

        expect(sentBody['status'], 'Updated text');
        expect(sentBody['media_attributes'], [
          {
            'id': 'media_1',
            'description': 'AI generated description: Updated alt text.',
          },
        ]);
      },
    );

    test(
      'followAccount passes notify flag for notifications bell toggle',
      () async {
        late Map<String, dynamic> sentBody;
        final mockClient = MockClient((request) async {
          sentBody = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode({'id': '42', 'following': true, 'notifying': true}),
            200,
          );
        });

        final service = MastodonService(client: mockClient);
        final rel = await service.followAccount(
          instanceUrl: 'https://mastodon.social',
          accessToken: 'tok',
          accountId: '42',
          notify: true,
        );

        expect(sentBody['notify'], isTrue);
        expect(rel.following, isTrue);
        expect(rel.notifying, isTrue);
      },
    );

    test(
      'editStatus sends an empty media_ids list when all media were removed',
      () async {
        late Map<String, dynamic> sentBody;
        final mockClient = MockClient((request) async {
          sentBody = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode({
              'id': '9',
              'created_at': '2026-11-27T08:00:00.000Z',
              'content': '<p>No more media</p>',
              'account': {'id': '1', 'username': 'a', 'acct': 'a'},
            }),
            200,
          );
        });

        await MastodonService(client: mockClient).editStatus(
          instanceUrl: 'https://mastodon.social',
          accessToken: 'tok',
          statusId: '9',
          statusText: 'No more media',
        );

        // Mastodon only updates attachments when the key is present.
        expect(sentBody.containsKey('media_ids'), isTrue);
        expect(sentBody['media_ids'], isEmpty);
      },
    );

    group('uploadMedia async processing', () {
      late Directory tmp;
      late String filePath;

      setUp(() async {
        tmp = await Directory.systemTemp.createTemp('fcm_upload');
        filePath = '${tmp.path}/clip.mp4';
        await File(filePath).writeAsBytes(List<int>.filled(16, 1));
      });
      tearDown(() => tmp.delete(recursive: true));

      MastodonService serviceWith(List<int> pollStatuses) {
        var polls = 0;
        final client = MockClient((request) async {
          if (request.method == 'POST') {
            return http.Response(
              jsonEncode({'id': 'm1', 'type': 'video', 'url': null}),
              202,
            );
          }
          final code = pollStatuses[polls.clamp(0, pollStatuses.length - 1)];
          polls++;
          return http.Response(
            code == 200
                ? jsonEncode({
                    'id': 'm1',
                    'type': 'video',
                    'url': 'https://cdn.example/m1.mp4',
                  })
                : jsonEncode({'error': 'Processing failed'}),
            code,
          );
        });
        return MastodonService(
          client: client,
          mediaPollBackoff: const [Duration.zero],
          mediaPollAttempts: 3,
        );
      }

      Future<MastodonMediaAttachment> upload(MastodonService s) =>
          s.uploadMedia(
            instanceUrl: 'https://mastodon.social',
            accessToken: 'tok',
            filePath: filePath,
          );

      test('returns the processed attachment once polling sees 200', () async {
        final media = await upload(serviceWith([206, 200]));
        expect(media.url, 'https://cdn.example/m1.mp4');
      });

      test('throws MediaStillProcessingException (with id) when polling '
          'gives up, instead of returning an unprocessed attachment', () async {
        await expectLater(
          upload(serviceWith([206])),
          throwsA(
            isA<MediaStillProcessingException>().having(
              (e) => e.mediaId,
              'mediaId',
              'm1',
            ),
          ),
        );
      });

      test(
        'surfaces server processing errors instead of a pending attachment',
        () async {
          await expectLater(
            upload(serviceWith([422])),
            throwsA(
              isA<MastodonApiException>().having(
                (e) => e.message,
                'message',
                contains('Processing failed'),
              ),
            ),
          );
        },
      );
    });
  });
}
