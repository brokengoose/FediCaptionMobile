// Copyright (c) 2026 brokengoose <brokengoose@users.noreply.github.com>
// SPDX-License-Identifier: MIT

import 'dart:typed_data';

import 'ai_models.dart';

/// Processing state for a media attachment in the composer.
enum AttachmentStatus {
  scanning('AI Scanning...'),
  ready('Alt-Text Ready'),
  missingAltText('Missing Alt-Text'),
  error('Error');

  const AttachmentStatus(this.label);

  final String label;
}

/// Represents a local or existing remote media attachment inside the post composer.
class ComposerAttachment {
  const ComposerAttachment({
    required this.localId,
    required this.isVideo,
    required this.mimeType,
    this.filePath,
    this.fileName,
    this.remoteMediaId,
    this.remoteUrl,
    this.previewUrl,
    this.previewBytes,
    this.extractedFrames = const [],
    this.altText = '',
    this.detailLevel = CaptionDetailLevel.descriptive,
    this.status = AttachmentStatus.missingAltText,
    this.errorMessage,
  });

  /// Unique client-side identifier for list stability.
  final String localId;
  final bool isVideo;
  final String mimeType;

  /// Local file path for newly attached media (null for existing edited media).
  final String? filePath;
  final String? fileName;

  /// Mastodon media ID when editing an existing post or after upload.
  final String? remoteMediaId;
  final String? remoteUrl;
  final String? previewUrl;

  /// Optional in-memory thumbnail/image bytes for instant preview and AI/bias analysis.
  final Uint8List? previewBytes;

  /// Cached extracted video keyframes (or resized image payload) for AI + bias checks.
  final List<MediaBinaryPayload> extractedFrames;

  final String altText;
  final CaptionDetailLevel detailLevel;
  final AttachmentStatus status;
  final String? errorMessage;

  bool get isExistingRemote => remoteMediaId != null && filePath == null;
  bool get hasAltText => altText.trim().isNotEmpty;

  ComposerAttachment copyWith({
    String? localId,
    bool? isVideo,
    String? mimeType,
    String? filePath,
    String? fileName,
    String? remoteMediaId,
    String? remoteUrl,
    String? previewUrl,
    Uint8List? previewBytes,
    List<MediaBinaryPayload>? extractedFrames,
    String? altText,
    CaptionDetailLevel? detailLevel,
    AttachmentStatus? status,
    String? errorMessage,
    bool clearError = false,
  }) {
    return ComposerAttachment(
      localId: localId ?? this.localId,
      isVideo: isVideo ?? this.isVideo,
      mimeType: mimeType ?? this.mimeType,
      filePath: filePath ?? this.filePath,
      fileName: fileName ?? this.fileName,
      remoteMediaId: remoteMediaId ?? this.remoteMediaId,
      remoteUrl: remoteUrl ?? this.remoteUrl,
      previewUrl: previewUrl ?? this.previewUrl,
      previewBytes: previewBytes ?? this.previewBytes,
      extractedFrames: extractedFrames ?? this.extractedFrames,
      altText: altText ?? this.altText,
      detailLevel: detailLevel ?? this.detailLevel,
      status: status ?? this.status,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}
