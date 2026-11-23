// Copyright (c) 2026 brokengoose <brokengoose@users.noreply.github.com>
// SPDX-License-Identifier: MIT

import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_theme.dart';
import '../../models/mastodon_models.dart';
import '../../state/app_controller.dart';
import '../helpers/status_action_handler.dart';
import '../widgets/status_card.dart';

/// Instant client-side search screen over locally cached timelines, bookmarks,
/// favorites, notifications, and media alt-text — zero Mastodon server load.
class LocalSearchScreen extends StatefulWidget {
  const LocalSearchScreen({
    super.key,
    required this.app,
  });

  final AppController app;

  @override
  State<LocalSearchScreen> createState() => _LocalSearchScreenState();
}

class _LocalSearchScreenState extends State<LocalSearchScreen> {
  final TextEditingController _queryController = TextEditingController();
  late final StatusActionHandler _actions;
  List<MastodonStatus> _results = const [];

  @override
  void initState() {
    super.initState();
    _actions = StatusActionHandler(app: widget.app);
    _queryController.addListener(_onQueryChanged);
  }

  void _onQueryChanged() {
    setState(() {
      _results = widget.app.timelineCache.searchLocal(_queryController.text);
    });
  }

  @override
  void dispose() {
    _queryController.removeListener(_onQueryChanged);
    _queryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fedi = context.fediColors;
    final indexedCount = widget.app.timelineCache.totalCachedPostCount;
    final query = _queryController.text.trim();

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _queryController,
          autofocus: true,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: 'Search $indexedCount cached posts & alt-text…',
            border: InputBorder.none,
            suffixIcon: query.isNotEmpty
                ? IconButton(
                    tooltip: 'Clear search',
                    icon: const Icon(Icons.clear),
                    onPressed: _queryController.clear,
                  )
                : null,
          ),
        ),
      ),
      body: query.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.search, size: 48, color: fedi.subtleText),
                    const SizedBox(height: 12),
                    Text(
                      'Offline Local Search ($indexedCount cached posts)',
                      style: Theme.of(context).textTheme.titleMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Searches post text, Content Warnings, authors, and media alt-text locally on your device without placing any search load on your Mastodon server.',
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: fedi.subtleText),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          : _results.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'No cached posts match "$query".',
                      style: Theme.of(context).textTheme.bodyLarge,
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.only(top: 6, bottom: 32),
                  itemCount: _results.length,
                  itemBuilder: (context, index) {
                    final status = _results[index];
                    return RepaintBoundary(
                      key: ValueKey('search_${status.id}'),
                      child: StatusCard(
                        status: status,
                        app: widget.app,
                        onOpenProfile: (acc) =>
                            _actions.openProfile(context, acc),
                        onOpenThread: (st) => _actions.openThread(context, st),
                        onReply: (st) => _actions.openReply(context, st),
                        onToggleBoost: (st) async {
                          final updated =
                              await _actions.toggleBoost(context, st);
                          if (updated != null) {
                            widget.app.timelineCache
                                .updateStatusEverywhere(updated);
                            _onQueryChanged();
                          }
                        },
                        onToggleFavorite: (st) async {
                          final updated =
                              await _actions.toggleFavorite(context, st);
                          if (updated != null) {
                            widget.app.timelineCache
                                .updateStatusEverywhere(updated);
                            _onQueryChanged();
                          }
                        },
                        onToggleBookmark: (st) async {
                          final updated =
                              await _actions.toggleBookmark(context, st);
                          if (updated != null) {
                            widget.app.timelineCache
                                .updateStatusEverywhere(updated);
                            _onQueryChanged();
                          }
                        },
                        onEdit: (st) => _actions.openEdit(context, st),
                        onDelete: (st) async {
                          final deleted =
                              await _actions.confirmAndDelete(context, st);
                          if (deleted) {
                            widget.app.timelineCache
                                .removeStatusEverywhere(st.id);
                            _onQueryChanged();
                          }
                        },
                      ),
                    );
                  },
                ),
    );
  }
}
