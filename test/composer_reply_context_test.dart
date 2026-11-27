// Copyright (c) 2026 brokengoose <brokengoose@users.noreply.github.com>
// SPDX-License-Identifier: MIT

import 'package:fedicaption_mobile/models/mastodon_models.dart';
import 'package:fedicaption_mobile/state/app_controller.dart';
import 'package:fedicaption_mobile/ui/screens/composer_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'helpers/test_app.dart';

void main() {
  testWidgets(
    'ComposerScreen shows full post (CW, quote, untruncated text, media alt-text) above reply field',
    (tester) async {
      final app = AppController();
      addTearDown(app.dispose);

      final quoted = MastodonStatus(
        id: 'q1',
        createdAt: DateTime.utc(2026, 11, 26, 1, 0),
        account: const MastodonAccount(
          id: 'acc_bob',
          username: 'bob',
          acct: 'bob@example.social',
          displayName: 'Bob',
          avatar: '',
        ),
        contentHtml: '<p>Quoted original message</p>',
      );

      final parentStatus = MastodonStatus(
        id: 'p1',
        createdAt: DateTime.utc(2026, 11, 26, 2, 0),
        account: const MastodonAccount(
          id: 'acc_alice',
          username: 'alice',
          acct: 'alice@example.social',
          displayName: 'Alice Example',
          avatar: '',
        ),
        spoilerText: 'Detailed design notes',
        contentHtml:
            '<p>First paragraph of a long Mastodon post.</p>'
            '<p>Second paragraph continuing the thought.</p>'
            '<p>Third paragraph adding more context.</p>'
            '<p>Fourth paragraph ending marker.</p>',
        quotedStatus: quoted,
        mediaAttachments: const [
          MastodonMediaAttachment(
            id: 'm1',
            type: 'image',
            url: '',
            previewUrl: '',
            description: 'A detailed sunset over Lake Superior',
          ),
        ],
      );

      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(1000, 1200);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        localizedTestApp(
          home: ComposerScreen(app: app, replyToStatus: parentStatus),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('@alice@example.social'), findsWidgets);
      expect(find.text('Alice Example'), findsOneWidget);
      expect(find.text('CW: Detailed design notes'), findsOneWidget);
      expect(
        find.textContaining('Quoted original message', findRichText: true),
        findsOneWidget,
      );
      expect(
        find.textContaining(
          'First paragraph of a long Mastodon post.',
          findRichText: true,
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining(
          'Fourth paragraph ending marker.',
          findRichText: true,
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining('A detailed sunset over Lake Superior'),
        findsOneWidget,
      );

      final bodyBottom = tester
          .getBottomLeft(
            find.textContaining(
              'Fourth paragraph ending marker.',
              findRichText: true,
            ),
          )
          .dy;
      final altBottom = tester
          .getBottomLeft(
            find.textContaining('A detailed sunset over Lake Superior'),
          )
          .dy;
      final replyFieldTop = tester.getTopLeft(find.byType(TextField).last).dy;

      expect(bodyBottom, lessThan(replyFieldTop));
      expect(altBottom, lessThan(replyFieldTop));
    },
  );
}
