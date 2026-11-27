// Copyright (c) 2026 brokengoose <brokengoose@users.noreply.github.com>
// SPDX-License-Identifier: MIT

import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

/// Outcome of attempting to optimize and strip metadata from an image file.
enum ImageOptimizationStatus {
  /// Re-encoded in memory with EXIF/GPS/XMP metadata removed.
  optimized,

  /// Multi-frame animated image preserved untouched to avoid dropping frames.
  preservedAnimated,

  /// File could not be decoded (e.g. unsupported format such as HEIC or
  /// corrupt bytes), so the original file is kept intact with any metadata.
  decodeFailed,

  /// Source file did not exist or had 0 bytes.
  emptyOrMissing,
}

/// Result of optimizing a local image before uploading to Mastodon or sending
/// to an AI provider.
class OptimizedImageFile {
  const OptimizedImageFile({
    required this.filePath,
    required this.mimeType,
    required this.isTempFile,
    required this.originalByteCount,
    required this.optimizedByteCount,
    this.status = ImageOptimizationStatus.optimized,
  });

  final String filePath;
  final String mimeType;
  final bool isTempFile;
  final int originalByteCount;
  final int optimizedByteCount;
  final ImageOptimizationStatus status;

  /// True when the image was re-encoded without EXIF/GPS/XMP metadata.
  bool get metadataStripped => status == ImageOptimizationStatus.optimized;

  /// True when decoding failed and the original file was kept with metadata.
  bool get decodeFailed => status == ImageOptimizationStatus.decodeFailed;
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
  const ImageUploadOptimizer({this.maxDimension = 2048, this.jpegQuality = 85});

  /// Maximum width or height in pixels (2048px is plenty for crisp Mastodon
  /// display while shrinking 12–48MP photos by 80–95%).
  final int maxDimension;

  /// JPEG quality (1–100) for opaque photos.
  final int jpegQuality;

  /// Optimizes [sourcePath] (reading, decoding, resizing, and re-encoding in a
  /// background isolate) and writes a clean, EXIF-free temp file. Animated
  /// GIFs/WebPs are preserved untouched, and undecodable files report
  /// [ImageOptimizationStatus.decodeFailed] so callers can warn the user.
  Future<OptimizedImageFile> optimizeFile(
    String sourcePath, {
    required String fallbackMimeType,
  }) async {
    final maxDim = maxDimension;
    final quality = jpegQuality;
    final tempDirPath = Directory.systemTemp.path;

    ({OptimizedImageFile result, String? failureDetail}) outcome;
    try {
      outcome = await Isolate.run(
        () => _optimizeFileSync(
          sourcePath: sourcePath,
          fallbackMimeType: fallbackMimeType,
          maxDimension: maxDim,
          jpegQuality: quality,
          tempDirPath: tempDirPath,
        ),
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('ImageUploadOptimizer isolate failure ($sourcePath): $e');
      }
      return OptimizedImageFile(
        filePath: sourcePath,
        mimeType: fallbackMimeType,
        isTempFile: false,
        originalByteCount: 0,
        optimizedByteCount: 0,
        status: ImageOptimizationStatus.decodeFailed,
      );
    }

    if (kDebugMode && outcome.failureDetail != null) {
      debugPrint(
        'ImageUploadOptimizer could not strip metadata from $sourcePath: '
        '${outcome.failureDetail}',
      );
    }
    return outcome.result;
  }

  static ({OptimizedImageFile result, String? failureDetail})
  _optimizeFileSync({
    required String sourcePath,
    required String fallbackMimeType,
    required int maxDimension,
    required int jpegQuality,
    required String tempDirPath,
  }) {
    final file = File(sourcePath);
    if (!file.existsSync()) {
      return (
        result: OptimizedImageFile(
          filePath: sourcePath,
          mimeType: fallbackMimeType,
          isTempFile: false,
          originalByteCount: 0,
          optimizedByteCount: 0,
          status: ImageOptimizationStatus.emptyOrMissing,
        ),
        failureDetail: null,
      );
    }

    Uint8List rawBytes;
    try {
      rawBytes = file.readAsBytesSync();
    } catch (e) {
      return (
        result: OptimizedImageFile(
          filePath: sourcePath,
          mimeType: fallbackMimeType,
          isTempFile: false,
          originalByteCount: 0,
          optimizedByteCount: 0,
          status: ImageOptimizationStatus.decodeFailed,
        ),
        failureDetail: e.toString(),
      );
    }

    final originalSize = rawBytes.length;
    if (originalSize == 0) {
      return (
        result: OptimizedImageFile(
          filePath: sourcePath,
          mimeType: fallbackMimeType,
          isTempFile: false,
          originalByteCount: 0,
          optimizedByteCount: 0,
          status: ImageOptimizationStatus.emptyOrMissing,
        ),
        failureDetail: null,
      );
    }

    img.Image? decoded;
    String? decodeError;
    try {
      decoded = img.decodeImage(rawBytes);
    } catch (e) {
      decodeError = e.toString();
    }
    if (decoded == null) {
      return (
        result: OptimizedImageFile(
          filePath: sourcePath,
          mimeType: fallbackMimeType,
          isTempFile: false,
          originalByteCount: originalSize,
          optimizedByteCount: originalSize,
          status: ImageOptimizationStatus.decodeFailed,
        ),
        failureDetail: decodeError ?? 'Unsupported image format',
      );
    }

    if (decoded.numFrames > 1) {
      return (
        result: OptimizedImageFile(
          filePath: sourcePath,
          mimeType: fallbackMimeType,
          isTempFile: false,
          originalByteCount: originalSize,
          optimizedByteCount: originalSize,
          status: ImageOptimizationStatus.preservedAnimated,
        ),
        failureDetail: null,
      );
    }

    final optimized = _optimizeDecoded(
      decoded,
      maxDimension: maxDimension,
      jpegQuality: jpegQuality,
    );
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final outPath = p.join(
      tempDirPath,
      'fedicaption_opt_$stamp.${optimized.extension}',
    );
    File(outPath).writeAsBytesSync(optimized.bytes, flush: true);

    return (
      result: OptimizedImageFile(
        filePath: outPath,
        mimeType: optimized.mimeType,
        isTempFile: true,
        originalByteCount: originalSize,
        optimizedByteCount: optimized.bytes.length,
      ),
      failureDetail: null,
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

    return _optimizeDecoded(
      decoded,
      maxDimension: maxDimension,
      jpegQuality: jpegQuality,
    );
  }

  static OptimizedImageBytes _optimizeDecoded(
    img.Image decoded, {
    required int maxDimension,
    required int jpegQuality,
  }) {
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
      final pngBytes = Uint8List.fromList(img.encodePng(processed));
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
