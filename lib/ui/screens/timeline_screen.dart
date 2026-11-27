// Copyright (c) 2026 brokengoose <brokengoose@users.noreply.github.com>
// SPDX-License-Identifier: MIT

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/accessibility_announcer.dart';
import '../../l10n/l10n.dart';
import '../../l10n/model_localizations.dart';
import '../../models/mastodon_models.dart';
import '../../state/app_controller.dart';
import '../helpers/keyboard_shortcuts.dart';
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

  int? _selectedIndex;
  final Map<String, GlobalKey> _itemKeys = {};
  final Set<String> _expandedCwIds = {};

  @override
  void initState() {
    super.initState();
    _actions = StatusActionHandler(app: widget.app);
    _lastSeenRefreshNonce = widget.app.timelineRefreshNonce;
    widget.app.addListener(_onAppChanged);
    widget.app.timelineCache.addListener(_onTimelineCacheChanged);
    _scrollController.addListener(_onScroll);
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
    _loadOrUseCache();
  }

  GlobalKey _keyForStatus(String id) =>
      _itemKeys.putIfAbsent(id, () => GlobalKey());

  MastodonStatus? get _selectedStatus {
    final idx = _selectedIndex;
    if (idx == null || idx < 0 || idx >= _statuses.length) return null;
    return _statuses[idx];
  }

  void _moveSelection(int delta) {
    if (_statuses.isEmpty) return;
    final int next;
    if (_selectedIndex == null) {
      next = delta >= 0 ? 0 : _statuses.length - 1;
    } else {
      next = (_selectedIndex! + delta).clamp(0, _statuses.length - 1);
    }
    setState(() => _selectedIndex = next);

    final status = _statuses[next];
    final target = status.displayStatus;
    final key = _itemKeys[status.id];
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (key?.currentContext != null) {
        KeyboardNavHelper.ensureKeyVisible(key);
      } else if (_scrollController.hasClients) {
        final pos = _scrollController.position;
        final step = delta > 0 ? 340.0 : -340.0;
        final targetOffset = (pos.pixels + step).clamp(
          pos.minScrollExtent,
          pos.maxScrollExtent,
        );
        _scrollController.animateTo(
          targetOffset,
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
        );
      }
    });

    if (next >= _statuses.length - 3 && !_isLoadingMore && _hasMore) {
      _loadMore();
    }

    final snippet = target.plainText.trim();
    final preview =
        snippet.length > 90 ? '${snippet.substring(0, 90)}…' : snippet;
    AccessibilityAnnouncer.announce(
      context.l10n.timelineAnnouncePostSelection(
        next + 1,
        _statuses.length,
        target.account.effectiveDisplayName,
        preview,
      ),
    );
  }

  void _toggleSelectedCw() {
    final target = _selectedStatus?.displayStatus;
    if (target == null || target.spoilerText.trim().isEmpty) return;
    setState(() {
      if (!_expandedCwIds.remove(target.id)) {
        _expandedCwIds.add(target.id);
      }
    });
  }

  bool _handleKeyEvent(KeyEvent event) {
    return KeyboardNavHelper.handleStatusFeedKeyEvent(
      event,
      isActive: () => mounted && (ModalRoute.of(context)?.isCurrent ?? false),
      onNext: () => _moveSelection(1),
      onPrevious: () => _moveSelection(-1),
      onPageDown: () =>
          KeyboardNavHelper.scrollByPage(_scrollController, direction: 1),
      onPageUp: () =>
          KeyboardNavHelper.scrollByPage(_scrollController, direction: -1),
      onScrollToTop: () {
        if (_selectedIndex != null && _statuses.isNotEmpty) {
          setState(() => _selectedIndex = 0);
        }
        KeyboardNavHelper.scrollToTop(_scrollController);
      },
      onOpen: () {
        final st = _selectedStatus;
        if (st != null) _actions.openThread(context, st);
      },
      onReply: () {
        final st = _selectedStatus;
        if (st != null) _actions.openReply(context, st);
      },
      onFavorite: () {
        final st = _selectedStatus;
        if (st != null) _toggleFavorite(st.displayStatus);
      },
      onBoost: () {
        final st = _selectedStatus;
        if (st != null) _toggleBoost(st.displayStatus);
      },
      onBookmark: () {
        final st = _selectedStatus;
        if (st != null) _toggleBookmark(st.displayStatus);
      },
      onToggleCw: _toggleSelectedCw,
      onOpenProfile: () {
        final st = _selectedStatus;
        if (st != null) _actions.openProfile(context, st.displayStatus.account);
      },
      onRefresh: _refreshIncremental,
    );
  }

  void _onAppChanged() {
    if (widget.app.timelineRefreshNonce != _lastSeenRefreshNonce) {
      _lastSeenRefreshNonce = widget.app.timelineRefreshNonce;
      _refreshIncremental(silentAnnouncement: true);
    }
  }

  void _onTimelineCacheChanged() {
    if (!mounted) return;
    final cached = widget.app.timelineCache.timelineFor(widget.timelineType);
    if (cached != null && !identical(cached.statuses, _statuses)) {
      setState(() {
        _statuses = cached.statuses;
        _hasMore = cached.hasMore;
      });
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
        final l10n = context.l10n;
        final title = widget.timelineType.localizedFullTitle(l10n);
        AccessibilityAnnouncer.announce(
          newer.isEmpty
              ? l10n.timelineAnnounceUpToDate(title)
              : l10n.timelineAnnounceLoadedNew(newer.length, title),
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
        final l10n = context.l10n;
        AccessibilityAnnouncer.announce(
          l10n.timelineAnnounceLoadedInitial(
            widget.timelineType.localizedFullTitle(l10n),
            items.length,
          ),
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
      setState(() {
        _statuses = StatusActionHandler.removeFromList(_statuses, target.id);
      });
    }
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    widget.app.timelineCache.removeListener(_onTimelineCacheChanged);
    widget.app.removeListener(_onAppChanged);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
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
                label: Text(l10n.commonRetry),
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
                l10n.timelineEmptyMessage(
                  widget.timelineType.localizedFullTitle(l10n),
                ),
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
          final target = status.displayStatus;
          final isSelected = _selectedIndex == index;
          return RepaintBoundary(
            key: _keyForStatus(status.id),
            child: StatusCard(
              status: status,
              app: widget.app,
              isKeyboardSelected: isSelected,
              cwRevealedOverride: target.spoilerText.trim().isNotEmpty
                  ? _expandedCwIds.contains(target.id)
                  : null,
              onToggleCw: target.spoilerText.trim().isNotEmpty
                  ? () => setState(() {
                        if (!_expandedCwIds.remove(target.id)) {
                          _expandedCwIds.add(target.id);
                        }
                      })
                  : null,
              onOpenProfile: (acc) => _actions.openProfile(context, acc),
              onOpenThread: (st) {
                setState(() => _selectedIndex = index);
                _actions.openThread(context, st);
              },
              onReply: (st) => _actions.openReply(context, st),
              onToggleBoost: _toggleBoost,
              onToggleFavorite: _toggleFavorite,
              onToggleBookmark: _toggleBookmark,
              onEdit: (st) async {
                final edited = await _actions.openEdit(context, st);
                if (edited != null) _replaceStatus(edited.displayStatus);
              },
              onDelete: _deleteStatus,
            ),
          );
        },
      ),
    );
  }
}
