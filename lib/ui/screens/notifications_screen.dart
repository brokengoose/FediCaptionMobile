// Copyright (c) 2026 brokengoose <brokengoose@users.noreply.github.com>
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';

import '../../core/accessibility_announcer.dart';
import '../../core/theme/app_theme.dart';
import '../../core/time_utils.dart';
import '../../models/mastodon_models.dart';
import '../../state/app_controller.dart';
import '../widgets/accessible_avatar.dart';
import 'profile_screen.dart';
import 'thread_screen.dart';

/// Displays Mastodon notifications (`GET /api/v1/notifications`) with clickable
/// user avatars/handles and direct thread navigation.
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
  List<MastodonNotification> _notifications = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final session = widget.app.session;
    if (session == null) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final items = await widget.app.mastodon.fetchNotifications(
        instanceUrl: session.instanceUrl,
        accessToken: session.accessToken,
      );
      if (!mounted) return;
      setState(() {
        _notifications = items;
        _isLoading = false;
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
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.only(top: 6, bottom: 88),
        itemCount: _notifications.length,
        itemBuilder: (context, index) {
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
                        onTap: () => _openProfile(item.account),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: InkWell(
                          onTap: () => _openProfile(item.account),
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
                      onTap: () => _openThread(item.status!),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: scheme.surface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: fedi.cardBorder),
                        ),
                        child: Text(
                          item.status!.plainText.isNotEmpty
                              ? item.status!.plainText
                              : '(Media post)',
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
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
