// Copyright (c) 2026 brokengoose <brokengoose@users.noreply.github.com>
// SPDX-License-Identifier: MIT

import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;

import '../core/accessibility_announcer.dart';
import '../core/constants.dart';
import '../core/media_utils.dart';
import '../l10n/l10n.dart';
import '../models/ai_models.dart';
import '../models/bias_models.dart';
import '../models/composer_attachment.dart';
import '../models/mastodon_models.dart';
import '../services/image_upload_optimizer.dart';
import '../services/mastodon_service.dart';
import '../services/video_frame_extractor.dart';
import 'app_controller.dart';

/// State controller for the post composer (create, reply, and edit own post).
class ComposerController extends ChangeNotifier {
  ComposerController({
    required this.app,
    this.replyToStatus,
    this.editingStatus,
    VideoFrameExtractor? videoFrameExtractor,
    ImageUploadOptimizer? imageOptimizer,
  }) : _videoFrameExtractor =
           videoFrameExtractor ?? const VideoFrameExtractor(),
       _imageOptimizer = imageOptimizer ?? const ImageUploadOptimizer() {
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

    _captureInitialSnapshot();
    textController.addListener(_safeNotify);
    spoilerController.addListener(_safeNotify);
  }

  late String _initialText;
  late String _initialSpoiler;
  late PostVisibility _initialVisibility;
  late String _initialAttachmentSignature;

  void _captureInitialSnapshot() {
    _initialText = textController.text;
    _initialSpoiler = spoilerController.text;
    _initialVisibility = _visibility;
    _initialAttachmentSignature = _attachmentSignature();
  }

  String _attachmentSignature() => _attachments
      .map((a) => '${a.remoteMediaId ?? a.localId}:${a.altText}')
      .join('|');

  final AppController app;
  final MastodonStatus? replyToStatus;
  final MastodonStatus? editingStatus;
  final VideoFrameExtractor _videoFrameExtractor;
  final ImageUploadOptimizer _imageOptimizer;
  final Set<String> _tempOptimizedFiles = {};

  final TextEditingController textController = TextEditingController();
  final TextEditingController spoilerController = TextEditingController();

  bool _disposed = false;
  bool _showContentWarning = false;
  PostVisibility _visibility = PostVisibility.public;
  String _language = '';
  List<ComposerAttachment> _attachments = [];

  /// Media already uploaded during an earlier (failed) publish attempt,
  /// keyed by attachment `localId`.
  final Map<
    String,
    ({String id, String accessToken, String filePath, String description})
  >
  _uploadedMedia = {};

  bool _isLoadingSource = false;
  bool _isCheckingBias = false;
  bool _isPublishing = false;
  String? _errorMessage;

  int _localIdCounter = 0;

  void _safeNotify() {
    if (!_disposed) {
      notifyListeners();
    }
  }

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

  /// Includes BOTH post body and Content Warning in the remaining-character counter.
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

  /// True when the user has entered or modified content beyond the initial
  /// composer state (used to guard against accidental draft loss on Back/Esc).
  bool get hasUnsavedChanges {
    if (isEditing) {
      return textController.text != _initialText ||
          spoilerController.text != _initialSpoiler ||
          _visibility != _initialVisibility ||
          _attachmentSignature() != _initialAttachmentSignature;
    }
    if (isReply) {
      return textController.text.trim() != _initialText.trim() ||
          spoilerController.text.trim() != _initialSpoiler.trim() ||
          _attachments.isNotEmpty;
    }
    return textController.text.trim().isNotEmpty ||
        spoilerController.text.trim().isNotEmpty ||
        _attachments.isNotEmpty;
  }

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
    _safeNotify();

    try {
      final source = await app.mastodon.fetchStatusSource(
        instanceUrl: session.instanceUrl,
        accessToken: session.accessToken,
        statusId: target.id,
      );
      if (_disposed) return;
      textController.text = source.text;
      if (source.spoilerText.trim().isNotEmpty) {
        spoilerController.text = source.spoilerText;
        _showContentWarning = true;
      }
      _captureInitialSnapshot();
    } catch (e) {
      _errorMessage = app.l10n.composerErrorFallbackEditSource(e.toString());
    } finally {
      _isLoadingSource = false;
      _safeNotify();
    }
  }

  void toggleContentWarning(bool enabled) {
    _showContentWarning = enabled;
    if (!enabled) {
      spoilerController.clear();
    }
    _safeNotify();
  }

  void setVisibility(PostVisibility value) {
    _visibility = value;
    _safeNotify();
  }

  void replacePostText(String newText) {
    textController.text = newText;
    textController.selection = TextSelection.collapsed(offset: newText.length);
    _safeNotify();
  }

  /// Attaches a local image or video file, strips EXIF & resizes images
  /// client-side before upload/AI analysis, and auto-scans with AI if enabled.
  Future<void> addLocalMedia({
    required String filePath,
    required bool isVideo,
  }) async {
    if (!canAddMoreMedia) {
      _errorMessage = app.l10n.composerErrorMaxMedia(
        limits.maxMediaAttachments,
      );
      _safeNotify();
      return;
    }

    _errorMessage = null;
    final localId = 'local_${++_localIdCounter}';
    final fileName = p.basename(filePath);
    var effectivePath = filePath;
    var mimeType = MediaUtils.guessMimeType(filePath, isVideo: isVideo);
    var metadataNotStripped = false;

    if (!isVideo) {
      final optimized = await _imageOptimizer.optimizeFile(
        filePath,
        fallbackMimeType: mimeType,
      );
      if (_disposed) {
        if (optimized.isTempFile) {
          _deleteTempFileQuietly(optimized.filePath);
        }
        return;
      }
      effectivePath = optimized.filePath;
      mimeType = optimized.mimeType;
      metadataNotStripped = optimized.decodeFailed;
      if (optimized.isTempFile) {
        _tempOptimizedFiles.add(effectivePath);
      }
    }

    final shouldAutoScan =
        app.settings.isAiEnabled && app.settings.autoGenerate;
    final initial = ComposerAttachment(
      localId: localId,
      isVideo: isVideo,
      mimeType: mimeType,
      filePath: effectivePath,
      fileName: fileName,
      detailLevel: app.settings.defaultDetailLevel,
      status: shouldAutoScan
          ? AttachmentStatus.scanning
          : AttachmentStatus.missingAltText,
      metadataNotStripped: metadataNotStripped,
    );

    _attachments = [..._attachments, initial];
    _safeNotify();

    if (shouldAutoScan) {
      await scanAttachmentWithAi(localId);
    }
  }

  void removeAttachment(String localId) {
    final removed = _findAttachment(localId);
    _attachments = _attachments.where((a) => a.localId != localId).toList();
    if (removed?.filePath != null &&
        _tempOptimizedFiles.remove(removed!.filePath)) {
      _deleteTempFileQuietly(removed.filePath!);
    }
    _safeNotify();
  }

  void updateAttachmentAltText(String localId, String altText) {
    _attachments = _attachments.map((a) {
      if (a.localId != localId) return a;
      final nextStatus = altText.trim().isNotEmpty
          ? AttachmentStatus.ready
          : AttachmentStatus.missingAltText;
      return a.copyWith(altText: altText, status: nextStatus, clearError: true);
    }).toList();
    _safeNotify();
  }

  void updateAttachmentDetailLevel(
    String localId,
    CaptionDetailLevel detailLevel,
  ) {
    _attachments = _attachments.map((a) {
      if (a.localId != localId) return a;
      return a.copyWith(detailLevel: detailLevel);
    }).toList();
    _safeNotify();
  }

  /// Runs AI alt-text generation for a single attachment (local or remote edited media).
  Future<void> scanAttachmentWithAi(String localId) async {
    final index = _attachments.indexWhere((a) => a.localId == localId);
    if (index < 0) return;

    final attachment = _attachments[index];
    _updateAttachment(
      localId,
      attachment.copyWith(status: AttachmentStatus.scanning, clearError: true),
    );

    final loc = app.l10n;
    AccessibilityAnnouncer.announce(
      attachment.isVideo
          ? loc.composerAnnounceScanningVideo(index + 1)
          : loc.composerAnnounceScanningImage(index + 1),
    );

    try {
      List<MediaBinaryPayload> preExtracted = const [];

      if (attachment.isExistingRemote) {
        // Prefer pre-sized preview_url over full-res url to save server egress.
        final targetUrl = attachment.previewUrl?.isNotEmpty == true
            ? attachment.previewUrl!
            : (attachment.remoteUrl ?? '');
        final downloaded = await app.mastodon.downloadMediaBytes(targetUrl);
        preExtracted = [
          MediaBinaryPayload(
            bytes: downloaded.bytes,
            mimeType: downloaded.mimeType,
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
          extractedFrames: preExtracted.isNotEmpty
              ? preExtracted
              : latest.extractedFrames,
          previewBytes: preExtracted.isNotEmpty
              ? preExtracted.first.bytes
              : latest.previewBytes,
          clearError: true,
        ),
      );

      AccessibilityAnnouncer.announce(
        loc.composerAnnounceAltReady(_positionOf(localId, index)),
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
        loc.composerAnnounceAltError(_positionOf(localId, index)),
      );
    }
  }

  /// 1-based position of [localId] for announcements, re-resolved after async
  /// work so removing an earlier attachment doesn't misnumber the result.
  int _positionOf(String localId, int fallbackIndex) {
    final i = _attachments.indexWhere((a) => a.localId == localId);
    return (i >= 0 ? i : fallbackIndex) + 1;
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
    _safeNotify();

    final loc = app.l10n;
    AccessibilityAnnouncer.announce(loc.composerAnnounceCheckingBias);

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

      final referencedStatuses = <ReferencedStatusContext>[
        if (replyToStatus != null)
          ReferencedStatusContext.fromStatus(replyToStatus!),
      ];

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
        contentLanguageCode: _language.trim().isNotEmpty
            ? _language.trim()
            : null,
        responseLanguageCode: app.effectiveLocale.languageCode,
        labels: biasComponentLabelsFrom(loc),
      );

      if (result.hasBias) {
        AccessibilityAnnouncer.announce(
          loc.composerAnnounceBiasReview(result.summary),
        );
      }
      return result;
    } finally {
      _isCheckingBias = false;
      _safeNotify();
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
          return [MediaBinaryPayload(bytes: bytes, mimeType: att.mimeType)];
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
    final loc = app.l10n;
    if (session == null) {
      _errorMessage = loc.composerErrorNotSignedIn;
      _safeNotify();
      return null;
    }

    _isPublishing = true;
    _errorMessage = null;
    _safeNotify();

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
          final description = att.altText.trim();
          // Reuse an upload from a previous failed publish attempt so a retry
          // doesn't re-send the file and orphan the first upload. Alt-text
          // edits since then invalidate it (upload description would be stale).
          final prior = _uploadedMedia[att.localId];
          final String mediaId;
          if (prior != null &&
              prior.accessToken == session.accessToken &&
              prior.filePath == att.filePath &&
              prior.description == description) {
            mediaId = prior.id;
          } else {
            void remember(String id) => _uploadedMedia[att.localId] = (
              id: id,
              accessToken: session.accessToken,
              filePath: att.filePath!,
              description: description,
            );
            try {
              final uploaded = await app.mastodon.uploadMedia(
                instanceUrl: session.instanceUrl,
                accessToken: session.accessToken,
                filePath: att.filePath!,
                description: description,
              );
              mediaId = uploaded.id;
              remember(mediaId);
            } on MediaStillProcessingException catch (e) {
              // Uploaded but still processing: keep the id so retrying later
              // publishes it instead of uploading the file again.
              remember(e.mediaId);
              rethrow;
            }
          }
          mediaIds.add(mediaId);
          mediaAttributes.add({'id': mediaId, 'description': description});
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
        AccessibilityAnnouncer.announce(loc.composerAnnounceUpdated);
      } else {
        saved = await app.mastodon.createStatus(
          instanceUrl: session.instanceUrl,
          accessToken: session.accessToken,
          statusText: textController.text.trim(),
          spoilerText: _showContentWarning
              ? spoilerController.text.trim()
              : null,
          visibility: _visibility,
          inReplyToId: replyToStatus?.displayStatus.id,
          language: _language.trim().isEmpty ? null : _language.trim(),
          mediaIds: mediaIds,
        );
        AccessibilityAnnouncer.announce(loc.composerAnnouncePublished);
      }

      if (isEditing) {
        app.applyEditedStatus(saved.displayStatus);
      } else {
        app.notifyTimelinesShouldRefresh();
      }
      return saved;
    } catch (e) {
      _errorMessage = e.toString();
      AccessibilityAnnouncer.announce(loc.composerAnnouncePublishFailed);
      return null;
    } finally {
      _isPublishing = false;
      _safeNotify();
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
    _safeNotify();
  }

  void _deleteTempFileQuietly(String path) {
    try {
      final f = File(path);
      if (f.existsSync()) {
        f.deleteSync();
      }
    } catch (_) {
      // Best-effort cleanup.
    }
  }

  @override
  void dispose() {
    _disposed = true;
    for (final path in _tempOptimizedFiles) {
      _deleteTempFileQuietly(path);
    }
    _tempOptimizedFiles.clear();
    textController.dispose();
    spoilerController.dispose();
    super.dispose();
  }
}
