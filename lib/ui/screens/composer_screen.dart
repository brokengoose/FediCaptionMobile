// Copyright (c) 2026 brokengoose <brokengoose@users.noreply.github.com>
// SPDX-License-Identifier: MIT

import 'package:file_picker/file_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/theme/app_theme.dart';
import '../../models/app_settings.dart';
import '../../models/mastodon_models.dart';
import '../../state/app_controller.dart';
import '../../state/composer_controller.dart';
import '../widgets/bias_review_sheet.dart';
import '../widgets/composer_attachment_tile.dart';
import '../widgets/missing_alt_text_dialog.dart';

/// Post composer for creating new posts, replying, and editing own posts.
/// Implements automatic AI alt-text scanning, dynamic instance character/media limits,
/// Accessibility Rules (alt-text policy), and Pre-Post Racial & Gender Bias Checking.
class ComposerScreen extends StatefulWidget {
  const ComposerScreen({
    super.key,
    required this.app,
    this.replyToStatus,
    this.editingStatus,
  });

  final AppController app;
  final MastodonStatus? replyToStatus;
  final MastodonStatus? editingStatus;

  @override
  State<ComposerScreen> createState() => _ComposerScreenState();
}

class _ComposerScreenState extends State<ComposerScreen> {
  late final ComposerController _controller;
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _controller = ComposerController(
      app: widget.app,
      replyToStatus: widget.replyToStatus,
      editingStatus: widget.editingStatus,
    );
    _controller.loadEditSourceIfNeeded();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto(ImageSource source) async {
    final file = await _imagePicker.pickImage(
      source: source,
      maxWidth: 2048,
      maxHeight: 2048,
      imageQuality: 85,
    );
    if (file == null) return;
    await _controller.addLocalMedia(filePath: file.path, isVideo: false);
  }

  Future<void> _pickVideo(ImageSource source) async {
    final file = await _imagePicker.pickVideo(source: source);
    if (file == null) return;
    await _controller.addLocalMedia(filePath: file.path, isVideo: true);
  }

  Future<void> _pickFromFiles() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const [
        'jpg',
        'jpeg',
        'png',
        'webp',
        'gif',
        'mp4',
        'mov',
        'webm',
      ],
    );
    final path = result?.files.single.path;
    if (path == null || path.isEmpty) return;
    final lower = path.toLowerCase();
    final isVideo = lower.endsWith('.mp4') ||
        lower.endsWith('.mov') ||
        lower.endsWith('.webm');
    await _controller.addLocalMedia(filePath: path, isVideo: isVideo);
  }

  /// Complete pre-post publishing flow:
  /// 1. Accessibility Rules (Pre-Post Alt-Text Policy)
  /// 2. Bias Rules (Pre-Post Racial & Gender Bias Check)
  /// 3. Publish immediately if no bias detected, or pause for review if bias found
  Future<void> _handleSubmit() async {
    if (!_controller.canSubmit) return;

    // Step 1: Accessibility Rules — Pre-Post Alt-Text Policy
    final altPolicy = widget.app.settings.altTextPolicy;
    final missingAlt = _controller.attachmentsMissingAltText;
    if (missingAlt.isNotEmpty && altPolicy != PolicyMode.off) {
      final action = await showDialog<MissingAltTextAction>(
        context: context,
        builder: (_) => MissingAltTextDialog(
          missingCount: missingAlt.length,
          policy: altPolicy,
        ),
      );

      if (!mounted) return;
      if (action == MissingAltTextAction.autoGenerateWithAi) {
        await _controller.generateAllMissingAltText();
        return; // Let user inspect/listen to newly generated alt-text before posting.
      }
      if (action != MissingAltTextAction.postAnyway) {
        return;
      }
    }

    // Step 2: Bias Rules — Pre-Post Racial & Gender Bias Check
    final biasPolicy = widget.app.settings.biasPolicy;
    if (biasPolicy != PolicyMode.off) {
      final biasResult = await _controller.runBiasCheck();
      if (!mounted) return;

      // Per Section 4.2: If NO bias is detected, publish IMMEDIATELY without showing a dialog.
      if (biasResult.hasBias) {
        final action = await showModalBottomSheet<BiasReviewAction>(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          builder: (_) => BiasReviewSheet(
            result: biasResult,
            policy: biasPolicy,
          ),
        );

        if (!mounted) return;
        switch (action) {
          case BiasReviewAction.useSuggestedInComposer:
            if (biasResult.suggestedAlternateWording != null) {
              _controller.replacePostText(biasResult.suggestedAlternateWording!);
            }
            return;
          case BiasReviewAction.useSuggestedAndPublishNow:
            if (biasResult.suggestedAlternateWording != null) {
              _controller.replacePostText(biasResult.suggestedAlternateWording!);
            }
            await _publishAndClose();
            return;
          case BiasReviewAction.publishAnyway:
            if (biasPolicy == PolicyMode.warn) {
              await _publishAndClose();
            }
            return;
          case BiasReviewAction.editInComposer:
          case null:
            return;
        }
      }
    }

    // Step 3: Publish immediately
    await _publishAndClose();
  }

  Future<void> _publishAndClose() async {
    final saved = await _controller.publishNow();
    if (!mounted) return;
    if (saved != null) {
      Navigator.of(context).pop(saved);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fedi = context.fediColors;

    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final remaining = _controller.remainingCharacters;
        final overLimit = _controller.isOverCharacterLimit;
        final limits = _controller.limits;

        final submitLabel = _controller.isCheckingBias
            ? 'Checking Bias…'
            : _controller.isPublishing
                ? (_controller.isEditing ? 'Saving…' : 'Publishing…')
                : (_controller.isEditing ? 'Save Changes' : 'Publish');

        return Scaffold(
          appBar: AppBar(
            title: Text(
              _controller.isEditing
                  ? 'Edit Post'
                  : (_controller.isReply ? 'Reply' : 'Compose Post'),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: FilledButton(
                  onPressed: _controller.canSubmit ? _handleSubmit : null,
                  child: Text(submitLabel),
                ),
              ),
            ],
          ),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_controller.isLoadingSource)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: LinearProgressIndicator(),
                  ),

                // Reply context banner
                if (widget.replyToStatus != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest.withAlpha(115),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: fedi.cardBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Replying to ${widget.replyToStatus!.displayStatus.account.handle}',
                          style: Theme.of(context)
                              .textTheme
                              .labelMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.replyToStatus!.displayStatus.plainText,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                if (_controller.errorMessage != null) ...[
                  Semantics(
                    liveRegion: true,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: scheme.errorContainer,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        _controller.errorMessage!,
                        style: TextStyle(color: scheme.onErrorContainer),
                      ),
                    ),
                  ),
                ],

                // Content Warning toggle & input
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Content Warning / Spoiler'),
                  subtitle: const Text(
                    'Included in character counter and pre-post bias check.',
                  ),
                  value: _controller.showContentWarning,
                  onChanged: _controller.toggleContentWarning,
                ),
                if (_controller.showContentWarning) ...[
                  TextField(
                    controller: _controller.spoilerController,
                    decoration: const InputDecoration(
                      labelText: 'Content Warning',
                      hintText: 'Brief summary or topic warning',
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // Main post body
                TextField(
                  controller: _controller.textController,
                  maxLines: 8,
                  minLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'What is on your mind?',
                    hintText: 'Write your Mastodon post…',
                    alignLabelWithHint: true,
                  ),
                ),

                const SizedBox(height: 8),

                // Live dynamic server character counter (includes body + CW)
                Row(
                  children: [
                    Semantics(
                      liveRegion: overLimit,
                      label:
                          '$remaining characters remaining out of ${limits.maxCharacters} maximum.',
                      child: Text(
                        '${_controller.usedCharacters} / ${limits.maxCharacters} chars ($remaining remaining)',
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                              color: overLimit ? scheme.error : fedi.subtleText,
                              fontWeight: overLimit
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                      ),
                    ),
                    const Spacer(),
                    if (_controller.isCheckingBias || _controller.isPublishing)
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                  ],
                ),

                const SizedBox(height: 14),

                // Visibility selector (when creating new post / reply)
                if (!_controller.isEditing) ...[
                  DropdownButtonFormField<PostVisibility>(
                    key: ValueKey(_controller.visibility),
                    initialValue: _controller.visibility,
                    decoration: const InputDecoration(
                      labelText: 'Post Visibility',
                    ),
                    items: PostVisibility.values
                        .map(
                          (v) => DropdownMenuItem(
                            value: v,
                            child: Text('${v.label} — ${v.description}'),
                          ),
                        )
                        .toList(),
                    onChanged: (next) {
                      if (next != null) _controller.setVisibility(next);
                    },
                    isExpanded: true,
                  ),
                  const SizedBox(height: 14),
                ],

                // Attach Media toolbar
                Semantics(
                  header: true,
                  child: Text(
                    'Media Attachments (${_controller.attachments.length} / ${limits.maxMediaAttachments})',
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _controller.canAddMoreMedia
                          ? () => _pickPhoto(ImageSource.camera)
                          : null,
                      icon: const Icon(Icons.photo_camera),
                      label: const Text('Camera'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _controller.canAddMoreMedia
                          ? () => _pickPhoto(ImageSource.gallery)
                          : null,
                      icon: const Icon(Icons.photo_library),
                      label: const Text('Photo Library'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _controller.canAddMoreMedia
                          ? () => _pickVideo(ImageSource.gallery)
                          : null,
                      icon: const Icon(Icons.video_library),
                      label: const Text('Video'),
                    ),
                    OutlinedButton.icon(
                      onPressed:
                          _controller.canAddMoreMedia ? _pickFromFiles : null,
                      icon: const Icon(Icons.attach_file),
                      label: const Text('File Picker'),
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                // Per-attachment controls & AI alt-text editors
                for (var i = 0; i < _controller.attachments.length; i++)
                  ComposerAttachmentTile(
                    key: ValueKey(_controller.attachments[i].localId),
                    index: i,
                    attachment: _controller.attachments[i],
                    maxAltTextLength: limits.altTextLimit,
                    language: widget.app.settings.language,
                    tts: widget.app.tts,
                    onAltTextChanged: (text) =>
                        _controller.updateAttachmentAltText(
                      _controller.attachments[i].localId,
                      text,
                    ),
                    onDetailLevelChanged: (level) =>
                        _controller.updateAttachmentDetailLevel(
                      _controller.attachments[i].localId,
                      level,
                    ),
                    onRescan: () => _controller.scanAttachmentWithAi(
                      _controller.attachments[i].localId,
                    ),
                    onRemove: () => _controller.removeAttachment(
                      _controller.attachments[i].localId,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
