// Copyright (c) 2026 brokengoose <brokengoose@users.noreply.github.com>
// SPDX-License-Identifier: MIT

import '../l10n/l10n.dart';

/// Relative and accessible timestamp formatting helpers.
class TimeUtils {
  TimeUtils._();

  /// Compact relative timestamp for visual display in post headers (e.g. `5m`, `2h`, `3d`).
  static String formatRelativeCompact(
    DateTime timestamp, {
    DateTime? now,
    AppLocalizations? l10n,
  }) {
    final loc = l10n ?? AppLocalizationsEn();
    final reference = (now ?? DateTime.now()).toUtc();
    final diff = reference.difference(timestamp.toUtc());

    if (diff.isNegative || diff.inSeconds < 60) {
      return loc.timeCompactNow;
    }
    if (diff.inMinutes < 60) {
      return loc.timeCompactMinutes(diff.inMinutes);
    }
    if (diff.inHours < 24) {
      return loc.timeCompactHours(diff.inHours);
    }
    if (diff.inDays < 30) {
      return loc.timeCompactDays(diff.inDays);
    }
    if (diff.inDays < 365) {
      final months = (diff.inDays / 30).floor();
      return loc.timeCompactMonths(months);
    }
    final years = (diff.inDays / 365).floor();
    return loc.timeCompactYears(years);
  }

  /// Verbose accessible timestamp for VoiceOver / TalkBack labels.
  static String formatRelativeAccessible(
    DateTime timestamp, {
    DateTime? now,
    AppLocalizations? l10n,
  }) {
    final loc = l10n ?? AppLocalizationsEn();
    final reference = (now ?? DateTime.now()).toUtc();
    final diff = reference.difference(timestamp.toUtc());

    if (diff.isNegative || diff.inSeconds < 60) {
      return loc.timeAccessibleJustNow;
    }
    if (diff.inMinutes < 60) {
      return loc.timeAccessibleMinutesAgo(diff.inMinutes);
    }
    if (diff.inHours < 24) {
      return loc.timeAccessibleHoursAgo(diff.inHours);
    }
    if (diff.inDays < 30) {
      return loc.timeAccessibleDaysAgo(diff.inDays);
    }
    final local = timestamp.toLocal();
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
  }
}
