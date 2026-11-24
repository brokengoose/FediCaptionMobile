// Copyright (c) 2026 brokengoose <brokengoose@users.noreply.github.com>
// SPDX-License-Identifier: MIT

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/accessibility_announcer.dart';
import '../../l10n/l10n.dart';
import '../../models/mastodon_models.dart';
import '../../state/app_controller.dart';
import '../helpers/keyboard_shortcuts.dart';
import '../helpers/status_action_handler.dart';
import '../widgets/status_card.dart';

/// Displays a conversation thread (`GET /api/v1/statuses/{id}/context`).
class ThreadScreen extends StatefulWidget {
  const ThreadScreen({
    super.key,
    required this.app,
    required this.rootStatus,
  });

  final AppController app;
  final MastodonStatus rootStatus;

  @override
  State<ThreadScreen> createState() => _ThreadScreenState();
}

class _ThreadScreenState extends State<ThreadScreen> {
  late final StatusActionHandler _actions;
  late MastodonStatus _focalStatus;
  List<MastodonStatus> _ancestors = [];
  List<MastodonStatus> _descendants = [];
  bool _isLoading = true;
  String? _error;

  int _selectedIndex = 0;
  final Map<String, GlobalKey> _itemKeys = {};
  final Set<String> _expandedCwIds = {};

  List<MastodonStatus> get _allOrderedStatuses => [
        ..._ancestors,
        _focalStatus,
        ..._descendants,
      ];

  @override
  void initState() {
    super.initState();
    _actions = StatusActionHandler(app: widget.app);
    _focalStatus = widget.rootStatus.displayStatus;
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
    _loadContext();
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    super.dispose();
  }

  GlobalKey _keyForStatus(String id) =>
      _itemKeys.putIfAbsent(id, () => GlobalKey());

  MastodonStatus? get _selectedStatus {
    final all = _allOrderedStatuses;
    if (all.isEmpty) return null;
    final idx = _selectedIndex.clamp(0, all.length - 1);
    return all[idx];
  }

  void _moveSelection(int delta) {
    final all = _allOrderedStatuses;
    if (all.isEmpty) return;
    final next = (_selectedIndex + delta).clamp(0, all.length - 1);
    setState(() => _selectedIndex = next);
    final status = all[next];
    final key = _itemKeys[status.id];
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) KeyboardNavHelper.ensureKeyVisible(key);
    });
    AccessibilityAnnouncer.announce(
      context.l10n.threadAnnounceSelection(
        next + 1,
        all.length,
        status.displayStatus.account.effectiveDisplayName,
      ),
    );
  }

  bool _handleKeyEvent(KeyEvent event) {
    return KeyboardNavHelper.handleStatusFeedKeyEvent(
      event,
      isActive: () => mounted && (ModalRoute.of(context)?.isCurrent ?? false),
      onNext: () => _moveSelection(1),
      onPrevious: () => _moveSelection(-1),
      onOpen: () {
        final st = _selectedStatus;
        if (st != null) {
          _actions.openThread(context, st, skipIfStatusId: _focalStatus.id);
        }
      },
      onReply: () async {
        final st = _selectedStatus;
        if (st == null) return;
        final posted = await _actions.openReply(context, st);
        if (posted != null && mounted) _loadContext();
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
      onOpenProfile: () {
        final st = _selectedStatus;
        if (st != null) _actions.openProfile(context, st.displayStatus.account);
      },
      onRefresh: _loadContext,
      onShowHelp: () => KeyboardShortcutsDialog.show(context),
      onEscape: () => Navigator.of(context).maybePop(),
    );
  }

  Future<void> _loadContext() async {
    final session = widget.app.session;
    if (session == null) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final ctx = await widget.app.mastodon.fetchStatusContext(
        instanceUrl: session.instanceUrl,
        accessToken: session.accessToken,
        statusId: _focalStatus.id,
      );
      if (!mounted) return;
      widget.app.quoteCache.seedStatuses([
        _focalStatus,
        ...ctx.ancestors,
        ...ctx.descendants,
      ]);
      setState(() {
        _ancestors = ctx.ancestors;
        _descendants = ctx.descendants;
        _selectedIndex = ctx.ancestors.length;
        _isLoading = false;
      });
      AccessibilityAnnouncer.announce(
        context.l10n.threadAnnounceLoaded(
          ctx.ancestors.length,
          ctx.descendants.length,
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

  void _replaceStatus(MastodonStatus updated) {
    if (!mounted) return;
    setState(() {
      if (_focalStatus.id == updated.id) _focalStatus = updated;
      _ancestors = StatusActionHandler.replaceInList(_ancestors, updated);
      _descendants = StatusActionHandler.replaceInList(_descendants, updated);
    });
  }

  Future<void> _deleteStatus(MastodonStatus target) async {
    final deleted = await _actions.confirmAndDelete(context, target);
    if (!deleted || !mounted) return;

    if (target.id == _focalStatus.id) {
      widget.app.notifyTimelinesShouldRefresh();
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _ancestors = StatusActionHandler.removeFromList(_ancestors, target.id);
      _descendants = StatusActionHandler.removeFromList(_descendants, target.id);
    });
  }

  Widget _buildCard(
    MastodonStatus status, {
    required int flatIndex,
    bool highlight = false,
  }) {
    final target = status.displayStatus;
    final card = StatusCard(
      key: _keyForStatus(status.id),
      status: status,
      app: widget.app,
      enableTranslationOffer: highlight,
      enableReadAloud: highlight,
      isKeyboardSelected: _selectedIndex == flatIndex,
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
      onOpenThread: (st) => _actions.openThread(
        context,
        st,
        skipIfStatusId: _focalStatus.id,
      ),
      onReply: (st) async {
        final posted = await _actions.openReply(context, st);
        if (posted != null && mounted) {
          _loadContext();
        }
      },
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

    if (!highlight) return card;
    return Container(
      decoration: BoxDecoration(
        border: BorderDirectional(
          start: BorderSide(
            color: Theme.of(context).colorScheme.primary,
            width: 4,
          ),
        ),
      ),
      child: card,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.threadTitle)),
      body: RefreshIndicator(
        onRefresh: _loadContext,
        child: ListView(
          padding: const EdgeInsets.only(top: 6, bottom: 48),
          children: [
            for (var i = 0; i < _ancestors.length; i++)
              _buildCard(_ancestors[i], flatIndex: i),
            _buildCard(
              _focalStatus,
              flatIndex: _ancestors.length,
              highlight: true,
            ),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.all(20),
                child: Center(child: CircularProgressIndicator()),
              ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(_error!, textAlign: TextAlign.center),
              ),
            if (_descendants.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Semantics(
                  header: true,
                  child: Text(
                    l10n.threadRepliesHeader(_descendants.length),
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              for (var i = 0; i < _descendants.length; i++)
                _buildCard(
                  _descendants[i],
                  flatIndex: _ancestors.length + 1 + i,
                ),
            ],
          ],
        ),
      ),
    );
  }
}
