// Copyright (c) 2026 brokengoose <brokengoose@users.noreply.github.com>
// SPDX-License-Identifier: MIT

/// Relative and accessible timestamp formatting helpers.
class TimeUtils {
  TimeUtils._();

  /// Compact relative timestamp for visual display in post headers (e.g. `5m`, `2h`, `3d`).
  static String formatRelativeCompact(DateTime timestamp, {DateTime? now}) {
    final reference = (now ?? DateTime.now()).toUtc();
    final diff = reference.difference(timestamp.toUtc());

    if (diff.isNegative || diff.inSeconds < 60) {
      return 'now';
    }
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m';
    }
    if (diff.inHours < 24) {
      return '${diff.inHours}h';
    }
    if (diff.inDays < 30) {
      return '${diff.inDays}d';
    }
    if (diff.inDays < 365) {
      final months = (diff.inDays / 30).floor();
      return '${months}mo';
    }
    final years = (diff.inDays / 365).floor();
    return '${years}y';
  }

  /// Verbose accessible timestamp for VoiceOver / TalkBack labels.
  static String formatRelativeAccessible(DateTime timestamp, {DateTime? now}) {
    final reference = (now ?? DateTime.now()).toUtc();
    final diff = reference.difference(timestamp.toUtc());

    if (diff.isNegative || diff.inSeconds < 60) {
      return 'just now';
    }
    if (diff.inMinutes < 60) {
      final m = diff.inMinutes;
      return '$m ${m == 1 ? 'minute' : 'minutes'} ago';
    }
    if (diff.inHours < 24) {
      final h = diff.inHours;
      return '$h ${h == 1 ? 'hour' : 'hours'} ago';
    }
    if (diff.inDays < 30) {
      final d = diff.inDays;
      return '$d ${d == 1 ? 'day' : 'days'} ago';
    }
    final local = timestamp.toLocal();
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
  }
}
