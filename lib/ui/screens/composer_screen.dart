// Copyright (c) 2026 brokengoose <brokengoose@users.noreply.github.com>
// SPDX-License-Identifier: MIT

import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/accessibility_announcer.dart';
import '../../core/html_utils.dart';
import '../../core/media_utils.dart';
import '../../core/theme/app_theme.dart';
import '../../core/time_utils.dart';
import '../../l10n/l10n.dart';
import '../../l10n/model_localizations.dart';
import '../../models/app_settings.dart';
import '../../models/mastodon_models.dart';
import '../../state/app_controller.dart';
import '../../state/composer_controller.dart';
import '../helpers/keyboard_shortcuts.dart';
import '../helpers/status_action_handler.dart';
import '../widgets/accessible_tip.dart';
import '../widgets/bias_review_sheet.dart';
import '../widgets/composer_attachment_tile.dart';
import '../widgets/linkified_text.dart';
import '../widgets/media_attachment_card.dart';
import '../widgets/missing_alt_text_dialog.dart';
import '../widgets/quoted_status_card.dart';
import '../widgets/status_header_parts.dart';

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
  bool _confirmingDiscard = false;

  @override
  void initState() {
    super.initState();
    _controller = ComposerController(
      app: widget.app,
      replyToStatus: widget.replyToStatus,
      editingStatus: widget.editingStatus,
    );
    unawaited(_controller.loadEditSourceIfNeeded());
    HardwareKeyboard.instance.addHandler(_handleComposerKeyEvent);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleComposerKeyEvent);
    _controller.dispose();
    super.dispose();
  }

  bool _handleComposerKeyEvent(KeyEvent event) {
    if (!mounted || event is! KeyDownEvent) return false;
    final route = ModalRoute.of(context);
    if (route == null || !route.isCurrent) return false;

    final key = event.logicalKey;
    if (KeyboardNavHelper.isPrimaryModifierPressed() &&
        (key == LogicalKeyboardKey.enter ||
            key == LogicalKeyboardKey.numpadEnter)) {
      if (_controller.canSubmit) {
        unawaited(_handleSubmit());
      }
      return true;
    }
    if (key == LogicalKeyboardKey.escape && !_controller.isPublishing) {
      unawaited(Navigator.of(context).maybePop());
      return true;
    }
    return false;
  }

  void _showPickerError(Object error) {
    if (!mounted) return;
    final detail = error is PlatformException
        ? (error.message ?? error.code)
        : error.toString();
    final msg = context.l10n.composerErrorPickMedia(detail);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    AccessibilityAnnouncer.announce(msg);
  }

  Future<void> _confirmAndPop() async {
    if (_confirmingDiscard || !mounted) return;
    _confirmingDiscard = true;
    try {
      final l10n = context.l10n;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(
            _controller.isEditing
                ? l10n.composerDiscardEditTitle
                : l10n.composerDiscardDraftTitle,
          ),
          content: Text(l10n.composerDiscardDraftBody),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l10n.composerKeepEditing),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(l10n.composerDiscard),
            ),
          ],
        ),
      );
      if (confirmed == true && mounted) {
        Navigator.of(context).pop();
      }
    } finally {
      _confirmingDiscard = false;
    }
  }

  Future<void> _pickPhoto(ImageSource source) async {
    try {
      final file = await _imagePicker.pickImage(
        source: source,
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 85,
      );
      if (file == null) return;
      await _controller.addLocalMedia(filePath: file.path, isVideo: false);
    } catch (e) {
      _showPickerError(e);
    }
  }

  Future<void> _pickVideo(ImageSource source) async {
    try {
      final file = await _imagePicker.pickVideo(source: source);
      if (file == null) return;
      await _controller.addLocalMedia(filePath: file.path, isVideo: true);
    } catch (e) {
      _showPickerError(e);
    }
  }

  Future<void> _pickFromFiles() async {
    try {
      final picked = await FilePicker.pickFile(
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
      final path = picked?.path;
      if (path == null || path.isEmpty) return;
      await _controller.addLocalMedia(
        filePath: path,
        isVideo: MediaUtils.isVideoFilePath(path),
      );
    } catch (e) {
      _showPickerError(e);
    }
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
          aiEnabled: widget.app.settings.isAiEnabled,
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

      // Silent pass: if no bias is detected, publish immediately without showing a dialog.
      if (biasResult.hasBias) {
        final action = await showModalBottomSheet<BiasReviewAction>(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          builder: (_) =>
              BiasReviewSheet(result: biasResult, policy: biasPolicy),
        );

        if (!mounted) return;
        switch (action) {
          case BiasReviewAction.useSuggestedInComposer:
            if (biasResult.suggestedAlternateWording != null) {
              _controller.replacePostText(
                biasResult.suggestedAlternateWording!,
              );
            }
            return;
          case BiasReviewAction.useSuggestedAndPublishNow:
            if (biasResult.suggestedAlternateWording != null) {
              _controller.replacePostText(
                biasResult.suggestedAlternateWording!,
              );
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
    final l10n = context.l10n;

    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final remaining = _controller.remainingCharacters;
        final overLimit = _controller.isOverCharacterLimit;
        final limits = _controller.limits;

        final submitShortcut = KeyboardNavHelper.primaryShortcutLabel(
          context,
          'Enter',
        );
        final submitLabel = _controller.isCheckingBias
            ? l10n.composerCheckingBias
            : _controller.isPublishing
            ? (_controller.isEditing
                  ? l10n.composerSaving
                  : l10n.composerPublishing)
            : (_controller.isEditing
                  ? l10n.composerSaveChanges
                  : l10n.composerPublish);

        return PopScope(
          canPop: !_controller.hasUnsavedChanges && !_controller.isPublishing,
          onPopInvokedWithResult: (didPop, _) {
            if (didPop || _controller.isPublishing || _confirmingDiscard) {
              return;
            }
            unawaited(_confirmAndPop());
          },
          child: Scaffold(
            appBar: AppBar(
              title: Text(
                _controller.isEditing
                    ? l10n.composerTitleEdit
                    : (_controller.isReply
                          ? l10n.composerTitleReply
                          : l10n.composerTitleNew),
              ),
              actions: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  child: AccessibleTip(
                    message: _controller.isEditing
                        ? l10n.composerEditSubmitTip(submitShortcut)
                        : l10n.composerPublishSubmitTip(submitShortcut),
                    child: FilledButton(
                      onPressed: _controller.canSubmit ? _handleSubmit : null,
                      child: Text(submitLabel),
                    ),
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

                  // Full post being replied to
                  if (widget.replyToStatus != null) ...[
                    _ReplyContextCard(
                      app: widget.app,
                      status: widget.replyToStatus!,
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
                    title: Text(l10n.composerCwSwitchTitle),
                    subtitle: Text(l10n.composerCwSwitchSubtitle),
                    value: _controller.showContentWarning,
                    onChanged: _controller.toggleContentWarning,
                  ),
                  if (_controller.showContentWarning) ...[
                    TextField(
                      controller: _controller.spoilerController,
                      decoration: InputDecoration(
                        labelText: l10n.composerCwLabel,
                        hintText: l10n.composerCwHint,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Main post body
                  TextField(
                    controller: _controller.textController,
                    maxLines: 8,
                    minLines: 4,
                    decoration: InputDecoration(
                      labelText: l10n.composerBodyLabel,
                      hintText: l10n.composerBodyHint,
                      alignLabelWithHint: true,
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Live dynamic server character counter (includes body + CW)
                  Row(
                    children: [
                      Semantics(
                        liveRegion: overLimit,
                        label: l10n.composerCharsRemainingSemantics(
                          remaining,
                          limits.maxCharacters,
                        ),
                        child: Text(
                          l10n.composerCharsCounter(
                            _controller.usedCharacters,
                            limits.maxCharacters,
                            remaining,
                          ),
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(
                                color: overLimit
                                    ? scheme.error
                                    : fedi.subtleText,
                                fontWeight: overLimit
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                        ),
                      ),
                      const Spacer(),
                      if (_controller.isCheckingBias ||
                          _controller.isPublishing)
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
                      decoration: InputDecoration(
                        labelText: l10n.composerVisibilityLabel,
                      ),
                      items: PostVisibility.values
                          .map(
                            (v) => DropdownMenuItem(
                              value: v,
                              child: Text(
                                l10n.composerVisibilityItem(
                                  v.localizedLabel(l10n),
                                  v.localizedDescription(l10n),
                                ),
                              ),
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
                      l10n.composerAttachmentsHeader(
                        _controller.attachments.length,
                        limits.maxMediaAttachments,
                      ),
                      style: Theme.of(context).textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (Theme.of(context).platform == TargetPlatform.iOS ||
                          Theme.of(context).platform == TargetPlatform.android)
                        AccessibleTip(
                          message: l10n.composerCameraTip,
                          child: OutlinedButton.icon(
                            onPressed: _controller.canAddMoreMedia
                                ? () => _pickPhoto(ImageSource.camera)
                                : null,
                            icon: const Icon(Icons.photo_camera),
                            label: Text(l10n.composerCameraLabel),
                          ),
                        ),
                      AccessibleTip(
                        message: l10n.composerPhotoLibraryTip,
                        child: OutlinedButton.icon(
                          onPressed: _controller.canAddMoreMedia
                              ? () => _pickPhoto(ImageSource.gallery)
                              : null,
                          icon: const Icon(Icons.photo_library),
                          label: Text(l10n.composerPhotoLibraryLabel),
                        ),
                      ),
                      AccessibleTip(
                        message: l10n.composerVideoTip,
                        child: OutlinedButton.icon(
                          onPressed: _controller.canAddMoreMedia
                              ? () => _pickVideo(ImageSource.gallery)
                              : null,
                          icon: const Icon(Icons.video_library),
                          label: Text(l10n.composerVideoLabel),
                        ),
                      ),
                      AccessibleTip(
                        message: l10n.composerFilePickerTip,
                        child: OutlinedButton.icon(
                          onPressed: _controller.canAddMoreMedia
                              ? _pickFromFiles
                              : null,
                          icon: const Icon(Icons.attach_file),
                          label: Text(l10n.composerFilePickerLabel),
                        ),
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
                      aiEnabled: widget.app.settings.isAiEnabled,
                      ttsSpeechRate: widget.app.settings.ttsSpeechRate,
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
          ),
        );
      },
    );
  }
}

/// Renders the entire Mastodon post being replied to (author header,
/// Content Warning, quoted post if present, full body, and media attachments)
/// above the composer input area.
class _ReplyContextCard extends StatefulWidget {
  const _ReplyContextCard({required this.app, required this.status});

  final AppController app;
  final MastodonStatus status;

  @override
  State<_ReplyContextCard> createState() => _ReplyContextCardState();
}

class _ReplyContextCardState extends State<_ReplyContextCard> {
  late final StatusActionHandler _actions = StatusActionHandler(
    app: widget.app,
  );
  bool _cwRevealed = true;
  LeadingQuoteMatch? _leadingQuote;

  @override
  void initState() {
    super.initState();
    _syncQuoteResolution();
  }

  @override
  void didUpdateWidget(covariant _ReplyContextCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldTarget = oldWidget.status.displayStatus;
    final newTarget = widget.status.displayStatus;
    if (oldTarget.id != newTarget.id ||
        oldTarget.contentHtml != newTarget.contentHtml) {
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
          unawaited(widget.app.resolveQuotedStatus(quoteUrl));
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fedi = context.fediColors;
    final l10n = context.l10n;
    final target = widget.status.displayStatus;
    final hasCw = target.spoilerText.trim().isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: fedi.isHighContrast
            ? scheme.surface
            : scheme.surfaceContainerHighest.withAlpha(115),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: fedi.cardBorder,
          width: fedi.isHighContrast ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.reply, size: 16, color: scheme.primary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  l10n.composerReplyingTo(target.account.handle),
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: scheme.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          StatusAuthorHeader(
            status: target,
            onOpenProfile: (acc) => _actions.openProfile(context, acc),
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
          if (!hasCw || _cwRevealed) ...[
            ListenableBuilder(
              listenable: widget.app.quoteCache,
              builder: (context, _) {
                final quoteMatch = _leadingQuote;
                final quoteUrl = quoteMatch?.quoteUrl;
                final embeddedQuote =
                    target.quotedStatus ??
                    (quoteUrl != null
                        ? widget.app.cachedQuotedStatus(quoteUrl)
                        : null);
                final isLoadingQuote =
                    target.quotedStatus == null &&
                    quoteUrl != null &&
                    (widget.app.isResolvingQuote(quoteUrl) ||
                        !widget.app.hasResolvedQuote(quoteUrl));
                final hasQuoteWindow =
                    target.quotedStatus != null || quoteUrl != null;

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
                        onOpenProfile: (acc) =>
                            _actions.openProfile(context, acc),
                        onOpenThread: (st) => _actions.openThread(context, st),
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
                      LinkifiedText.html(
                        bodyHtml,
                        style: Theme.of(context).textTheme.bodyLarge,
                        mentions: target.mentions,
                        onTapMention: (mention) => _actions.openProfile(
                          context,
                          mention.toStubAccount(),
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
                  l10n.statusEditedAt(
                    TimeUtils.formatRelativeCompact(
                      target.editedAt!,
                      l10n: l10n,
                    ),
                  ),
                  style: Theme.of(context).textTheme.labelSmall
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
        ],
      ),
    );
  }
}
