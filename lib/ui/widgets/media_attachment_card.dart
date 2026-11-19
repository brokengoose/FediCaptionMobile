// Copyright (c) 2026 brokengoose <brokengoose@users.noreply.github.com>
// SPDX-License-Identifier: MIT

import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_theme.dart';
import '../../models/mastodon_models.dart';
import '../../state/app_controller.dart';

/// Displays a timeline media attachment with ALT TEXT PROVIDED / NO ALT TEXT status,
/// expandable readable alt-text box, on-demand "Describe with AI" button, and "Read Aloud" TTS.
class MediaAttachmentCard extends StatefulWidget {
  const MediaAttachmentCard({
    super.key,
    required this.attachment,
    required this.app,
    this.postContext,
  });

  final MastodonMediaAttachment attachment;
  final AppController app;
  final String? postContext;

  @override
  State<MediaAttachmentCard> createState() => _MediaAttachmentCardState();
}

class _MediaAttachmentCardState extends State<MediaAttachmentCard> {
  bool _altExpanded = true;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([widget.app, widget.app.tts]),
      builder: (context, _) {
        final att = widget.attachment;
        final fedi = context.fediColors;
        final scheme = Theme.of(context).colorScheme;

        final authorAlt = (att.description ?? '').trim();
        final aiAlt = widget.app.aiDescriptionForMedia(att.id);
        final isDescribing = widget.app.isDescribingMedia(att.id);
        final describeError = widget.app.mediaDescribeError(att.id);

        final effectiveAlt = aiAlt ?? authorAlt;
        final hasAnyAlt = effectiveAlt.isNotEmpty;
        final ttsKey = 'timeline_media_${att.id}';
        final isSpeaking = widget.app.tts.isSpeakingKey(ttsKey);

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
              if (att.bestPreviewUrl.isNotEmpty)
                Semantics(
                  image: true,
                  label: hasAnyAlt
                      ? '${att.isVideo ? 'Video' : 'Image'}: $effectiveAlt'
                      : '${att.isVideo ? 'Video' : 'Image'} with no alt text provided.',
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 280),
                        child: Image.network(
                          att.bestPreviewUrl,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            height: 120,
                            color: scheme.surfaceContainerHighest,
                            alignment: Alignment.center,
                            child: const Icon(Icons.broken_image, size: 40),
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
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.play_arrow, color: Colors.white),
                              SizedBox(width: 4),
                              Text(
                                'VIDEO',
                                style: TextStyle(
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

              // Alt-text status bar & expandable toggle
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                color: att.hasAltText ? fedi.altPresentBg : fedi.altMissingBg,
                child: Row(
                  children: [
                    Icon(
                      att.hasAltText
                          ? Icons.closed_caption
                          : Icons.warning_amber_rounded,
                      size: 18,
                      color:
                          att.hasAltText ? fedi.altPresentFg : fedi.altMissingFg,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        att.hasAltText ? 'ALT TEXT PROVIDED' : 'NO ALT TEXT',
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: att.hasAltText
                                  ? fedi.altPresentFg
                                  : fedi.altMissingFg,
                            ),
                      ),
                    ),
                    if (hasAnyAlt)
                      Semantics(
                        button: true,
                        toggled: _altExpanded,
                        label: _altExpanded
                            ? 'Collapse alt text box'
                            : 'Expand alt text box',
                        child: TextButton.icon(
                          onPressed: () {
                            setState(() => _altExpanded = !_altExpanded);
                          },
                          style: TextButton.styleFrom(
                            foregroundColor: att.hasAltText
                                ? fedi.altPresentFg
                                : fedi.altMissingFg,
                          ),
                          icon: Icon(
                            _altExpanded ? Icons.expand_less : Icons.expand_more,
                          ),
                          label: Text(_altExpanded ? 'Hide' : 'Show'),
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
                      if (authorAlt.isNotEmpty) ...[
                        Text(
                          'Author Alt-Text:',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: fedi.subtleText,
                              ),
                        ),
                        const SizedBox(height: 4),
                        SelectableText(
                          authorAlt,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                      if (aiAlt != null && aiAlt.isNotEmpty) ...[
                        if (authorAlt.isNotEmpty) const Divider(height: 16),
                        Text(
                          'On-Demand AI Description:',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: scheme.primary,
                              ),
                        ),
                        const SizedBox(height: 4),
                        SelectableText(
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
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: scheme.error),
                  ),
                ),

              // Action buttons: Describe with AI / Re-Describe with AI & Read Aloud
              Padding(
                padding: const EdgeInsets.all(8),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Semantics(
                      button: true,
                      enabled: !isDescribing,
                      label: isDescribing
                          ? 'Generating AI description'
                          : (aiAlt != null || att.hasAltText
                              ? 'Re-describe media with AI'
                              : 'Describe media with AI'),
                      child: OutlinedButton.icon(
                        onPressed: isDescribing
                            ? null
                            : () => widget.app.describeTimelineMedia(
                                  att,
                                  postContext: widget.postContext,
                                ),
                        icon: isDescribing
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.auto_awesome, size: 18),
                        label: Text(
                          isDescribing
                              ? 'Describing…'
                              : (aiAlt != null || att.hasAltText
                                  ? 'Re-Describe with AI'
                                  : 'Describe with AI'),
                        ),
                      ),
                    ),
                    if (hasAnyAlt)
                      Semantics(
                        button: true,
                        toggled: isSpeaking,
                        label: isSpeaking
                            ? 'Stop reading alt text aloud'
                            : 'Read alt text aloud',
                        child: OutlinedButton.icon(
                          onPressed: () => widget.app.tts.toggleSpeak(
                            key: ttsKey,
                            text: effectiveAlt,
                            languageName: widget.app.settings.language,
                          ),
                          icon: Icon(
                            isSpeaking ? Icons.stop : Icons.volume_up,
                            size: 18,
                          ),
                          label: Text(isSpeaking ? 'Stop Reading' : 'Read Aloud'),
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
