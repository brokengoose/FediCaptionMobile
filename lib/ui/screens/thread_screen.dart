// Copyright (c) 2026 brokengoose <brokengoose@users.noreply.github.com>
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';

import '../../core/accessibility_announcer.dart';
import '../../models/mastodon_models.dart';
import '../../state/app_controller.dart';
import '../widgets/status_card.dart';
import 'composer_screen.dart';
import 'profile_screen.dart';

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
  late MastodonStatus _focalStatus;
  List<MastodonStatus> _ancestors = [];
  List<MastodonStatus> _descendants = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
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
    setState(() {
      if (_focalStatus.id == updated.id) _focalStatus = updated;
      _ancestors =
          _ancestors.map((s) => s.id == updated.id ? updated : s).toList();
      _descendants =
          _descendants.map((s) => s.id == updated.id ? updated : s).toList();
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
    if (target.id == _focalStatus.id) {
      widget.app.notifyTimelinesShouldRefresh();
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _ancestors = _ancestors.where((s) => s.id != target.id).toList();
      _descendants = _descendants.where((s) => s.id != target.id).toList();
    });
  }

  Widget _buildCard(MastodonStatus status, {bool highlight = false}) {
    final card = StatusCard(
      status: status,
      app: widget.app,
      onOpenProfile: (acc) => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ProfileScreen(
            app: widget.app,
            accountId: acc.id,
            initialAccount: acc,
          ),
        ),
      ),
      onOpenThread: (st) {
        if (st.id == _focalStatus.id) return;
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => ThreadScreen(app: widget.app, rootStatus: st),
          ),
        );
      },
      onReply: (st) async {
        final posted = await Navigator.of(context).push<MastodonStatus>(
          MaterialPageRoute<MastodonStatus>(
            builder: (_) => ComposerScreen(app: widget.app, replyToStatus: st),
          ),
        );
        if (posted != null) {
          _loadContext();
        }
      },
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
      onEdit: (st) async {
        final edited = await Navigator.of(context).push<MastodonStatus>(
          MaterialPageRoute<MastodonStatus>(
            builder: (_) => ComposerScreen(app: widget.app, editingStatus: st),
          ),
        );
        if (edited != null) {
          _replaceStatus(edited.displayStatus);
        }
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
