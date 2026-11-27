// Copyright (c) 2026 brokengoose <brokengoose@users.noreply.github.com>
// SPDX-License-Identifier: MIT

import 'package:fedicaption_mobile/core/theme/app_theme.dart';
import 'package:fedicaption_mobile/models/mastodon_models.dart';
import 'package:fedicaption_mobile/state/app_controller.dart';
import 'package:fedicaption_mobile/ui/helpers/keyboard_shortcuts.dart';
import 'package:fedicaption_mobile/ui/screens/home_shell.dart';
import 'package:fedicaption_mobile/ui/screens/timeline_screen.dart';
import 'package:fedicaption_mobile/ui/widgets/accessible_tip.dart';
import 'package:fedicaption_mobile/ui/widgets/status_card.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

MastodonStatus _sampleStatus(
  String id, {
  required String text,
  String spoiler = '',
}) {
  return MastodonStatus(
    id: id,
    createdAt: DateTime.utc(2026, 11, 23, 12, 0),
    account: MastodonAccount(
      id: 'acc_$id',
      username: 'user$id',
      acct: 'user$id@example.social',
      displayName: 'User $id',
      avatar: '',
    ),
    contentHtml: '<p>$text</p>',
    spoilerText: spoiler,
  );
}

void main() {
  group('Keyboard navigation shortcuts', () {
    testWidgets('j/k moves post selection and x toggles Content Warning', (
      tester,
    ) async {
      final app = AppController();
      addTearDown(app.dispose);

      app.timelineCache.putTimeline(TimelineType.home, [
        _sampleStatus(
          '1',
          text: 'First post secret body',
          spoiler: 'Spoiler 1',
        ),
        _sampleStatus('2', text: 'Second post body'),
      ], hasMore: false);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: TimelineScreen(app: app, timelineType: TimelineType.home),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Initially no card selected and CW body hidden.
      expect(find.textContaining('First post secret body'), findsNothing);

      // Press 'j' -> selects post 1.
      await tester.sendKeyEvent(LogicalKeyboardKey.keyJ);
      await tester.pumpAndSettle();

      var cards = tester
          .widgetList<StatusCard>(find.byType(StatusCard))
          .toList();
      expect(cards[0].isKeyboardSelected, isTrue);
      expect(cards[1].isKeyboardSelected, isFalse);

      // Press 'x' -> expands Content Warning on selected post 1.
      await tester.sendKeyEvent(LogicalKeyboardKey.keyX);
      await tester.pumpAndSettle();
      expect(find.textContaining('First post secret body'), findsOneWidget);

      // Press 'j' again -> moves selection to post 2.
      await tester.sendKeyEvent(LogicalKeyboardKey.keyJ);
      await tester.pumpAndSettle();

      cards = tester.widgetList<StatusCard>(find.byType(StatusCard)).toList();
      expect(cards[0].isKeyboardSelected, isFalse);
      expect(cards[1].isKeyboardSelected, isTrue);

      // Press 'k' -> moves selection back to post 1.
      await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
      await tester.pumpAndSettle();

      cards = tester.widgetList<StatusCard>(find.byType(StatusCard)).toList();
      expect(cards[0].isKeyboardSelected, isTrue);
      expect(cards[1].isKeyboardSelected, isFalse);
    });

    testWidgets(
      'g chords switch timelines and ? opens shortcuts dialog in HomeShell',
      (tester) async {
        final app = AppController();
        addTearDown(app.dispose);

        // Seed cached timelines so tab switching makes zero network calls.
        for (final type in [
          TimelineType.home,
          TimelineType.local,
          TimelineType.bookmarks,
        ]) {
          app.timelineCache.putTimeline(type, [
            _sampleStatus('1', text: 'Cached ${type.shortLabel} post'),
          ], hasMore: false);
        }

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light(),
            home: HomeShell(app: app),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Home Timeline'), findsOneWidget);

        // Press 'g' then 'l' -> Local Timeline.
        await tester.sendKeyEvent(LogicalKeyboardKey.keyG);
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.keyL);
        await tester.pumpAndSettle();
        expect(find.text('Local Timeline'), findsOneWidget);

        // Press 'g' then 'b' -> Bookmarks.
        await tester.sendKeyEvent(LogicalKeyboardKey.keyG);
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.keyB);
        await tester.pumpAndSettle();
        expect(find.text('Bookmarks'), findsOneWidget);

        // Press '?' (Shift + /) -> Keyboard Shortcuts dialog.
        await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.slash);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
        await tester.pumpAndSettle();
        expect(find.byType(KeyboardShortcutsDialog), findsOneWidget);
        expect(find.text('Keyboard Shortcuts'), findsOneWidget);
        expect(find.text('Next post'), findsOneWidget);
      },
    );

    testWidgets(
      'single-letter shortcuts are ignored while typing in a TextField',
      (tester) async {
        final controller = TextEditingController();
        addTearDown(controller.dispose);
        var shortcutFired = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: TextField(controller: controller, autofocus: true),
            ),
          ),
        );
        await tester.pumpAndSettle();

        bool handler(KeyEvent event) {
          return KeyboardNavHelper.handleStatusFeedKeyEvent(
            event,
            isActive: () => true,
            onNext: () => shortcutFired = true,
          );
        }

        HardwareKeyboard.instance.addHandler(handler);
        addTearDown(() => HardwareKeyboard.instance.removeHandler(handler));

        await tester.sendKeyEvent(LogicalKeyboardKey.keyJ);
        await tester.pump();

        expect(shortcutFired, isFalse);
      },
    );

    testWidgets(
      'AccessibleTip shows explanatory tip on Tab focus and mouse hover',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light(),
            home: Scaffold(
              body: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AccessibleTip(
                      message: 'Compose a new Mastodon post',
                      child: FilledButton(
                        onPressed: () {},
                        child: const Text('Compose'),
                      ),
                    ),
                    const SizedBox(height: 16),
                    AccessibleTip(
                      message: 'Open Settings & AI Configuration',
                      child: OutlinedButton(
                        onPressed: () {},
                        child: const Text('Settings'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Tab focuses the first button -> shows its tip immediately.
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pumpAndSettle();
        expect(find.text('Compose a new Mastodon post'), findsOneWidget);

        // Mouse hover over the second button -> shows its tip after waitDuration.
        final gesture = await tester.createGesture(
          kind: PointerDeviceKind.mouse,
        );
        addTearDown(gesture.removePointer);
        await gesture.addPointer(location: Offset.zero);
        await gesture.moveTo(tester.getCenter(find.text('Settings')));
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pumpAndSettle();
        expect(find.text('Open Settings & AI Configuration'), findsOneWidget);
      },
    );

    testWidgets('wide window expands post cards without wide margins', (
      tester,
    ) async {
      final app = AppController();
      addTearDown(app.dispose);

      app.timelineCache.putTimeline(TimelineType.home, [
        _sampleStatus('1', text: 'Wide layout post'),
      ], hasMore: false);

      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(1200, 900);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: HomeShell(app: app),
        ),
      );
      await tester.pumpAndSettle();

      final widthAt1200 = tester.getSize(find.byType(StatusCard)).width;
      expect(widthAt1200, greaterThan(850));

      tester.view.physicalSize = const Size(1600, 900);
      await tester.pumpAndSettle();

      final widthAt1600 = tester.getSize(find.byType(StatusCard)).width;
      expect(widthAt1600, closeTo(widthAt1200 + 400, 4.0));
    });

    testWidgets('Page Down and Page Up scroll TimelineScreen by one page', (
      tester,
    ) async {
      final app = AppController();
      addTearDown(app.dispose);

      app.timelineCache.putTimeline(TimelineType.home, [
        for (var i = 1; i <= 20; i++)
          _sampleStatus('$i', text: 'Timeline post number $i'),
      ], hasMore: false);

      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(800, 600);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: TimelineScreen(app: app, timelineType: TimelineType.home),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final scrollable = tester.state<ScrollableState>(
        find.byType(Scrollable).first,
      );
      final viewportHeight = scrollable.position.viewportDimension;
      expect(scrollable.position.pixels, 0.0);

      await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
      await tester.pumpAndSettle();
      expect(scrollable.position.pixels, closeTo(viewportHeight * 0.9, 2.0));

      await tester.sendKeyEvent(LogicalKeyboardKey.pageUp);
      await tester.pumpAndSettle();
      expect(scrollable.position.pixels, closeTo(0.0, 0.5));
    });

    testWidgets(
      'Home key scrolls TimelineScreen back to the newest post at top',
      (tester) async {
        final app = AppController();
        addTearDown(app.dispose);

        app.timelineCache.putTimeline(TimelineType.home, [
          for (var i = 1; i <= 20; i++)
            _sampleStatus('$i', text: 'Timeline post number $i'),
        ], hasMore: false);

        tester.view.devicePixelRatio = 1.0;
        tester.view.physicalSize = const Size(800, 600);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light(),
            home: Scaffold(
              body: TimelineScreen(app: app, timelineType: TimelineType.home),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final scrollable = tester.state<ScrollableState>(
          find.byType(Scrollable).first,
        );

        await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
        await tester.pumpAndSettle();
        await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
        await tester.pumpAndSettle();
        expect(scrollable.position.pixels, greaterThan(500));

        await tester.sendKeyEvent(LogicalKeyboardKey.home);
        await tester.pumpAndSettle();
        expect(scrollable.position.pixels, closeTo(0.0, 0.5));
        expect(find.text('Timeline post number 1'), findsOneWidget);
      },
    );
  });
}
