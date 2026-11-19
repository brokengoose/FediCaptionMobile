// Copyright (c) 2026 brokengoose <brokengoose@users.noreply.github.com>
// SPDX-License-Identifier: MIT

import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants.dart';
import '../../core/theme/app_theme.dart';
import '../../core/time_utils.dart';
import '../../models/mastodon_models.dart';
import '../../state/app_controller.dart';
import 'accessible_avatar.dart';
import 'media_attachment_card.dart';

/// Accessible Mastodon status card supporting:
/// - Clickable user avatar, display name, and handle (including boost banner)
/// - Clickable relative timestamp permalink in the upper-right corner
/// - On-demand AI alt-text description & Read Aloud on media
/// - Reply, Boost, Favorite, Bookmark, Thread, Edit (own posts), and Delete (own posts)
class StatusCard extends StatefulWidget {
  const StatusCard({
    super.key,
    required this.status,
    required this.app,
    required this.onOpenProfile,
    required this.onOpenThread,
    required this.onReply,
    required this.onToggleBoost,
    required this.onToggleFavorite,
    required this.onToggleBookmark,
    this.onEdit,
    this.onDelete,
  });

  final MastodonStatus status;
  final AppController app;
  final void Function(MastodonAccount account) onOpenProfile;
  final void Function(MastodonStatus status) onOpenThread;
  final void Function(MastodonStatus status) onReply;
  final Future<void> Function(MastodonStatus status) onToggleBoost;
  final Future<void> Function(MastodonStatus status) onToggleFavorite;
  final Future<void> Function(MastodonStatus status) onToggleBookmark;
  final void Function(MastodonStatus status)? onEdit;
  final Future<void> Function(MastodonStatus status)? onDelete;

  @override
  State<StatusCard> createState() => _StatusCardState();
}

class _StatusCardState extends State<StatusCard> {
  bool _cwRevealed = false;

  Future<void> _openPermalink(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final outer = widget.status;
    final target = outer.displayStatus;
    final isOwnPost = widget.app.currentAccount?.id == target.account.id;
    final scheme = Theme.of(context).colorScheme;
    final fedi = context.fediColors;

    final hasCw = target.spoilerText.trim().isNotEmpty;
    final compactTime = TimeUtils.formatRelativeCompact(target.createdAt);
    final verboseTime = TimeUtils.formatRelativeAccessible(target.createdAt);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Boost banner (clickable booster profile)
            if (outer.isBoost)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Semantics(
                  button: true,
                  label:
                      'Boosted by ${outer.account.effectiveDisplayName}. Tap to view profile.',
                  child: InkWell(
                    onTap: () => widget.onOpenProfile(outer.account),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 4,
                        horizontal: 4,
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.repeat, size: 16, color: fedi.subtleText),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '${outer.account.effectiveDisplayName} boosted',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelMedium
                                  ?.copyWith(color: fedi.subtleText),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

            // Header: Clickable author avatar + display name + handle + Upper-right permalink timestamp
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AccessibleAvatar(
                  imageUrl: target.account.avatar,
                  displayName: target.account.effectiveDisplayName,
                  onTap: () => widget.onOpenProfile(target.account),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Semantics(
                    button: true,
                    label:
                        '${target.account.effectiveDisplayName}, ${target.account.handle}. Tap to view posts.',
                    child: InkWell(
                      onTap: () => widget.onOpenProfile(target.account),
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
                              target.account.effectiveDisplayName,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(fontWeight: FontWeight.bold),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              target.account.handle,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
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
                // Upper-right clickable timestamp linking to original post on Mastodon server
                Semantics(
                  link: true,
                  label:
                      'Posted $verboseTime. Open original post in external browser.',
                  child: InkWell(
                    onTap: target.permalinkUrl.isNotEmpty
                        ? () => _openPermalink(target.permalinkUrl)
                        : null,
                    borderRadius: BorderRadius.circular(8),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        minWidth: AppConstants.minTouchTargetSize,
                        minHeight: AppConstants.minTouchTargetSize,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              compactTime,
                              style: Theme.of(context)
                                  .textTheme
                                  .labelMedium
                                  ?.copyWith(
                                    color: scheme.primary,
                                    decoration: TextDecoration.underline,
                                  ),
                            ),
                            const SizedBox(width: 2),
                            Icon(
                              Icons.open_in_new,
                              size: 14,
                              color: scheme.primary,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Content Warning (Spoiler)
            if (hasCw) ...[
              Container(
                padding: const EdgeInsets.all(10),
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
                        'CW: ${target.spoilerText}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: fedi.biasWarningFg,
                            ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Semantics(
                      button: true,
                      toggled: _cwRevealed,
                      label: _cwRevealed
                          ? 'Hide content behind content warning'
                          : 'Show content behind content warning',
                      child: OutlinedButton(
                        onPressed: () =>
                            setState(() => _cwRevealed = !_cwRevealed),
                        child: Text(_cwRevealed ? 'Hide' : 'Show More'),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],

            // Main post body + Media attachments
            if (!hasCw || _cwRevealed) ...[
              if (target.plainText.isNotEmpty)
                InkWell(
                  onTap: () => widget.onOpenThread(target),
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(
                      target.plainText,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ),
                ),
              if (target.editedAt != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'Edited ${TimeUtils.formatRelativeCompact(target.editedAt!)}',
                    style: Theme.of(context)
                        .textTheme
                        .labelSmall
                        ?.copyWith(color: fedi.subtleText),
                  ),
                ),
              for (final media in target.mediaAttachments)
                MediaAttachmentCard(
                  attachment: media,
                  app: widget.app,
                  postContext: target.plainText,
                ),
            ],

            const SizedBox(height: 8),
            const Divider(height: 1),
            const SizedBox(height: 4),

            // Accessible Action Bar
            Wrap(
              spacing: 4,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _ActionIcon(
                  icon: Icons.reply,
                  label: target.repliesCount > 0 ? '${target.repliesCount}' : '',
                  semanticLabel:
                      'Reply to ${target.account.effectiveDisplayName} (${target.repliesCount} replies)',
                  onPressed: () => widget.onReply(target),
                ),
                _ActionIcon(
                  icon: Icons.repeat,
                  label: target.reblogsCount > 0 ? '${target.reblogsCount}' : '',
                  active: target.reblogged,
                  activeColor: scheme.secondary,
                  semanticLabel: target.reblogged
                      ? 'Unboost post (${target.reblogsCount} boosts)'
                      : 'Boost post (${target.reblogsCount} boosts)',
                  onPressed: () => widget.onToggleBoost(target),
                ),
                _ActionIcon(
                  icon: target.favourited ? Icons.star : Icons.star_border,
                  label: target.favouritesCount > 0
                      ? '${target.favouritesCount}'
                      : '',
                  active: target.favourited,
                  activeColor: scheme.primary,
                  semanticLabel: target.favourited
                      ? 'Unfavorite post (${target.favouritesCount} favorites)'
                      : 'Favorite post (${target.favouritesCount} favorites)',
                  onPressed: () => widget.onToggleFavorite(target),
                ),
                _ActionIcon(
                  icon: target.bookmarked
                      ? Icons.bookmark
                      : Icons.bookmark_border,
                  label: '',
                  active: target.bookmarked,
                  activeColor: scheme.primary,
                  semanticLabel:
                      target.bookmarked ? 'Remove bookmark' : 'Bookmark post',
                  onPressed: () => widget.onToggleBookmark(target),
                ),
                _ActionIcon(
                  icon: Icons.forum_outlined,
                  label: 'Thread',
                  semanticLabel: 'View conversation thread',
                  onPressed: () => widget.onOpenThread(target),
                ),
                if (isOwnPost && widget.onEdit != null)
                  _ActionIcon(
                    icon: Icons.edit,
                    label: 'Edit',
                    semanticLabel: 'Edit your post and media alt text',
                    onPressed: () => widget.onEdit!(target),
                  ),
                if (isOwnPost && widget.onDelete != null)
                  _ActionIcon(
                    icon: Icons.delete_outline,
                    label: '',
                    activeColor: scheme.error,
                    semanticLabel: 'Delete your post',
                    onPressed: () => widget.onDelete!(target),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionIcon extends StatelessWidget {
  const _ActionIcon({
    required this.icon,
    required this.label,
    required this.semanticLabel,
    required this.onPressed,
    this.active = false,
    this.activeColor,
  });

  final IconData icon;
  final String label;
  final String semanticLabel;
  final VoidCallback onPressed;
  final bool active;
  final Color? activeColor;

  @override
  Widget build(BuildContext context) {
    final defaultColor = Theme.of(context).colorScheme.onSurfaceVariant;
    final color = active
        ? (activeColor ?? Theme.of(context).colorScheme.primary)
        : defaultColor;

    return Semantics(
      button: true,
      selected: active,
      label: semanticLabel,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minWidth: AppConstants.minTouchTargetSize,
            minHeight: AppConstants.minTouchTargetSize,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 20, color: color),
                if (label.isNotEmpty) ...[
                  const SizedBox(width: 4),
                  Text(
                    label,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: color,
                          fontWeight:
                              active ? FontWeight.bold : FontWeight.normal,
                        ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
