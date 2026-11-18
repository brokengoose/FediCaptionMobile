// Copyright (c) 2026 brokengoose <brokengoose@users.noreply.github.com>
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';

import '../../core/accessibility_announcer.dart';
import '../../models/mastodon_models.dart';
import '../../state/app_controller.dart';
import '../widgets/status_card.dart';
import 'composer_screen.dart';
import 'profile_screen.dart';
import 'thread_screen.dart';

/// Displays any Mastodon status feed (`Home`, `Local`, `Federated`, `Bookmarks`,
/// `Favorites`, `My Published Posts`) with pull-to-refresh and pagination.
class TimelineScreen extends StatefulWidget {
  const TimelineScreen({
    super.key,
    required this.app,
    required this.timelineType,
  });

  final AppController app;
  final TimelineType timelineType;

  @override
  State<TimelineScreen> createState() => _TimelineScreenState();
}

class _TimelineScreenState extends State<TimelineScreen> {
  final ScrollController _scrollController = ScrollController();

  List<MastodonStatus> _statuses = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String? _error;
  int _lastSeenRefreshNonce = -1;

  @override
  void initState() {
    super.initState();
    _lastSeenRefreshNonce = widget.app.timelineRefreshNonce;
    widget.app.addListener(_onAppChanged);
    _scrollController.addListener(_onScroll);
    _loadInitial();
  }

  @override
  void didUpdateWidget(covariant TimelineScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.timelineType != widget.timelineType) {
      _loadInitial();
    }
  }

  void _onAppChanged() {
    if (widget.app.timelineRefreshNonce != _lastSeenRefreshNonce) {
      _lastSeenRefreshNonce = widget.app.timelineRefreshNonce;
      _loadInitial(silentAnnouncement: true);
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 320 &&
        !_isLoading &&
        !_isLoadingMore &&
        _hasMore &&
        _statuses.isNotEmpty) {
      _loadMore();
    }
  }

  Future<void> _loadInitial({bool silentAnnouncement = false}) async {
    final session = widget.app.session;
    final account = widget.app.currentAccount;
    if (session == null || account == null) return;

    setState(() {
      _isLoading = true;
      _error = null;
      _hasMore = true;
    });

    try {
      final items = await widget.app.mastodon.fetchTimeline(
        instanceUrl: session.instanceUrl,
        accessToken: session.accessToken,
        type: widget.timelineType,
        currentUserId: account.id,
      );
      if (!mounted) return;
      setState(() {
        _statuses = items;
        _isLoading = false;
        _hasMore = items.length >= 15;
      });
      if (!silentAnnouncement) {
        AccessibilityAnnouncer.announce(
          '${widget.timelineType.fullTitle} loaded with ${items.length} posts.',
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    final session = widget.app.session;
    final account = widget.app.currentAccount;
    if (session == null || account == null || _statuses.isEmpty) return;

    setState(() => _isLoadingMore = true);
    try {
      final items = await widget.app.mastodon.fetchTimeline(
        instanceUrl: session.instanceUrl,
        accessToken: session.accessToken,
        type: widget.timelineType,
        currentUserId: account.id,
        maxId: _statuses.last.id,
      );
      if (!mounted) return;
      setState(() {
        _statuses = [..._statuses, ...items];
        _isLoadingMore = false;
        _hasMore = items.length >= 15;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingMore = false);
    }
  }

  void _replaceStatus(MastodonStatus updatedTarget) {
    setState(() {
      _statuses = _statuses.map((s) {
        if (s.id == updatedTarget.id) return updatedTarget;
        if (s.reblog?.id == updatedTarget.id) {
          return s.copyWith(reblog: updatedTarget);
        }
        return s;
      }).toList();
    });
  }

  Future<void> _toggleBoost(MastodonStatus target) async {
    final session = widget.app.session;
    if (session == null) return;
    try {
      final updated = await widget.app.mastodon.toggleReblog(
        instanceUrl: session.instanceUrl,
        accessToken: session.accessToken,
        statusId: target.id,
        currentlyReblogged: target.reblogged,
      );
      _replaceStatus(updated.displayStatus);
      AccessibilityAnnouncer.announce(
        updated.displayStatus.reblogged ? 'Post boosted.' : 'Boost removed.',
      );
    } catch (e) {
      _showSnack('Could not update boost: $e');
    }
  }

  Future<void> _toggleFavorite(MastodonStatus target) async {
    final session = widget.app.session;
    if (session == null) return;
    try {
      final updated = await widget.app.mastodon.toggleFavourite(
        instanceUrl: session.instanceUrl,
        accessToken: session.accessToken,
        statusId: target.id,
        currentlyFavourited: target.favourited,
      );
      _replaceStatus(updated.displayStatus);
      AccessibilityAnnouncer.announce(
        updated.displayStatus.favourited
            ? 'Post favorited.'
            : 'Removed from favorites.',
      );
    } catch (e) {
      _showSnack('Could not update favorite: $e');
    }
  }

  Future<void> _toggleBookmark(MastodonStatus target) async {
    final session = widget.app.session;
    if (session == null) return;
    try {
      final updated = await widget.app.mastodon.toggleBookmark(
        instanceUrl: session.instanceUrl,
        accessToken: session.accessToken,
        statusId: target.id,
        currentlyBookmarked: target.bookmarked,
      );
      _replaceStatus(updated.displayStatus);
      AccessibilityAnnouncer.announce(
        updated.displayStatus.bookmarked
            ? 'Post bookmarked.'
            : 'Bookmark removed.',
      );
    } catch (e) {
      _showSnack('Could not update bookmark: $e');
    }
  }

  Future<void> _deleteStatus(MastodonStatus target) async {
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
    if (confirmed != true) return;

    final session = widget.app.session;
    if (session == null) return;
    try {
      await widget.app.mastodon.deleteStatus(
        instanceUrl: session.instanceUrl,
        accessToken: session.accessToken,
        statusId: target.id,
      );
      if (!mounted) return;
      setState(() {
        _statuses = _statuses
            .where((s) => s.id != target.id && s.reblog?.id != target.id)
            .toList();
      });
      AccessibilityAnnouncer.announce('Post deleted.');
    } catch (e) {
      _showSnack('Failed to delete post: $e');
    }
  }

  void _openProfile(MastodonAccount account) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ProfileScreen(
          app: widget.app,
          accountId: account.id,
          initialAccount: account,
        ),
      ),
    );
  }

  void _openThread(MastodonStatus status) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ThreadScreen(app: widget.app, rootStatus: status),
      ),
    );
  }

  void _openReply(MastodonStatus status) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ComposerScreen(app: widget.app, replyToStatus: status),
      ),
    );
  }

  void _openEdit(MastodonStatus status) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ComposerScreen(app: widget.app, editingStatus: status),
      ),
    );
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    widget.app.removeListener(_onAppChanged);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 42),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _loadInitial,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_statuses.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadInitial,
        child: ListView(
          children: [
            const SizedBox(height: 96),
            Center(
              child: Text(
                'No posts in ${widget.timelineType.fullTitle} yet.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadInitial,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.only(top: 6, bottom: 88),
        itemCount: _statuses.length + (_isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= _statuses.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            );
          }

          final status = _statuses[index];
          return StatusCard(
            status: status,
            app: widget.app,
            onOpenProfile: _openProfile,
            onOpenThread: _openThread,
            onReply: _openReply,
            onToggleBoost: _toggleBoost,
            onToggleFavorite: _toggleFavorite,
            onToggleBookmark: _toggleBookmark,
            onEdit: _openEdit,
            onDelete: _deleteStatus,
          );
        },
      ),
    );
  }
}
