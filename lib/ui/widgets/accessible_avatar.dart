// Copyright (c) 2026 brokengoose <brokengoose@users.noreply.github.com>
// SPDX-License-Identifier: MIT

import 'package:material_ui/material_ui.dart';

import '../../core/constants.dart';
import 'accessible_tip.dart';
import 'cached_network_image_provider.dart';

/// Accessible user avatar with >= 48x48dp touch target when interactive.
class AccessibleAvatar extends StatelessWidget {
  const AccessibleAvatar({
    super.key,
    required this.imageUrl,
    required this.displayName,
    this.radius = 20,
    this.onTap,
    this.semanticLabel,
  });

  final String imageUrl;
  final String displayName;
  final double radius;
  final VoidCallback? onTap;
  final String? semanticLabel;

  String get _initial {
    final trimmed = displayName.trim();
    if (trimmed.isEmpty) return '?';
    return trimmed.characters.first.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final avatar = CircleAvatar(
      radius: radius,
      backgroundColor: scheme.primaryContainer,
      foregroundColor: scheme.onPrimaryContainer,
      backgroundImage:
          imageUrl.isNotEmpty ? DiskCachedNetworkImage(imageUrl) : null,
      onBackgroundImageError: imageUrl.isNotEmpty ? (_, __) {} : null,
      child: imageUrl.isEmpty
          ? Text(
              _initial,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: radius * 0.85,
              ),
            )
          : null,
    );

    if (onTap == null) {
      return ExcludeSemantics(child: avatar);
    }

    final tipText = semanticLabel ?? 'View profile and posts by $displayName';
    return Semantics(
      button: true,
      label: tipText,
      child: AccessibleTip(
        message: tipText,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppConstants.minTouchTargetSize / 2),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minWidth: AppConstants.minTouchTargetSize,
              minHeight: AppConstants.minTouchTargetSize,
            ),
            child: Center(child: avatar),
          ),
        ),
      ),
    );
  }
}
