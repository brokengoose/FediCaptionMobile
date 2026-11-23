// Copyright (c) 2026 brokengoose <brokengoose@users.noreply.github.com>
// SPDX-License-Identifier: MIT

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fedicaption_mobile/models/app_settings.dart';
import 'package:fedicaption_mobile/models/mastodon_models.dart';
import 'package:fedicaption_mobile/services/image_upload_optimizer.dart';
import 'package:fedicaption_mobile/services/link_preview_fetcher.dart';
import 'package:fedicaption_mobile/services/mastodon_service.dart';
import 'package:fedicaption_mobile/services/media_cache_service.dart';
import 'package:fedicaption_mobile/state/quote_cache_controller.dart';
import 'package:fedicaption_mobile/state/timeline_cache_controller.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image/image.dart' as img;

MastodonStatus _status(
  String id, {
  String contentHtml = '<p>Hello world</p>',
  String spoilerText = '',
  String? url,
  String authorName = 'Alice',
  String acct = 'alice@example.social',
  List<MastodonMediaAttachment> media = const [],
  DateTime? createdAt,
}) {
  return MastodonStatus(
    id: id,
    createdAt: createdAt ?? DateTime.utc(2026, 11, 23, 12, 0, int.tryParse(id) ?? 0),
    account: MastodonAccount(
      id: 'acc_$id',
      username: authorName.toLowerCase(),
      acct: acct,
      displayName: authorName,
      avatar: '',
    ),
    contentHtml: contentHtml,
    spoilerText: spoilerText,
    url: url ?? 'https://example.social/@${authorName.toLowerCase()}/$id',
    uri: url ?? 'https://example.social/users/${authorName.toLowerCase()}/statuses/$id',
    mediaAttachments: media,
  );
}

void main() {
  group('ImageUploadOptimizer', () {
    test('resizes oversized opaque images to maxDimension and strips EXIF metadata', () {
      final src = img.Image(width: 2600, height: 1300);
      img.fill(src, color: img.ColorRgb8(40, 120, 200));
      src.exif.imageIfd['Make'] = 'TestCameraCorp';
      src.exif.imageIfd['Software'] = 'SecretGPSPhone';
      final rawJpg = Uint8List.fromList(img.encodeJpg(src, quality: 95));

      // Verify EXIF was present before optimization.
      final before = img.decodeJpg(rawJpg);
      expect(before?.exif.imageIfd.hasMake, isTrue);

      final result = ImageUploadOptimizer.optimizeBytes(
        rawJpg,
        maxDimension: 2048,
        jpegQuality: 85,
      );

      expect(result, isNotNull);
      expect(result!.mimeType, 'image/jpeg');
      expect(result.width, 2048);
      expect(result.height, 1024);

      // Verify EXIF tags are completely stripped after optimization.
      final after = img.decodeJpg(result.bytes);
      expect(after, isNotNull);
      expect(after!.exif.imageIfd.hasMake, isFalse);
      expect(after.exif.imageIfd.hasSoftware, isFalse);
      expect(after.exif.gpsIfd.isEmpty, isTrue);
    });

    test('preserves PNG format when image contains transparent pixels', () {
      final transparent = img.Image(width: 100, height: 100, numChannels: 4);
      img.fill(transparent, color: img.ColorRgba8(0, 0, 0, 0));
      transparent.setPixelRgba(10, 10, 255, 0, 0, 255);
      final rawPng = Uint8List.fromList(img.encodePng(transparent));

      final result = ImageUploadOptimizer.optimizeBytes(rawPng);
      expect(result, isNotNull);
      expect(result!.mimeType, 'image/png');
      expect(result.extension, 'png');
    });

    test('returns null for animated multi-frame GIFs to preserve animation', () {
      final anim = img.Image(width: 16, height: 16);
      img.fill(anim, color: img.ColorRgb8(255, 0, 0));
      final frame2 = img.Image(width: 16, height: 16);
      img.fill(frame2, color: img.ColorRgb8(0, 255, 0));
      anim.addFrame(frame2);
      final gifBytes = Uint8List.fromList(img.encodeGif(anim));

      final result = ImageUploadOptimizer.optimizeBytes(gifBytes);
      expect(result, isNull);
    });
  });

  group('MediaCacheService', () {
    test('persists to disk across RAM clears and deduplicates concurrent requests', () async {
      final tempDir = await Directory.systemTemp.createTemp('fedicaption_cache_test_');
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });

      var networkCalls = 0;
      final mockClient = MockClient((request) async {
        networkCalls++;
        await Future<void>.delayed(const Duration(milliseconds: 20));
        return http.Response.bytes(
          [1, 2, 3, 4, 5],
          200,
          headers: {'content-type': 'image/png'},
        );
      });

      final cache = MediaCacheService(
        client: mockClient,
        cacheDirectory: tempDir,
      );

      // Fire 4 concurrent requests for the exact same avatar URL -> 1 HTTP GET.
      final results = await Future.wait([
        cache.getOrFetch('https://cdn.example.social/avatar1.png'),
        cache.getOrFetch('https://cdn.example.social/avatar1.png'),
        cache.getOrFetch('https://cdn.example.social/avatar1.png'),
        cache.getOrFetch('https://cdn.example.social/avatar1.png'),
      ]);
      expect(networkCalls, 1);
      expect(results.first.bytes, [1, 2, 3, 4, 5]);
      expect(results.first.mimeType, 'image/png');

      // Clear RAM cache and fetch again -> served from persistent disk cache!
      cache.clearMemory();
      final diskHit = await cache.getOrFetch('https://cdn.example.social/avatar1.png');
      expect(networkCalls, 1);
      expect(diskHit.bytes, [1, 2, 3, 4, 5]);
      expect(diskHit.mimeType, 'image/png');
    });
  });

  group('TimelineCacheController', () {
    test('merges since_id updates, propagates mutations, and searches posts + alt-text offline', () {
      final cache = TimelineCacheController();
      addTearDown(cache.dispose);

      final s1 = _status(
        '10',
        contentHtml: '<p>Exploring the Cascade mountains</p>',
        media: const [
          MastodonMediaAttachment(
            id: 'm1',
            type: 'image',
            url: 'https://cdn.example/img.jpg',
            description: 'Snowy volcanic peak under clear blue sky',
          ),
        ],
      );
      final s2 = _status(
        '20',
        contentHtml: '<p>Coffee time in Seattle</p>',
        spoilerText: 'Caffeine warning',
      );

      cache.putTimeline(TimelineType.home, [s2, s1], hasMore: true);
      expect(cache.isTimelineFresh(TimelineType.home), isTrue);

      // Merge incremental since_id response containing one new post and one duplicate.
      final s3 = _status('30', contentHtml: '<p>Fresh toot</p>');
      final merged = cache.mergeNewerTimeline(TimelineType.home, [s3, s2]);
      expect(merged.map((s) => s.id).toList(), ['30', '20', '10']);

      // Search matches post body, CW, and media alt-text with 0 server requests.
      expect(cache.searchLocal('volcanic sky').map((s) => s.id), ['10']);
      expect(cache.searchLocal('caffeine seattle').map((s) => s.id), ['20']);
      expect(cache.searchLocal('nonexistent'), isEmpty);

      // Deletion propagates across cached timelines.
      cache.removeStatusEverywhere('20');
      expect(
        cache.timelineFor(TimelineType.home)!.statuses.map((s) => s.id),
        ['30', '10'],
      );
    });
  });

  group('QuoteCacheController & MastodonService optimizations', () {
    test('seedStatuses resolves quoted URLs locally with 0 server requests', () async {
      var serverHits = 0;
      final mockClient = MockClient((req) async {
        serverHits++;
        return http.Response('{"statuses": []}', 200);
      });
      final mastodon = MastodonService(client: mockClient);
      final quotes = QuoteCacheController(mastodon: mastodon);
      addTearDown(quotes.dispose);

      final seeded = _status(
        '123456789',
        url: 'https://remote.example/@bob/123456789',
        contentHtml: '<p>Already in timeline!</p>',
      );
      quotes.seedStatuses([seeded]);

      final resolved = await quotes.resolve(
        'https://remote.example/@bob/123456789/',
        session: const MastodonSession(
          instanceUrl: 'https://mastodon.social',
          accessToken: 'tok',
        ),
      );
      expect(resolved?.id, '123456789');
      expect(serverHits, 0);
    });

    test('same-instance status URLs use cheap /api/v1/statuses/{id} instead of search', () async {
      final requestedPaths = <String>[];
      final mockClient = MockClient((req) async {
        requestedPaths.add(req.url.path);
        return http.Response(
          jsonEncode({
            'id': '1122334455',
            'created_at': '2026-11-23T10:00:00Z',
            'content': '<p>Local post</p>',
            'account': {
              'id': '1',
              'username': 'alice',
              'acct': 'alice',
              'display_name': 'Alice',
            },
          }),
          200,
        );
      });

      final mastodon = MastodonService(client: mockClient);
      final status = await mastodon.resolveStatusByUrl(
        instanceUrl: 'https://mastodon.social',
        accessToken: 'tok',
        statusUrl: 'https://mastodon.social/@alice/1122334455',
      );

      expect(status?.id, '1122334455');
      expect(requestedPaths, ['/api/v1/statuses/1122334455']);
    });

    test('fetchTimeline sends since_id, fetchAccount caches within TTL, and 429 reports Retry-After', () async {
      final requests = <Uri>[];
      var accountCalls = 0;
      final mockClient = MockClient((req) async {
        requests.add(req.url);
        if (req.url.path == '/api/v1/timelines/home') {
          return http.Response('[]', 200);
        }
        if (req.url.path == '/api/v1/accounts/42') {
          accountCalls++;
          return http.Response(
            jsonEncode({
              'id': '42',
              'username': 'sam',
              'acct': 'sam',
              'display_name': 'Sam',
            }),
            200,
          );
        }
        return http.Response(
          '{"error":"Too many requests"}',
          429,
          headers: {'retry-after': '30'},
        );
      });

      final mastodon = MastodonService(client: mockClient);
      await mastodon.fetchTimeline(
        instanceUrl: 'https://mastodon.social',
        accessToken: 'tok',
        type: TimelineType.home,
        currentUserId: '1',
        sinceId: '99999',
      );
      expect(requests.first.queryParameters['since_id'], '99999');

      // Second fetchAccount within TTL hits cache -> only 1 HTTP call.
      await mastodon.fetchAccount(
        instanceUrl: 'https://mastodon.social',
        accessToken: 'tok',
        accountId: '42',
      );
      await mastodon.fetchAccount(
        instanceUrl: 'https://mastodon.social',
        accessToken: 'tok',
        accountId: '42',
      );
      expect(accountCalls, 1);

      // 429 surfaces Retry-After nicely.
      expect(
        () => mastodon.fetchStatusContext(
          instanceUrl: 'https://mastodon.social',
          accessToken: 'tok',
          statusId: '777',
        ),
        throwsA(
          isA<MastodonApiException>()
              .having((e) => e.statusCode, 'statusCode', 429)
              .having((e) => e.message, 'message', contains('30s')),
        ),
      );
    });
  });

  group('LinkPreviewFetcher streaming & caching', () {
    test('rejects binary content-type from headers, caps bytes, and caches excerpts', () async {
      var htmlCalls = 0;
      var pdfBodyEmitted = false;
      final mockClient = MockClient.streaming((request, bodyStream) async {
        if (request.url.path.endsWith('.pdf')) {
          final stream = Stream<List<int>>.fromIterable([
            List<int>.filled(1024, 65),
          ]).map((chunk) {
            pdfBodyEmitted = true;
            return chunk;
          });
          return http.StreamedResponse(
            stream,
            200,
            headers: {'content-type': 'application/pdf'},
          );
        }
        htmlCalls++;
        final bigHtml =
            '<html><head><title>Article Title</title></head><body>${'hello ' * 50000}</body></html>';
        return http.StreamedResponse(
          Stream<List<int>>.fromIterable([utf8.encode(bigHtml)]),
          200,
          headers: {'content-type': 'text/html; charset=utf-8'},
        );
      });

      final fetcher = LinkPreviewFetcher(
        client: mockClient,
        maxDownloadBytes: 4096,
      );

      final pdf = await fetcher.fetch('https://example.org/huge.pdf');
      expect(pdf, isNull);
      expect(pdfBodyEmitted, isFalse);

      final first = await fetcher.fetch('https://example.org/article');
      final second = await fetcher.fetch('https://example.org/article');
      expect(first?.title, 'Article Title');
      expect(second?.title, 'Article Title');
      expect(htmlCalls, 1);
    });
  });
}
