// Copyright (c) 2026 brokengoose <brokengoose@users.noreply.github.com>
// SPDX-License-Identifier: MIT

import 'dart:io';

import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_theme.dart';
import '../../l10n/l10n.dart';
import '../../l10n/model_localizations.dart';
import '../../models/ai_models.dart';
import '../../models/composer_attachment.dart';
import '../../services/tts_service.dart';

/// Per-attachment editor card in the composer:
/// - Status badge (`AI Scanning...`, `Alt-Text Ready`, `Missing Alt-Text`, or `Error`)
/// - Editable alt-text text area with live character counter (`current / max chars`)
/// - Re-Scan with AI button & per-attachment detail-level selector
/// - Read Aloud (TTS) button
/// - Remove attachment button
class ComposerAttachmentTile extends StatefulWidget {
  const ComposerAttachmentTile({
    super.key,
    required this.index,
    required this.attachment,
    required this.maxAltTextLength,
    required this.language,
    required this.tts,
    required this.onAltTextChanged,
    required this.onDetailLevelChanged,
    required this.onRescan,
    required this.onRemove,
    this.aiEnabled = true,
    this.ttsSpeechRate = 0.5,
  });

  final int index;
  final ComposerAttachment attachment;
  final int maxAltTextLength;
  final String language;
  final TtsService tts;
  final ValueChanged<String> onAltTextChanged;
  final ValueChanged<CaptionDetailLevel> onDetailLevelChanged;
  final VoidCallback onRescan;
  final VoidCallback onRemove;
  final bool aiEnabled;
  final double ttsSpeechRate;

  @override
  State<ComposerAttachmentTile> createState() => _ComposerAttachmentTileState();
}

class _ComposerAttachmentTileState extends State<ComposerAttachmentTile> {
  late final TextEditingController _altController;

  @override
  void initState() {
    super.initState();
    _altController = TextEditingController(text: widget.attachment.altText);
  }

  @override
  void didUpdateWidget(covariant ComposerAttachmentTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.attachment.altText != _altController.text) {
      _altController.value = TextEditingValue(
        text: widget.attachment.altText,
        selection: TextSelection.collapsed(
          offset: widget.attachment.altText.length,
        ),
      );
    }
  }

  @override
  void dispose() {
    _altController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final att = widget.attachment;
    final fedi = context.fediColors;
    final scheme = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    final isScanning = att.status == AttachmentStatus.scanning;
    final currentLen = att.altText.length;
    final isOverLimit = currentLen > widget.maxAltTextLength;
    final ttsKey = 'composer_att_${att.localId}';

    final (badgeBg, badgeFg, badgeIcon) = switch (att.status) {
      AttachmentStatus.scanning => (
          scheme.primaryContainer,
          scheme.onPrimaryContainer,
          Icons.auto_awesome,
        ),
      AttachmentStatus.ready => (
          fedi.altPresentBg,
          fedi.altPresentFg,
          Icons.check_circle_outline,
        ),
      AttachmentStatus.missingAltText => (
          fedi.altMissingBg,
          fedi.altMissingFg,
          Icons.warning_amber_rounded,
        ),
      AttachmentStatus.error => (
          scheme.errorContainer,
          scheme.onErrorContainer,
          Icons.error_outline,
        ),
    };

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _buildThumbnail(context),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        att.isVideo
                            ? l10n.composerAttachmentVideoLabel(widget.index + 1)
                            : l10n.composerAttachmentImageLabel(widget.index + 1),
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Semantics(
                        liveRegion: true,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: badgeBg,
                            borderRadius: BorderRadius.circular(6),
                            border: fedi.isHighContrast
                                ? Border.all(color: badgeFg, width: 1.5)
                                : null,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isScanning)
                                SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: badgeFg,
                                  ),
                                )
                              else
                                Icon(badgeIcon, size: 15, color: badgeFg),
                              const SizedBox(width: 6),
                              Text(
                                att.status.localizedLabel(l10n),
                                style: Theme.of(context)
                                    .textTheme
                                    .labelMedium
                                    ?.copyWith(
                                      color: badgeFg,
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: widget.onRemove,
                  tooltip: l10n.composerRemoveAttachmentTooltip(widget.index + 1),
                  icon: Icon(Icons.delete_outline, color: scheme.error),
                ),
              ],
            ),

            if (att.errorMessage != null && att.errorMessage!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                att.errorMessage!,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: scheme.error),
              ),
            ],

            const SizedBox(height: 12),

            TextField(
              controller: _altController,
              maxLines: 4,
              minLines: 2,
              onChanged: widget.onAltTextChanged,
              decoration: InputDecoration(
                labelText: l10n.composerAltTextLabel,
                hintText: att.isVideo
                    ? l10n.composerAltTextHintVideo
                    : l10n.composerAltTextHintImage,
                helperText: l10n.composerAltTextCounterHelper(
                  currentLen,
                  widget.maxAltTextLength,
                ),
                helperStyle: TextStyle(
                  color: isOverLimit ? scheme.error : fedi.subtleText,
                  fontWeight: isOverLimit ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),

            if (widget.aiEnabled) ...[
              const SizedBox(height: 10),
              DropdownButtonFormField<CaptionDetailLevel>(
                key: ValueKey(att.detailLevel),
                initialValue: att.detailLevel,
                decoration: InputDecoration(
                  labelText: l10n.composerDetailLevelLabel,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                ),
                items: CaptionDetailLevel.values
                    .map(
                      (level) => DropdownMenuItem(
                        value: level,
                        child: Text(level.localizedLabel(l10n)),
                      ),
                    )
                    .toList(),
                onChanged: isScanning
                    ? null
                    : (next) {
                        if (next != null) {
                          widget.onDetailLevelChanged(next);
                        }
                      },
              ),
            ],

            const SizedBox(height: 10),

            ListenableBuilder(
              listenable: widget.tts,
              builder: (context, _) {
                final isSpeaking = widget.tts.isSpeakingKey(ttsKey);
                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (widget.aiEnabled)
                      FilledButton.tonalIcon(
                        onPressed: isScanning ? null : widget.onRescan,
                        icon: const Icon(Icons.auto_awesome, size: 18),
                        label: Text(
                          isScanning
                              ? l10n.composerScanningButton
                              : l10n.composerRescanButton,
                        ),
                      ),
                    OutlinedButton.icon(
                      onPressed: att.altText.trim().isEmpty
                          ? null
                          : () => widget.tts.toggleSpeak(
                                key: ttsKey,
                                text: att.altText,
                                languageName: widget.language,
                                speechRate: widget.ttsSpeechRate,
                              ),
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
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThumbnail(BuildContext context) {
    final att = widget.attachment;
    final scheme = Theme.of(context).colorScheme;

    Widget content;
    if (att.previewBytes != null) {
      content = Image.memory(att.previewBytes!, fit: BoxFit.cover);
    } else if (!att.isVideo && att.filePath != null) {
      content = Image.file(
        File(att.filePath!),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const Icon(Icons.image_outlined),
      );
    } else if (att.previewUrl != null && att.previewUrl!.isNotEmpty) {
      content = Image.network(
        att.previewUrl!,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const Icon(Icons.image_outlined),
      );
    } else {
      content = Icon(
        att.isVideo ? Icons.videocam : Icons.image_outlined,
        size: 32,
        color: scheme.onSurfaceVariant,
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 68,
        height: 68,
        color: scheme.surfaceContainerHighest,
        child: Stack(
          fit: StackFit.expand,
          children: [
            content,
            if (att.isVideo)
              const Align(
                alignment: AlignmentDirectional.bottomEnd,
                child: Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(
                    Icons.videocam,
                    size: 18,
                    color: Colors.white,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
