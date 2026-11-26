// Copyright (c) 2026 brokengoose <brokengoose@users.noreply.github.com>
// SPDX-License-Identifier: MIT

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_theme.dart';
import '../../l10n/l10n.dart';
import '../../models/mastodon_models.dart';
import '../../state/app_controller.dart';
import '../helpers/keyboard_shortcuts.dart';
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
  final ScrollController _scrollController = ScrollController();
  late final StatusActionHandler _actions;
  List<MastodonStatus> _results = const [];

  @override
  void initState() {
    super.initState();
    _actions = StatusActionHandler(app: widget.app);
    _queryController.addListener(_onQueryChanged);
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
  }

  void _onQueryChanged() {
    setState(() {
      _results = widget.app.timelineCache.searchLocal(_queryController.text);
    });
  }

  bool _handleKeyEvent(KeyEvent event) {
    if (!mounted || (event is! KeyDownEvent && event is! KeyRepeatEvent)) {
      return false;
    }
    if (ModalRoute.of(context)?.isCurrent != true) return false;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.escape && event is KeyDownEvent) {
      Navigator.of(context).maybePop();
      return true;
    }
    if (KeyboardNavHelper.hasNoCommandModifiers() &&
        !HardwareKeyboard.instance.isShiftPressed &&
        _results.isNotEmpty) {
      if (key == LogicalKeyboardKey.pageDown) {
        KeyboardNavHelper.scrollByPage(_scrollController, direction: 1);
        return true;
      }
      if (key == LogicalKeyboardKey.pageUp) {
        KeyboardNavHelper.scrollByPage(_scrollController, direction: -1);
        return true;
      }
      if (key == LogicalKeyboardKey.home &&
          event is KeyDownEvent &&
          !KeyboardNavHelper.isTextInputFocused()) {
        KeyboardNavHelper.scrollToTop(_scrollController);
        return true;
      }
    }
    return false;
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    _queryController.removeListener(_onQueryChanged);
    _queryController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fedi = context.fediColors;
    final l10n = context.l10n;
    final indexedCount = widget.app.timelineCache.totalCachedPostCount;
    final query = _queryController.text.trim();

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _queryController,
          autofocus: true,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: l10n.searchHint(indexedCount),
            border: InputBorder.none,
            suffixIcon: query.isNotEmpty
                ? IconButton(
                    tooltip: l10n.searchClearTooltip,
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
                      l10n.searchEmptyTitle(indexedCount),
                      style: Theme.of(context).textTheme.titleMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.searchEmptyDescription,
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
                      l10n.searchNoResults(query),
                      style: Theme.of(context).textTheme.bodyLarge,
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : ListView.builder(
                  controller: _scrollController,
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
