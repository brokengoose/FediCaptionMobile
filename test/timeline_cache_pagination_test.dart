// Copyright (c) 2026 brokengoose <brokengoose@users.noreply.github.com>
// SPDX-License-Identifier: MIT

import 'package:fedicaption_mobile/models/app_settings.dart';
import 'package:fedicaption_mobile/models/mastodon_models.dart';
import 'package:fedicaption_mobile/state/timeline_cache_controller.dart';
import 'package:flutter_test/flutter_test.dart';

const _author = MastodonAccount(
  id: 'a',
  username: 'alice',
  acct: 'alice',
  displayName: 'Alice',
  avatar: '',
);

/// Statuses with descending numeric IDs, newest first (like Mastodon pages).
List<MastodonStatus> _page(int fromId, int count) => [
  for (var i = 0; i < count; i++)
    MastodonStatus(
      id: '${fromId - i}',
      createdAt: DateTime.utc(2026, 11, 27),
      account: _author,
      contentHtml: '<p>post ${fromId - i}</p>',
    ),
];

List<MastodonNotification> _notifPage(int fromId, int count) => [
  for (var i = 0; i < count; i++)
    MastodonNotification(
      id: '${fromId - i}',
      type: 'mention',
      createdAt: DateTime.utc(2026, 11, 27),
      account: _author,
    ),
];

void main() {
  group('TimelineCacheController pagination', () {
    late TimelineCacheController cache;

    setUp(() {
      cache = TimelineCacheController(
        maxStatusesPerTimeline: 50,
        maxNotifications: 50,
        pageSize: 25,
      );
    });
    tearDown(() => cache.dispose());

    test('scrolling past the cap keeps the older page so max_id advances', () {
      cache.putTimeline(TimelineType.home, _page(1000, 50), hasMore: true);

      final combined = cache.appendOlderTimeline(
        TimelineType.home,
        _page(950, 25),
        hasMore: true,
      );

      expect(combined, hasLength(75));
      expect(combined.last.id, '926');
      expect(cache.timelineFor(TimelineType.home)!.statuses.last.id, '926');
    });

    test('updating a status does not shrink a scrolled-back timeline', () {
      cache.putTimeline(TimelineType.home, _page(1000, 50), hasMore: true);
      cache.appendOlderTimeline(
        TimelineType.home,
        _page(950, 25),
        hasMore: true,
      );

      final edited = _page(990, 1).single.copyWith(favourited: true);
      cache.updateStatusEverywhere(edited);

      final statuses = cache.timelineFor(TimelineType.home)!.statuses;
      expect(statuses, hasLength(75));
      expect(statuses.firstWhere((s) => s.id == '990').favourited, isTrue);
    });

    test(
      'refresh with a full page of new posts replaces the cache (no gap)',
      () {
        cache.putTimeline(TimelineType.home, _page(1000, 30), hasMore: true);

        // 25 (= page size) newer posts means more may exist between them and
        // the cached head; merging would silently hide that gap.
        final merged = cache.mergeNewerTimeline(
          TimelineType.home,
          _page(2000, 25),
        );

        expect(merged.map((s) => s.id), _page(2000, 25).map((s) => s.id));
        expect(cache.timelineFor(TimelineType.home)!.hasMore, isTrue);
      },
    );

    test('refresh with a partial page merges onto the cached head', () {
      cache.putTimeline(TimelineType.home, _page(1000, 30), hasMore: false);

      final merged = cache.mergeNewerTimeline(
        TimelineType.home,
        _page(1003, 3),
      );

      expect(merged, hasLength(33));
      expect(merged.first.id, '1003');
      expect(merged[3].id, '1000');
    });

    test('trimming the bottom on refresh re-enables pagination', () {
      cache.putTimeline(TimelineType.home, _page(1000, 50), hasMore: false);

      cache.mergeNewerTimeline(TimelineType.home, _page(1010, 10));

      final page = cache.timelineFor(TimelineType.home)!;
      expect(page.statuses, hasLength(50));
      expect(page.hasMore, isTrue);
    });

    test('notifications: scrolling past the cap keeps the older page', () {
      cache.putNotifications(_notifPage(1000, 50), hasMore: true);

      final combined = cache.appendOlderNotifications(
        _notifPage(950, 30),
        hasMore: true,
      );

      expect(combined, hasLength(80));
      expect(combined.last.id, '921');
    });

    test('notifications: full page of newer replaces the cache (no gap)', () {
      cache.putNotifications(_notifPage(1000, 30), hasMore: false);

      final merged = cache.mergeNewerNotifications(
        _notifPage(2000, 30),
        pageSize: 30,
      );

      expect(merged.first.id, '2000');
      expect(merged, hasLength(30));
      expect(cache.notifications!.hasMore, isTrue);
    });
  });
}
