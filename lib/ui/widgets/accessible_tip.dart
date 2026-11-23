// Copyright (c) 2026 brokengoose <brokengoose@users.noreply.github.com>
// SPDX-License-Identifier: MIT

import 'package:material_ui/material_ui.dart';

/// Displays an explanatory text tip when either:
/// - the mouse hovers over [child], OR
/// - keyboard focus (`Tab` / `Shift+Tab`) enters [child].
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
  bool _hasFocus = false;

  void _handleFocusChange(bool hasFocus) {
    if (_hasFocus == hasFocus) return;
    _hasFocus = hasFocus;
    if (hasFocus) {
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

    return Focus(
      skipTraversal: true,
      canRequestFocus: false,
      onFocusChange: _handleFocusChange,
      child: Tooltip(
        key: _tooltipKey,
        message: widget.message,
        preferBelow: widget.preferBelow,
        waitDuration: widget.waitDuration,
        showDuration: const Duration(seconds: 4),
        excludeFromSemantics: true,
        child: widget.child,
      ),
    );
  }
}
