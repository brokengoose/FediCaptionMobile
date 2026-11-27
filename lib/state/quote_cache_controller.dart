// Copyright (c) 2026 brokengoose <brokengoose@users.noreply.github.com>
// SPDX-License-Identifier: MIT

import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';

import '../models/app_settings.dart';
import '../models/mastodon_models.dart';
import '../services/mastodon_service.dart';

/// Scoped [ChangeNotifier] that resolves and caches quoted Mastodon post URLs
/// with:
/// - Automatic seeding from timelines, threads, profiles, and notifications
///   (zero server calls when a quoted post is already in memory)
/// - Concurrency throttling (max [maxConcurrentResolutions] simultaneous
///   `/api/v2/search?resolve=true` calls so fast scrolling never bursts)
/// - Bounded LRU eviction so memory stays bounded
class QuoteCacheController extends ChangeNotifier {
  QuoteCacheController({
    required this._mastodon,
    this.maxEntries = 300,
    this.maxConcurrentResolutions = 2,
  });

  final MastodonService _mastodon;
  final int maxEntries;
  final int maxConcurrentResolutions;

  // LinkedHashMap maintains insertion order for lightweight LRU eviction.
  final LinkedHashMap<String, MastodonStatus?> _cache =
      LinkedHashMap<String, MastodonStatus?>();
  final Map<String, Future<MastodonStatus?>> _inFlightFutures = {};
  final Queue<Completer<void>> _slotWaiters = Queue<Completer<void>>();
  int _activeResolutions = 0;
  bool _disposed = false;

  /// Bumped by [clear] (account switch); resolutions started under an older
  /// epoch drop their results, since they used the previous account's
  /// session and instance-local status IDs.
  int _epoch = 0;

  MastodonStatus? cachedStatus(String url) {
    final key = _normalizeKey(url);
    if (!_cache.containsKey(key)) return null;
    // Touch entry to refresh recency for LRU ordering.
    final value = _cache.remove(key);
    _cache[key] = value;
    return value;
  }

  bool hasResolved(String url) => _cache.containsKey(_normalizeKey(url));
  bool isResolving(String url) =>
      _inFlightFutures.containsKey(_normalizeKey(url));

  /// Pre-populates the quote cache with statuses already fetched from timelines,
  /// threads, notifications, or profiles so subsequent `RE: <url>` resolutions
  /// hit memory with zero Mastodon server calls.
  void seedStatuses(Iterable<MastodonStatus> statuses) {
    var added = false;
    for (final raw in statuses) {
      final target = raw.displayStatus;
      added |= _seedSingle(target);
      if (target.quotedStatus != null) {
        added |= _seedSingle(target.quotedStatus!.displayStatus);
      }
    }
    if (added) {
      _safeNotify();
    }
  }

  /// Overwrites any cached quote entry matching [updated] by status ID or
  /// canonical URL/URI so edited quoted posts show updated content immediately.
  void updateStatus(MastodonStatus updated) {
    final target = updated.displayStatus;
    var changed = false;

    for (final key in _cache.keys.toList()) {
      final cached = _cache[key];
      if (cached != null && cached.displayStatus.id == target.id) {
        _cache[key] = target;
        changed = true;
      }
    }

    for (final candidate in [target.permalinkUrl, target.uri]) {
      final key = _normalizeKey(candidate);
      if (key.isNotEmpty && _cache.containsKey(key)) {
        _cache[key] = target;
        changed = true;
      }
    }

    if (changed) {
      _safeNotify();
    }
  }

  /// Removes any cached quote entry matching [targetId] so deleted posts are
  /// not kept in the quote-resolution cache.
  void removeStatus(String targetId) {
    var removed = false;
    for (final key in _cache.keys.toList()) {
      final cached = _cache[key];
      if (cached != null &&
          (cached.id == targetId || cached.displayStatus.id == targetId)) {
        _cache.remove(key);
        removed = true;
      }
    }
    if (removed) {
      _safeNotify();
    }
  }

  bool _seedSingle(MastodonStatus status) {
    var changed = false;
    for (final candidate in [status.permalinkUrl, status.uri]) {
      final key = _normalizeKey(candidate);
      if (key.isNotEmpty && _cache[key] == null) {
        _putEntry(key, status);
        changed = true;
      }
    }
    return changed;
  }

  /// Resolves [url] (via cheap local status lookup or throttled
  /// `/api/v2/search?resolve=true`) and caches the result.
  /// Set [forceRetry] to bypass a previously cached `null` failure.
  Future<MastodonStatus?> resolve(
    String url, {
    required MastodonSession? session,
    bool forceRetry = false,
  }) async {
    final key = _normalizeKey(url);
    if (key.isEmpty || session == null) return null;

    if (!forceRetry && _cache.containsKey(key)) {
      return cachedStatus(key);
    }

    final existing = _inFlightFutures[key];
    if (existing != null) {
      return existing;
    }

    if (forceRetry) {
      _cache.remove(key);
    }

    final future = _resolveThrottled(key, url.trim(), session);
    _inFlightFutures[key] = future;
    _safeNotify();

    try {
      return await future;
    } finally {
      // Only drop our own entry: after a clear() a newer resolution for the
      // same key may already be in flight.
      if (identical(_inFlightFutures[key], future)) {
        unawaited(_inFlightFutures.remove(key));
      }
      _safeNotify();
    }
  }

  Future<MastodonStatus?> _resolveThrottled(
    String key,
    String rawUrl,
    MastodonSession session,
  ) async {
    final epoch = _epoch;
    await _acquireSlot();
    try {
      if (_disposed || epoch != _epoch) return null;
      final resolved = await _mastodon.resolveStatusByUrl(
        instanceUrl: session.instanceUrl,
        accessToken: session.accessToken,
        statusUrl: rawUrl,
      );
      if (epoch != _epoch) return null; // Account switched meanwhile.
      final target = resolved?.displayStatus;
      _putEntry(key, target);
      if (target != null) {
        _seedSingle(target);
      }
      return target;
    } catch (_) {
      if (epoch == _epoch) _putEntry(key, null);
      return null;
    } finally {
      _releaseSlot();
    }
  }

  Future<void> _acquireSlot() async {
    if (_activeResolutions < maxConcurrentResolutions) {
      _activeResolutions++;
      return;
    }
    final waiter = Completer<void>();
    _slotWaiters.addLast(waiter);
    await waiter.future;
  }

  void _releaseSlot() {
    if (_slotWaiters.isNotEmpty) {
      final next = _slotWaiters.removeFirst();
      if (!next.isCompleted) {
        next.complete();
      }
      return;
    }
    if (_activeResolutions > 0) {
      _activeResolutions--;
    }
  }

  static String _normalizeKey(String url) {
    var trimmed = url.trim();
    while (trimmed.endsWith('/')) {
      trimmed = trimmed.substring(0, trimmed.length - 1);
    }
    return trimmed;
  }

  void _putEntry(String key, MastodonStatus? status) {
    _cache.remove(key);
    _cache[key] = status;
    while (_cache.length > maxEntries) {
      _cache.remove(_cache.keys.first);
    }
  }

  void clear() {
    _epoch++;
    _cache.clear();
    _inFlightFutures.clear();
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
    while (_slotWaiters.isNotEmpty) {
      final waiter = _slotWaiters.removeFirst();
      if (!waiter.isCompleted) waiter.complete();
    }
    super.dispose();
  }
}
