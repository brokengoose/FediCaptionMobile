// Copyright (c) 2026 brokengoose <brokengoose@users.noreply.github.com>
// SPDX-License-Identifier: MIT

import 'package:flutter/foundation.dart';

import '../core/constants.dart';
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
    this.pageSize = AppConstants.timelinePageSize,
    this.notificationsPageSize = AppConstants.notificationsPageSize,
  });

  final Duration defaultTtl;

  /// Soft caps: applied to fresh loads and refreshes, but never to explicit
  /// scroll-back (see [appendOlderTimeline]).
  final int maxStatusesPerTimeline;
  final int maxNotifications;

  /// Page sizes requested from the server; a `since_id` refresh that returns
  /// a full page may have more posts between it and the cached head.
  final int pageSize;
  final int notificationsPageSize;

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
  ///
  /// A full page ([pageSize] or more) means newer posts may exist between this
  /// page and the cached head, so the cache is replaced instead of merged (a
  /// merge would silently hide that gap). Growth is trimmed from the bottom,
  /// never below what the user has already scrolled back through, and any
  /// trim re-enables pagination.
  List<MastodonStatus> mergeNewerTimeline(
    TimelineType type,
    List<MastodonStatus> newer, {
    DateTime? fetchedAt,
    int? pageSize,
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
    if (newer.length >= (pageSize ?? this.pageSize)) {
      putTimeline(type, newer, hasMore: true, fetchedAt: fetchedAt);
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

    final limit = existing.statuses.length > maxStatusesPerTimeline
        ? existing.statuses.length
        : maxStatusesPerTimeline;
    final trimmed = merged.length > limit;
    final capped = List<MastodonStatus>.unmodifiable(
      trimmed ? merged.sublist(0, limit) : merged,
    );
    _timelines[type] = CachedTimelinePage(
      statuses: capped,
      fetchedAt: fetchedAt ?? DateTime.now(),
      hasMore: existing.hasMore || trimmed,
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
    // Not capped: the user explicitly scrolled back, and capping here would
    // drop the page just loaded, so `max_id` never advances and infinite
    // scroll stalls at the cap. Fresh loads/refreshes re-apply the cap.
    final merged = List<MastodonStatus>.unmodifiable(<MastodonStatus>[
      ...current,
      for (final s in older)
        if (seenIds.add(s.id)) s,
    ]);
    _timelines[type] = CachedTimelinePage(
      statuses: merged,
      fetchedAt: existing?.fetchedAt ?? DateTime.now(),
      hasMore: hasMore,
    );
    _safeNotify();
    return merged;
  }

  static MastodonStatus _replaceStatusIn(
    MastodonStatus existing,
    MastodonStatus updatedTarget,
  ) {
    if (existing.id == updatedTarget.id) {
      return updatedTarget;
    }
    var current = existing;
    if (existing.reblog != null) {
      final nextReblog = _replaceStatusIn(existing.reblog!, updatedTarget);
      if (!identical(nextReblog, existing.reblog)) {
        current = current.copyWith(reblog: nextReblog);
      }
    }
    if (existing.quotedStatus != null) {
      final nextQuoted = _replaceStatusIn(
        existing.quotedStatus!,
        updatedTarget,
      );
      if (!identical(nextQuoted, existing.quotedStatus)) {
        current = current.copyWith(quotedStatus: nextQuoted);
      }
    }
    return current;
  }

  /// Updates a mutated status (boost/favorite/bookmark/edit) across every
  /// cached timeline and notification without requiring a server refetch.
  void updateStatusEverywhere(MastodonStatus updatedTarget) {
    final target = updatedTarget.displayStatus;
    var anyChanged = false;
    for (final entry in _timelines.entries.toList()) {
      var timelineChanged = false;
      final updatedList = entry.value.statuses.map((s) {
        final next = _replaceStatusIn(s, target);
        if (!identical(next, s)) {
          timelineChanged = true;
        }
        return next;
      }).toList();
      if (timelineChanged) {
        anyChanged = true;
        _timelines[entry.key] = CachedTimelinePage(
          // Same length as before; never re-cap (would truncate scroll-back).
          statuses: List<MastodonStatus>.unmodifiable(updatedList),
          fetchedAt: entry.value.fetchedAt,
          hasMore: entry.value.hasMore,
        );
      }
    }
    if (_notifications != null) {
      var notifChanged = false;
      final updatedNotifs = _notifications!.notifications.map((n) {
        if (n.status == null) return n;
        final nextStatus = _replaceStatusIn(n.status!, target);
        if (!identical(nextStatus, n.status)) {
          notifChanged = true;
          return n.copyWith(status: nextStatus);
        }
        return n;
      }).toList();
      if (notifChanged) {
        anyChanged = true;
        _notifications = CachedNotificationsPage(
          notifications: List<MastodonNotification>.unmodifiable(updatedNotifs),
          fetchedAt: _notifications!.fetchedAt,
          hasMore: _notifications!.hasMore,
        );
      }
    }
    if (anyChanged) _safeNotify();
  }

  /// Removes a deleted status across every cached timeline and drops
  /// notifications that point at it.
  void removeStatusEverywhere(String targetId) {
    bool matches(MastodonStatus s) =>
        s.id == targetId || s.displayStatus.id == targetId;
    var changed = false;
    for (final entry in _timelines.entries.toList()) {
      final filtered = entry.value.statuses.where((s) => !matches(s)).toList();
      if (filtered.length != entry.value.statuses.length) {
        changed = true;
        _timelines[entry.key] = CachedTimelinePage(
          statuses: filtered,
          fetchedAt: entry.value.fetchedAt,
          hasMore: entry.value.hasMore,
        );
      }
    }
    final notifs = _notifications;
    if (notifs != null) {
      final filtered = notifs.notifications
          .where((n) => n.status == null || !matches(n.status!))
          .toList();
      if (filtered.length != notifs.notifications.length) {
        changed = true;
        _notifications = CachedNotificationsPage(
          notifications: List<MastodonNotification>.unmodifiable(filtered),
          fetchedAt: notifs.fetchedAt,
          hasMore: notifs.hasMore,
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
      notifications: List<MastodonNotification>.unmodifiable(
        items.length > maxNotifications
            ? items.sublist(0, maxNotifications)
            : items,
      ),
      fetchedAt: fetchedAt ?? DateTime.now(),
      hasMore: hasMore,
    );
    _safeNotify();
  }

  List<MastodonNotification> mergeNewerNotifications(
    List<MastodonNotification> newer, {
    DateTime? fetchedAt,
    int? pageSize,
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
    // Full page: possible gap to the cached head (see mergeNewerTimeline).
    if (newer.length >= (pageSize ?? notificationsPageSize)) {
      putNotifications(newer, hasMore: true, fetchedAt: fetchedAt);
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
    final limit = existing.notifications.length > maxNotifications
        ? existing.notifications.length
        : maxNotifications;
    final trimmed = merged.length > limit;
    final capped = List<MastodonNotification>.unmodifiable(
      trimmed ? merged.sublist(0, limit) : merged,
    );
    _notifications = CachedNotificationsPage(
      notifications: capped,
      fetchedAt: fetchedAt ?? DateTime.now(),
      hasMore: existing.hasMore || trimmed,
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
    // Not capped: explicit scroll-back (see appendOlderTimeline).
    final merged = List<MastodonNotification>.unmodifiable(
      <MastodonNotification>[
        ...current,
        for (final n in older)
          if (seenIds.add(n.id)) n,
      ],
    );
    _notifications = CachedNotificationsPage(
      notifications: merged,
      fetchedAt: existing?.fetchedAt ?? DateTime.now(),
      hasMore: hasMore,
    );
    _safeNotify();
    return merged;
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
