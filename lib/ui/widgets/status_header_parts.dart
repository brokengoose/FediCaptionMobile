// Copyright (c) 2026 brokengoose <brokengoose@users.noreply.github.com>
// SPDX-License-Identifier: MIT

import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants.dart';
import '../../core/theme/app_theme.dart';
import '../../core/time_utils.dart';
import '../../l10n/l10n.dart';
import '../../models/mastodon_models.dart';
import 'accessible_avatar.dart';
import 'accessible_button_semantics.dart';
import 'accessible_tip.dart';

/// Shared author header row (clickable avatar, display name, handle, and
/// upper-right clickable relative timestamp permalink) used in both
/// [StatusCard] and [QuotedStatusCard].
class StatusAuthorHeader extends StatelessWidget {
  const StatusAuthorHeader({
    super.key,
    required this.status,
    required this.onOpenProfile,
    this.compact = false,
  });

  final MastodonStatus status;
  final void Function(MastodonAccount account) onOpenProfile;
  final bool compact;

  Future<void> _openPermalink(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fedi = context.fediColors;
    final l10n = context.l10n;
    final compactTime = TimeUtils.formatRelativeCompact(
      status.createdAt,
      l10n: l10n,
    );
    final verboseTime = TimeUtils.formatRelativeAccessible(
      status.createdAt,
      l10n: l10n,
    );
    final VoidCallback? openPermalink = status.permalinkUrl.isNotEmpty
        ? () => _openPermalink(status.permalinkUrl)
        : null;

    return Row(
      crossAxisAlignment: compact
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      children: [
        AccessibleAvatar(
          imageUrl: status.account.avatar,
          displayName: status.account.effectiveDisplayName,
          radius: compact ? 16 : 20,
          onTap: () => onOpenProfile(status.account),
        ),
        SizedBox(width: compact ? 6 : 8),
        Expanded(
          child: AccessibleButtonSemantics(
            label: l10n.statusHeaderSemantics(
              status.account.effectiveDisplayName,
              status.account.handle,
            ),
            onTap: () => onOpenProfile(status.account),
            child: AccessibleTip(
              message: l10n.avatarViewProfileSemantics(
                status.account.effectiveDisplayName,
              ),
              child: InkWell(
                onTap: () => onOpenProfile(status.account),
                borderRadius: BorderRadius.circular(8),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    minHeight: AppConstants.minTouchTargetSize,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        status.account.effectiveDisplayName,
                        style: Theme.of(context).textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        status.account.handle,
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(color: fedi.subtleText),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        AccessibleButtonSemantics(
          link: true,
          label: compact
              ? l10n.statusQuotedTimestampSemantics(verboseTime)
              : l10n.statusTimestampSemantics(verboseTime),
          onTap: openPermalink,
          child: AccessibleTip(
            message: l10n.statusTimestampTip(verboseTime),
            child: InkWell(
              onTap: openPermalink,
              borderRadius: BorderRadius.circular(8),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  minWidth: AppConstants.minTouchTargetSize,
                  minHeight: AppConstants.minTouchTargetSize,
                ),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: compact ? 4 : 6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        compactTime,
                        style:
                            (compact
                                    ? Theme.of(context).textTheme.labelSmall
                                    : Theme.of(context).textTheme.labelMedium)
                                ?.copyWith(
                                  color: scheme.primary,
                                  decoration: TextDecoration.underline,
                                ),
                      ),
                      const SizedBox(width: 2),
                      Icon(
                        Icons.open_in_new,
                        size: compact ? 13 : 14,
                        color: scheme.primary,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Shared accessible Content Warning (spoiler) banner with a Show/Hide toggle.
class ContentWarningBanner extends StatelessWidget {
  const ContentWarningBanner({
    super.key,
    required this.spoilerText,
    required this.revealed,
    required this.onToggle,
    this.compact = false,
  });

  final String spoilerText;
  final bool revealed;
  final VoidCallback onToggle;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final fedi = context.fediColors;
    final l10n = context.l10n;
    return Container(
      padding: EdgeInsets.all(compact ? 8 : 10),
      decoration: BoxDecoration(
        color: fedi.biasWarningBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: fedi.cardBorder,
          width: fedi.isHighContrast ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              l10n.cwBannerText(spoilerText),
              style:
                  (compact
                          ? Theme.of(context).textTheme.bodySmall
                          : Theme.of(context).textTheme.bodyMedium)
                      ?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: fedi.biasWarningFg,
                      ),
            ),
          ),
          const SizedBox(width: 8),
          AccessibleButtonSemantics(
            toggled: revealed,
            label: revealed ? l10n.cwHideSemantics : l10n.cwShowSemantics,
            onTap: onToggle,
            child: AccessibleTip(
              message: revealed ? l10n.cwHideTip : l10n.cwShowTip,
              child: compact
                  ? TextButton(
                      onPressed: onToggle,
                      child: Text(revealed ? l10n.commonHide : l10n.commonShow),
                    )
                  : OutlinedButton(
                      onPressed: onToggle,
                      child: Text(
                        revealed ? l10n.commonHide : l10n.commonShowMore,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
