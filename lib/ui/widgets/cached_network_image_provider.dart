// Copyright (c) 2026 brokengoose <brokengoose@users.noreply.github.com>
// SPDX-License-Identifier: MIT

import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

import '../../services/media_cache_service.dart';

/// Disk-cached [ImageProvider] backed by [MediaCacheService].
///
/// Serves avatars and media previews directly from the app's persistent disk
/// cache across restarts and deduplicates simultaneous requests for the same URL.
@immutable
class DiskCachedNetworkImage extends ImageProvider<DiskCachedNetworkImage> {
  const DiskCachedNetworkImage(
    this.url, {
    this.scale = 1.0,
    this.cacheService,
  });

  final String url;
  final double scale;
  final MediaCacheService? cacheService;

  @override
  Future<DiskCachedNetworkImage> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture<DiskCachedNetworkImage>(this);
  }

  @override
  ImageStreamCompleter loadImage(
    DiskCachedNetworkImage key,
    ImageDecoderCallback decode,
  ) {
    return MultiFrameImageStreamCompleter(
      codec: _loadAsync(key, decode),
      scale: key.scale,
      debugLabel: key.url,
      informationCollector: () => <DiagnosticsNode>[
        DiagnosticsProperty<ImageProvider>('Image provider', this),
        DiagnosticsProperty<DiskCachedNetworkImage>('Image key', key),
      ],
    );
  }

  Future<ui.Codec> _loadAsync(
    DiskCachedNetworkImage key,
    ImageDecoderCallback decode,
  ) async {
    try {
      final service = cacheService ?? MediaCacheService.instance;
      final cached = await service.getOrFetch(key.url);
      final buffer = await ui.ImmutableBuffer.fromUint8List(cached.bytes);
      return await decode(buffer);
    } catch (_) {
      // Same as Flutter's NetworkImage: drop the failed entry so the next
      // resolve retries instead of replaying the cached error until restart.
      // Deferred because the completer is still being registered right now.
      scheduleMicrotask(() {
        PaintingBinding.instance.imageCache.evict(key);
      });
      rethrow;
    }
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DiskCachedNetworkImage &&
        other.url == url &&
        other.scale == scale;
  }

  @override
  int get hashCode => Object.hash(url, scale);

  @override
  String toString() =>
      '${objectRuntimeType(this, 'DiskCachedNetworkImage')}("$url", scale: $scale)';
}
