// Copyright (c) 2026 brokengoose <brokengoose@users.noreply.github.com>
// SPDX-License-Identifier: MIT

import 'dart:async';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/accessibility_announcer.dart';
import '../../core/theme/app_theme.dart';
import '../../l10n/l10n.dart';
import '../../models/mastodon_models.dart';
import '../../state/app_controller.dart';
import '../helpers/keyboard_shortcuts.dart';
import '../helpers/status_action_handler.dart';
import '../widgets/accessible_avatar.dart';
import '../widgets/accessible_button_semantics.dart';
import '../widgets/linkified_text.dart';
import '../widgets/status_card.dart';

/// Displays any Mastodon user's profile and personal posts timeline
/// (`GET /api/v1/accounts/{id}` & `/statuses`), with a prominent Subscribe/Unsubscribe
/// button, Notifications bell toggle (`notify: true/false`), and lazy pagination.
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
  final ScrollController _scrollController = ScrollController();
  late final StatusActionHandler _actions;

  MastodonAccount? _account;
  MastodonRelationship? _relationship;
  List<MastodonStatus> _statuses = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  bool _isUpdatingFollow = false;
  String? _error;

  int? _selectedIndex;
  final Map<String, GlobalKey> _itemKeys = {};
  final Set<String> _expandedCwIds = {};

  bool get _isOwnProfile => widget.app.currentAccount?.id == widget.accountId;

  @override
  void initState() {
    super.initState();
    _actions = StatusActionHandler(app: widget.app);
    _account = widget.initialAccount;
    _scrollController.addListener(_onScroll);
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
    unawaited(_load());
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    _scrollController.dispose();
    super.dispose();
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
    final key = _itemKeys[status.id];
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) KeyboardNavHelper.ensureKeyVisible(key);
    });
    if (next >= _statuses.length - 3 && !_isLoadingMore && _hasMore) {
      unawaited(_loadMore());
    }

    // Same screen-reader feedback as the main timeline's j/k navigation.
    final target = status.displayStatus;
    final snippet = target.plainText.trim();
    final preview = snippet.length > 90
        ? '${snippet.substring(0, 90)}…'
        : snippet;
    AccessibilityAnnouncer.announce(
      context.l10n.timelineAnnouncePostSelection(
        next + 1,
        _statuses.length,
        target.account.effectiveDisplayName,
        preview,
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
        if (st != null) unawaited(_actions.openReply(context, st));
      },
      onFavorite: () async {
        final st = _selectedStatus?.displayStatus;
        if (st == null) return;
        final updated = await _actions.toggleFavorite(context, st);
        if (updated != null) _replaceStatus(updated);
      },
      onBoost: () async {
        final st = _selectedStatus?.displayStatus;
        if (st == null) return;
        final updated = await _actions.toggleBoost(context, st);
        if (updated != null) _replaceStatus(updated);
      },
      onBookmark: () async {
        final st = _selectedStatus?.displayStatus;
        if (st == null) return;
        final updated = await _actions.toggleBookmark(context, st);
        if (updated != null) _replaceStatus(updated);
      },
      onToggleCw: () {
        final target = _selectedStatus?.displayStatus;
        if (target == null || target.spoilerText.trim().isEmpty) return;
        setState(() {
          if (!_expandedCwIds.remove(target.id)) {
            _expandedCwIds.add(target.id);
          }
        });
      },
      onRefresh: _load,
      onShowHelp: () => KeyboardShortcutsDialog.show(context),
      onEscape: () => Navigator.of(context).maybePop(),
    );
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 320 &&
        !_isLoading &&
        !_isLoadingMore &&
        _hasMore &&
        _statuses.isNotEmpty) {
      unawaited(_loadMore());
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
          ? Future<MastodonRelationship?>.value()
          : widget.app.mastodon.fetchRelationship(
              instanceUrl: session.instanceUrl,
              accessToken: session.accessToken,
              accountId: widget.accountId,
            );

      final account = await accountFuture;
      final statuses = await statusesFuture;
      final rel = await relFuture;

      if (!mounted) return;
      widget.app.quoteCache.seedStatuses(statuses);
      setState(() {
        _account = account;
        _statuses = statuses;
        _relationship = rel;
        _isLoading = false;
        _hasMore = statuses.length >= 15;
      });
      AccessibilityAnnouncer.announce(
        context.l10n.profileAnnounceLoaded(
          account.effectiveDisplayName,
          statuses.length,
        ),
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
    if (session == null || _statuses.isEmpty) return;

    setState(() => _isLoadingMore = true);
    try {
      final items = await widget.app.mastodon.fetchAccountStatuses(
        instanceUrl: session.instanceUrl,
        accessToken: session.accessToken,
        accountId: widget.accountId,
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

  Future<void> _toggleSubscribe() async {
    final session = widget.app.session;
    final rel = _relationship;
    if (session == null || _isUpdatingFollow) return;

    setState(() => _isUpdatingFollow = true);
    final l10n = context.l10n;
    final targetName =
        _account?.effectiveDisplayName ?? l10n.commonUserFallback;
    try {
      final MastodonRelationship updated;
      if (rel?.following == true || rel?.requested == true) {
        updated = await widget.app.mastodon.unfollowAccount(
          instanceUrl: session.instanceUrl,
          accessToken: session.accessToken,
          accountId: widget.accountId,
        );
        AccessibilityAnnouncer.announce(
          l10n.profileAnnounceUnsubscribed(targetName),
        );
      } else {
        updated = await widget.app.mastodon.followAccount(
          instanceUrl: session.instanceUrl,
          accessToken: session.accessToken,
          accountId: widget.accountId,
        );
        // Locked accounts return `requested` instead of `following`.
        AccessibilityAnnouncer.announce(
          updated.requested && !updated.following
              ? l10n.profileAnnounceFollowRequested(targetName)
              : l10n.profileAnnounceSubscribed(targetName),
        );
      }
      if (!mounted) return;
      setState(() => _relationship = updated);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.profileErrorSubscription(e.toString()))),
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
    final l10n = context.l10n;
    final targetName =
        _account?.effectiveDisplayName ?? l10n.commonUserFallback;
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
            ? l10n.profileAnnounceNotifyEnabled(targetName)
            : l10n.profileAnnounceNotifyDisabled(targetName),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.profileErrorNotifications(e.toString()))),
      );
    } finally {
      if (mounted) setState(() => _isUpdatingFollow = false);
    }
  }

  void _replaceStatus(MastodonStatus updatedTarget) {
    if (!mounted) return;
    setState(() {
      _statuses = StatusActionHandler.replaceInList(_statuses, updatedTarget);
    });
  }

  Future<void> _deleteStatus(MastodonStatus target) async {
    final deleted = await _actions.confirmAndDelete(context, target);
    if (deleted && mounted) {
      setState(() {
        _statuses = StatusActionHandler.removeFromList(_statuses, target.id);
      });
    }
  }

  Widget _buildHeader(
    BuildContext context,
    MastodonAccount account,
    MastodonRelationship? rel,
  ) {
    final fedi = context.fediColors;
    final scheme = Theme.of(context).colorScheme;
    final l10n = context.l10n;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: fedi.cardBorder)),
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
                      style: Theme.of(context).textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      account.handle,
                      style: Theme.of(context).textTheme.bodyMedium
                          ?.copyWith(color: fedi.subtleText),
                    ),
                    if (rel?.followedBy == true)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          l10n.profileFollowsYou,
                          style: Theme.of(context).textTheme.labelSmall
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

          // Prominent Subscribe / Unsubscribe & Notifications bell toggle
          if (!_isOwnProfile) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: AccessibleButtonSemantics(
                    toggled: rel?.following == true,
                    onTap: _isUpdatingFollow ? null : _toggleSubscribe,
                    label: rel?.following == true
                        ? l10n.profileUnsubscribeSemantics(
                            account.effectiveDisplayName,
                          )
                        : (rel?.requested == true
                              ? l10n.profileRequestedSemantics
                              : l10n.profileSubscribeSemantics(
                                  account.effectiveDisplayName,
                                )),
                    child: rel?.following == true
                        ? OutlinedButton.icon(
                            onPressed: _isUpdatingFollow
                                ? null
                                : _toggleSubscribe,
                            icon: const Icon(Icons.person_remove),
                            label: Text(l10n.profileUnsubscribe),
                          )
                        : FilledButton.icon(
                            onPressed: _isUpdatingFollow
                                ? null
                                : _toggleSubscribe,
                            icon: const Icon(Icons.person_add),
                            label: Text(
                              rel?.requested == true
                                  ? l10n.profileRequested
                                  : l10n.profileSubscribe,
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 10),
                AccessibleButtonSemantics(
                  toggled: rel?.notifying == true,
                  onTap: (_isUpdatingFollow || rel?.following != true)
                      ? null
                      : _toggleNotifyBell,
                  label: rel?.notifying == true
                      ? l10n.profileDisableNotifySemantics(
                          account.effectiveDisplayName,
                        )
                      : l10n.profileEnableNotifySemantics(
                          account.effectiveDisplayName,
                        ),
                  child: IconButton.filledTonal(
                    onPressed: (_isUpdatingFollow || rel?.following != true)
                        ? null
                        : _toggleNotifyBell,
                    tooltip: rel?.notifying == true
                        ? l10n.profileNotifyOnTooltip
                        : l10n.profileNotifyOffTooltip,
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
            LinkifiedText.html(
              account.note,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],

          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 6,
            children: [
              Text(
                l10n.profilePostsCount(account.statusesCount),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                l10n.profileFollowingCount(account.followingCount),
                style: TextStyle(color: fedi.subtleText),
              ),
              Text(
                l10n.profileFollowersCount(account.followersCount),
                style: TextStyle(color: fedi.subtleText),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final account = _account;
    final rel = _relationship;
    final hasHeader = account != null;

    // Header slot + either a single status-state placeholder or lazy list of posts + optional loader.
    final int bodyCount = (_isLoading || _error != null || _statuses.isEmpty)
        ? 1
        : _statuses.length + (_isLoadingMore ? 1 : 0);
    final int totalCount = (hasHeader ? 1 : 0) + bodyCount;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isOwnProfile
              ? l10n.timelineMyPostsFull
              : (account?.effectiveDisplayName ?? l10n.profileTitle),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.only(bottom: 48),
          itemCount: totalCount,
          itemBuilder: (context, index) {
            if (hasHeader && index == 0) {
              return _buildHeader(context, account, rel);
            }
            final bodyIndex = hasHeader ? index - 1 : index;

            if (_isLoading) {
              return const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (_error != null) {
              return Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Text(_error!, textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: _load,
                      child: Text(l10n.commonRetry),
                    ),
                  ],
                ),
              );
            }
            if (_statuses.isEmpty) {
              return Padding(
                padding: const EdgeInsets.all(32),
                child: Center(child: Text(l10n.profileEmptyPosts)),
              );
            }
            if (bodyIndex >= _statuses.length) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              );
            }

            final status = _statuses[bodyIndex];
            final target = status.displayStatus;
            return StatusCard(
              key: _keyForStatus(status.id),
              status: status,
              app: widget.app,
              isKeyboardSelected: _selectedIndex == bodyIndex,
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
              onOpenProfile: (acc) => _actions.openProfile(
                context,
                acc,
                skipIfAccountId: widget.accountId,
              ),
              onOpenThread: (st) => _actions.openThread(context, st),
              onReply: (st) => _actions.openReply(context, st),
              onToggleBoost: (st) async {
                final updated = await _actions.toggleBoost(context, st);
                if (updated != null) _replaceStatus(updated);
              },
              onToggleFavorite: (st) async {
                final updated = await _actions.toggleFavorite(context, st);
                if (updated != null) _replaceStatus(updated);
              },
              onToggleBookmark: (st) async {
                final updated = await _actions.toggleBookmark(context, st);
                if (updated != null) _replaceStatus(updated);
              },
              onEdit: (st) async {
                final edited = await _actions.openEdit(context, st);
                if (edited != null) _replaceStatus(edited.displayStatus);
              },
              onDelete: _deleteStatus,
            );
          },
        ),
      ),
    );
  }
}
