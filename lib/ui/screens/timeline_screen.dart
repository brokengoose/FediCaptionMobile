// Copyright (c) 2026 brokengoose <brokengoose@users.noreply.github.com>
// SPDX-License-Identifier: MIT

import 'package:material_ui/material_ui.dart';

import '../../core/accessibility_announcer.dart';
import '../../models/mastodon_models.dart';
import '../../state/app_controller.dart';
import '../helpers/status_action_handler.dart';
import '../widgets/status_card.dart';

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
  late final StatusActionHandler _actions;

  List<MastodonStatus> _statuses = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String? _error;
  int _lastSeenRefreshNonce = -1;

  @override
  void initState() {
    super.initState();
    _actions = StatusActionHandler(app: widget.app);
    _lastSeenRefreshNonce = widget.app.timelineRefreshNonce;
    widget.app.addListener(_onAppChanged);
    _scrollController.addListener(_onScroll);
    _loadOrUseCache();
  }

  @override
  void didUpdateWidget(covariant TimelineScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.timelineType != widget.timelineType) {
      _loadOrUseCache();
    }
  }

  void _onAppChanged() {
    if (widget.app.timelineRefreshNonce != _lastSeenRefreshNonce) {
      _lastSeenRefreshNonce = widget.app.timelineRefreshNonce;
      _refreshIncremental(silentAnnouncement: true);
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 600 &&
        !_isLoading &&
        !_isLoadingMore &&
        _hasMore &&
        _statuses.isNotEmpty) {
      _loadMore();
    }
  }

  /// Serves cached posts immediately on tab switch with zero server requests
  /// while the cache is fresh, falling back to an incremental `since_id` check
  /// if stale or a full initial load if empty.
  void _loadOrUseCache() {
    final cached = widget.app.timelineCache.timelineFor(widget.timelineType);
    if (cached != null && cached.statuses.isNotEmpty) {
      setState(() {
        _statuses = cached.statuses;
        _hasMore = cached.hasMore;
        _isLoading = false;
        _error = null;
      });
      if (!widget.app.timelineCache.isTimelineFresh(widget.timelineType)) {
        _refreshIncremental(silentAnnouncement: true);
      }
      return;
    }
    _loadInitial();
  }

  /// Pull-to-refresh / post-publish refresh using `since_id` so Mastodon only
  /// transfers genuinely new posts instead of re-serializing the full page.
  Future<void> _refreshIncremental({bool silentAnnouncement = false}) async {
    final session = widget.app.session;
    final account = widget.app.currentAccount;
    if (session == null || account == null) return;

    if (_statuses.isEmpty) {
      await _loadInitial(silentAnnouncement: silentAnnouncement);
      return;
    }

    try {
      final newer = await widget.app.mastodon.fetchTimeline(
        instanceUrl: session.instanceUrl,
        accessToken: session.accessToken,
        type: widget.timelineType,
        currentUserId: account.id,
        sinceId: _statuses.first.id,
      );
      if (!mounted) return;
      if (newer.isNotEmpty) {
        widget.app.quoteCache.seedStatuses(newer);
      }
      final merged = widget.app.timelineCache.mergeNewerTimeline(
        widget.timelineType,
        newer,
      );
      setState(() {
        _statuses = merged;
        _error = null;
        _isLoading = false;
      });
      if (!silentAnnouncement) {
        AccessibilityAnnouncer.announce(
          newer.isEmpty
              ? '${widget.timelineType.fullTitle} is up to date.'
              : 'Loaded ${newer.length} new posts in ${widget.timelineType.fullTitle}.',
        );
      }
    } catch (e) {
      if (!mounted) return;
      if (_statuses.isEmpty) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
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
      final hasMore = items.length >= 15;
      widget.app.quoteCache.seedStatuses(items);
      widget.app.timelineCache.putTimeline(
        widget.timelineType,
        items,
        hasMore: hasMore,
      );
      setState(() {
        _statuses = items;
        _isLoading = false;
        _hasMore = hasMore;
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
      final hasMore = items.length >= 15;
      widget.app.quoteCache.seedStatuses(items);
      final combined = widget.app.timelineCache.appendOlderTimeline(
        widget.timelineType,
        items,
        hasMore: hasMore,
      );
      setState(() {
        _statuses = combined;
        _isLoadingMore = false;
        _hasMore = hasMore;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingMore = false);
    }
  }

  void _replaceStatus(MastodonStatus updatedTarget) {
    if (!mounted) return;
    widget.app.timelineCache.updateStatusEverywhere(updatedTarget);
    setState(() {
      _statuses = StatusActionHandler.replaceInList(_statuses, updatedTarget);
    });
  }

  Future<void> _toggleBoost(MastodonStatus target) async {
    final updated = await _actions.toggleBoost(context, target);
    if (updated != null) _replaceStatus(updated);
  }

  Future<void> _toggleFavorite(MastodonStatus target) async {
    final updated = await _actions.toggleFavorite(context, target);
    if (updated != null) _replaceStatus(updated);
  }

  Future<void> _toggleBookmark(MastodonStatus target) async {
    final updated = await _actions.toggleBookmark(context, target);
    if (updated != null) _replaceStatus(updated);
  }

  Future<void> _deleteStatus(MastodonStatus target) async {
    final deleted = await _actions.confirmAndDelete(context, target);
    if (deleted && mounted) {
      widget.app.timelineCache.removeStatusEverywhere(target.id);
      setState(() {
        _statuses = StatusActionHandler.removeFromList(_statuses, target.id);
      });
    }
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
      onRefresh: _refreshIncremental,
      child: ListView.builder(
        controller: _scrollController,
        scrollCacheExtent: const ScrollCacheExtent.pixels(1000),
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
          return RepaintBoundary(
            key: ValueKey(status.id),
            child: StatusCard(
              status: status,
              app: widget.app,
              onOpenProfile: (acc) => _actions.openProfile(context, acc),
              onOpenThread: (st) => _actions.openThread(context, st),
              onReply: (st) => _actions.openReply(context, st),
              onToggleBoost: _toggleBoost,
              onToggleFavorite: _toggleFavorite,
              onToggleBookmark: _toggleBookmark,
              onEdit: (st) => _actions.openEdit(context, st),
              onDelete: _deleteStatus,
            ),
          );
        },
      ),
    );
  }
}
