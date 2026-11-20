// Copyright (c) 2026 brokengoose <brokengoose@users.noreply.github.com>
// SPDX-License-Identifier: MIT

import 'dart:convert';

import 'package:fedicaption_mobile/models/app_settings.dart';
import 'package:fedicaption_mobile/services/mastodon_service.dart';
import 'package:fedicaption_mobile/state/quote_cache_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  const session = MastodonSession(
    instanceUrl: 'https://example.social',
    accessToken: 'tok_123',
  );

  Map<String, dynamic> statusJson(String id, String text) => {
        'id': id,
        'created_at': '2026-11-20T12:00:00Z',
        'content': '<p>$text</p>',
        'account': {
          'id': '1',
          'username': 'alice',
          'acct': 'alice@example.social',
          'display_name': 'Alice',
          'avatar': '',
        },
      };

  group('QuoteCacheController', () {
    test('caches resolved statuses and supports retry after transient failure', () async {
      var requests = 0;
      var failNext = true;
      final client = MockClient((request) async {
        requests++;
        if (failNext) {
          return http.Response('Service unavailable', 503);
        }
        return http.Response(
          jsonEncode({
            'statuses': [statusJson('100', 'Recovered quoted post')],
          }),
          200,
        );
      });

      final cache = QuoteCacheController(
        mastodon: MastodonService(client: client),
      );
      addTearDown(cache.dispose);

      const url = 'https://example.social/@alice/100';

      // Initial attempt fails -> cached as null.
      final first = await cache.resolve(url, session: session);
      expect(first, isNull);
      expect(cache.hasResolved(url), isTrue);
      expect(requests, 1);

      // Normal resolve reuses cache without hitting network.
      final second = await cache.resolve(url, session: session);
      expect(second, isNull);
      expect(requests, 1);

      // Retry bypasses cached null and succeeds.
      failNext = false;
      final retried = await cache.resolve(
        url,
        session: session,
        forceRetry: true,
      );
      expect(retried, isNotNull);
      expect(retried!.plainText, 'Recovered quoted post');
      expect(requests, 2);
    });

    test('evicts oldest entries when cache exceeds maxEntries (LRU)', () async {
      final client = MockClient((request) async {
        final q = request.url.queryParameters['q'] ?? '';
        final id = q.split('/').last;
        return http.Response(
          jsonEncode({
            'statuses': [statusJson(id, 'Post $id')],
          }),
          200,
        );
      });

      final cache = QuoteCacheController(
        mastodon: MastodonService(client: client),
        maxEntries: 2,
      );
      addTearDown(cache.dispose);

      const url1 = 'https://example.social/@alice/1';
      const url2 = 'https://example.social/@alice/2';
      const url3 = 'https://example.social/@alice/3';

      await cache.resolve(url1, session: session);
      await cache.resolve(url2, session: session);
      // Touch url1 so url2 becomes the least recently used entry.
      expect(cache.cachedStatus(url1)?.id, '1');

      await cache.resolve(url3, session: session);
      expect(cache.hasResolved(url1), isTrue);
      expect(cache.hasResolved(url3), isTrue);
      expect(cache.hasResolved(url2), isFalse);
    });
  });
}
