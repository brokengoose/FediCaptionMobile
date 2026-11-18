// Copyright (c) 2026 brokengoose <brokengoose@users.noreply.github.com>
// SPDX-License-Identifier: MIT

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../core/accessibility_announcer.dart';
import '../core/constants.dart';
import '../models/ai_models.dart';
import '../models/bias_models.dart';
import '../models/composer_attachment.dart';
import '../models/mastodon_models.dart';
import '../services/video_frame_extractor.dart';
import 'app_controller.dart';

/// State controller for the post composer (create, reply, and edit own post).
class ComposerController extends ChangeNotifier {
  ComposerController({
    required this.app,
    this.replyToStatus,
    this.editingStatus,
    VideoFrameExtractor? videoFrameExtractor,
  }) : _videoFrameExtractor = videoFrameExtractor ?? const VideoFrameExtractor() {
    if (replyToStatus != null) {
      final target = replyToStatus!.displayStatus;
      final mention = target.account.handle;
      textController.text = '$mention ';
      if (target.spoilerText.trim().isNotEmpty) {
        spoilerController.text = target.spoilerText.trim();
        _showContentWarning = true;
      }
      _visibility = target.visibility;
    } else if (editingStatus != null) {
      final target = editingStatus!.displayStatus;
      _visibility = target.visibility;
      _language = target.language ?? '';
      if (target.spoilerText.trim().isNotEmpty) {
        spoilerController.text = target.spoilerText;
        _showContentWarning = true;
      }
      textController.text = target.plainText;
      _attachments = target.mediaAttachments
          .map(
            (m) => ComposerAttachment(
              localId: 'remote_${m.id}',
              isVideo: m.isVideo,
              mimeType: m.isVideo ? 'video/mp4' : 'image/jpeg',
              remoteMediaId: m.id,
              remoteUrl: m.url,
              previewUrl: m.bestPreviewUrl,
              altText: m.description ?? '',
              detailLevel: app.settings.defaultDetailLevel,
              status: m.hasAltText
                  ? AttachmentStatus.ready
                  : AttachmentStatus.missingAltText,
            ),
          )
          .toList();
    }

    textController.addListener(notifyListeners);
    spoilerController.addListener(notifyListeners);
  }

  final AppController app;
  final MastodonStatus? replyToStatus;
  final MastodonStatus? editingStatus;
  final VideoFrameExtractor _videoFrameExtractor;

  final TextEditingController textController = TextEditingController();
  final TextEditingController spoilerController = TextEditingController();

  bool _showContentWarning = false;
  PostVisibility _visibility = PostVisibility.public;
  String _language = '';
  List<ComposerAttachment> _attachments = [];

  bool _isLoadingSource = false;
  bool _isCheckingBias = false;
  bool _isPublishing = false;
  String? _errorMessage;

  int _localIdCounter = 0;

  bool get isEditing => editingStatus != null;
  bool get isReply => replyToStatus != null;
  bool get showContentWarning => _showContentWarning;
  PostVisibility get visibility => _visibility;
  String get language => _language;
  List<ComposerAttachment> get attachments => List.unmodifiable(_attachments);
  bool get isLoadingSource => _isLoadingSource;
  bool get isCheckingBias => _isCheckingBias;
  bool get isPublishing => _isPublishing;
  String? get errorMessage => _errorMessage;

  InstanceLimits get limits => app.instanceLimits;

  /// Per Section 6.2: includes BOTH post body and Content Warning in remaining-character counter.
  int get usedCharacters {
    final bodyLen = textController.text.length;
    final cwLen = _showContentWarning ? spoilerController.text.length : 0;
    return bodyLen + cwLen;
  }

  int get remainingCharacters => limits.maxCharacters - usedCharacters;

  bool get isOverCharacterLimit => remainingCharacters < 0;

  bool get canAddMoreMedia => _attachments.length < limits.maxMediaAttachments;

  bool get hasAnyScanningAttachment =>
      _attachments.any((a) => a.status == AttachmentStatus.scanning);

  List<ComposerAttachment> get attachmentsMissingAltText =>
      _attachments.where((a) => !a.hasAltText).toList();

  bool get canSubmit =>
      !_isPublishing &&
      !_isCheckingBias &&
      !_isLoadingSource &&
      !hasAnyScanningAttachment &&
      !isOverCharacterLimit &&
      (textController.text.trim().isNotEmpty || _attachments.isNotEmpty);

  /// Loads raw post source (`GET /api/v1/statuses/{id}/source`) when editing an own post.
  Future<void> loadEditSourceIfNeeded() async {
    final target = editingStatus?.displayStatus;
    final session = app.session;
    if (target == null || session == null) return;

    _isLoadingSource = true;
    notifyListeners();

    try {
      final source = await app.mastodon.fetchStatusSource(
        instanceUrl: session.instanceUrl,
        accessToken: session.accessToken,
        statusId: target.id,
      );
      textController.text = source.text;
      if (source.spoilerText.trim().isNotEmpty) {
        spoilerController.text = source.spoilerText;
        _showContentWarning = true;
      }
    } catch (e) {
      _errorMessage = 'Loaded fallback post text (could not fetch raw source: $e)';
    } finally {
      _isLoadingSource = false;
      notifyListeners();
    }
  }

  void toggleContentWarning(bool enabled) {
    _showContentWarning = enabled;
    if (!enabled) {
      spoilerController.clear();
    }
    notifyListeners();
  }

  void setVisibility(PostVisibility value) {
    _visibility = value;
    notifyListeners();
  }

  void setLanguage(String value) {
    _language = value;
    notifyListeners();
  }

  void replacePostText(String newText) {
    textController.text = newText;
    textController.selection = TextSelection.collapsed(offset: newText.length);
    notifyListeners();
  }

  /// Attaches a local image or video file and auto-scans it with AI if enabled.
  Future<void> addLocalMedia({
    required String filePath,
    required bool isVideo,
  }) async {
    if (!canAddMoreMedia) {
      _errorMessage =
          'Maximum of ${limits.maxMediaAttachments} media attachments reached.';
      notifyListeners();
      return;
    }

    _errorMessage = null;
    final localId = 'local_${++_localIdCounter}';
    final fileName = p.basename(filePath);
    final mimeType = _guessMimeType(filePath, isVideo: isVideo);

    final initial = ComposerAttachment(
      localId: localId,
      isVideo: isVideo,
      mimeType: mimeType,
      filePath: filePath,
      fileName: fileName,
      detailLevel: app.settings.defaultDetailLevel,
      status: app.settings.autoGenerate
          ? AttachmentStatus.scanning
          : AttachmentStatus.missingAltText,
    );

    _attachments = [..._attachments, initial];
    notifyListeners();

    if (app.settings.autoGenerate) {
      await scanAttachmentWithAi(localId);
    }
  }

  void removeAttachment(String localId) {
    _attachments = _attachments.where((a) => a.localId != localId).toList();
    notifyListeners();
  }

  void updateAttachmentAltText(String localId, String altText) {
    _attachments = _attachments.map((a) {
      if (a.localId != localId) return a;
      final nextStatus = altText.trim().isNotEmpty
          ? AttachmentStatus.ready
          : AttachmentStatus.missingAltText;
      return a.copyWith(
        altText: altText,
        status: nextStatus,
        clearError: true,
      );
    }).toList();
    notifyListeners();
  }

  void updateAttachmentDetailLevel(
    String localId,
    CaptionDetailLevel detailLevel,
  ) {
    _attachments = _attachments.map((a) {
      if (a.localId != localId) return a;
      return a.copyWith(detailLevel: detailLevel);
    }).toList();
    notifyListeners();
  }

  /// Runs AI alt-text generation for a single attachment (local or remote edited media).
  Future<void> scanAttachmentWithAi(String localId) async {
    final index = _attachments.indexWhere((a) => a.localId == localId);
    if (index < 0) return;

    final attachment = _attachments[index];
    _updateAttachment(
      localId,
      attachment.copyWith(
        status: AttachmentStatus.scanning,
        clearError: true,
      ),
    );

    AccessibilityAnnouncer.announce(
      'AI scanning ${attachment.isVideo ? 'video' : 'image'} attachment ${index + 1}.',
    );

    try {
      List<MediaBinaryPayload> preExtracted = const [];

      if (attachment.isExistingRemote) {
        final targetUrl = attachment.isVideo
            ? (attachment.previewUrl ?? attachment.remoteUrl ?? '')
            : (attachment.remoteUrl ?? attachment.previewUrl ?? '');
        final downloaded = await app.mastodon.downloadMediaBytes(targetUrl);
        preExtracted = [
          MediaBinaryPayload(
            bytes: downloaded.bytes,
            mimeType: downloaded.mimeType,
            isVideo: false,
          ),
        ];
      } else if (attachment.isVideo && attachment.filePath != null) {
        // Pre-extract keyframes when needed for preview/bias reuse or frame-based providers.
        final file = File(attachment.filePath!);
        final size = await file.exists() ? await file.length() : 0;
        final canSendInlineGemini =
            app.settings.activeProvider == AiProviderType.gemini &&
                size > 0 &&
                size <= AppConstants.geminiInlineVideoMaxBytes;
        if (!canSendInlineGemini) {
          preExtracted = await _videoFrameExtractor.extractKeyframes(
            attachment.filePath!,
            frameCount: app.settings.videoKeyframeCount,
          );
        }
      }

      final caption = await app.aiProvider.generateAltText(
        settings: app.settings,
        credentials: app.credentials,
        isVideo: attachment.isVideo,
        detailLevel: attachment.detailLevel,
        maxAltTextLength: limits.altTextLimit,
        localFilePath: attachment.filePath,
        preExtractedMedia: preExtracted,
        mimeType: attachment.mimeType,
        draftPostContext: textController.text.trim(),
      );

      final latest = _findAttachment(localId);
      if (latest == null) return; // User removed while scanning.

      _updateAttachment(
        localId,
        latest.copyWith(
          altText: caption,
          status: AttachmentStatus.ready,
          extractedFrames:
              preExtracted.isNotEmpty ? preExtracted : latest.extractedFrames,
          previewBytes: preExtracted.isNotEmpty
              ? preExtracted.first.bytes
              : latest.previewBytes,
          clearError: true,
        ),
      );

      AccessibilityAnnouncer.announce(
        'Alt-text ready for attachment ${index + 1}.',
      );
    } catch (e) {
      final latest = _findAttachment(localId);
      if (latest == null) return;
      _updateAttachment(
        localId,
        latest.copyWith(
          status: AttachmentStatus.error,
          errorMessage: e.toString(),
        ),
      );
      AccessibilityAnnouncer.announce(
        'Error generating alt-text for attachment ${index + 1}.',
      );
    }
  }

  /// Auto-generates alt-text for all attachments that currently lack alt-text.
  Future<void> generateAllMissingAltText() async {
    final missingIds = attachmentsMissingAltText.map((a) => a.localId).toList();
    for (final id in missingIds) {
      await scanAttachmentWithAi(id);
    }
  }

  /// Runs the full 4-component pre-post racial and gender bias check.
  Future<BiasCheckResult> runBiasCheck() async {
    _isCheckingBias = true;
    _errorMessage = null;
    notifyListeners();

    AccessibilityAnnouncer.announce(
      'Checking post, media, links, and context for racial or gender bias.',
    );

    try {
      final biasAttachments = <BiasAttachmentInput>[];
      for (var i = 0; i < _attachments.length; i++) {
        final att = _attachments[i];
        final frames = await _collectVisualFramesForBiasCheck(att);
        biasAttachments.add(
          BiasAttachmentInput(
            index: i + 1,
            altText: att.altText,
            isVideo: att.isVideo,
            visualFrames: frames,
          ),
        );
      }

      final referencedStatuses = <ReferencedStatusContext>[];
      if (replyToStatus != null) {
        final target = replyToStatus!.displayStatus;
        referencedStatuses.add(
          ReferencedStatusContext(
            authorHandle: target.account.acct,
            contentText: target.plainText,
            spoilerText: target.spoilerText,
            mediaAltTexts: target.mediaAttachments
                .map((m) => (m.description ?? '').trim())
                .where((d) => d.isNotEmpty)
                .toList(),
            sourceUrl: target.permalinkUrl,
          ),
        );
      }

      final input = BiasCheckInput(
        postText: textController.text,
        spoilerText: _showContentWarning ? spoilerController.text : '',
        attachments: biasAttachments,
        referencedStatuses: referencedStatuses,
      );

      final result = await app.biasChecker.checkDraft(
        input: input,
        settings: app.settings,
        credentials: app.credentials,
        session: app.session,
      );

      if (result.hasBias) {
        AccessibilityAnnouncer.announce(
          'Pre-post bias review: ${result.summary}',
        );
      }
      return result;
    } finally {
      _isCheckingBias = false;
      notifyListeners();
    }
  }

  Future<List<MediaBinaryPayload>> _collectVisualFramesForBiasCheck(
    ComposerAttachment att,
  ) async {
    if (att.extractedFrames.isNotEmpty) {
      return att.extractedFrames;
    }
    if (att.filePath != null) {
      final file = File(att.filePath!);
      if (await file.exists()) {
        if (!att.isVideo) {
          final bytes = await file.readAsBytes();
          return [
            MediaBinaryPayload(
              bytes: bytes,
              mimeType: att.mimeType,
              isVideo: false,
            ),
          ];
        } else {
          return _videoFrameExtractor.extractKeyframes(
            att.filePath!,
            frameCount: app.settings.videoKeyframeCount,
          );
        }
      }
    }
    if (att.isExistingRemote) {
      final url = att.previewUrl ?? att.remoteUrl ?? '';
      if (url.isNotEmpty) {
        try {
          final downloaded = await app.mastodon.downloadMediaBytes(url);
          return [
            MediaBinaryPayload(
              bytes: downloaded.bytes,
              mimeType: downloaded.mimeType,
              isVideo: false,
            ),
          ];
        } catch (_) {
          // Proceed with alt-text only if remote download fails.
        }
      }
    }
    return const [];
  }

  /// Publishes a new post or saves edits to an existing own post.
  Future<MastodonStatus?> publishNow() async {
    final session = app.session;
    if (session == null) {
      _errorMessage = 'Not signed in to Mastodon.';
      notifyListeners();
      return null;
    }

    _isPublishing = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final mediaIds = <String>[];
      final mediaAttributes = <Map<String, String>>[];

      for (final att in _attachments) {
        if (att.isExistingRemote && att.remoteMediaId != null) {
          mediaIds.add(att.remoteMediaId!);
          mediaAttributes.add({
            'id': att.remoteMediaId!,
            'description': att.altText.trim(),
          });
        } else if (att.filePath != null) {
          final uploaded = await app.mastodon.uploadMedia(
            instanceUrl: session.instanceUrl,
            accessToken: session.accessToken,
            filePath: att.filePath!,
            description: att.altText.trim(),
          );
          mediaIds.add(uploaded.id);
          mediaAttributes.add({
            'id': uploaded.id,
            'description': att.altText.trim(),
          });
        }
      }

      final MastodonStatus saved;
      if (isEditing) {
        saved = await app.mastodon.editStatus(
          instanceUrl: session.instanceUrl,
          accessToken: session.accessToken,
          statusId: editingStatus!.displayStatus.id,
          statusText: textController.text.trim(),
          spoilerText: _showContentWarning ? spoilerController.text.trim() : '',
          language: _language.trim().isEmpty ? null : _language.trim(),
          mediaIds: mediaIds,
          mediaAttributes: mediaAttributes,
        );
        AccessibilityAnnouncer.announce('Post updated successfully.');
      } else {
        saved = await app.mastodon.createStatus(
          instanceUrl: session.instanceUrl,
          accessToken: session.accessToken,
          statusText: textController.text.trim(),
          spoilerText: _showContentWarning ? spoilerController.text.trim() : null,
          visibility: _visibility,
          inReplyToId: replyToStatus?.displayStatus.id,
          language: _language.trim().isEmpty ? null : _language.trim(),
          mediaIds: mediaIds,
        );
        AccessibilityAnnouncer.announce('Post published successfully.');
      }

      app.notifyTimelinesShouldRefresh();
      return saved;
    } catch (e) {
      _errorMessage = e.toString();
      AccessibilityAnnouncer.announce('Failed to publish post.');
      return null;
    } finally {
      _isPublishing = false;
      notifyListeners();
    }
  }

  ComposerAttachment? _findAttachment(String localId) {
    for (final a in _attachments) {
      if (a.localId == localId) return a;
    }
    return null;
  }

  void _updateAttachment(String localId, ComposerAttachment updated) {
    _attachments = _attachments
        .map((a) => a.localId == localId ? updated : a)
        .toList();
    notifyListeners();
  }

  String _guessMimeType(String path, {required bool isVideo}) {
    final lower = path.toLowerCase();
    if (isVideo) {
      if (lower.endsWith('.mov')) return 'video/quicktime';
      if (lower.endsWith('.webm')) return 'video/webm';
      return 'video/mp4';
    }
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.gif')) return 'image/gif';
    return 'image/jpeg';
  }

  @override
  void dispose() {
    textController.dispose();
    spoilerController.dispose();
    super.dispose();
  }
}
