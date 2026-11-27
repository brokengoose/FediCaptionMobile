// Copyright (c) 2026 brokengoose <brokengoose@users.noreply.github.com>
// SPDX-License-Identifier: MIT

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/accessibility_announcer.dart';
import '../../core/theme/app_theme.dart';
import '../../core/time_utils.dart';
import '../../l10n/l10n.dart';
import '../../l10n/model_localizations.dart';
import '../../models/mastodon_models.dart';
import '../../state/app_controller.dart';
import '../helpers/keyboard_shortcuts.dart';
import '../helpers/status_action_handler.dart';
import '../widgets/accessible_avatar.dart';
import '../widgets/accessible_tip.dart';
import '../widgets/linkified_text.dart';

/// Displays Mastodon notifications (`GET /api/v1/notifications`) with clickable
/// user avatars/handles, direct thread navigation, and infinite-scroll pagination.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({
    super.key,
    required this.app,
  });

  final AppController app;

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final ScrollController _scrollController = ScrollController();
  late final StatusActionHandler _actions;

  List<MastodonNotification> _notifications = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String? _error;

  int? _selectedIndex;
  final Map<String, GlobalKey> _itemKeys = {};

  @override
  void initState() {
    super.initState();
    _actions = StatusActionHandler(app: widget.app);
    widget.app.timelineCache.addListener(_onTimelineCacheChanged);
    _scrollController.addListener(_onScroll);
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
    _loadOrUseCache();
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    widget.app.timelineCache.removeListener(_onTimelineCacheChanged);
    _scrollController.dispose();
    super.dispose();
  }

  void _onTimelineCacheChanged() {
    if (!mounted) return;
    final cached = widget.app.timelineCache.notifications;
    if (cached != null && !identical(cached.notifications, _notifications)) {
      setState(() {
        _notifications = cached.notifications;
        _hasMore = cached.hasMore;
      });
    }
  }

  GlobalKey _keyForNotification(String id) =>
      _itemKeys.putIfAbsent(id, () => GlobalKey());

  MastodonNotification? get _selectedNotification {
    final idx = _selectedIndex;
    if (idx == null || idx < 0 || idx >= _notifications.length) return null;
    return _notifications[idx];
  }

  void _moveSelection(int delta) {
    if (_notifications.isEmpty) return;
    final int next;
    if (_selectedIndex == null) {
      next = delta >= 0 ? 0 : _notifications.length - 1;
    } else {
      next = (_selectedIndex! + delta).clamp(0, _notifications.length - 1);
    }
    setState(() => _selectedIndex = next);
    final item = _notifications[next];
    final key = _itemKeys[item.id];
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) KeyboardNavHelper.ensureKeyVisible(key);
    });
    if (next >= _notifications.length - 3 && !_isLoadingMore && _hasMore) {
      _loadMore();
    }
    final l10n = context.l10n;
    AccessibilityAnnouncer.announce(
      l10n.notificationsAnnounceSelection(
        next + 1,
        _notifications.length,
        item.localizedSummary(l10n),
      ),
    );
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
        if (_selectedIndex != null && _notifications.isNotEmpty) {
          setState(() => _selectedIndex = 0);
        }
        KeyboardNavHelper.scrollToTop(_scrollController);
      },
      onOpen: () {
        final item = _selectedNotification;
        if (item == null) return;
        if (item.status != null) {
          _actions.openThread(context, item.status!);
        } else {
          _actions.openProfile(context, item.account);
        }
      },
      onOpenProfile: () {
        final item = _selectedNotification;
        if (item != null) _actions.openProfile(context, item.account);
      },
      onReply: () {
        final st = _selectedNotification?.status;
        if (st != null) _actions.openReply(context, st);
      },
      onRefresh: _refreshIncremental,
    );
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 500 &&
        !_isLoading &&
        !_isLoadingMore &&
        _hasMore &&
        _notifications.isNotEmpty) {
      _loadMore();
    }
  }

  void _loadOrUseCache() {
    final cached = widget.app.timelineCache.notifications;
    if (cached != null && cached.notifications.isNotEmpty) {
      setState(() {
        _notifications = cached.notifications;
        _hasMore = cached.hasMore;
        _isLoading = false;
        _error = null;
      });
      if (!widget.app.timelineCache.isNotificationsFresh()) {
        _refreshIncremental(silentAnnouncement: true);
      }
      return;
    }
    _load();
  }

  Future<void> _refreshIncremental({bool silentAnnouncement = false}) async {
    final session = widget.app.session;
    if (session == null) return;
    if (_notifications.isEmpty) {
      await _load();
      return;
    }

    try {
      final newer = await widget.app.mastodon.fetchNotifications(
        instanceUrl: session.instanceUrl,
        accessToken: session.accessToken,
        sinceId: _notifications.first.id,
      );
      if (!mounted) return;
      _seedNotificationStatuses(newer);
      final merged = widget.app.timelineCache.mergeNewerNotifications(newer);
      setState(() {
        _notifications = merged;
        _error = null;
        _isLoading = false;
      });
      if (!silentAnnouncement) {
        final l10n = context.l10n;
        AccessibilityAnnouncer.announce(
          newer.isEmpty
              ? l10n.notificationsAnnounceUpToDate
              : l10n.notificationsAnnounceLoadedNew(newer.length),
        );
      }
    } catch (_) {
      // Keep cached notifications visible on transient refresh error.
    }
  }

  void _seedNotificationStatuses(List<MastodonNotification> items) {
    final statuses = <MastodonStatus>[
      for (final n in items)
        if (n.status != null) n.status!,
    ];
    if (statuses.isNotEmpty) {
      widget.app.quoteCache.seedStatuses(statuses);
    }
  }

  Future<void> _load() async {
    final session = widget.app.session;
    if (session == null) return;
    setState(() {
      _isLoading = true;
      _error = null;
      _hasMore = true;
    });

    try {
      final items = await widget.app.mastodon.fetchNotifications(
        instanceUrl: session.instanceUrl,
        accessToken: session.accessToken,
      );
      if (!mounted) return;
      final hasMore = items.length >= 15;
      _seedNotificationStatuses(items);
      widget.app.timelineCache.putNotifications(items, hasMore: hasMore);
      setState(() {
        _notifications = items;
        _isLoading = false;
        _hasMore = hasMore;
      });
      AccessibilityAnnouncer.announce(
        context.l10n.notificationsAnnounceLoadedInitial(items.length),
      );
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
    if (session == null || _notifications.isEmpty) return;

    setState(() => _isLoadingMore = true);
    try {
      final items = await widget.app.mastodon.fetchNotifications(
        instanceUrl: session.instanceUrl,
        accessToken: session.accessToken,
        maxId: _notifications.last.id,
      );
      if (!mounted) return;
      final hasMore = items.length >= 15;
      _seedNotificationStatuses(items);
      final combined = widget.app.timelineCache.appendOlderNotifications(
        items,
        hasMore: hasMore,
      );
      setState(() {
        _notifications = combined;
        _isLoadingMore = false;
        _hasMore = hasMore;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingMore = false);
    }
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'mention':
        return Icons.alternate_email;
      case 'reblog':
        return Icons.repeat;
      case 'favourite':
        return Icons.star;
      case 'follow':
      case 'follow_request':
        return Icons.person_add;
      case 'status':
        return Icons.notifications_active;
      case 'quote':
      case 'quoted_update':
        return Icons.format_quote;
      default:
        return Icons.notifications;
    }
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
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh),
                label: Text(l10n.commonRetry),
              ),
            ],
          ),
        ),
      );
    }
    if (_notifications.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          children: [
            const SizedBox(height: 96),
            Center(child: Text(l10n.notificationsEmpty)),
          ],
        ),
      );
    }

    final fedi = context.fediColors;
    final scheme = Theme.of(context).colorScheme;

    return RefreshIndicator(
      onRefresh: _refreshIncremental,
      child: ListView.builder(
        controller: _scrollController,
        scrollCacheExtent: const ScrollCacheExtent.pixels(800),
        padding: const EdgeInsets.only(top: 6, bottom: 88),
        itemCount: _notifications.length + (_isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= _notifications.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            );
          }

          final item = _notifications[index];
          final relTime = TimeUtils.formatRelativeCompact(
            item.createdAt,
            l10n: l10n,
          );
          final isSelected = _selectedIndex == index;

          return Card(
            key: _keyForNotification(item.id),
            shape: isSelected
                ? RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: scheme.primary, width: 2.5),
                  )
                : null,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        _iconForType(item.type),
                        size: 20,
                        color: scheme.primary,
                      ),
                      const SizedBox(width: 8),
                      AccessibleAvatar(
                        imageUrl: item.account.avatar,
                        displayName: item.account.effectiveDisplayName,
                        radius: 18,
                        onTap: () =>
                            _actions.openProfile(context, item.account),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: AccessibleTip(
                          message: l10n.avatarViewProfileSemantics(
                            item.account.effectiveDisplayName,
                          ),
                          child: InkWell(
                            onTap: () =>
                                _actions.openProfile(context, item.account),
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.localizedSummary(l10n),
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleSmall
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  '${item.account.handle} · $relTime',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(color: fedi.subtleText),
                                ),
                              ],
                            ),
                          ),
                        ),
                        ),
                      ),
                    ],
                  ),
                  if (item.status != null) ...[
                    const SizedBox(height: 8),
                    AccessibleTip(
                      message: l10n.notificationsOpenThreadTip,
                      child: InkWell(
                        onTap: () => _actions.openThread(context, item.status!),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: scheme.surface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: fedi.cardBorder),
                        ),
                        child: item.status!.plainText.isNotEmpty
                            ? LinkifiedText.html(
                                item.status!.contentHtml,
                                maxLines: 4,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodyMedium,
                                mentions: item.status!.mentions,
                                onTapMention: (mention) => _actions.openProfile(
                                  context,
                                  mention.toStubAccount(),
                                ),
                              )
                            : Text(
                                l10n.notificationsMediaPostPlaceholder,
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                      ),
                    ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
