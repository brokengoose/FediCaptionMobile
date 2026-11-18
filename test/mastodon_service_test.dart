// Copyright (c) 2026 brokengoose <brokengoose@users.noreply.github.com>
// SPDX-License-Identifier: MIT

import 'dart:convert';

import 'package:fedicaption_mobile/core/constants.dart';
import 'package:fedicaption_mobile/services/mastodon_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('MastodonService', () {
    test('OAuth app registration sends GitHub repository URL as website', () async {
      late Map<String, dynamic> sentBody;
      final mockClient = MockClient((request) async {
        expect(request.url.toString(), 'https://mastodon.social/api/v1/apps');
        sentBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({
            'client_id': 'cid_123',
            'client_secret': 'csec_456',
          }),
          200,
        );
      });

      final service = MastodonService(client: mockClient);
      final creds = await service.registerOAuthApp('mastodon.social');

      expect(creds.clientId, 'cid_123');
      expect(sentBody['website'], AppConstants.repositoryUrl);
      expect(sentBody['website'], isNot(contains('joinmastodon.org')));
      expect(sentBody['redirect_uris'], AppConstants.oauthRedirectUri);
    });

    test('editStatus sends PUT with media_attributes containing updated alt-text', () async {
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
    });

    test('followAccount passes notify flag for notifications bell toggle', () async {
      late Map<String, dynamic> sentBody;
      final mockClient = MockClient((request) async {
        sentBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({
            'id': '42',
            'following': true,
            'notifying': true,
          }),
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
    });
  });
}
