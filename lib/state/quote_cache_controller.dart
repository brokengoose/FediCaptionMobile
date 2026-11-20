// Copyright (c) 2026 brokengoose <brokengoose@users.noreply.github.com>
// SPDX-License-Identifier: MIT

import 'dart:collection';

import 'package:flutter/foundation.dart';

import '../models/app_settings.dart';
import '../models/mastodon_models.dart';
import '../services/mastodon_service.dart';

/// Scoped [ChangeNotifier] that resolves and caches quoted Mastodon post URLs
/// with bounded LRU eviction so scrolling timelines do not trigger full-app rebuilds
/// or grow memory unboundedly.
class QuoteCacheController extends ChangeNotifier {
  QuoteCacheController({
    required MastodonService mastodon,
    this.maxEntries = 200,
  }) : _mastodon = mastodon;

  final MastodonService _mastodon;
  final int maxEntries;

  // LinkedHashMap maintains insertion order for lightweight LRU eviction.
  final LinkedHashMap<String, MastodonStatus?> _cache =
      LinkedHashMap<String, MastodonStatus?>();
  final Set<String> _inFlightUrls = {};
  bool _disposed = false;

  MastodonStatus? cachedStatus(String url) {
    final trimmed = url.trim();
    if (!_cache.containsKey(trimmed)) return null;
    // Touch entry to refresh recency for LRU ordering.
    final value = _cache.remove(trimmed);
    _cache[trimmed] = value;
    return value;
  }

  bool hasResolved(String url) => _cache.containsKey(url.trim());
  bool isResolving(String url) => _inFlightUrls.contains(url.trim());

  /// Resolves [url] via `/api/v2/search?resolve=true` and caches the result.
  /// Set [forceRetry] to bypass a previously cached `null` failure.
  Future<MastodonStatus?> resolve(
    String url, {
    required MastodonSession? session,
    bool forceRetry = false,
  }) async {
    final trimmed = url.trim();
    if (trimmed.isEmpty || session == null) return null;

    if (!forceRetry && _cache.containsKey(trimmed)) {
      return cachedStatus(trimmed);
    }
    if (_inFlightUrls.contains(trimmed)) {
      return null;
    }

    if (forceRetry) {
      _cache.remove(trimmed);
    }

    _inFlightUrls.add(trimmed);
    _safeNotify();

    try {
      final resolved = await _mastodon.resolveStatusByUrl(
        instanceUrl: session.instanceUrl,
        accessToken: session.accessToken,
        statusUrl: trimmed,
      );
      _putEntry(trimmed, resolved?.displayStatus);
      return _cache[trimmed];
    } catch (_) {
      _putEntry(trimmed, null);
      return null;
    } finally {
      _inFlightUrls.remove(trimmed);
      _safeNotify();
    }
  }

  void _putEntry(String url, MastodonStatus? status) {
    _cache.remove(url);
    _cache[url] = status;
    while (_cache.length > maxEntries) {
      _cache.remove(_cache.keys.first);
    }
  }

  void clear() {
    _cache.clear();
    _inFlightUrls.clear();
    _safeNotify();
  }

  void _safeNotify() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
