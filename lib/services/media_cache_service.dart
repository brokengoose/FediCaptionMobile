// Copyright (c) 2026 brokengoose <brokengoose@users.noreply.github.com>
// SPDX-License-Identifier: MIT

import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../core/constants.dart';

/// Cached remote media bytes and detected MIME type.
class CachedMediaBytes {
  const CachedMediaBytes({required this.bytes, required this.mimeType});

  final Uint8List bytes;
  final String mimeType;
}

/// Persistent disk-backed media cache with in-flight request deduplication
/// and bounded LRU eviction.
///
/// Reduces Mastodon media CDN / S3 egress by caching avatars, timeline preview
/// images, and full-screen images across restarts, and reusing cached bytes
/// across `AccessibleAvatar`, `MediaAttachmentCard`, `ImageViewerScreen` share,
/// and `TimelineMediaAiController`.
class MediaCacheService {
  MediaCacheService({
    http.Client? client,
    Directory? cacheDirectory,
    this.maxDiskBytes = 150 * 1024 * 1024, // 150 MB
    this.maxAge = const Duration(days: 14),
    this.maxMemoryEntries = 48,
  }) : _client = client ?? http.Client(),
       _ownsClient = client == null,
       _overrideDirectory = cacheDirectory;

  static final MediaCacheService instance = MediaCacheService();

  final http.Client _client;
  final bool _ownsClient;
  final Directory? _overrideDirectory;
  final int maxDiskBytes;
  final Duration maxAge;
  final int maxMemoryEntries;

  Directory? _resolvedDir;
  bool _diskUnavailable = false;
  final Map<String, Future<CachedMediaBytes>> _inFlight = {};
  final LinkedHashMap<String, CachedMediaBytes> _memoryCache =
      LinkedHashMap<String, CachedMediaBytes>();

  /// Returns bytes for [url] from RAM cache, persistent disk cache, or a single
  /// deduplicated HTTP GET request.
  Future<CachedMediaBytes> getOrFetch(
    String url, {
    Duration timeout = const Duration(seconds: 25),
  }) async {
    final trimmed = url.trim();
    if (trimmed.isEmpty) {
      throw StateError('Media URL is empty.');
    }

    // 1. Hot RAM LRU hit.
    final memHit = _memoryCache.remove(trimmed);
    if (memHit != null) {
      _memoryCache[trimmed] = memHit;
      return memHit;
    }

    // 2. Deduplicate concurrent requests for the exact same URL.
    final existingFlight = _inFlight[trimmed];
    if (existingFlight != null) {
      return existingFlight;
    }

    final future = _fetchAndCache(trimmed, timeout: timeout);
    _inFlight[trimmed] = future;
    try {
      return await future;
    } finally {
      // Only drops the map entry; the future itself was awaited above.
      unawaited(_inFlight.remove(trimmed));
    }
  }

  Future<CachedMediaBytes> _fetchAndCache(
    String url, {
    required Duration timeout,
  }) async {
    // 2a. Check persistent disk cache first.
    final diskHit = await _readFromDisk(url);
    if (diskHit != null) {
      _putMemory(url, diskHit);
      return diskHit;
    }

    // 2b. Download once from origin/CDN with an identifying User-Agent.
    final uri = Uri.parse(url);
    final res = await _client
        .get(
          uri,
          headers: const {
            'User-Agent':
                'FediCaption/${AppConstants.appVersion} (+${AppConstants.repositoryUrl})',
          },
        )
        .timeout(timeout);

    if (res.statusCode < 200 ||
        res.statusCode >= 300 ||
        res.bodyBytes.isEmpty) {
      throw HttpException('Failed to load media (${res.statusCode})', uri: uri);
    }

    final mimeType = _resolveMimeType(res.headers['content-type'], uri.path);
    final result = CachedMediaBytes(bytes: res.bodyBytes, mimeType: mimeType);
    _putMemory(url, result);
    await _writeToDisk(url, result);
    return result;
  }

  /// Prunes expired files and evicts oldest entries if cache exceeds [maxDiskBytes].
  /// Safe to call fire-and-forget during startup.
  Future<void> pruneIfNeeded() async {
    final dir = await _getCacheDirectory();
    if (dir == null || !await dir.exists()) return;

    try {
      final now = DateTime.now();
      final entries = <({File file, DateTime modified, int size})>[];
      var totalBytes = 0;

      await for (final entity in dir.list(followLinks: false)) {
        if (entity is! File) continue;
        final stat = await entity.stat();
        if (now.difference(stat.modified) > maxAge) {
          await _deleteQuietly(entity);
          continue;
        }
        totalBytes += stat.size;
        entries.add((file: entity, modified: stat.modified, size: stat.size));
      }

      if (totalBytes <= maxDiskBytes) return;

      // Evict oldest files first until back under 85% of budget.
      entries.sort((a, b) => a.modified.compareTo(b.modified));
      final targetBytes = (maxDiskBytes * 0.85).round();
      for (final entry in entries) {
        if (totalBytes <= targetBytes) break;
        await _deleteQuietly(entry.file);
        totalBytes -= entry.size;
      }
    } catch (_) {
      // Best-effort pruning.
    }
  }

  void clearMemory() {
    _memoryCache.clear();
  }

  void dispose() {
    if (_ownsClient) {
      _client.close();
    }
  }

  void _putMemory(String url, CachedMediaBytes entry) {
    // Only keep reasonably sized images in the hot RAM mirror (< 2 MB).
    if (entry.bytes.length > 2 * 1024 * 1024) return;
    _memoryCache.remove(url);
    _memoryCache[url] = entry;
    while (_memoryCache.length > maxMemoryEntries) {
      _memoryCache.remove(_memoryCache.keys.first);
    }
  }

  Future<Directory?> _getCacheDirectory() async {
    if (_overrideDirectory != null) {
      if (!await _overrideDirectory.exists()) {
        await _overrideDirectory.create(recursive: true);
      }
      return _overrideDirectory;
    }
    if (kIsWeb ||
        _diskUnavailable ||
        Platform.environment.containsKey('FLUTTER_TEST')) {
      return null;
    }
    if (_resolvedDir != null) return _resolvedDir;

    try {
      final tmp = await getTemporaryDirectory();
      final dir = Directory(p.join(tmp.path, 'fedicaption_media_cache'));
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      _resolvedDir = dir;
      return dir;
    } catch (_) {
      // E.g. MissingPluginException in headless unit/widget tests.
      _diskUnavailable = true;
      return null;
    }
  }

  Future<CachedMediaBytes?> _readFromDisk(String url) async {
    final dir = await _getCacheDirectory();
    if (dir == null) return null;
    final key = _cacheKey(url);
    final dataFile = File(p.join(dir.path, '$key.bin'));
    if (!await dataFile.exists()) return null;

    try {
      final stat = await dataFile.stat();
      if (DateTime.now().difference(stat.modified) > maxAge) {
        await _deleteQuietly(dataFile);
        return null;
      }
      final bytes = await dataFile.readAsBytes();
      if (bytes.isEmpty) return null;

      String mimeType = _guessMimeFromPath(Uri.tryParse(url)?.path ?? '');
      final metaFile = File(p.join(dir.path, '$key.mime'));
      if (await metaFile.exists()) {
        final stored = (await metaFile.readAsString()).trim();
        if (stored.isNotEmpty) mimeType = stored;
      }
      return CachedMediaBytes(bytes: bytes, mimeType: mimeType);
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeToDisk(String url, CachedMediaBytes entry) async {
    final dir = await _getCacheDirectory();
    if (dir == null) return;
    // Skip persisting gigantic single blobs (> 15 MB) to disk cache.
    if (entry.bytes.length > 15 * 1024 * 1024) return;
    final key = _cacheKey(url);
    final dataFile = File(p.join(dir.path, '$key.bin'));
    final metaFile = File(p.join(dir.path, '$key.mime'));
    try {
      await dataFile.writeAsBytes(entry.bytes);
      await metaFile.writeAsString(entry.mimeType);
    } catch (_) {
      // Best-effort disk write.
    }
  }

  Future<void> _deleteQuietly(File file) async {
    try {
      if (await file.exists()) await file.delete();
    } catch (_) {
      // Ignore deletion errors.
    }
  }

  /// Collision-resistant deterministic 128-bit hex key derived from [url]
  /// (two independent 64-bit FNV-1a passes over UTF-8 bytes).
  static String _cacheKey(String url) {
    final bytes = utf8.encode(url);
    var h1 = 0xcbf29ce484222325;
    var h2 = 0x84222325cbf29ce4;
    const prime1 = 0x100000001b3;
    const prime2 = 0x100000001b5;
    for (final b in bytes) {
      h1 ^= b;
      h1 = (h1 * prime1) & 0xFFFFFFFFFFFFFFFF;
      h2 ^= (b ^ 0x5A);
      h2 = (h2 * prime2) & 0xFFFFFFFFFFFFFFFF;
    }
    return '${h1.toUnsigned(64).toRadixString(16).padLeft(16, '0')}'
        '${h2.toUnsigned(64).toRadixString(16).padLeft(16, '0')}';
  }

  static String _resolveMimeType(String? contentTypeHeader, String path) {
    final header = (contentTypeHeader ?? '').split(';').first.trim();
    if (header.isNotEmpty && header != 'application/octet-stream') {
      return header;
    }
    return _guessMimeFromPath(path);
  }

  static String _guessMimeFromPath(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.gif')) return 'image/gif';
    return 'image/jpeg';
  }
}
