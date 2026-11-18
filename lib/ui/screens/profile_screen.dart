// Copyright (c) 2026 brokengoose <brokengoose@users.noreply.github.com>
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';

import '../../core/accessibility_announcer.dart';
import '../../core/theme/app_theme.dart';
import '../../models/mastodon_models.dart';
import '../../state/app_controller.dart';
import '../widgets/accessible_avatar.dart';
import '../widgets/status_card.dart';
import 'composer_screen.dart';
import 'thread_screen.dart';

/// Displays any Mastodon user's profile and personal posts timeline
/// (`GET /api/v1/accounts/{id}` & `/statuses`), with a prominent Subscribe/Unsubscribe
/// button and Notifications bell toggle (`notify: true/false`) near the top (Section 6.4).
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    required this.app,
    required this.accountId,
    this.initialAccount,
  });

  final AppController app;
  final String accountId;
  final MastodonAccount? initialAccount;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  MastodonAccount? _account;
  MastodonRelationship? _relationship;
  List<MastodonStatus> _statuses = [];
  bool _isLoading = true;
  bool _isUpdatingFollow = false;
  String? _error;

  bool get _isOwnProfile => widget.app.currentAccount?.id == widget.accountId;

  @override
  void initState() {
    super.initState();
    _account = widget.initialAccount;
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
      final accountFuture = widget.app.mastodon.fetchAccount(
        instanceUrl: session.instanceUrl,
        accessToken: session.accessToken,
        accountId: widget.accountId,
      );
      final statusesFuture = widget.app.mastodon.fetchAccountStatuses(
        instanceUrl: session.instanceUrl,
        accessToken: session.accessToken,
        accountId: widget.accountId,
      );
      final relFuture = _isOwnProfile
          ? Future<MastodonRelationship?>.value(null)
          : widget.app.mastodon.fetchRelationship(
              instanceUrl: session.instanceUrl,
              accessToken: session.accessToken,
              accountId: widget.accountId,
            );

      final account = await accountFuture;
      final statuses = await statusesFuture;
      final rel = await relFuture;

      if (!mounted) return;
      setState(() {
        _account = account;
        _statuses = statuses;
        _relationship = rel;
        _isLoading = false;
      });
      AccessibilityAnnouncer.announce(
        'Loaded profile for ${account.effectiveDisplayName} with ${statuses.length} posts.',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleSubscribe() async {
    final session = widget.app.session;
    final rel = _relationship;
    if (session == null || _isUpdatingFollow) return;

    setState(() => _isUpdatingFollow = true);
    try {
      final MastodonRelationship updated;
      if (rel?.following == true || rel?.requested == true) {
        updated = await widget.app.mastodon.unfollowAccount(
          instanceUrl: session.instanceUrl,
          accessToken: session.accessToken,
          accountId: widget.accountId,
        );
        AccessibilityAnnouncer.announce(
          'Unsubscribed from ${_account?.effectiveDisplayName ?? 'user'}.',
        );
      } else {
        updated = await widget.app.mastodon.followAccount(
          instanceUrl: session.instanceUrl,
          accessToken: session.accessToken,
          accountId: widget.accountId,
        );
        AccessibilityAnnouncer.announce(
          'Subscribed to ${_account?.effectiveDisplayName ?? 'user'}.',
        );
      }
      if (!mounted) return;
      setState(() => _relationship = updated);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update subscription: $e')),
      );
    } finally {
      if (mounted) setState(() => _isUpdatingFollow = false);
    }
  }

  Future<void> _toggleNotifyBell() async {
    final session = widget.app.session;
    final rel = _relationship;
    if (session == null || rel == null || _isUpdatingFollow) return;

    setState(() => _isUpdatingFollow = true);
    try {
      final nextNotify = !rel.notifying;
      final updated = await widget.app.mastodon.followAccount(
        instanceUrl: session.instanceUrl,
        accessToken: session.accessToken,
        accountId: widget.accountId,
        notify: nextNotify,
      );
      if (!mounted) return;
      setState(() => _relationship = updated);
      AccessibilityAnnouncer.announce(
        nextNotify
            ? 'Notifications enabled for ${_account?.effectiveDisplayName ?? 'user'}.'
            : 'Notifications disabled for ${_account?.effectiveDisplayName ?? 'user'}.',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update notifications: $e')),
      );
    } finally {
      if (mounted) setState(() => _isUpdatingFollow = false);
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

  Future<void> _deleteStatus(MastodonStatus target) async {
    final session = widget.app.session;
    if (session == null) return;
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
  }

  @override
  Widget build(BuildContext context) {
    final account = _account;
    final rel = _relationship;
    final fedi = context.fediColors;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isOwnProfile
              ? 'My Published Posts'
              : (account?.effectiveDisplayName ?? 'Profile'),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 48),
          children: [
            if (account != null)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: fedi.cardBorder),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        AccessibleAvatar(
                          imageUrl: account.avatar,
                          displayName: account.effectiveDisplayName,
                          radius: 30,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                account.effectiveDisplayName,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleLarge
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              Text(
                                account.handle,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(color: fedi.subtleText),
                              ),
                              if (rel?.followedBy == true)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    'Follows you',
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(
                                          color: scheme.primary,
                                          fontWeight: FontWeight.bold,
                                        ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    // Prominent Subscribe / Unsubscribe & Notifications bell toggle (Section 6.4)
                    if (!_isOwnProfile) ...[
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: Semantics(
                              button: true,
                              toggled: rel?.following == true,
                              label: rel?.following == true
                                  ? 'Unsubscribe from ${account.effectiveDisplayName}'
                                  : (rel?.requested == true
                                      ? 'Follow request pending'
                                      : 'Subscribe to ${account.effectiveDisplayName}'),
                              child: rel?.following == true
                                  ? OutlinedButton.icon(
                                      onPressed: _isUpdatingFollow
                                          ? null
                                          : _toggleSubscribe,
                                      icon: const Icon(Icons.person_remove),
                                      label: const Text('Unsubscribe'),
                                    )
                                  : FilledButton.icon(
                                      onPressed: _isUpdatingFollow
                                          ? null
                                          : _toggleSubscribe,
                                      icon: const Icon(Icons.person_add),
                                      label: Text(
                                        rel?.requested == true
                                            ? 'Requested'
                                            : 'Subscribe',
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Semantics(
                            button: true,
                            toggled: rel?.notifying == true,
                            label: rel?.notifying == true
                                ? 'Disable post notifications for ${account.effectiveDisplayName}'
                                : 'Enable post notifications for ${account.effectiveDisplayName}',
                            child: IconButton.filledTonal(
                              onPressed: (_isUpdatingFollow ||
                                      rel?.following != true)
                                  ? null
                                  : _toggleNotifyBell,
                              tooltip: rel?.notifying == true
                                  ? 'Notifications On (tap to disable)'
                                  : 'Notifications Off (tap to enable)',
                              icon: Icon(
                                rel?.notifying == true
                                    ? Icons.notifications_active
                                    : Icons.notifications_none,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],

                    if (account.plainBio.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        account.plainBio,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],

                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 16,
                      runSpacing: 6,
                      children: [
                        Text(
                          '${account.statusesCount} Posts',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '${account.followingCount} Following',
                          style: TextStyle(color: fedi.subtleText),
                        ),
                        Text(
                          '${account.followersCount} Followers',
                          style: TextStyle(color: fedi.subtleText),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

            if (_isLoading)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Text(_error!, textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: _load,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              )
            else if (_statuses.isEmpty)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: Text('No posts published yet.')),
              )
            else
              for (final status in _statuses)
                StatusCard(
                  status: status,
                  app: widget.app,
                  onOpenProfile: (acc) {
                    if (acc.id == widget.accountId) return;
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => ProfileScreen(
                          app: widget.app,
                          accountId: acc.id,
                          initialAccount: acc,
                        ),
                      ),
                    );
                  },
                  onOpenThread: (st) => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          ThreadScreen(app: widget.app, rootStatus: st),
                    ),
                  ),
                  onReply: (st) => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          ComposerScreen(app: widget.app, replyToStatus: st),
                    ),
                  ),
                  onToggleBoost: (st) async {
                    final s = widget.app.session;
                    if (s == null) return;
                    final updated = await widget.app.mastodon.toggleReblog(
                      instanceUrl: s.instanceUrl,
                      accessToken: s.accessToken,
                      statusId: st.id,
                      currentlyReblogged: st.reblogged,
                    );
                    _replaceStatus(updated.displayStatus);
                  },
                  onToggleFavorite: (st) async {
                    final s = widget.app.session;
                    if (s == null) return;
                    final updated = await widget.app.mastodon.toggleFavourite(
                      instanceUrl: s.instanceUrl,
                      accessToken: s.accessToken,
                      statusId: st.id,
                      currentlyFavourited: st.favourited,
                    );
                    _replaceStatus(updated.displayStatus);
                  },
                  onToggleBookmark: (st) async {
                    final s = widget.app.session;
                    if (s == null) return;
                    final updated = await widget.app.mastodon.toggleBookmark(
                      instanceUrl: s.instanceUrl,
                      accessToken: s.accessToken,
                      statusId: st.id,
                      currentlyBookmarked: st.bookmarked,
                    );
                    _replaceStatus(updated.displayStatus);
                  },
                  onEdit: (st) => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          ComposerScreen(app: widget.app, editingStatus: st),
                    ),
                  ),
                  onDelete: _deleteStatus,
                ),
          ],
        ),
      ),
    );
  }
}
