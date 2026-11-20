// Copyright (c) 2026 brokengoose <brokengoose@users.noreply.github.com>
// SPDX-License-Identifier: MIT

import 'package:material_ui/material_ui.dart';

import '../../core/constants.dart';
import '../../core/html_utils.dart';
import '../../core/theme/app_theme.dart';
import '../../core/time_utils.dart';
import '../../models/mastodon_models.dart';
import '../../state/app_controller.dart';
import 'linkified_text.dart';
import 'media_attachment_card.dart';
import 'quoted_status_card.dart';
import 'status_header_parts.dart';

/// Accessible Mastodon status card supporting:
/// - Clickable user avatar, display name, and handle (including boost banner)
/// - Clickable relative timestamp permalink in the upper-right corner
/// - Embedded `RE: <url>` / native quoted post window displayed above the reply
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
  LeadingQuoteMatch? _leadingQuote;

  @override
  void initState() {
    super.initState();
    _syncQuoteResolution();
  }

  @override
  void didUpdateWidget(covariant StatusCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.status.displayStatus.id != widget.status.displayStatus.id ||
        oldWidget.status.displayStatus.contentHtml !=
            widget.status.displayStatus.contentHtml) {
      _syncQuoteResolution();
    }
  }

  void _syncQuoteResolution() {
    final target = widget.status.displayStatus;
    _leadingQuote = HtmlUtils.extractLeadingQuote(target.contentHtml);
    final quoteUrl = _leadingQuote?.quoteUrl;
    if (target.quotedStatus == null &&
        quoteUrl != null &&
        !widget.app.hasResolvedQuote(quoteUrl) &&
        !widget.app.isResolvingQuote(quoteUrl)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          widget.app.resolveQuotedStatus(quoteUrl);
        }
      });
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

            StatusAuthorHeader(
              status: target,
              onOpenProfile: widget.onOpenProfile,
            ),

            const SizedBox(height: 8),

            if (hasCw) ...[
              ContentWarningBanner(
                spoilerText: target.spoilerText,
                revealed: _cwRevealed,
                onToggle: () => setState(() => _cwRevealed = !_cwRevealed),
              ),
              const SizedBox(height: 8),
            ],

            // Embedded Quoted Post (above reply) + Main post body + Media attachments
            if (!hasCw || _cwRevealed) ...[
              ListenableBuilder(
                listenable: widget.app.quoteCache,
                builder: (context, _) {
                  final quoteMatch = _leadingQuote;
                  final quoteUrl = quoteMatch?.quoteUrl;
                  final embeddedQuote = target.quotedStatus ??
                      (quoteUrl != null
                          ? widget.app.cachedQuotedStatus(quoteUrl)
                          : null);
                  final isLoadingQuote = target.quotedStatus == null &&
                      quoteUrl != null &&
                      (widget.app.isResolvingQuote(quoteUrl) ||
                          !widget.app.hasResolvedQuote(quoteUrl));
                  final hasQuoteWindow =
                      target.quotedStatus != null || quoteUrl != null;

                  // Strip redundant leading `RE: <url>` from outer post text when displaying quote window.
                  final bodyHtml = quoteMatch != null
                      ? quoteMatch.remainingHtml
                      : target.contentHtml;
                  final bodyPlainText = HtmlUtils.htmlToPlainText(bodyHtml);

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (hasQuoteWindow)
                        QuotedStatusCard(
                          app: widget.app,
                          quotedStatus: embeddedQuote,
                          quoteUrl: quoteUrl,
                          isLoading: isLoadingQuote,
                          onOpenProfile: widget.onOpenProfile,
                          onOpenThread: widget.onOpenThread,
                          onRetry: quoteUrl != null
                              ? () => widget.app.resolveQuotedStatus(
                                    quoteUrl,
                                    forceRetry: true,
                                  )
                              : null,
                        ),
                      if (hasQuoteWindow && bodyPlainText.isNotEmpty)
                        const SizedBox(height: 6),
                      if (bodyPlainText.isNotEmpty)
                        InkWell(
                          onTap: () => widget.onOpenThread(target),
                          borderRadius: BorderRadius.circular(6),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: LinkifiedText.html(
                              bodyHtml,
                              style: Theme.of(context).textTheme.bodyLarge,
                              mentions: target.mentions,
                              onTapMention: (mention) =>
                                  widget.onOpenProfile(mention.toStubAccount()),
                            ),
                          ),
                        ),
                    ],
                  );
                },
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
