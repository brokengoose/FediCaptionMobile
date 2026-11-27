// Copyright (c) 2026 brokengoose <brokengoose@users.noreply.github.com>
// SPDX-License-Identifier: MIT

import 'dart:async';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../l10n/l10n.dart';

/// Shared helpers for standard Mastodon keyboard navigation across macOS,
/// iPadOS (hardware keyboard), Android (hardware keyboard), and desktop.
class KeyboardNavHelper {
  KeyboardNavHelper._();

  static bool _goChordPending = false;
  static Timer? _goChordTimer;

  /// True while awaiting the second key of a Mastodon `g <key>` timeline chord
  /// (`g h`, `g l`, `g p`, `g n`, `g b`, `g f`, `g u`).
  static bool get isGoChordActive => _goChordPending;

  /// Starts a 1-second window for a `g <key>` navigation chord.
  static void beginGoChord() {
    _goChordTimer?.cancel();
    _goChordPending = true;
    _goChordTimer = Timer(const Duration(seconds: 1), cancelGoChord);
  }

  /// Clears any pending `g <key>` chord.
  static void cancelGoChord() {
    _goChordTimer?.cancel();
    _goChordTimer = null;
    _goChordPending = false;
  }

  /// Returns `true` if a text input (`EditableText` / `TextField`) currently
  /// holds keyboard focus so single-letter shortcuts never hijack typing.
  static bool isTextInputFocused() {
    final primary = FocusManager.instance.primaryFocus;
    final ctx = primary?.context;
    if (ctx == null) return false;
    if (ctx.widget is EditableText) return true;
    return ctx.findAncestorWidgetOfExactType<EditableText>() != null;
  }

  /// Returns `true` when the primary platform modifier (Cmd on macOS/iOS,
  /// Ctrl on Android/Linux/Windows) is held without Alt.
  static bool isPrimaryModifierPressed() {
    final hw = HardwareKeyboard.instance;
    return (hw.isMetaPressed || hw.isControlPressed) && !hw.isAltPressed;
  }

  /// Display form of a primary-modifier shortcut for help text and tooltips:
  /// `⌘N` on Apple platforms, `Ctrl+N` elsewhere.
  static String primaryShortcutLabel(BuildContext context, String key) {
    final platform = Theme.of(context).platform;
    final isApple =
        platform == TargetPlatform.macOS || platform == TargetPlatform.iOS;
    return isApple ? '⌘$key' : 'Ctrl+$key';
  }

  /// Returns `true` when no modifier keys (Cmd, Ctrl, Alt) are held.
  static bool hasNoCommandModifiers() {
    final hw = HardwareKeyboard.instance;
    return !hw.isMetaPressed && !hw.isControlPressed && !hw.isAltPressed;
  }

  /// Smoothly scrolls the widget attached to [key] into view when mounted.
  static void ensureKeyVisible(GlobalKey? key) {
    final ctx = key?.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      alignment: 0.15,
    );
  }

  /// Scrolls [controller] by approximately one viewport page (90% of viewport
  /// height for reading continuity). Pass `direction: 1` for Page Down or `-1`
  /// for Page Up.
  static void scrollByPage(
    ScrollController controller, {
    required int direction,
  }) {
    if (!controller.hasClients) return;
    final pos = controller.position;
    if (!pos.hasViewportDimension || pos.viewportDimension <= 0) return;
    final pageStep = (pos.viewportDimension * 0.9).clamp(
      120.0,
      pos.viewportDimension,
    );
    final target = (pos.pixels + direction * pageStep).clamp(
      pos.minScrollExtent,
      pos.maxScrollExtent,
    );
    if ((target - pos.pixels).abs() < 0.5) return;
    controller.animateTo(
      target,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  /// Smoothly scrolls [controller] to the top of the list (`minScrollExtent`).
  static void scrollToTop(ScrollController controller) {
    if (!controller.hasClients) return;
    final pos = controller.position;
    if ((pos.pixels - pos.minScrollExtent).abs() < 0.5) return;
    controller.animateTo(
      pos.minScrollExtent,
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
    );
  }

  /// Shared dispatcher for standard Mastodon post-list keyboard shortcuts.
  /// Returns `true` if [event] was handled.
  static bool handleStatusFeedKeyEvent(
    KeyEvent event, {
    required bool Function() isActive,
    VoidCallback? onNext,
    VoidCallback? onPrevious,
    VoidCallback? onPageDown,
    VoidCallback? onPageUp,
    VoidCallback? onScrollToTop,
    VoidCallback? onOpen,
    VoidCallback? onReply,
    VoidCallback? onFavorite,
    VoidCallback? onBoost,
    VoidCallback? onBookmark,
    VoidCallback? onToggleCw,
    VoidCallback? onOpenProfile,
    VoidCallback? onRefresh,
    VoidCallback? onShowHelp,
    VoidCallback? onEscape,
  }) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return false;
    if (!isActive() || isTextInputFocused()) return false;

    final key = event.logicalKey;

    if (key == LogicalKeyboardKey.escape && onEscape != null) {
      if (event is KeyRepeatEvent) return true;
      onEscape();
      return true;
    }

    // Cmd+R / Ctrl+R refreshes current list.
    if (isPrimaryModifierPressed() &&
        key == LogicalKeyboardKey.keyR &&
        onRefresh != null) {
      if (event is KeyRepeatEvent) return true;
      onRefresh();
      return true;
    }

    // Do not hijack keys while a `g <key>` chord is active or Cmd/Ctrl/Alt held.
    if (isGoChordActive || !hasNoCommandModifiers()) return false;

    final shiftPressed = HardwareKeyboard.instance.isShiftPressed;

    // `?` (Shift+/ or LogicalKeyboardKey.question) -> Keyboard shortcuts help.
    if ((key == LogicalKeyboardKey.question ||
            (key == LogicalKeyboardKey.slash && shiftPressed)) &&
        onShowHelp != null) {
      if (event is KeyRepeatEvent) return true;
      onShowHelp();
      return true;
    }

    if (shiftPressed) return false;

    // Repeat-friendly navigation keys (`j`/`↓`, `k`/`↑`).
    if ((key == LogicalKeyboardKey.keyJ ||
            key == LogicalKeyboardKey.arrowDown) &&
        onNext != null) {
      onNext();
      return true;
    }
    if ((key == LogicalKeyboardKey.keyK || key == LogicalKeyboardKey.arrowUp) &&
        onPrevious != null) {
      onPrevious();
      return true;
    }
    if (key == LogicalKeyboardKey.pageDown && onPageDown != null) {
      onPageDown();
      return true;
    }
    if (key == LogicalKeyboardKey.pageUp && onPageUp != null) {
      onPageUp();
      return true;
    }

    // Single-fire action keys (ignore key-repeat).
    if (event is KeyRepeatEvent) return false;

    if (key == LogicalKeyboardKey.home && onScrollToTop != null) {
      onScrollToTop();
      return true;
    }

    if ((key == LogicalKeyboardKey.enter ||
            key == LogicalKeyboardKey.numpadEnter ||
            key == LogicalKeyboardKey.keyO) &&
        onOpen != null) {
      onOpen();
      return true;
    }
    if (key == LogicalKeyboardKey.keyR && onReply != null) {
      onReply();
      return true;
    }
    if (key == LogicalKeyboardKey.keyF && onFavorite != null) {
      onFavorite();
      return true;
    }
    if (key == LogicalKeyboardKey.keyB && onBoost != null) {
      onBoost();
      return true;
    }
    if (key == LogicalKeyboardKey.keyM && onBookmark != null) {
      onBookmark();
      return true;
    }
    if (key == LogicalKeyboardKey.keyX && onToggleCw != null) {
      onToggleCw();
      return true;
    }
    if (key == LogicalKeyboardKey.keyP && onOpenProfile != null) {
      onOpenProfile();
      return true;
    }
    if (key == LogicalKeyboardKey.period && onRefresh != null) {
      onRefresh();
      return true;
    }

    return false;
  }
}

/// Accessible modal dialog listing all standard Mastodon keyboard shortcuts
/// supported by FediCaption (triggered via `?` or the AppBar shortcuts icon).
class KeyboardShortcutsDialog extends StatelessWidget {
  const KeyboardShortcutsDialog({super.key});

  static bool _isOpen = false;

  static Future<void> show(BuildContext context) async {
    if (_isOpen) return;
    _isOpen = true;
    try {
      await showDialog<void>(
        context: context,
        builder: (_) => const KeyboardShortcutsDialog(),
      );
    } finally {
      _isOpen = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    String mod(String key) =>
        KeyboardNavHelper.primaryShortcutLabel(context, key);
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.keyboard_outlined),
          const SizedBox(width: 10),
          Text(l10n.shortcutsTitle),
        ],
      ),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _section(context, l10n.shortcutsSectionNavigation, [
                (l10n.shortcutsOrKeyCombo('j', '↓'), l10n.shortcutsNextPost),
                (
                  l10n.shortcutsOrKeyCombo('k', '↑'),
                  l10n.shortcutsPreviousPost,
                ),
                (
                  l10n.shortcutsOrKeyCombo('PgUp', 'PgDn'),
                  l10n.shortcutsScrollPage,
                ),
                ('Home', l10n.shortcutsScrollToTop),
                (
                  l10n.shortcutsOrKeyCombo('Enter', 'o'),
                  l10n.shortcutsOpenPost,
                ),
                ('Esc', l10n.shortcutsEscape),
              ]),
              const SizedBox(height: 12),
              _section(context, l10n.shortcutsSectionActions, [
                ('r', l10n.shortcutsReply),
                ('f', l10n.shortcutsFavorite),
                ('b', l10n.shortcutsBoost),
                ('m', l10n.shortcutsBookmark),
                ('x', l10n.shortcutsToggleCw),
                ('p', l10n.shortcutsOpenProfile),
              ]),
              const SizedBox(height: 12),
              _section(context, l10n.shortcutsSectionTimelines, [
                (
                  l10n.shortcutsOrKeyCombo('g h', '1'),
                  l10n.shortcutsHomeTimeline,
                ),
                (
                  l10n.shortcutsOrKeyCombo('g l', '2'),
                  l10n.shortcutsLocalTimeline,
                ),
                (
                  l10n.shortcutsOrKeyCombo('g p', '3'),
                  l10n.shortcutsFederatedTimeline,
                ),
                (
                  l10n.shortcutsOrKeyCombo('g n', '4'),
                  l10n.shortcutsNotificationsTimeline,
                ),
                (
                  l10n.shortcutsOrKeyCombo('g b', '5'),
                  l10n.shortcutsBookmarksTimeline,
                ),
                (
                  l10n.shortcutsOrKeyCombo('g f', '6'),
                  l10n.shortcutsFavoritesTimeline,
                ),
                (
                  l10n.shortcutsOrKeyCombo('g u', '7'),
                  l10n.shortcutsMyPostsTimeline,
                ),
              ]),
              const SizedBox(height: 12),
              _section(context, l10n.shortcutsSectionApp, [
                (
                  l10n.shortcutsOrKeyCombo('n', mod('N')),
                  l10n.shortcutsComposeNew,
                ),
                (mod('Enter'), l10n.shortcutsPublishPost),
                (
                  l10n.shortcutsOrKeyCombo('/', mod('F')),
                  l10n.shortcutsLocalSearch,
                ),
                (
                  l10n.shortcutsOrKeyCombo('.', mod('R')),
                  l10n.shortcutsRefresh,
                ),
                (mod(','), l10n.shortcutsOpenSettings),
                ('?', l10n.shortcutsShowHelp),
              ]),
            ],
          ),
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonClose),
        ),
      ],
    );
  }

  Widget _section(
    BuildContext context,
    String title,
    List<(String, String)> rows,
  ) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.bold, color: scheme.primary),
          ),
        ),
        const SizedBox(height: 6),
        for (final (keys, desc) in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: [
                Container(
                  constraints: const BoxConstraints(minWidth: 108),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: scheme.outlineVariant),
                  ),
                  child: Text(
                    keys,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.labelMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    desc,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
