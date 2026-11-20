// Copyright (c) 2026 brokengoose <brokengoose@users.noreply.github.com>
// SPDX-License-Identifier: MIT

/// Shared media file type and MIME-type detection helpers.
class MediaUtils {
  MediaUtils._();

  static const List<String> supportedVideoExtensions = [
    '.mp4',
    '.mov',
    '.webm',
  ];

  /// Returns `true` when [path] ends with a supported video file extension.
  static bool isVideoFilePath(String path) {
    final lower = path.toLowerCase();
    return supportedVideoExtensions.any(lower.endsWith);
  }

  /// Infers an image or video MIME type from a file [path] extension.
  static String guessMimeType(String path, {required bool isVideo}) {
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
}
