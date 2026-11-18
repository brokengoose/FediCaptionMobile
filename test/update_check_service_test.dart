// Copyright (c) 2026 brokengoose <brokengoose@users.noreply.github.com>
// SPDX-License-Identifier: MIT

import 'dart:convert';

import 'package:fedicaption_mobile/services/update_check_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('UpdateCheckService', () {
    test('isNewerVersion compares semantic versions accurately', () {
      expect(UpdateCheckService.isNewerVersion('1.1.0', '1.0.0'), isTrue);
      expect(UpdateCheckService.isNewerVersion('v2.0.0', '1.9.9'), isTrue);
      expect(UpdateCheckService.isNewerVersion('1.0.1', '1.0.0'), isTrue);
      expect(UpdateCheckService.isNewerVersion('1.0.0', '1.0.0'), isFalse);
      expect(UpdateCheckService.isNewerVersion('0.9.5', '1.0.0'), isFalse);
    });

    test('detects newer GitHub release', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path.endsWith('/releases/latest')) {
          return http.Response(
            jsonEncode({
              'tag_name': 'v1.2.0',
              'html_url':
                  'https://github.com/brokengoose/FediCaptionMobile/releases/tag/v1.2.0',
            }),
            200,
          );
        }
        return http.Response('Not found', 404);
      });

      final service = UpdateCheckService(client: mockClient);
      final update = await service.checkForUpdate(currentVersion: '1.0.0');

      expect(update, isNotNull);
      expect(update!.latestVersion, '1.2.0');
      expect(update.releaseUrl, contains('releases/tag/v1.2.0'));
    });

    test('falls back to VERSION file on main branch when no GitHub release exists', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path.endsWith('/releases/latest')) {
          return http.Response('Not found', 404);
        }
        if (request.url.path.endsWith('/main/VERSION')) {
          return http.Response('1.3.0\n', 200);
        }
        return http.Response('Not found', 404);
      });

      final service = UpdateCheckService(client: mockClient);
      final update = await service.checkForUpdate(currentVersion: '1.0.0');

      expect(update, isNotNull);
      expect(update!.latestVersion, '1.3.0');
    });
  });
}
