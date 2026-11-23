// Copyright (c) 2026 brokengoose <brokengoose@users.noreply.github.com>
// SPDX-License-Identifier: MIT

import 'package:flutter/foundation.dart';

import '../models/mastodon_models.dart';

/// Cached snapshot for a single Mastodon timeline tab.
class CachedTimelinePage {
  const CachedTimelinePage({
    required this.statuses,
    required this.fetchedAt,
    required this.hasMore,
  });

  final List<MastodonStatus> statuses;
  final DateTime fetchedAt;
  final bool hasMore;
}

/// Cached snapshot for notifications.
class CachedNotificationsPage {
  const CachedNotificationsPage({
    required this.notifications,
    required this.fetchedAt,
    required this.hasMore,
  });

  final List<MastodonNotification> notifications;
  final DateTime fetchedAt;
  final bool hasMore;
}

/// Client-side timeline & notifications cache with:
/// - Instant zero-network tab switching within [defaultTtl]
/// - Incremental `since_id` delta merging on pull-to-refresh
/// - Cross-timeline mutation propagation (boost/favorite/bookmark/delete)
/// - Instant offline full-text search across cached posts, CWs, authors, and alt-text
class TimelineCacheController extends ChangeNotifier {
  TimelineCacheController({
    this.defaultTtl = const Duration(minutes: 5),
    this.maxStatusesPerTimeline = 200,
    this.maxNotifications = 200,
  });

  final Duration defaultTtl;
  final int maxStatusesPerTimeline;
  final int maxNotifications;

  final Map<TimelineType, CachedTimelinePage> _timelines = {};
  CachedNotificationsPage? _notifications;
  bool _disposed = false;

  CachedTimelinePage? timelineFor(TimelineType type) => _timelines[type];
  CachedNotificationsPage? get notifications => _notifications;

  bool isTimelineFresh(TimelineType type, {DateTime? now}) {
    final entry = _timelines[type];
    if (entry == null || entry.statuses.isEmpty) return false;
    final current = now ?? DateTime.now();
    return current.difference(entry.fetchedAt) < defaultTtl;
  }

  bool isNotificationsFresh({DateTime? now}) {
    final entry = _notifications;
    if (entry == null || entry.notifications.isEmpty) return false;
    final current = now ?? DateTime.now();
    return current.difference(entry.fetchedAt) < defaultTtl;
  }

  /// Stores a full initial timeline fetch.
  void putTimeline(
    TimelineType type,
    List<MastodonStatus> statuses, {
    required bool hasMore,
    DateTime? fetchedAt,
  }) {
    _timelines[type] = CachedTimelinePage(
      statuses: _capStatuses(statuses),
      fetchedAt: fetchedAt ?? DateTime.now(),
      hasMore: hasMore,
    );
    _safeNotify();
  }

  /// Prepends incremental `since_id` results onto an existing cached timeline,
  /// deduplicating by outer status ID.
  List<MastodonStatus> mergeNewerTimeline(
    TimelineType type,
    List<MastodonStatus> newer, {
    DateTime? fetchedAt,
  }) {
    final existing = _timelines[type];
    if (existing == null || existing.statuses.isEmpty) {
      putTimeline(
        type,
        newer,
        hasMore: newer.length >= 15,
        fetchedAt: fetchedAt,
      );
      return _timelines[type]!.statuses;
    }

    final seenIds = <String>{};
    final merged = <MastodonStatus>[];
    for (final s in newer) {
      if (seenIds.add(s.id)) merged.add(s);
    }
    for (final s in existing.statuses) {
      if (seenIds.add(s.id)) merged.add(s);
    }

    final capped = _capStatuses(merged);
    _timelines[type] = CachedTimelinePage(
      statuses: capped,
      fetchedAt: fetchedAt ?? DateTime.now(),
      hasMore: existing.hasMore,
    );
    _safeNotify();
    return capped;
  }

  /// Appends older paginated (`max_id`) items to an existing cached timeline.
  List<MastodonStatus> appendOlderTimeline(
    TimelineType type,
    List<MastodonStatus> older, {
    required bool hasMore,
  }) {
    final existing = _timelines[type];
    final current = existing?.statuses ?? const <MastodonStatus>[];
    final seenIds = <String>{for (final s in current) s.id};
    final merged = <MastodonStatus>[
      ...current,
      for (final s in older)
        if (seenIds.add(s.id)) s,
    ];
    final capped = _capStatuses(merged);
    _timelines[type] = CachedTimelinePage(
      statuses: capped,
      fetchedAt: existing?.fetchedAt ?? DateTime.now(),
      hasMore: hasMore,
    );
    _safeNotify();
    return capped;
  }

  /// Updates a mutated status (boost/favorite/bookmark/edit) across every
  /// cached timeline without requiring any server refetch.
  void updateStatusEverywhere(MastodonStatus updatedTarget) {
    var changed = false;
    for (final entry in _timelines.entries.toList()) {
      final updatedList = entry.value.statuses.map((s) {
        if (s.id == updatedTarget.id) {
          changed = true;
          return updatedTarget;
        }
        if (s.reblog?.id == updatedTarget.id) {
          changed = true;
          return s.copyWith(reblog: updatedTarget);
        }
        return s;
      }).toList();
      if (changed) {
        _timelines[entry.key] = CachedTimelinePage(
          statuses: updatedList,
          fetchedAt: entry.value.fetchedAt,
          hasMore: entry.value.hasMore,
        );
      }
    }
    if (changed) _safeNotify();
  }

  /// Removes a deleted status across every cached timeline.
  void removeStatusEverywhere(String targetId) {
    var changed = false;
    for (final entry in _timelines.entries.toList()) {
      final filtered = entry.value.statuses
          .where((s) => s.id != targetId && s.displayStatus.id != targetId)
          .toList();
      if (filtered.length != entry.value.statuses.length) {
        changed = true;
        _timelines[entry.key] = CachedTimelinePage(
          statuses: filtered,
          fetchedAt: entry.value.fetchedAt,
          hasMore: entry.value.hasMore,
        );
      }
    }
    if (changed) _safeNotify();
  }

  /// Marks all cached timelines stale so the next view/refresh triggers a
  /// lightweight `since_id` delta check.
  void markAllStale() {
    final epoch = DateTime.fromMillisecondsSinceEpoch(0);
    for (final entry in _timelines.entries.toList()) {
      _timelines[entry.key] = CachedTimelinePage(
        statuses: entry.value.statuses,
        fetchedAt: epoch,
        hasMore: entry.value.hasMore,
      );
    }
    if (_notifications != null) {
      _notifications = CachedNotificationsPage(
        notifications: _notifications!.notifications,
        fetchedAt: epoch,
        hasMore: _notifications!.hasMore,
      );
    }
  }

  void putNotifications(
    List<MastodonNotification> items, {
    required bool hasMore,
    DateTime? fetchedAt,
  }) {
    _notifications = CachedNotificationsPage(
      notifications: items.length > maxNotifications
          ? items.sublist(0, maxNotifications)
          : List<MastodonNotification>.unmodifiable(items),
      fetchedAt: fetchedAt ?? DateTime.now(),
      hasMore: hasMore,
    );
    _safeNotify();
  }

  List<MastodonNotification> mergeNewerNotifications(
    List<MastodonNotification> newer, {
    DateTime? fetchedAt,
  }) {
    final existing = _notifications;
    if (existing == null || existing.notifications.isEmpty) {
      putNotifications(
        newer,
        hasMore: newer.length >= 15,
        fetchedAt: fetchedAt,
      );
      return _notifications!.notifications;
    }

    final seenIds = <String>{};
    final merged = <MastodonNotification>[];
    for (final n in newer) {
      if (seenIds.add(n.id)) merged.add(n);
    }
    for (final n in existing.notifications) {
      if (seenIds.add(n.id)) merged.add(n);
    }
    final capped = merged.length > maxNotifications
        ? merged.sublist(0, maxNotifications)
        : merged;
    _notifications = CachedNotificationsPage(
      notifications: capped,
      fetchedAt: fetchedAt ?? DateTime.now(),
      hasMore: existing.hasMore,
    );
    _safeNotify();
    return capped;
  }

  List<MastodonNotification> appendOlderNotifications(
    List<MastodonNotification> older, {
    required bool hasMore,
  }) {
    final existing = _notifications;
    final current = existing?.notifications ?? const <MastodonNotification>[];
    final seenIds = <String>{for (final n in current) n.id};
    final merged = <MastodonNotification>[
      ...current,
      for (final n in older)
        if (seenIds.add(n.id)) n,
    ];
    final capped = merged.length > maxNotifications
        ? merged.sublist(0, maxNotifications)
        : merged;
    _notifications = CachedNotificationsPage(
      notifications: capped,
      fetchedAt: existing?.fetchedAt ?? DateTime.now(),
      hasMore: hasMore,
    );
    _safeNotify();
    return capped;
  }

  /// Total count of distinct cached statuses currently searchable offline.
  int get totalCachedPostCount {
    final ids = <String>{};
    for (final page in _timelines.values) {
      for (final s in page.statuses) {
        ids.add(s.displayStatus.id);
      }
    }
    return ids.length;
  }

  /// Performs an instant, zero-server-load client-side search across all
  /// locally cached posts (body text, Content Warning, author name/handle,
  /// and media alt-text descriptions). All whitespace-separated query tokens
  /// must match (case-insensitive).
  List<MastodonStatus> searchLocal(String rawQuery) {
    final terms = rawQuery
        .trim()
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        .toList();
    if (terms.isEmpty) return const [];

    final uniqueById = <String, MastodonStatus>{};
    for (final page in _timelines.values) {
      for (final status in page.statuses) {
        final target = status.displayStatus;
        uniqueById.putIfAbsent(target.id, () => target);
      }
    }
    final notifItems = _notifications?.notifications ?? const [];
    for (final notif in notifItems) {
      final st = notif.status?.displayStatus;
      if (st != null) {
        uniqueById.putIfAbsent(st.id, () => st);
      }
    }

    final matches = <MastodonStatus>[];
    for (final status in uniqueById.values) {
      final haystack = _buildSearchHaystack(status);
      if (terms.every(haystack.contains)) {
        matches.add(status);
      }
    }
    matches.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return matches;
  }

  static String _buildSearchHaystack(MastodonStatus status) {
    final buf = StringBuffer()
      ..write(status.plainText)
      ..write(' ')
      ..write(status.spoilerText)
      ..write(' ')
      ..write(status.account.effectiveDisplayName)
      ..write(' ')
      ..write(status.account.handle);
    for (final media in status.mediaAttachments) {
      if (media.hasAltText) {
        buf
          ..write(' ')
          ..write(media.description);
      }
    }
    return buf.toString().toLowerCase();
  }

  List<MastodonStatus> _capStatuses(List<MastodonStatus> items) {
    if (items.length <= maxStatusesPerTimeline) {
      return List<MastodonStatus>.unmodifiable(items);
    }
    return List<MastodonStatus>.unmodifiable(
      items.sublist(0, maxStatusesPerTimeline),
    );
  }

  void clear() {
    _timelines.clear();
    _notifications = null;
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
