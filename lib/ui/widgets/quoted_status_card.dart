// Copyright (c) 2026 brokengoose <brokengoose@users.noreply.github.com>
// SPDX-License-Identifier: MIT

import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_theme.dart';
import '../../l10n/l10n.dart';
import '../../models/mastodon_models.dart';
import '../../state/app_controller.dart';
import 'linkified_text.dart';
import 'media_attachment_card.dart';
import 'status_header_parts.dart';

/// Embedded inset window rendering a quoted Mastodon post inside a parent [StatusCard].
class QuotedStatusCard extends StatefulWidget {
  const QuotedStatusCard({
    super.key,
    required this.app,
    required this.onOpenProfile,
    required this.onOpenThread,
    this.quotedStatus,
    this.quoteUrl,
    this.isLoading = false,
    this.onRetry,
  });

  final AppController app;
  final void Function(MastodonAccount account) onOpenProfile;
  final void Function(MastodonStatus status) onOpenThread;
  final MastodonStatus? quotedStatus;
  final String? quoteUrl;
  final bool isLoading;
  final VoidCallback? onRetry;

  @override
  State<QuotedStatusCard> createState() => _QuotedStatusCardState();
}

class _QuotedStatusCardState extends State<QuotedStatusCard> {
  bool _cwRevealed = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fedi = context.fediColors;
    final l10n = context.l10n;
    final quoted = widget.quotedStatus?.displayStatus;

    final containerDecoration = BoxDecoration(
      color: fedi.isHighContrast
          ? scheme.surface
          : scheme.surface.withAlpha(235),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: fedi.isHighContrast ? scheme.primary : fedi.cardBorder,
        width: fedi.isHighContrast ? 2.0 : 1.2,
      ),
    );

    if (widget.isLoading && quoted == null) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(12),
        decoration: containerDecoration,
        child: Row(
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                l10n.quotedPostLoading,
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: fedi.subtleText),
              ),
            ),
          ],
        ),
      );
    }

    if (quoted == null) {
      final fallbackUrl = (widget.quoteUrl ?? '').trim();
      if (fallbackUrl.isEmpty) return const SizedBox.shrink();
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(12),
        decoration: containerDecoration,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.format_quote, size: 18, color: fedi.subtleText),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    l10n.quotedPostLoadError,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: fedi.subtleText,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (widget.onRetry != null)
                  TextButton.icon(
                    onPressed: widget.onRetry,
                    icon: const Icon(Icons.refresh, size: 16),
                    label: Text(l10n.commonRetry),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            LinkifiedText.plain(
              fallbackUrl,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      );
    }

    final hasCw = quoted.spoilerText.trim().isNotEmpty;

    return Semantics(
      container: true,
      label: l10n.quotedPostSemantics(
        quoted.account.effectiveDisplayName,
        quoted.account.handle,
      ),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(12),
        decoration: containerDecoration,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.format_quote, size: 16, color: scheme.primary),
                const SizedBox(width: 4),
                Text(
                  l10n.quotedPostBadge,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: scheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),

            StatusAuthorHeader(
              status: quoted,
              onOpenProfile: widget.onOpenProfile,
              compact: true,
            ),

            const SizedBox(height: 6),

            if (hasCw) ...[
              ContentWarningBanner(
                spoilerText: quoted.spoilerText,
                revealed: _cwRevealed,
                onToggle: () => setState(() => _cwRevealed = !_cwRevealed),
                compact: true,
              ),
              const SizedBox(height: 6),
            ],

            if (!hasCw || _cwRevealed) ...[
              if (quoted.plainText.isNotEmpty)
                InkWell(
                  onTap: () => widget.onOpenThread(quoted),
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: LinkifiedText.html(
                      quoted.contentHtml,
                      style: Theme.of(context).textTheme.bodyMedium,
                      mentions: quoted.mentions,
                      onTapMention: (mention) =>
                          widget.onOpenProfile(mention.toStubAccount()),
                    ),
                  ),
                ),
              for (final media in quoted.mediaAttachments)
                MediaAttachmentCard(
                  attachment: media,
                  app: widget.app,
                  postContext: quoted.plainText,
                ),
            ],
          ],
        ),
      ),
    );
  }
}
