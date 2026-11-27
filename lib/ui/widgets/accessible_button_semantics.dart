// Copyright (c) 2026 brokengoose <brokengoose@users.noreply.github.com>
// SPDX-License-Identifier: MIT

import 'package:material_ui/material_ui.dart';

/// Gives a tappable control exactly one screen-reader node, with a
/// descriptive [label], optional [toggled]/[selected] state and a working
/// tap action.
///
/// Wrapping a Material button (or an `InkWell` with visible text) in a plain
/// `Semantics(button: true, label: …)` causes two problems:
/// - around a Material button it creates a second, non-activatable "button"
///   node above the real one, so screen readers hear it twice and one copy
///   does nothing;
/// - around an `InkWell` the visible text is merged in, so labels are read
///   twice (e.g. "Reply to Alice (3 replies) | 3").
///
/// This widget replaces the child's semantics instead (`excludeSemantics`),
/// re-exposes the tap via [onTap], and mirrors keyboard focus inside the child
/// so screen readers still follow Tab navigation.
///
/// Pass the same callback as the child's `onPressed`/`onTap`; `null` marks the
/// control disabled.
class AccessibleButtonSemantics extends StatefulWidget {
  const AccessibleButtonSemantics({
    super.key,
    required this.label,
    required this.onTap,
    required this.child,
    this.toggled,
    this.selected,
    this.hint,
    this.image = false,
    this.link = false,
  });

  final String label;
  final VoidCallback? onTap;
  final Widget child;
  final bool? toggled;
  final bool? selected;
  final String? hint;

  /// Also flags the node as an image (e.g. tappable media previews).
  final bool image;

  /// Exposes the node as a link instead of a button (opens a URL).
  final bool link;

  @override
  State<AccessibleButtonSemantics> createState() =>
      _AccessibleButtonSemanticsState();
}

class _AccessibleButtonSemanticsState extends State<AccessibleButtonSemantics> {
  bool _focused = false;

  void _onFocusChange(bool focused) {
    if (_focused != focused) setState(() => _focused = focused);
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      button: !widget.link,
      link: widget.link,
      image: widget.image,
      enabled: widget.onTap != null,
      focusable: widget.onTap != null,
      focused: _focused,
      toggled: widget.toggled,
      selected: widget.selected,
      label: widget.label,
      hint: widget.hint,
      onTap: widget.onTap,
      excludeSemantics: true,
      child: Focus(
        canRequestFocus: false,
        skipTraversal: true,
        onFocusChange: _onFocusChange,
        child: widget.child,
      ),
    );
  }
}
