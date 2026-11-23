// Copyright (c) 2026 brokengoose <brokengoose@users.noreply.github.com>
// SPDX-License-Identifier: MIT

import 'package:material_ui/material_ui.dart';

import '../../core/accessibility_announcer.dart';
import '../../models/mastodon_models.dart';
import '../../state/app_controller.dart';
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

  @override
  void initState() {
    super.initState();
    _actions = StatusActionHandler(app: widget.app);
    _focalStatus = widget.rootStatus.displayStatus;
    _loadContext();
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
        _isLoading = false;
      });
      AccessibilityAnnouncer.announce(
        'Conversation loaded with ${ctx.ancestors.length} earlier posts and ${ctx.descendants.length} replies.',
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

  Widget _buildCard(MastodonStatus status, {bool highlight = false}) {
    final card = StatusCard(
      status: status,
      app: widget.app,
      enableTranslationOffer: highlight,
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
        border: Border(
          left: BorderSide(
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
    return Scaffold(
      appBar: AppBar(title: const Text('Conversation Thread')),
      body: RefreshIndicator(
        onRefresh: _loadContext,
        child: ListView(
          padding: const EdgeInsets.only(top: 6, bottom: 48),
          children: [
            for (final ancestor in _ancestors) _buildCard(ancestor),
            _buildCard(_focalStatus, highlight: true),
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
                    'Replies (${_descendants.length})',
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              for (final reply in _descendants) _buildCard(reply),
            ],
          ],
        ),
      ),
    );
  }
}
