// Copyright (c) 2026 brokengoose <brokengoose@users.noreply.github.com>
// SPDX-License-Identifier: MIT

import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

/// Result of optimizing a local image before uploading to Mastodon or sending
/// to an AI provider.
class OptimizedImageFile {
  const OptimizedImageFile({
    required this.filePath,
    required this.mimeType,
    required this.isTempFile,
    required this.originalByteCount,
    required this.optimizedByteCount,
  });

  final String filePath;
  final String mimeType;
  final bool isTempFile;
  final int originalByteCount;
  final int optimizedByteCount;
}

/// Pure in-memory encoded output produced by [ImageUploadOptimizer.optimizeBytes].
class OptimizedImageBytes {
  const OptimizedImageBytes({
    required this.bytes,
    required this.mimeType,
    required this.extension,
    required this.width,
    required this.height,
  });

  final Uint8List bytes;
  final String mimeType;
  final String extension;
  final int width;
  final int height;
}

/// Client-side image preprocessor that strips all EXIF/GPS/XMP metadata,
/// bakes orientation into pixel coordinates, resizes oversized images to a
/// Mastodon-friendly maximum edge, and re-encodes cleanly before upload.
///
/// Reduces Mastodon upload bandwidth, Sidekiq ImageMagick/libvips CPU load,
/// server storage, and Cloud AI payload sizes while protecting user privacy.
class ImageUploadOptimizer {
  const ImageUploadOptimizer({
    this.maxDimension = 2048,
    this.jpegQuality = 85,
  });

  /// Maximum width or height in pixels (2048px is plenty for crisp Mastodon
  /// display while shrinking 12–48MP photos by 80–95%).
  final int maxDimension;

  /// JPEG quality (1–100) for opaque photos.
  final int jpegQuality;

  /// Optimizes [sourcePath] in a background isolate and writes a clean,
  /// EXIF-free temp file. Animated GIFs and undecodable files fall back
  /// gracefully to the original [sourcePath].
  Future<OptimizedImageFile> optimizeFile(
    String sourcePath, {
    required String fallbackMimeType,
  }) async {
    final file = File(sourcePath);
    if (!await file.exists()) {
      return OptimizedImageFile(
        filePath: sourcePath,
        mimeType: fallbackMimeType,
        isTempFile: false,
        originalByteCount: 0,
        optimizedByteCount: 0,
      );
    }

    final rawBytes = await file.readAsBytes();
    final originalSize = rawBytes.length;
    if (originalSize == 0) {
      return OptimizedImageFile(
        filePath: sourcePath,
        mimeType: fallbackMimeType,
        isTempFile: false,
        originalByteCount: 0,
        optimizedByteCount: 0,
      );
    }

    final maxDim = maxDimension;
    final quality = jpegQuality;

    OptimizedImageBytes? optimized;
    try {
      optimized = await Isolate.run(
        () => optimizeBytes(
          rawBytes,
          maxDimension: maxDim,
          jpegQuality: quality,
        ),
      );
    } catch (_) {
      optimized = null;
    }

    if (optimized == null) {
      return OptimizedImageFile(
        filePath: sourcePath,
        mimeType: fallbackMimeType,
        isTempFile: false,
        originalByteCount: originalSize,
        optimizedByteCount: originalSize,
      );
    }

    final stamp = DateTime.now().microsecondsSinceEpoch;
    final outPath = p.join(
      Directory.systemTemp.path,
      'fedicaption_opt_$stamp.${optimized.extension}',
    );
    await File(outPath).writeAsBytes(optimized.bytes, flush: true);

    return OptimizedImageFile(
      filePath: outPath,
      mimeType: optimized.mimeType,
      isTempFile: true,
      originalByteCount: originalSize,
      optimizedByteCount: optimized.bytes.length,
    );
  }

  /// Synchronously strips EXIF metadata, bakes EXIF orientation, downscales
  /// images exceeding [maxDimension], and encodes a clean JPEG (or PNG when
  /// non-opaque transparency is present).
  ///
  /// Returns `null` for animated images (such as animated GIFs/WebPs) or
  /// formats that cannot be decoded, signalling the caller to keep the original.
  static OptimizedImageBytes? optimizeBytes(
    Uint8List rawBytes, {
    int maxDimension = 2048,
    int jpegQuality = 85,
  }) {
    final decoded = img.decodeImage(rawBytes);
    if (decoded == null) return null;

    // Preserve animated GIF/WebP/APNG files untouched so animation isn't lost.
    if (decoded.numFrames > 1) return null;

    // Bake EXIF orientation into pixels before stripping metadata.
    var processed = img.bakeOrientation(decoded);

    if (processed.width > maxDimension || processed.height > maxDimension) {
      if (processed.width >= processed.height) {
        processed = img.copyResize(
          processed,
          width: maxDimension,
          interpolation: img.Interpolation.average,
        );
      } else {
        processed = img.copyResize(
          processed,
          height: maxDimension,
          interpolation: img.Interpolation.average,
        );
      }
    }

    // Explicitly clear any EXIF/metadata attached to the decoded image object.
    processed.exif.clear();

    final hasAlpha = _hasNonOpaqueAlpha(processed);
    if (hasAlpha) {
      final pngBytes = Uint8List.fromList(img.encodePng(processed, level: 6));
      return OptimizedImageBytes(
        bytes: pngBytes,
        mimeType: 'image/png',
        extension: 'png',
        width: processed.width,
        height: processed.height,
      );
    }

    final jpgBytes = Uint8List.fromList(
      img.encodeJpg(processed, quality: jpegQuality),
    );
    return OptimizedImageBytes(
      bytes: jpgBytes,
      mimeType: 'image/jpeg',
      extension: 'jpg',
      width: processed.width,
      height: processed.height,
    );
  }

  static bool _hasNonOpaqueAlpha(img.Image image) {
    if (!image.hasAlpha) return false;
    final maxAlpha = image.maxChannelValue;
    for (final pixel in image) {
      if (pixel.a < maxAlpha) {
        return true;
      }
    }
    return false;
  }
}
