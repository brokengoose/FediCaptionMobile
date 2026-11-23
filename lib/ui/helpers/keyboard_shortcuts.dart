// Copyright (c) 2026 brokengoose <brokengoose@users.noreply.github.com>
// SPDX-License-Identifier: MIT

import 'dart:async';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

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

  /// Shared dispatcher for standard Mastodon post-list keyboard shortcuts.
  /// Returns `true` if [event] was handled.
  static bool handleStatusFeedKeyEvent(
    KeyEvent event, {
    required bool Function() isActive,
    VoidCallback? onNext,
    VoidCallback? onPrevious,
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

    // Single-fire action keys (ignore key-repeat).
    if (event is KeyRepeatEvent) return false;

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
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.keyboard_outlined),
          SizedBox(width: 10),
          Text('Keyboard Shortcuts'),
        ],
      ),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _section(context, 'Post Navigation', const [
                ('j  or  ↓', 'Next post'),
                ('k  or  ↑', 'Previous post'),
                ('Enter  or  o', 'Open selected post / thread'),
                ('Esc', 'Go back or close viewer'),
              ]),
              const SizedBox(height: 12),
              _section(context, 'Selected Post Actions', const [
                ('r', 'Reply to selected post'),
                ('f', 'Favorite / unfavorite'),
                ('b', 'Boost / unboost'),
                ('m', 'Bookmark / unbookmark'),
                ('x', 'Expand / collapse Content Warning'),
                ('p', 'Open author profile'),
              ]),
              const SizedBox(height: 12),
              _section(context, 'Switch Timelines', const [
                ('g h  or  1', 'Home timeline'),
                ('g l  or  2', 'Local timeline'),
                ('g p  or  3', 'Federated timeline'),
                ('g n  or  4', 'Notifications / Alerts'),
                ('g b  or  5', 'Bookmarks'),
                ('g f  or  6', 'Favorites'),
                ('g u  or  7', 'My Published Posts'),
              ]),
              const SizedBox(height: 12),
              _section(context, 'App & Composer', const [
                ('n  or  ⌘N', 'Compose new post'),
                ('⌘Enter', 'Publish post (in Composer)'),
                ('/  or  ⌘F', 'Offline local search'),
                ('.  or  ⌘R', 'Refresh current view'),
                ('⌘,', 'Open Settings'),
                ('?', 'Show this help sheet'),
              ]),
            ],
          ),
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
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
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: scheme.primary,
                ),
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
                    border: Border.all(
                      color: scheme.outlineVariant,
                    ),
                  ),
                  child: Text(
                    keys,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
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
