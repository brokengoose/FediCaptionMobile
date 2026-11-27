// Copyright (c) 2026 brokengoose <brokengoose@users.noreply.github.com>
// SPDX-License-Identifier: MIT

import 'package:fedicaption_mobile/models/mastodon_models.dart';
import 'package:fedicaption_mobile/state/app_controller.dart';
import 'package:fedicaption_mobile/state/quote_cache_controller.dart';
import 'package:fedicaption_mobile/state/timeline_cache_controller.dart';
import 'package:fedicaption_mobile/ui/screens/timeline_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'helpers/test_app.dart';

MastodonStatus _status({
  required String id,
  required String text,
  String? url,
  MastodonStatus? reblog,
  MastodonStatus? quotedStatus,
  DateTime? editedAt,
}) {
  return MastodonStatus(
    id: id,
    createdAt: DateTime.utc(2026, 11, 27, 8, 0),
    account: const MastodonAccount(
      id: 'acc_me',
      username: 'me',
      acct: 'me@example.social',
      displayName: 'Me',
      avatar: '',
    ),
    contentHtml: '<p>$text</p>',
    url: url ?? 'https://example.social/@me/$id',
    uri: url ?? 'https://example.social/users/me/statuses/$id',
    reblog: reblog,
    quotedStatus: quotedStatus,
    editedAt: editedAt,
  );
}

void main() {
  group('Edited status cache propagation', () {
    test(
        'TimelineCacheController.updateStatusEverywhere updates timelines, boosts, quoted posts, and notifications',
        () {
      final cache = TimelineCacheController();
      addTearDown(cache.dispose);

      final original = _status(id: '100', text: 'Original draft text');
      final boosted = _status(id: '200', text: 'Boost wrapper', reblog: original);
      final quoting = _status(
        id: '300',
        text: 'Quoting the post',
        quotedStatus: original,
      );

      cache.putTimeline(TimelineType.home, [boosted, quoting], hasMore: false);
      cache.putTimeline(TimelineType.myPosts, [original], hasMore: false);
      cache.putNotifications(
        [
          MastodonNotification(
            id: 'n1',
            type: 'mention',
            createdAt: DateTime.utc(2026, 11, 27, 8, 5),
            account: original.account,
            status: original,
          ),
        ],
        hasMore: false,
      );

      final edited = _status(
        id: '100',
        text: 'Updated edited text',
        editedAt: DateTime.utc(2026, 11, 27, 8, 10),
      );
      cache.updateStatusEverywhere(edited);

      final homeStatuses = cache.timelineFor(TimelineType.home)!.statuses;
      expect(homeStatuses[0].reblog!.plainText, 'Updated edited text');
      expect(homeStatuses[1].quotedStatus!.plainText, 'Updated edited text');

      final myStatuses = cache.timelineFor(TimelineType.myPosts)!.statuses;
      expect(myStatuses[0].plainText, 'Updated edited text');

      final notifStatus = cache.notifications!.notifications.first.status!;
      expect(notifStatus.plainText, 'Updated edited text');
      expect(cache.searchLocal('Updated edited'), hasLength(1));
      expect(cache.searchLocal('Original draft'), isEmpty);
    });

    test('QuoteCacheController.updateStatus overwrites previously cached quotes',
        () {
      final app = AppController();
      addTearDown(app.dispose);
      final QuoteCacheController quoteCache = app.quoteCache;

      const url = 'https://example.social/@me/100';
      final original = _status(id: '100', text: 'Original quoted text', url: url);
      quoteCache.seedStatuses([original]);
      expect(quoteCache.cachedStatus(url)?.plainText, 'Original quoted text');

      var notifyCount = 0;
      quoteCache.addListener(() => notifyCount++);

      final edited = _status(
        id: '100',
        text: 'Edited quoted text',
        url: url,
        editedAt: DateTime.utc(2026, 11, 27, 8, 15),
      );
      quoteCache.updateStatus(edited);

      expect(quoteCache.cachedStatus(url)?.plainText, 'Edited quoted text');
      expect(notifyCount, 1);
    });

    testWidgets(
        'TimelineScreen immediately displays edited post text when applyEditedStatus is called',
        (tester) async {
      final app = AppController();
      addTearDown(app.dispose);

      final original = _status(id: '501', text: 'Before editing text');
      app.timelineCache.putTimeline(
        TimelineType.home,
        [original],
        hasMore: false,
      );

      await tester.pumpWidget(
        localizedTestApp(
          home: Scaffold(
            body: TimelineScreen(
              app: app,
              timelineType: TimelineType.home,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Before editing text', findRichText: true),
        findsOneWidget,
      );

      final edited = _status(
        id: '501',
        text: 'After editing text',
        editedAt: DateTime.utc(2026, 11, 27, 8, 20),
      );
      app.applyEditedStatus(edited);
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Before editing text', findRichText: true),
        findsNothing,
      );
      expect(
        find.textContaining('After editing text', findRichText: true),
        findsOneWidget,
      );
    });
  });
}
