// Copyright (c) 2026 brokengoose <brokengoose@users.noreply.github.com>
// SPDX-License-Identifier: MIT

import 'package:material_ui/material_ui.dart';

import '../../core/constants.dart';
import '../../core/theme/app_theme.dart';
import '../../models/mastodon_models.dart';
import '../../state/app_controller.dart';
import '../widgets/accessible_avatar.dart';
import '../widgets/update_banner.dart';
import 'composer_screen.dart';
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

  void _selectTimeline(TimelineType type) {
    setState(() => _selectedTimeline = type);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.app,
      builder: (context, _) {
        final account = widget.app.currentAccount;
        final update = widget.app.visibleUpdate;
        final fedi = context.fediColors;

        final primaryIndex = _primaryTabs.indexOf(_selectedTimeline);

        return Scaffold(
          appBar: AppBar(
            leadingWidth: 56,
            titleSpacing: 4,
            // Upper-left logged-in profile header: tapping immediately shows My Published Posts
            title: account == null
                ? Text(_selectedTimeline.fullTitle)
                : Semantics(
                    button: true,
                    label:
                        '${account.effectiveDisplayName}, ${account.handle}. Tap to view your own published posts.',
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
                                    _selectedTimeline.fullTitle,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(fontWeight: FontWeight.bold),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    account.handle,
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
            actions: [
              IconButton(
                tooltip: 'Settings',
                icon: const Icon(Icons.settings_outlined),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => SettingsScreen(app: widget.app),
                  ),
                ),
              ),
            ],
          ),
          drawer: Drawer(
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
                              account.handle,
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
                    leading: const Icon(Icons.settings_outlined),
                    title: const Text('Settings & AI Configuration'),
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
          body: Column(
            children: [
              // Dismissible GitHub Update Available banner
              if (update != null)
                UpdateBanner(
                  update: update,
                  onDismiss: widget.app.dismissUpdateBanner,
                ),
              Expanded(
                child: _selectedTimeline == TimelineType.notifications
                    ? NotificationsScreen(app: widget.app)
                    : TimelineScreen(
                        app: widget.app,
                        timelineType: _selectedTimeline,
                      ),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => ComposerScreen(app: widget.app),
              ),
            ),
            icon: const Icon(Icons.edit),
            label: const Text('Post'),
            tooltip: 'Compose a new Mastodon post',
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: primaryIndex >= 0 ? primaryIndex : 0,
            onDestinationSelected: (idx) => _selectTimeline(_primaryTabs[idx]),
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home),
                label: 'Home',
              ),
              NavigationDestination(
                icon: Icon(Icons.groups_outlined),
                selectedIcon: Icon(Icons.groups),
                label: 'Local',
              ),
              NavigationDestination(
                icon: Icon(Icons.public_outlined),
                selectedIcon: Icon(Icons.public),
                label: 'Federated',
              ),
              NavigationDestination(
                icon: Icon(Icons.notifications_outlined),
                selectedIcon: Icon(Icons.notifications),
                label: 'Alerts',
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
    return ListTile(
      leading: Icon(selected ? selectedIcon : icon),
      title: Text(type.fullTitle),
      selected: selected,
      onTap: () {
        Navigator.of(context).pop();
        _selectTimeline(type);
      },
    );
  }
}
