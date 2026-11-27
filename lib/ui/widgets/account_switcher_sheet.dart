// Copyright (c) 2026 brokengoose <brokengoose@users.noreply.github.com>
// SPDX-License-Identifier: MIT

import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_theme.dart';
import '../../l10n/l10n.dart';
import '../../models/app_settings.dart';
import '../../state/app_controller.dart';
import '../screens/login_screen.dart';
import 'accessible_avatar.dart';

/// Modal bottom sheet showing all signed-in Mastodon accounts, highlighting the
/// active account & server and offering 1-tap switching, adding accounts, or
/// signing out of individual accounts.
class AccountSwitcherSheet extends StatelessWidget {
  const AccountSwitcherSheet({super.key, required this.app});

  final AppController app;

  static Future<void> show(BuildContext context, AppController app) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => AccountSwitcherSheet(app: app),
    );
  }

  Future<void> _switchTo(BuildContext context, StoredAccount target) async {
    final l10n = context.l10n;
    final ok = await app.switchAccount(target.key);
    if (!context.mounted) return;
    if (ok) {
      Navigator.of(context).pop();
    } else {
      final err = app.authError ?? '';
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.accountsSwitchError(err))));
    }
  }

  Future<void> _signOutAccount(
    BuildContext context,
    StoredAccount target,
  ) async {
    await app.logout(accountKey: target.key);
    if (!context.mounted) return;
    if (!app.isAuthenticated) {
      Navigator.of(context).pop();
    }
  }

  void _openAddAccount(BuildContext context) {
    final navigator = Navigator.of(context);
    navigator.pop();
    navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => LoginScreen(app: app, isAddingAccount: true),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final fedi = context.fediColors;

    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final accounts = app.accounts;
        final activeKey = app.activeAccountKey;
        final switching = app.isSwitchingAccount;

        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.78,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(Icons.switch_account, color: scheme.primary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Semantics(
                              header: true,
                              child: Text(
                                l10n.accountsSheetTitle,
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                            ),
                            Text(
                              l10n.accountsSheetSubtitle(accounts.length),
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: fedi.subtleText),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (switching) ...[
                    const SizedBox(height: 12),
                    const LinearProgressIndicator(),
                  ],
                  const SizedBox(height: 12),
                  for (final acc in accounts)
                    _AccountTile(
                      account: acc,
                      isActive: acc.key == activeKey,
                      enabled: !switching,
                      onSelect: () => _switchTo(context, acc),
                      onSignOut: () => _signOutAccount(context, acc),
                    ),
                  const SizedBox(height: 8),
                  const Divider(),
                  const SizedBox(height: 8),
                  FilledButton.tonalIcon(
                    onPressed: switching
                        ? null
                        : () => _openAddAccount(context),
                    icon: const Icon(Icons.person_add_outlined),
                    label: Text(l10n.accountsAddButton),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _AccountTile extends StatelessWidget {
  const _AccountTile({
    required this.account,
    required this.isActive,
    required this.enabled,
    required this.onSelect,
    required this.onSignOut,
  });

  final StoredAccount account;
  final bool isActive;
  final bool enabled;
  final VoidCallback onSelect;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final fedi = context.fediColors;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isActive ? scheme.primary : fedi.cardBorder,
          width: isActive || fedi.isHighContrast ? 2 : 1,
        ),
      ),
      child: ListTile(
        enabled: enabled,
        onTap: (!isActive && enabled) ? onSelect : null,
        leading: AccessibleAvatar(
          imageUrl: account.avatar,
          displayName: account.effectiveDisplayName,
          radius: 20,
        ),
        title: Row(
          children: [
            Flexible(
              child: Text(
                account.effectiveDisplayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            if (isActive) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  l10n.accountsActiveBadge,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: scheme.onPrimaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
        subtitle: Text(
          account.fullHandle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: fedi.subtleText),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isActive)
              Icon(Icons.check_circle, color: scheme.primary, size: 20),
            IconButton(
              tooltip: l10n.accountsSignOutAccountTooltip(account.fullHandle),
              icon: const Icon(Icons.logout, size: 20),
              onPressed: enabled ? onSignOut : null,
            ),
          ],
        ),
      ),
    );
  }
}
