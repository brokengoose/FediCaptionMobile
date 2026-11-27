// Copyright (c) 2026 brokengoose <brokengoose@users.noreply.github.com>
// SPDX-License-Identifier: MIT

import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

/// Displays an explanatory text tip when either:
/// - the mouse hovers over [child], OR
/// - keyboard focus (`Tab` / `Shift+Tab`) enters [child].
///
/// Automatically scales [Tooltip.verticalOffset] to at least half of
/// [child]'s rendered height (+8 px padding) so tall multi-line widgets (such
/// as post bodies) show the tooltip cleanly below or above their bounds rather
/// than overlapping the middle of the text.
///
/// Uses `excludeFromSemantics: true` by default so existing screen-reader
/// `Semantics` labels on buttons/areas are not spoken twice.
class AccessibleTip extends StatefulWidget {
  const AccessibleTip({
    super.key,
    required this.message,
    required this.child,
    this.preferBelow = true,
    this.waitDuration = const Duration(milliseconds: 350),
  });

  final String message;
  final Widget child;
  final bool preferBelow;
  final Duration waitDuration;

  @override
  State<AccessibleTip> createState() => _AccessibleTipState();
}

class _AccessibleTipState extends State<AccessibleTip> {
  final GlobalKey<TooltipState> _tooltipKey = GlobalKey<TooltipState>();
  final GlobalKey _childKey = GlobalKey();
  bool _hasFocus = false;
  double? _verticalOffset;

  @override
  void initState() {
    super.initState();
    _scheduleOffsetSync();
  }

  @override
  void didUpdateWidget(covariant AccessibleTip oldWidget) {
    super.didUpdateWidget(oldWidget);
    _scheduleOffsetSync();
  }

  void _scheduleOffsetSync() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _updateVerticalOffset();
    });
  }

  void _updateVerticalOffset() {
    final renderObject = _childKey.currentContext?.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) return;
    // Flutter places Tooltip relative to the vertical center of child; offset
    // by half the child's height + 8px so tall posts aren't covered mid-text.
    final next = math.max(24.0, (renderObject.size.height / 2) + 8.0);
    if (_verticalOffset == null || (next - _verticalOffset!).abs() > 0.5) {
      setState(() => _verticalOffset = next);
    }
  }

  void _handleFocusChange(bool hasFocus) {
    if (_hasFocus == hasFocus) return;
    _hasFocus = hasFocus;
    if (hasFocus) {
      _updateVerticalOffset();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _hasFocus) {
          _tooltipKey.currentState?.ensureTooltipVisible();
        }
      });
    } else {
      Tooltip.dismissAllToolTips();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.message.trim().isEmpty) return widget.child;

    return MouseRegion(
      opaque: false,
      onEnter: (_) => _updateVerticalOffset(),
      child: Focus(
        skipTraversal: true,
        canRequestFocus: false,
        onFocusChange: _handleFocusChange,
        child: Tooltip(
          key: _tooltipKey,
          message: widget.message,
          preferBelow: widget.preferBelow,
          verticalOffset: _verticalOffset,
          waitDuration: widget.waitDuration,
          showDuration: const Duration(seconds: 4),
          excludeFromSemantics: true,
          child: KeyedSubtree(key: _childKey, child: widget.child),
        ),
      ),
    );
  }
}
