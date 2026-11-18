// Copyright (c) 2026 brokengoose <brokengoose@users.noreply.github.com>
// SPDX-License-Identifier: MIT

import 'dart:io';
import 'dart:typed_data';

import 'package:video_player/video_player.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

import '../models/ai_models.dart';

/// Extracts evenly spaced keyframes from a local video file for vision models.
class VideoFrameExtractor {
  const VideoFrameExtractor();

  /// Computes evenly spaced timestamps in milliseconds across [durationMs].
  /// For example, with 4 frames across a 10,000ms video, returns ~[1000, 3666, 6333, 9000].
  static List<int> computeSampleTimestampsMs(int durationMs, int frameCount) {
    final safeCount = frameCount < 1 ? 1 : frameCount;
    if (durationMs <= 0) {
      return List<int>.generate(safeCount, (i) => i * 1500);
    }
    if (safeCount == 1) {
      return [(durationMs * 0.5).round()];
    }
    // Sample from 10% to 90% of duration to avoid black lead-in/lead-out frames.
    final start = (durationMs * 0.1).round();
    final end = (durationMs * 0.9).round();
    final span = (end - start).clamp(0, durationMs);
    return List<int>.generate(safeCount, (i) {
      final ratio = i / (safeCount - 1);
      return start + (span * ratio).round();
    });
  }

  /// Extracts [frameCount] (3, 4, or 6) evenly spaced JPEG keyframes from [videoPath].
  Future<List<MediaBinaryPayload>> extractKeyframes(
    String videoPath, {
    int frameCount = 4,
    int maxWidth = 1024,
    int quality = 75,
  }) async {
    int durationMs = 0;
    VideoPlayerController? controller;
    try {
      controller = VideoPlayerController.file(File(videoPath));
      await controller.initialize();
      durationMs = controller.value.duration.inMilliseconds;
    } catch (_) {
      durationMs = 0;
    } finally {
      await controller?.dispose();
    }

    final timestamps = computeSampleTimestampsMs(durationMs, frameCount);
    final frames = <MediaBinaryPayload>[];

    for (final timeMs in timestamps) {
      try {
        final Uint8List? bytes = await VideoThumbnail.thumbnailData(
          video: videoPath,
          imageFormat: ImageFormat.JPEG,
          timeMs: timeMs,
          maxWidth: maxWidth,
          quality: quality,
        );
        if (bytes != null && bytes.isNotEmpty) {
          frames.add(
            MediaBinaryPayload(
              bytes: bytes,
              mimeType: 'image/jpeg',
              isVideo: false,
            ),
          );
        }
      } catch (_) {
        // Continue attempting remaining frames.
      }
    }

    // Fallback to frame 0 if duration-based seeking failed on a codec.
    if (frames.isEmpty) {
      final fallbackBytes = await VideoThumbnail.thumbnailData(
        video: videoPath,
        imageFormat: ImageFormat.JPEG,
        timeMs: 0,
        maxWidth: maxWidth,
        quality: quality,
      );
      if (fallbackBytes != null && fallbackBytes.isNotEmpty) {
        frames.add(
          MediaBinaryPayload(
            bytes: fallbackBytes,
            mimeType: 'image/jpeg',
            isVideo: false,
          ),
        );
      }
    }

    return frames;
  }
}
