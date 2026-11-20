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
import 'linkified_text.dart';
import 'media_attachment_card.dart';

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
  });

  final AppController app;
  final void Function(MastodonAccount account) onOpenProfile;
  final void Function(MastodonStatus status) onOpenThread;
  final MastodonStatus? quotedStatus;
  final String? quoteUrl;
  final bool isLoading;

  @override
  State<QuotedStatusCard> createState() => _QuotedStatusCardState();
}

class _QuotedStatusCardState extends State<QuotedStatusCard> {
  bool _cwRevealed = false;

  Future<void> _openExternalUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fedi = context.fediColors;
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
        margin: const EdgeInsets.only(top: 10),
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
                'Loading quoted post…',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
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
        margin: const EdgeInsets.only(top: 10),
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
                    'Quoted post could not be loaded in-app',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: fedi.subtleText,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            LinkifiedText.plain(
              fallbackUrl,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      );
    }

    final hasCw = quoted.spoilerText.trim().isNotEmpty;
    final compactTime = TimeUtils.formatRelativeCompact(quoted.createdAt);
    final verboseTime = TimeUtils.formatRelativeAccessible(quoted.createdAt);

    return Semantics(
      container: true,
      label:
          'Quoted post by ${quoted.account.effectiveDisplayName}, ${quoted.account.handle}.',
      child: Container(
        margin: const EdgeInsets.only(top: 10),
        padding: const EdgeInsets.all(12),
        decoration: containerDecoration,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Quoted post label strip
            Row(
              children: [
                Icon(Icons.format_quote, size: 16, color: scheme.primary),
                const SizedBox(width: 4),
                Text(
                  'Quoted Post',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: scheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 6),

            // Author header + clickable permalink timestamp
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                AccessibleAvatar(
                  imageUrl: quoted.account.avatar,
                  displayName: quoted.account.effectiveDisplayName,
                  radius: 16,
                  onTap: () => widget.onOpenProfile(quoted.account),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: InkWell(
                    onTap: () => widget.onOpenProfile(quoted.account),
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
                            quoted.account.effectiveDisplayName,
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(fontWeight: FontWeight.bold),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            quoted.account.handle,
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
                Semantics(
                  link: true,
                  label:
                      'Quoted post from $verboseTime. Open original post in browser.',
                  child: InkWell(
                    onTap: quoted.permalinkUrl.isNotEmpty
                        ? () => _openExternalUrl(quoted.permalinkUrl)
                        : null,
                    borderRadius: BorderRadius.circular(8),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        minWidth: AppConstants.minTouchTargetSize,
                        minHeight: AppConstants.minTouchTargetSize,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              compactTime,
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(
                                    color: scheme.primary,
                                    decoration: TextDecoration.underline,
                                  ),
                            ),
                            const SizedBox(width: 2),
                            Icon(
                              Icons.open_in_new,
                              size: 13,
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

            const SizedBox(height: 6),

            if (hasCw) ...[
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: fedi.biasWarningBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: fedi.cardBorder),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'CW: ${quoted.spoilerText}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: fedi.biasWarningFg,
                            ),
                      ),
                    ),
                    TextButton(
                      onPressed: () =>
                          setState(() => _cwRevealed = !_cwRevealed),
                      child: Text(_cwRevealed ? 'Hide' : 'Show'),
                    ),
                  ],
                ),
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
                      onTapMention: (mention) => widget.onOpenProfile(
                        MastodonAccount(
                          id: mention.id,
                          username: mention.username,
                          acct: mention.acct,
                          displayName: mention.username,
                          avatar: '',
                          url: mention.url,
                        ),
                      ),
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
