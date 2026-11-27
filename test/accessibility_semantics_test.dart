// Copyright (c) 2026 brokengoose <brokengoose@users.noreply.github.com>
// SPDX-License-Identifier: MIT

import 'dart:ui' show PointerDeviceKind, Tristate;

import 'package:fedicaption_mobile/app.dart';
import 'package:fedicaption_mobile/models/mastodon_models.dart';
import 'package:fedicaption_mobile/models/update_info.dart';
import 'package:fedicaption_mobile/state/app_controller.dart';
import 'package:fedicaption_mobile/ui/screens/local_search_screen.dart';
import 'package:fedicaption_mobile/ui/widgets/accessible_button_semantics.dart';
import 'package:fedicaption_mobile/ui/widgets/media_attachment_card.dart';
import 'package:fedicaption_mobile/ui/widgets/status_card.dart';
import 'package:fedicaption_mobile/ui/widgets/update_banner.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/fakes.dart';
import 'helpers/test_app.dart';

const _alice = MastodonAccount(
  id: 'a',
  username: 'alice',
  acct: 'alice@example.social',
  displayName: 'Alice',
  avatar: '',
);

MastodonStatus _post({String spoilerText = '', bool withMedia = false}) {
  return MastodonStatus(
    id: '1',
    createdAt: DateTime.now().subtract(const Duration(hours: 2)),
    account: _alice,
    contentHtml: '<p>Hello world</p>',
    url: 'https://example.social/@alice/1',
    spoilerText: spoilerText,
    repliesCount: 3,
    mediaAttachments: withMedia
        ? const [
            MastodonMediaAttachment(
              id: 'm1',
              type: 'image',
              url: 'https://example.social/full.jpg',
              previewUrl: 'https://example.social/preview.jpg',
              description: 'A cat asleep on a keyboard',
            ),
          ]
        : const [],
  );
}

Widget _card(
  AppController app,
  MastodonStatus status, {
  bool selected = false,
}) {
  return localizedTestApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: StatusCard(
          status: status,
          app: app,
          isKeyboardSelected: selected,
          onOpenProfile: (_) {},
          onOpenThread: (_) {},
          onReply: (_) {},
          onToggleBoost: (_) async {},
          onToggleFavorite: (_) async {},
          onToggleBookmark: (_) async {},
        ),
      ),
    ),
  );
}

SemanticsOwner _semanticsOwner(WidgetTester tester) =>
    tester.binding.renderViews.first.owner!.semanticsOwner!;

/// Walks the live semantics tree and returns human-readable problems:
/// - a button node without a tap action that wraps an activatable descendant
///   (the "dead duplicate button" a screen reader lands on first);
/// - a button whose label merged in extra visible text (read twice).
List<String> _buttonProblems(WidgetTester tester) {
  final problems = <String>[];
  bool hasTappableDescendant(SemanticsNode node) {
    var found = false;
    node.visitChildren((child) {
      final d = child.getSemanticsData();
      if (d.hasAction(SemanticsAction.tap) || hasTappableDescendant(child)) {
        found = true;
        return false;
      }
      return true;
    });
    return found;
  }

  void visit(SemanticsNode node) {
    final d = node.getSemanticsData();
    if (d.flagsCollection.isButton) {
      if (!d.hasAction(SemanticsAction.tap) && hasTappableDescendant(node)) {
        problems.add('dead wrapper button: "${d.label}"');
      }
      if (d.label.contains('\n')) {
        problems.add(
          'merged/doubled label: "${d.label.replaceAll('\n', ' | ')}"',
        );
      }
    }
    node.visitChildren((c) {
      visit(c);
      return true;
    });
  }

  visit(_semanticsOwner(tester).rootSemanticsNode!);
  return problems;
}

void main() {
  group('Screen-reader semantics', () {
    testWidgets('StatusCard exposes one clean, activatable node per control', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final app = AppController();
      addTearDown(app.dispose);

      await tester.pumpWidget(_card(app, _post(spoilerText: 'Spoiler')));
      await tester.pump();

      expect(_buttonProblems(tester), isEmpty);
      expect(
        tester.getSemantics(
          find.bySemanticsLabel('Show content behind content warning'),
        ),
        isSemantics(isButton: true, hasTapAction: true),
      );
      expect(
        tester.getSemantics(
          find.bySemanticsLabel('Reply to Alice (3 replies)'),
        ),
        isSemantics(isButton: true, hasTapAction: true),
      );
      expect(
        tester.getSemantics(
          find.bySemanticsLabel(
            'Alice, @alice@example.social. Tap to view posts.',
          ),
        ),
        isSemantics(isButton: true, hasTapAction: true),
      );
      handle.dispose();
    });

    testWidgets('revealed post with media has no dead or doubled buttons', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final app = AppController();
      addTearDown(app.dispose);

      await tester.pumpWidget(_card(app, _post(withMedia: true)));
      await tester.pump();

      expect(_buttonProblems(tester), isEmpty);
      expect(
        tester.getSemantics(
          find.bySemanticsLabel(RegExp('^Image: A cat asleep')),
        ),
        isSemantics(isButton: true, isImage: true, hasTapAction: true),
      );
      handle.dispose();
    });

    testWidgets('keyboard-selected post is announced as selected', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final app = AppController();
      addTearDown(app.dispose);

      await tester.pumpWidget(_card(app, _post(), selected: true));
      await tester.pump();

      final selectedNodes = <SemanticsNode>[];
      void visit(SemanticsNode n) {
        if (n.getSemanticsData().flagsCollection.isSelected ==
            Tristate.isTrue) {
          selectedNodes.add(n);
        }
        n.visitChildren((c) {
          visit(c);
          return true;
        });
      }

      visit(_semanticsOwner(tester).rootSemanticsNode!);
      expect(selectedNodes, isNotEmpty);
      handle.dispose();
    });

    testWidgets('MediaAttachmentCard read-aloud button reports toggled state', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final app = AppController();
      addTearDown(app.dispose);

      await tester.pumpWidget(
        localizedTestApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: MediaAttachmentCard(
                attachment: _post(withMedia: true).mediaAttachments.single,
                app: app,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(_buttonProblems(tester), isEmpty);
      expect(
        tester.getSemantics(find.bySemanticsLabel('Read alt text aloud')),
        isSemantics(isButton: true, hasTapAction: true, hasToggledState: true),
      );
      handle.dispose();
    });

    testWidgets('UpdateBanner announces its text once', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        localizedTestApp(
          home: Scaffold(
            body: UpdateBanner(
              update: const UpdateInfo(
                latestVersion: '2.0.0',
                currentVersion: '1.0.0',
                releaseUrl: 'https://example.org/release',
              ),
              onDismiss: () {},
            ),
          ),
        ),
      );
      await tester.pump();

      final banner = tester.getSemantics(find.byType(UpdateBanner));
      expect(banner.getSemanticsData().label.contains('\n'), isFalse);
      handle.dispose();
    });

    testWidgets(
      'AccessibleButtonSemantics forwards taps and reports disabled',
      (tester) async {
        final handle = tester.ensureSemantics();
        var taps = 0;
        await tester.pumpWidget(
          localizedTestApp(
            home: Scaffold(
              body: Column(
                children: [
                  AccessibleButtonSemantics(
                    label: 'Do thing',
                    toggled: true,
                    onTap: () => taps++,
                    child: TextButton(
                      onPressed: () => taps++,
                      child: const Text('Thing'),
                    ),
                  ),
                  const AccessibleButtonSemantics(
                    label: 'Disabled thing',
                    onTap: null,
                    child: TextButton(onPressed: null, child: Text('Nope')),
                  ),
                ],
              ),
            ),
          ),
        );

        final node = tester.getSemantics(find.bySemanticsLabel('Do thing'));
        expect(
          node,
          matchesSemantics(
            label: 'Do thing',
            isButton: true,
            hasEnabledState: true,
            isEnabled: true,
            isFocusable: true,
            hasToggledState: true,
            isToggled: true,
            hasTapAction: true,
          ),
        );
        _semanticsOwner(tester).performAction(node.id, SemanticsAction.tap);
        expect(taps, 1);

        expect(
          tester.getSemantics(find.bySemanticsLabel('Disabled thing')),
          isSemantics(isButton: true, isEnabled: false, hasTapAction: false),
        );
        handle.dispose();
      },
    );

    testWidgets(
      'LocalSearchScreen debounces search, announces result count, and updates after edits',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final announcements = <String>[];
        tester.binding.defaultBinaryMessenger.setMockDecodedMessageHandler(
          SystemChannels.accessibility,
          (dynamic message) async {
            if (message is Map && message['type'] == 'announce') {
              final data = message['data'] as Map<dynamic, dynamic>?;
              final text = data?['message'] as String?;
              if (text != null) announcements.add(text);
            }
            return null;
          },
        );
        addTearDown(
          () => tester.binding.defaultBinaryMessenger
              .setMockDecodedMessageHandler(SystemChannels.accessibility, null),
        );

        final app = buildTestAppController();
        addTearDown(app.dispose);

        final post = sampleStatus(
          's1',
          contentHtml: '<p>Cascade mountains trail</p>',
        );
        app.timelineCache.putTimeline(TimelineType.home, [
          post,
        ], hasMore: false);

        // Verify cached haystack refreshes when a post is edited.
        expect(app.timelineCache.searchLocal('cascade'), hasLength(1));
        app.applyEditedStatus(
          post.copyWith(contentHtml: '<p>Olympic peninsula rain</p>'),
        );
        expect(app.timelineCache.searchLocal('cascade'), isEmpty);
        expect(app.timelineCache.searchLocal('olympic'), hasLength(1));

        await tester.pumpWidget(
          localizedTestApp(home: LocalSearchScreen(app: app)),
        );
        await tester.pumpAndSettle();

        await tester.enterText(find.byType(TextField), 'olympic');
        await tester.pump(const Duration(milliseconds: 50));
        // Still within 120ms debounce window: no results rendered yet.
        expect(find.byType(StatusCard), findsNothing);

        await tester.pump(const Duration(milliseconds: 100));
        expect(find.byType(StatusCard), findsOneWidget);

        await tester.pump(const Duration(milliseconds: 700));
        expect(announcements, contains('1 matching cached post'));
      },
    );

    testWidgets(
      'FediCaptionApp does not rebuild MaterialApp on unrelated AppController notifications',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final app = buildTestAppController();
        addTearDown(app.dispose);

        await tester.pumpWidget(FediCaptionApp(controller: app));
        await tester.pumpAndSettle();

        final before = tester.widget<MaterialApp>(find.byType(MaterialApp));
        final beforeNonce = app.timelineRefreshNonce;

        app.notifyTimelinesShouldRefresh();
        await tester.pump();

        expect(app.timelineRefreshNonce, beforeNonce + 1);
        final after = tester.widget<MaterialApp>(find.byType(MaterialApp));
        expect(identical(before, after), isTrue);
      },
    );

    testWidgets(
      'Hovering a tall post positions the Open post tooltip outside the post text',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        tester.view.devicePixelRatio = 1.0;
        tester.view.physicalSize = const Size(900, 900);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final app = buildTestAppController();
        addTearDown(app.dispose);

        final tallPost = MastodonStatus(
          id: 'tall1',
          createdAt: DateTime.utc(2026, 11, 27, 10),
          account: _alice,
          contentHtml:
              '<p>Paragraph one of a multi-line Mastodon post.</p>'
              '<p>Paragraph two continuing the discussion.</p>'
              '<p>Paragraph three with extra height.</p>'
              '<p>Paragraph four at the bottom.</p>',
          url: 'https://example.social/@alice/tall1',
        );

        await tester.pumpWidget(_card(app, tallPost));
        await tester.pumpAndSettle();

        final bodyFinder = find.ancestor(
          of: find.textContaining(
            'Paragraph one of a multi-line Mastodon post.',
            findRichText: true,
          ),
          matching: find.byType(InkWell),
        );
        expect(bodyFinder, findsOneWidget);
        final bodyRect = tester.getRect(bodyFinder);
        expect(bodyRect.height, greaterThan(100));

        final gesture = await tester.createGesture(
          kind: PointerDeviceKind.mouse,
        );
        addTearDown(gesture.removePointer);
        await gesture.addPointer(location: Offset.zero);
        await tester.pump();
        await gesture.moveTo(bodyRect.center);
        await tester.pump(const Duration(milliseconds: 500));

        final tipFinder = find.text(
          'Open post and conversation thread (Enter)',
        );
        expect(tipFinder, findsOneWidget);
        final tipRect = tester.getRect(tipFinder);
        expect(
          tipRect.top >= bodyRect.bottom || tipRect.bottom <= bodyRect.top,
          isTrue,
        );
      },
    );
  });
}
