// Copyright (c) 2026 brokengoose <brokengoose@users.noreply.github.com>
// SPDX-License-Identifier: MIT

import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_theme.dart';
import '../../l10n/l10n.dart';
import '../../models/mastodon_models.dart';
import '../../state/app_controller.dart';
import '../screens/image_viewer_screen.dart';
import '../screens/video_player_screen.dart';
import 'accessible_button_semantics.dart';
import 'accessible_tip.dart';
import 'cached_network_image_provider.dart';
import 'linkified_text.dart';

/// Displays a timeline media attachment with ALT TEXT PROVIDED / NO ALT TEXT status,
/// expandable readable alt-text box, on-demand "Describe with AI" button, and "Read Aloud" TTS.
class MediaAttachmentCard extends StatefulWidget {
  const MediaAttachmentCard({
    super.key,
    required this.attachment,
    required this.app,
    this.postContext,
    this.translatedAltText,
    this.readAloudLanguage,
  });

  final MastodonMediaAttachment attachment;
  final AppController app;
  final String? postContext;

  /// Optional translated alt-text displayed in place of the author's original
  /// alt-text when the parent post is showing a translation.
  final String? translatedAltText;

  /// Language of the author's (or translated) alt-text, as resolved by the
  /// parent post, so read-aloud picks the right voice. Falls back to the
  /// app's caption language, which is also what AI-generated alt-text uses.
  final String? readAloudLanguage;

  @override
  State<MediaAttachmentCard> createState() => _MediaAttachmentCardState();
}

class _MediaAttachmentCardState extends State<MediaAttachmentCard> {
  bool _altExpanded = true;

  /// Computes a deterministic preview height before the image downloads so
  /// timeline scrolling never jumps as images finish loading.
  double _previewHeightFor(double? aspectRatio) {
    if (aspectRatio == null || aspectRatio <= 0) return 240;
    if (aspectRatio < 0.85) return 280; // Portrait
    if (aspectRatio > 1.8) return 200; // Wide landscape
    return 240;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        widget.app.mediaAi,
        widget.app.tts,
        widget.app,
      ]),
      builder: (context, _) {
        final att = widget.attachment;
        final fedi = context.fediColors;
        final scheme = Theme.of(context).colorScheme;
        final l10n = context.l10n;

        final authorAlt = (att.description ?? '').trim();
        final translatedAlt = (widget.translatedAltText ?? '').trim();
        final displayedAuthorAlt = translatedAlt.isNotEmpty
            ? translatedAlt
            : authorAlt;
        final aiAlt = widget.app.aiDescriptionForMedia(att.id);
        final isDescribing = widget.app.isDescribingMedia(att.id);
        final describeError = widget.app.mediaDescribeError(att.id);

        final effectiveAlt = aiAlt ?? displayedAuthorAlt;
        final hasAnyAlt = effectiveAlt.isNotEmpty;
        final ttsKey = 'timeline_media_${att.id}';
        final isSpeaking = widget.app.tts.isSpeakingKey(ttsKey);

        void openFullScreen() {
          final fullUrl = att.url.isNotEmpty ? att.url : att.bestPreviewUrl;
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => att.isVideo
                  ? VideoPlayerScreen(
                      videoUrl: fullUrl,
                      altText: effectiveAlt,
                      isGifv: att.type == 'gifv',
                    )
                  : ImageViewerScreen(imageUrl: fullUrl, altText: effectiveAlt),
            ),
          );
        }

        void toggleAltExpanded() =>
            setState(() => _altExpanded = !_altExpanded);

        final VoidCallback? describe = isDescribing
            ? null
            : () => widget.app.describeTimelineMedia(
                att,
                postContext: widget.postContext,
              );

        void toggleReadAloud() => widget.app.tts.toggleSpeak(
          key: ttsKey,
          text: effectiveAlt,
          // AI captions are generated in the app's caption language.
          languageName: aiAlt == null
              ? (widget.readAloudLanguage ?? widget.app.settings.language)
              : widget.app.settings.language,
          speechRate: widget.app.settings.ttsSpeechRate,
        );

        return Container(
          margin: const EdgeInsets.only(top: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: fedi.cardBorder,
              width: fedi.isHighContrast ? 2 : 1,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (att.bestPreviewUrl.isNotEmpty || att.isVideo)
                AccessibleButtonSemantics(
                  image: !att.isVideo,
                  onTap: openFullScreen,
                  label: hasAnyAlt
                      ? (att.isVideo
                            ? l10n.mediaVideoWithAltSemantics(effectiveAlt)
                            : l10n.mediaImageWithAltSemantics(effectiveAlt))
                      : (att.isVideo
                            ? l10n.mediaVideoNoAltSemantics
                            : l10n.mediaImageNoAltSemantics),
                  child: AccessibleTip(
                    message: att.isVideo
                        ? l10n.mediaVideoOpenTip
                        : l10n.mediaImageOpenTip,
                    child: InkWell(
                      onTap: openFullScreen,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: double.infinity,
                            height: _previewHeightFor(att.aspectRatio),
                            child: ColoredBox(
                              color: scheme.surfaceContainerHighest,
                              child: Builder(
                                builder: (context) {
                                  final preview = ResizeImage.resizeIfNeeded(
                                    1200,
                                    null,
                                    DiskCachedNetworkImage(att.bestPreviewUrl),
                                  );
                                  return Image(
                                    image: preview,
                                    width: double.infinity,
                                    height: _previewHeightFor(att.aspectRatio),
                                    fit: BoxFit.cover,
                                    gaplessPlayback: true,
                                    errorBuilder: (_, _, _) {
                                      // The resize wrapper has its own cache
                                      // entry; evict it so the preview retries
                                      // next time this card is built.
                                      scheduleMicrotask(preview.evict);
                                      return const Center(
                                        child: Icon(
                                          Icons.broken_image,
                                          size: 40,
                                        ),
                                      );
                                    },
                                  );
                                },
                              ),
                            ),
                          ),
                          if (att.isVideo)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black87,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.play_arrow,
                                    color: Colors.white,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    l10n.mediaVideoBadge,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),

              // Alt-text status bar & expandable toggle
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                color: att.hasAltText ? fedi.altPresentBg : fedi.altMissingBg,
                child: Row(
                  children: [
                    Icon(
                      att.hasAltText
                          ? Icons.closed_caption
                          : Icons.warning_amber_rounded,
                      size: 18,
                      color: att.hasAltText
                          ? fedi.altPresentFg
                          : fedi.altMissingFg,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        att.hasAltText
                            ? l10n.mediaAltProvidedBadge
                            : l10n.mediaNoAltBadge,
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: att.hasAltText
                                  ? fedi.altPresentFg
                                  : fedi.altMissingFg,
                            ),
                      ),
                    ),
                    if (hasAnyAlt)
                      AccessibleButtonSemantics(
                        toggled: _altExpanded,
                        label: _altExpanded
                            ? l10n.mediaCollapseAltSemantics
                            : l10n.mediaExpandAltSemantics,
                        onTap: toggleAltExpanded,
                        child: TextButton.icon(
                          onPressed: toggleAltExpanded,
                          style: TextButton.styleFrom(
                            foregroundColor: att.hasAltText
                                ? fedi.altPresentFg
                                : fedi.altMissingFg,
                          ),
                          icon: Icon(
                            _altExpanded
                                ? Icons.expand_less
                                : Icons.expand_more,
                          ),
                          label: Text(
                            _altExpanded ? l10n.commonHide : l10n.commonShow,
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // Expandable readable alt-text box
              if (_altExpanded && hasAnyAlt)
                Container(
                  padding: const EdgeInsets.all(12),
                  color: scheme.surface,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (displayedAuthorAlt.isNotEmpty) ...[
                        Text(
                          translatedAlt.isNotEmpty
                              ? l10n.mediaAuthorAltTranslatedHeading
                              : l10n.mediaAuthorAltHeading,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: fedi.subtleText,
                              ),
                        ),
                        const SizedBox(height: 4),
                        LinkifiedText.plain(
                          displayedAuthorAlt,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                      if (aiAlt != null && aiAlt.isNotEmpty) ...[
                        if (authorAlt.isNotEmpty) const Divider(height: 16),
                        Text(
                          l10n.mediaOnDemandAiHeading,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: scheme.primary,
                              ),
                        ),
                        const SizedBox(height: 4),
                        LinkifiedText.plain(
                          aiAlt,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ],
                  ),
                ),

              if (describeError != null && describeError.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  child: Text(
                    describeError,
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: scheme.error),
                  ),
                ),

              // Action buttons: Describe with AI / Re-Describe with AI & Read Aloud
              if (widget.app.settings.isAiEnabled || hasAnyAlt)
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (widget.app.settings.isAiEnabled)
                        AccessibleButtonSemantics(
                          onTap: describe,
                          label: isDescribing
                              ? l10n.mediaDescribingSemantics
                              : (aiAlt != null || att.hasAltText
                                    ? l10n.mediaRedescribeSemantics
                                    : l10n.mediaDescribeSemantics),
                          child: AccessibleTip(
                            message: l10n.mediaDescribeTip,
                            child: OutlinedButton.icon(
                              onPressed: describe,
                              icon: isDescribing
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.auto_awesome, size: 18),
                              label: Text(
                                isDescribing
                                    ? l10n.mediaDescribingButton
                                    : (aiAlt != null || att.hasAltText
                                          ? l10n.mediaRedescribeButton
                                          : l10n.mediaDescribeButton),
                              ),
                            ),
                          ),
                        ),
                      if (hasAnyAlt)
                        AccessibleButtonSemantics(
                          toggled: isSpeaking,
                          label: isSpeaking
                              ? l10n.mediaStopReadingSemantics
                              : l10n.mediaReadAloudSemantics,
                          onTap: toggleReadAloud,
                          child: AccessibleTip(
                            message: isSpeaking
                                ? l10n.mediaStopReadingTip
                                : l10n.mediaReadAloudTip,
                            child: OutlinedButton.icon(
                              onPressed: toggleReadAloud,
                              icon: Icon(
                                isSpeaking ? Icons.stop : Icons.volume_up,
                                size: 18,
                              ),
                              label: Text(
                                isSpeaking
                                    ? l10n.mediaStopReadingButton
                                    : l10n.mediaReadAloudButton,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
