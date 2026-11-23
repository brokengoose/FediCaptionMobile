// Copyright (c) 2026 brokengoose <brokengoose@users.noreply.github.com>
// SPDX-License-Identifier: MIT

import 'package:material_ui/material_ui.dart';

import '../../core/accessibility_announcer.dart';
import '../../core/theme/app_theme.dart';
import '../../core/time_utils.dart';
import '../../models/mastodon_models.dart';
import '../../state/app_controller.dart';
import '../helpers/status_action_handler.dart';
import '../widgets/accessible_avatar.dart';
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

  @override
  void initState() {
    super.initState();
    _actions = StatusActionHandler(app: widget.app);
    _scrollController.addListener(_onScroll);
    _loadOrUseCache();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
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
        AccessibilityAnnouncer.announce(
          newer.isEmpty
              ? 'Notifications are up to date.'
              : 'Loaded ${newer.length} new notifications.',
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
        'Loaded ${items.length} notifications.',
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
                label: const Text('Retry'),
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
          children: const [
            SizedBox(height: 96),
            Center(child: Text('No notifications yet.')),
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
          final relTime = TimeUtils.formatRelativeCompact(item.createdAt);

          return Card(
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
                                  '${item.account.effectiveDisplayName} ${item.actionDescription}',
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
                    ],
                  ),
                  if (item.status != null) ...[
                    const SizedBox(height: 8),
                    InkWell(
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
                                '(Media post)',
                                style: Theme.of(context).textTheme.bodyMedium,
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
