// Copyright (c) 2026 brokengoose <brokengoose@users.noreply.github.com>
// SPDX-License-Identifier: MIT

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/accessibility_announcer.dart';
import '../../core/constants.dart';
import '../../core/theme/app_theme.dart';
import '../../l10n/l10n.dart';
import '../../l10n/model_localizations.dart';
import '../../models/mastodon_models.dart';
import '../../state/app_controller.dart';
import '../helpers/keyboard_shortcuts.dart';
import '../widgets/accessible_avatar.dart';
import '../widgets/accessible_tip.dart';
import '../widgets/account_switcher_sheet.dart';
import '../widgets/update_banner.dart';
import 'composer_screen.dart';
import 'local_search_screen.dart';
import 'notifications_screen.dart';
import 'settings_screen.dart';
import 'timeline_screen.dart';

/// Main logged-in shell displaying:
/// - Logged-in user's profile picture & username in upper-left/top area (tap -> My Published Posts)
/// - Dismissible GitHub Update Available banner
/// - Full timeline switcher (Home, Local, Federated, Notifications, Bookmarks, Favorites, My Published Posts)
/// - Accessible Compose button and Settings screen access
class HomeShell extends StatefulWidget {
  const HomeShell({
    super.key,
    required this.app,
  });

  final AppController app;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  TimelineType _selectedTimeline = TimelineType.home;

  static const List<TimelineType> _primaryTabs = [
    TimelineType.home,
    TimelineType.local,
    TimelineType.federated,
    TimelineType.notifications,
  ];

  static const List<TimelineType> _desktopDestinations = [
    TimelineType.home,
    TimelineType.local,
    TimelineType.federated,
    TimelineType.notifications,
    TimelineType.bookmarks,
    TimelineType.favorites,
    TimelineType.myPosts,
  ];

  void _selectTimeline(TimelineType type) {
    setState(() => _selectedTimeline = type);
    final l10n = context.l10n;
    AccessibilityAnnouncer.announce(
      l10n.homeAnnounceSwitchedTimeline(type.localizedFullTitle(l10n)),
    );
  }

  void _openComposer() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ComposerScreen(app: widget.app),
      ),
    );
  }

  void _openLocalSearch() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LocalSearchScreen(app: widget.app),
      ),
    );
  }

  void _openSettings() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SettingsScreen(app: widget.app),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_handleShellKeyEvent);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleShellKeyEvent);
    KeyboardNavHelper.cancelGoChord();
    super.dispose();
  }

  bool _handleShellKeyEvent(KeyEvent event) {
    if (!mounted || event is! KeyDownEvent) return false;
    final route = ModalRoute.of(context);
    if (route == null || !route.isCurrent) return false;
    if (KeyboardNavHelper.isTextInputFocused()) return false;

    final key = event.logicalKey;

    // Complete a pending `g <key>` timeline chord first.
    if (KeyboardNavHelper.isGoChordActive) {
      KeyboardNavHelper.cancelGoChord();
      final target = switch (key) {
        LogicalKeyboardKey.keyH => TimelineType.home,
        LogicalKeyboardKey.keyL => TimelineType.local,
        LogicalKeyboardKey.keyP => TimelineType.federated,
        LogicalKeyboardKey.keyN => TimelineType.notifications,
        LogicalKeyboardKey.keyB => TimelineType.bookmarks,
        LogicalKeyboardKey.keyF => TimelineType.favorites,
        LogicalKeyboardKey.keyU => TimelineType.myPosts,
        _ => null,
      };
      if (target != null) {
        _selectTimeline(target);
        return true;
      }
      return false;
    }

    // Platform modifier shortcuts (`⌘N`, `⌘F`, `⌘,`).
    if (KeyboardNavHelper.isPrimaryModifierPressed()) {
      if (key == LogicalKeyboardKey.keyN) {
        _openComposer();
        return true;
      }
      if (key == LogicalKeyboardKey.keyF) {
        _openLocalSearch();
        return true;
      }
      if (key == LogicalKeyboardKey.comma) {
        _openSettings();
        return true;
      }
      return false;
    }

    if (!KeyboardNavHelper.hasNoCommandModifiers()) return false;
    final shiftPressed = HardwareKeyboard.instance.isShiftPressed;

    // `?` shows the Keyboard Shortcuts reference dialog.
    if (key == LogicalKeyboardKey.question ||
        (key == LogicalKeyboardKey.slash && shiftPressed)) {
      KeyboardShortcutsDialog.show(context);
      return true;
    }

    if (shiftPressed) return false;

    if (key == LogicalKeyboardKey.keyG) {
      KeyboardNavHelper.beginGoChord();
      return true;
    }
    if (key == LogicalKeyboardKey.keyN) {
      _openComposer();
      return true;
    }
    if (key == LogicalKeyboardKey.slash) {
      _openLocalSearch();
      return true;
    }

    // Number keys 1-7 jump directly to timelines.
    final quickTimeline = switch (key) {
      LogicalKeyboardKey.digit1 => TimelineType.home,
      LogicalKeyboardKey.digit2 => TimelineType.local,
      LogicalKeyboardKey.digit3 => TimelineType.federated,
      LogicalKeyboardKey.digit4 => TimelineType.notifications,
      LogicalKeyboardKey.digit5 => TimelineType.bookmarks,
      LogicalKeyboardKey.digit6 => TimelineType.favorites,
      LogicalKeyboardKey.digit7 => TimelineType.myPosts,
      _ => null,
    };
    if (quickTimeline != null) {
      _selectTimeline(quickTimeline);
      return true;
    }

    return false;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ListenableBuilder(
      listenable: widget.app,
      builder: (context, _) {
        final account = widget.app.currentAccount;
        final activeHandle = widget.app.activeAccountFullHandle;
        final hasMultipleAccounts = widget.app.hasMultipleAccounts;
        final accountCacheSuffix =
            '${widget.app.activeAccountKey ?? ''}_${widget.app.accountGeneration}';
        final update = widget.app.visibleUpdate;
        final fedi = context.fediColors;
        final screenWidth = MediaQuery.sizeOf(context).width;
        final isWideLayout = screenWidth >= 840;
        final isExtendedRail = screenWidth >= 1100;

        final primaryIndex = _primaryTabs.indexOf(_selectedTimeline);
        final desktopIndex = _desktopDestinations.indexOf(_selectedTimeline);
        final selectedFullTitle = _selectedTimeline.localizedFullTitle(l10n);

        final contentColumn = Column(
          children: [
            if (widget.app.isSwitchingAccount) const LinearProgressIndicator(),
            // Dismissible GitHub Update Available banner
            if (update != null)
              UpdateBanner(
                update: update,
                onDismiss: widget.app.dismissUpdateBanner,
              ),
            Expanded(
              child: _selectedTimeline == TimelineType.notifications
                  ? NotificationsScreen(
                      key: ValueKey('notifications_$accountCacheSuffix'),
                      app: widget.app,
                    )
                  : TimelineScreen(
                      key: ValueKey('timeline_$accountCacheSuffix'),
                      app: widget.app,
                      timelineType: _selectedTimeline,
                    ),
            ),
          ],
        );

        return Scaffold(
          appBar: AppBar(
            leadingWidth: isWideLayout ? null : 56,
            automaticallyImplyLeading: !isWideLayout,
            titleSpacing: isWideLayout ? 16 : 4,
            // Upper-left logged-in profile header: tapping immediately shows My Published Posts
            title: account == null
                ? Text(selectedFullTitle)
                : Semantics(
                    button: true,
                    label: l10n.homeProfileHeaderSemantics(
                      account.effectiveDisplayName,
                      activeHandle,
                    ),
                    child: AccessibleTip(
                      message: l10n.homeProfileHeaderTip(activeHandle),
                      child: InkWell(
                        onTap: () => _selectTimeline(TimelineType.myPosts),
                      borderRadius: BorderRadius.circular(10),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          minHeight: AppConstants.minTouchTargetSize,
                        ),
                        child: Row(
                          children: [
                            AccessibleAvatar(
                              imageUrl: account.avatar,
                              displayName: account.effectiveDisplayName,
                              radius: 18,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    selectedFullTitle,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(fontWeight: FontWeight.bold),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    activeHandle,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(color: fedi.subtleText),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            actions: [
              if (account != null)
                hasMultipleAccounts
                    ? Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Semantics(
                          button: true,
                          label: l10n.accountsSwitchTooltip(activeHandle),
                          child: AccessibleTip(
                            message: l10n.accountsSwitchTooltip(activeHandle),
                            child: OutlinedButton(
                              onPressed: () => AccountSwitcherSheet.show(
                                context,
                                widget.app,
                              ),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                visualDensity: VisualDensity.compact,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  AccessibleAvatar(
                                    imageUrl: account.avatar,
                                    displayName: account.effectiveDisplayName,
                                    radius: 12,
                                  ),
                                  const SizedBox(width: 6),
                                  ConstrainedBox(
                                    constraints: BoxConstraints(
                                      maxWidth: isWideLayout ? 200 : 96,
                                    ),
                                    child: Text(
                                      isWideLayout
                                          ? activeHandle
                                          : account.handle,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(Icons.unfold_more, size: 18),
                                ],
                              ),
                            ),
                          ),
                        ),
                      )
                    : AccessibleTip(
                        message: l10n.accountsManageTooltip,
                        child: IconButton(
                          icon: const Icon(Icons.switch_account_outlined),
                          onPressed: () =>
                              AccountSwitcherSheet.show(context, widget.app),
                        ),
                      ),
              AccessibleTip(
                message: l10n.homeSearchTooltip,
                child: IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: _openLocalSearch,
                ),
              ),
              if (isWideLayout)
                AccessibleTip(
                  message: l10n.homeShortcutsTooltip,
                  child: IconButton(
                    icon: const Icon(Icons.keyboard_outlined),
                    onPressed: () => KeyboardShortcutsDialog.show(context),
                  ),
                ),
              AccessibleTip(
                message: l10n.homeSettingsTooltip,
                child: IconButton(
                  icon: const Icon(Icons.settings_outlined),
                  onPressed: _openSettings,
                ),
              ),
            ],
          ),
          drawer: isWideLayout
              ? null
              : Drawer(
                  child: SafeArea(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  if (account != null)
                    InkWell(
                      onTap: () {
                        Navigator.of(context).pop();
                        _selectTimeline(TimelineType.myPosts);
                      },
                      child: DrawerHeader(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            AccessibleAvatar(
                              imageUrl: account.avatar,
                              displayName: account.effectiveDisplayName,
                              radius: 26,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              account.effectiveDisplayName,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              activeHandle,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: fedi.subtleText),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ),
                  _drawerItem(
                    icon: Icons.home_outlined,
                    selectedIcon: Icons.home,
                    type: TimelineType.home,
                  ),
                  _drawerItem(
                    icon: Icons.groups_outlined,
                    selectedIcon: Icons.groups,
                    type: TimelineType.local,
                  ),
                  _drawerItem(
                    icon: Icons.public_outlined,
                    selectedIcon: Icons.public,
                    type: TimelineType.federated,
                  ),
                  _drawerItem(
                    icon: Icons.notifications_outlined,
                    selectedIcon: Icons.notifications,
                    type: TimelineType.notifications,
                  ),
                  const Divider(),
                  _drawerItem(
                    icon: Icons.bookmark_outline,
                    selectedIcon: Icons.bookmark,
                    type: TimelineType.bookmarks,
                  ),
                  _drawerItem(
                    icon: Icons.star_outline,
                    selectedIcon: Icons.star,
                    type: TimelineType.favorites,
                  ),
                  _drawerItem(
                    icon: Icons.article_outlined,
                    selectedIcon: Icons.article,
                    type: TimelineType.myPosts,
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.switch_account_outlined),
                    title: Text(l10n.accountsSwitchOrAddLabel),
                    subtitle: hasMultipleAccounts ? Text(activeHandle) : null,
                    onTap: () {
                      Navigator.of(context).pop();
                      AccountSwitcherSheet.show(context, widget.app);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.settings_outlined),
                    title: Text(l10n.homeDrawerSettings),
                    onTap: () {
                      Navigator.of(context).pop();
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => SettingsScreen(app: widget.app),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          body: isWideLayout
              ? Row(
                  children: [
                    NavigationRail(
                      extended: isExtendedRail,
                      selectedIndex: desktopIndex >= 0 ? desktopIndex : 0,
                      onDestinationSelected: (idx) =>
                          _selectTimeline(_desktopDestinations[idx]),
                      destinations: [
                        NavigationRailDestination(
                          icon: AccessibleTip(
                            message: l10n.homeNavHomeTip,
                            child: const Icon(Icons.home_outlined),
                          ),
                          selectedIcon: AccessibleTip(
                            message: l10n.homeNavHomeTip,
                            child: const Icon(Icons.home),
                          ),
                          label: Text(
                            TimelineType.home.localizedShortLabel(l10n),
                          ),
                        ),
                        NavigationRailDestination(
                          icon: AccessibleTip(
                            message: l10n.homeNavLocalTip,
                            child: const Icon(Icons.groups_outlined),
                          ),
                          selectedIcon: AccessibleTip(
                            message: l10n.homeNavLocalTip,
                            child: const Icon(Icons.groups),
                          ),
                          label: Text(
                            TimelineType.local.localizedShortLabel(l10n),
                          ),
                        ),
                        NavigationRailDestination(
                          icon: AccessibleTip(
                            message: l10n.homeNavFederatedTip,
                            child: const Icon(Icons.public_outlined),
                          ),
                          selectedIcon: AccessibleTip(
                            message: l10n.homeNavFederatedTip,
                            child: const Icon(Icons.public),
                          ),
                          label: Text(
                            TimelineType.federated.localizedShortLabel(l10n),
                          ),
                        ),
                        NavigationRailDestination(
                          icon: AccessibleTip(
                            message: l10n.homeNavNotificationsTip,
                            child: const Icon(Icons.notifications_outlined),
                          ),
                          selectedIcon: AccessibleTip(
                            message: l10n.homeNavNotificationsTip,
                            child: const Icon(Icons.notifications),
                          ),
                          label: Text(
                            TimelineType.notifications.localizedShortLabel(l10n),
                          ),
                        ),
                        NavigationRailDestination(
                          icon: AccessibleTip(
                            message: l10n.homeNavBookmarksTip,
                            child: const Icon(Icons.bookmark_outline),
                          ),
                          selectedIcon: AccessibleTip(
                            message: l10n.homeNavBookmarksTip,
                            child: const Icon(Icons.bookmark),
                          ),
                          label: Text(
                            TimelineType.bookmarks.localizedShortLabel(l10n),
                          ),
                        ),
                        NavigationRailDestination(
                          icon: AccessibleTip(
                            message: l10n.homeNavFavoritesTip,
                            child: const Icon(Icons.star_outline),
                          ),
                          selectedIcon: AccessibleTip(
                            message: l10n.homeNavFavoritesTip,
                            child: const Icon(Icons.star),
                          ),
                          label: Text(
                            TimelineType.favorites.localizedShortLabel(l10n),
                          ),
                        ),
                        NavigationRailDestination(
                          icon: AccessibleTip(
                            message: l10n.homeNavMyPostsTip,
                            child: const Icon(Icons.article_outlined),
                          ),
                          selectedIcon: AccessibleTip(
                            message: l10n.homeNavMyPostsTip,
                            child: const Icon(Icons.article),
                          ),
                          label: Text(
                            TimelineType.myPosts.localizedShortLabel(l10n),
                          ),
                        ),
                      ],
                    ),
                    const VerticalDivider(width: 1),
                    Expanded(
                      child: contentColumn,
                    ),
                  ],
                )
              : contentColumn,
          floatingActionButton: AccessibleTip(
            message: l10n.homeComposeTip,
            preferBelow: false,
            child: FloatingActionButton.extended(
              onPressed: _openComposer,
              icon: const Icon(Icons.edit),
              label: Text(l10n.homeComposeLabel),
            ),
          ),
          bottomNavigationBar: isWideLayout
              ? null
              : NavigationBar(
                  selectedIndex: primaryIndex >= 0 ? primaryIndex : 0,
                  onDestinationSelected: (idx) =>
                      _selectTimeline(_primaryTabs[idx]),
                  destinations: [
                    NavigationDestination(
                      icon: const Icon(Icons.home_outlined),
                      selectedIcon: const Icon(Icons.home),
                      label: TimelineType.home.localizedShortLabel(l10n),
                    ),
                    NavigationDestination(
                      icon: const Icon(Icons.groups_outlined),
                      selectedIcon: const Icon(Icons.groups),
                      label: TimelineType.local.localizedShortLabel(l10n),
                    ),
                    NavigationDestination(
                      icon: const Icon(Icons.public_outlined),
                      selectedIcon: const Icon(Icons.public),
                      label: TimelineType.federated.localizedShortLabel(l10n),
                    ),
                    NavigationDestination(
                      icon: const Icon(Icons.notifications_outlined),
                      selectedIcon: const Icon(Icons.notifications),
                      label: TimelineType.notifications.localizedShortLabel(l10n),
                    ),
                  ],
                ),
        );
      },
    );
  }

  Widget _drawerItem({
    required IconData icon,
    required IconData selectedIcon,
    required TimelineType type,
  }) {
    final selected = _selectedTimeline == type;
    final l10n = context.l10n;
    return ListTile(
      leading: Icon(selected ? selectedIcon : icon),
      title: Text(type.localizedFullTitle(l10n)),
      selected: selected,
      onTap: () {
        Navigator.of(context).pop();
        _selectTimeline(type);
      },
    );
  }
}
