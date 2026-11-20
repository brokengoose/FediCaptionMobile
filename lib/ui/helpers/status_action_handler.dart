// Copyright (c) 2026 brokengoose <brokengoose@users.noreply.github.com>
// SPDX-License-Identifier: MIT

import 'package:material_ui/material_ui.dart';

import '../../core/accessibility_announcer.dart';
import '../../models/mastodon_models.dart';
import '../../state/app_controller.dart';
import '../screens/composer_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/thread_screen.dart';

/// Shared navigation and status-mutation helpers used across [TimelineScreen],
/// [ProfileScreen], and [ThreadScreen] so boost, favorite, bookmark, and
/// destructive delete flows always provide confirmation dialogs, error handling,
/// `mounted` safety, and screen-reader announcements consistently.
class StatusActionHandler {
  const StatusActionHandler({
    required this.app,
  });

  final AppController app;

  /// Replaces a status (or wrapped boosted status) inside [list] after an action or edit.
  static List<MastodonStatus> replaceInList(
    List<MastodonStatus> list,
    MastodonStatus updatedTarget,
  ) {
    return list.map((s) {
      if (s.id == updatedTarget.id) return updatedTarget;
      if (s.reblog?.id == updatedTarget.id) {
        return s.copyWith(reblog: updatedTarget);
      }
      return s;
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
    try {
      final updated = await app.mastodon.toggleReblog(
        instanceUrl: session.instanceUrl,
        accessToken: session.accessToken,
        statusId: target.id,
        currentlyReblogged: target.reblogged,
      );
      final display = updated.displayStatus;
      AccessibilityAnnouncer.announce(
        display.reblogged ? 'Post boosted.' : 'Boost removed.',
      );
      return display;
    } catch (e) {
      if (context.mounted) {
        _showSnack(context, 'Could not update boost: $e');
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
    try {
      final updated = await app.mastodon.toggleFavourite(
        instanceUrl: session.instanceUrl,
        accessToken: session.accessToken,
        statusId: target.id,
        currentlyFavourited: target.favourited,
      );
      final display = updated.displayStatus;
      AccessibilityAnnouncer.announce(
        display.favourited ? 'Post favorited.' : 'Removed from favorites.',
      );
      return display;
    } catch (e) {
      if (context.mounted) {
        _showSnack(context, 'Could not update favorite: $e');
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
    try {
      final updated = await app.mastodon.toggleBookmark(
        instanceUrl: session.instanceUrl,
        accessToken: session.accessToken,
        statusId: target.id,
        currentlyBookmarked: target.bookmarked,
      );
      final display = updated.displayStatus;
      AccessibilityAnnouncer.announce(
        display.bookmarked ? 'Post bookmarked.' : 'Bookmark removed.',
      );
      return display;
    } catch (e) {
      if (context.mounted) {
        _showSnack(context, 'Could not update bookmark: $e');
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Post?'),
        content: const Text(
          'This will permanently delete your post from your Mastodon server.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
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
      AccessibilityAnnouncer.announce('Post deleted.');
      return true;
    } catch (e) {
      if (context.mounted) {
        _showSnack(context, 'Failed to delete post: $e');
      }
      return false;
    }
  }

  void _showSnack(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}
