// Copyright (c) 2026 brokengoose <brokengoose@users.noreply.github.com>
// SPDX-License-Identifier: MIT

import 'package:material_ui/material_ui.dart';

import '../../core/accessibility_announcer.dart';
import '../../l10n/l10n.dart';
import '../../models/mastodon_models.dart';
import '../../state/app_controller.dart';
import '../screens/composer_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/thread_screen.dart';

/// Shared navigation and status-mutation helpers used across [TimelineScreen],
/// [ProfileScreen], and [ThreadScreen] so boost, favorite, bookmark, and
/// destructive delete flows always provide confirmation dialogs, error handling,
/// `mounted` safety, shared-cache updates, and screen-reader announcements
/// consistently.
class StatusActionHandler {
  const StatusActionHandler({required this.app});

  final AppController app;

  /// Replaces a status (or wrapped boosted/quoted status) inside [list] after an action or edit.
  static List<MastodonStatus> replaceInList(
    List<MastodonStatus> list,
    MastodonStatus updatedTarget,
  ) {
    final target = updatedTarget.displayStatus;
    return list.map((s) {
      if (s.id == target.id) return target;
      var updated = s;
      if (s.reblog?.id == target.id) {
        updated = updated.copyWith(reblog: target);
      }
      if (s.quotedStatus?.displayStatus.id == target.id) {
        final nextQuote = s.quotedStatus!.isBoost
            ? s.quotedStatus!.copyWith(reblog: target)
            : target;
        updated = updated.copyWith(quotedStatus: nextQuote);
      }
      return updated;
    }).toList();
  }

  /// Removes a deleted status (and any boost wrapper referencing it) from [list].
  static List<MastodonStatus> removeFromList(
    List<MastodonStatus> list,
    String targetId,
  ) {
    return list
        .where((s) => s.id != targetId && s.reblog?.id != targetId)
        .toList();
  }

  void openProfile(
    BuildContext context,
    MastodonAccount account, {
    String? skipIfAccountId,
  }) {
    if (skipIfAccountId != null && account.id == skipIfAccountId) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ProfileScreen(
          app: app,
          accountId: account.id,
          initialAccount: account,
        ),
      ),
    );
  }

  void openThread(
    BuildContext context,
    MastodonStatus status, {
    String? skipIfStatusId,
  }) {
    if (skipIfStatusId != null && status.id == skipIfStatusId) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ThreadScreen(app: app, rootStatus: status),
      ),
    );
  }

  Future<MastodonStatus?> openReply(
    BuildContext context,
    MastodonStatus status,
  ) {
    return Navigator.of(context).push<MastodonStatus>(
      MaterialPageRoute<MastodonStatus>(
        builder: (_) => ComposerScreen(app: app, replyToStatus: status),
      ),
    );
  }

  Future<MastodonStatus?> openEdit(
    BuildContext context,
    MastodonStatus status,
  ) {
    return Navigator.of(context).push<MastodonStatus>(
      MaterialPageRoute<MastodonStatus>(
        builder: (_) => ComposerScreen(app: app, editingStatus: status),
      ),
    );
  }

  /// Toggles boost (`reblog`) on [target], returning the updated status or `null` on failure.
  Future<MastodonStatus?> toggleBoost(
    BuildContext context,
    MastodonStatus target,
  ) async {
    final session = app.session;
    if (session == null) return null;
    final l10n = context.l10n;
    try {
      final updated = await app.mastodon.toggleReblog(
        instanceUrl: session.instanceUrl,
        accessToken: session.accessToken,
        statusId: target.id,
        currentlyReblogged: target.reblogged,
      );
      final display = updated.displayStatus;
      _syncCaches(display);
      AccessibilityAnnouncer.announce(
        display.reblogged
            ? l10n.actionAnnounceBoosted
            : l10n.actionAnnounceUnboosted,
      );
      return display;
    } catch (e) {
      if (context.mounted) {
        _showSnack(context, l10n.actionErrorBoost(e.toString()));
      }
      return null;
    }
  }

  /// Toggles favorite on [target], returning the updated status or `null` on failure.
  Future<MastodonStatus?> toggleFavorite(
    BuildContext context,
    MastodonStatus target,
  ) async {
    final session = app.session;
    if (session == null) return null;
    final l10n = context.l10n;
    try {
      final updated = await app.mastodon.toggleFavourite(
        instanceUrl: session.instanceUrl,
        accessToken: session.accessToken,
        statusId: target.id,
        currentlyFavourited: target.favourited,
      );
      final display = updated.displayStatus;
      _syncCaches(display);
      AccessibilityAnnouncer.announce(
        display.favourited
            ? l10n.actionAnnounceFavorited
            : l10n.actionAnnounceUnfavorited,
      );
      return display;
    } catch (e) {
      if (context.mounted) {
        _showSnack(context, l10n.actionErrorFavorite(e.toString()));
      }
      return null;
    }
  }

  /// Toggles bookmark on [target], returning the updated status or `null` on failure.
  Future<MastodonStatus?> toggleBookmark(
    BuildContext context,
    MastodonStatus target,
  ) async {
    final session = app.session;
    if (session == null) return null;
    final l10n = context.l10n;
    try {
      final updated = await app.mastodon.toggleBookmark(
        instanceUrl: session.instanceUrl,
        accessToken: session.accessToken,
        statusId: target.id,
        currentlyBookmarked: target.bookmarked,
      );
      final display = updated.displayStatus;
      _syncCaches(display);
      AccessibilityAnnouncer.announce(
        display.bookmarked
            ? l10n.actionAnnounceBookmarked
            : l10n.actionAnnounceUnbookmarked,
      );
      return display;
    } catch (e) {
      if (context.mounted) {
        _showSnack(context, l10n.actionErrorBookmark(e.toString()));
      }
      return null;
    }
  }

  /// Prompts the user with a confirmation dialog before permanently deleting [target].
  /// Returns `true` if the post was deleted on the server.
  Future<bool> confirmAndDelete(
    BuildContext context,
    MastodonStatus target,
  ) async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.actionDeleteTitle),
        content: Text(l10n.actionDeleteConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.commonDelete),
          ),
        ],
      ),
    );
    if (confirmed != true) return false;

    final session = app.session;
    if (session == null) return false;

    try {
      await app.mastodon.deleteStatus(
        instanceUrl: session.instanceUrl,
        accessToken: session.accessToken,
        statusId: target.id,
      );
      app.removeStatusEverywhere(target.id);
      AccessibilityAnnouncer.announce(l10n.actionAnnounceDeleted);
      return true;
    } catch (e) {
      if (context.mounted) {
        _showSnack(context, l10n.actionErrorDelete(e.toString()));
      }
      return false;
    }
  }

  /// Propagates a mutated status to the shared timeline/notification and quote
  /// caches, so every screen (not just the one that acted) sees fresh state.
  void _syncCaches(MastodonStatus updated) => app.applyEditedStatus(updated);

  void _showSnack(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}
