// Copyright (c) 2026 brokengoose <brokengoose@users.noreply.github.com>
// SPDX-License-Identifier: MIT

import 'package:material_ui/material_ui.dart';

import '../../core/constants.dart';
import '../../core/theme/app_theme.dart';
import '../../l10n/l10n.dart';
import '../../state/app_controller.dart';
import '../widgets/accessible_avatar.dart';
import 'settings_screen.dart';

/// Mastodon authentication screen supporting OAuth 2.0 (`ASWebAuthenticationSession` /
/// Custom Tabs) and a manual Direct Access Token fallback.
class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    required this.app,
    this.isAddingAccount = false,
  });

  final AppController app;
  final bool isAddingAccount;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _instanceController =
      TextEditingController(text: 'mastodon.social');
  final TextEditingController _tokenController = TextEditingController();
  bool _showTokenFallback = false;
  bool _obscureToken = true;

  @override
  void dispose() {
    _instanceController.dispose();
    _tokenController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fedi = context.fediColors;
    final l10n = context.l10n;

    return ListenableBuilder(
      listenable: widget.app,
      builder: (context, _) {
        final busy = widget.app.isAuthenticating || widget.app.isSwitchingAccount;
        final error = widget.app.authError;
        final savedAccounts = widget.app.accounts;

        return Scaffold(
          appBar: AppBar(
            title: Text(
              widget.isAddingAccount
                  ? l10n.loginAddAccountTitle
                  : AppConstants.appName,
            ),
            actions: [
              if (!widget.isAddingAccount)
                IconButton(
                  tooltip: l10n.loginSettingsTooltip,
                  icon: const Icon(Icons.settings_outlined),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => SettingsScreen(app: widget.app),
                    ),
                  ),
                ),
            ],
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 12),
                      Center(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: Image.asset(
                            'assets/icon/app_icon.png',
                            width: 84,
                            height: 84,
                            semanticLabel: l10n.loginElephantSemanticLabel,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Semantics(
                        header: true,
                        child: Text(
                          l10n.loginWelcomeTitle,
                          textAlign: TextAlign.center,
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l10n.loginTagline,
                        textAlign: TextAlign.center,
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(color: fedi.subtleText),
                      ),
                      const SizedBox(height: 20),
                      Semantics(
                        container: true,
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: fedi.biasWarningBg,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: fedi.isHighContrast
                                  ? fedi.biasWarningFg
                                  : fedi.biasWarningFg.withValues(alpha: 0.35),
                              width: fedi.isHighContrast ? 2 : 1,
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.warning_amber_rounded,
                                color: fedi.biasWarningFg,
                                size: 22,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      l10n.loginExistingAccountWarningTitle,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: fedi.biasWarningFg,
                                          ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      l10n.loginExistingAccountWarningBody,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: fedi.biasWarningFg,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      TextField(
                        controller: _instanceController,
                        enabled: !busy,
                        keyboardType: TextInputType.url,
                        autocorrect: false,
                        textInputAction: TextInputAction.done,
                        decoration: InputDecoration(
                          labelText: l10n.loginServerDomainLabel,
                          hintText: l10n.loginServerDomainHint,
                          prefixIcon: const Icon(Icons.public),
                          helperText: l10n.loginServerDomainHelper,
                        ),
                      ),

                      const SizedBox(height: 16),

                      FilledButton.icon(
                        onPressed: busy
                            ? null
                            : () async {
                                final ok = await widget.app
                                    .loginWithOAuth(_instanceController.text);
                                if (ok &&
                                    widget.isAddingAccount &&
                                    context.mounted) {
                                  Navigator.of(context).pop(true);
                                }
                              },
                        icon: busy
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.login),
                        label: Text(
                          busy ? l10n.loginSigningIn : l10n.loginSignInOAuth,
                        ),
                      ),

                      if (error != null && error.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Semantics(
                          liveRegion: true,
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: scheme.errorContainer,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              error,
                              style: TextStyle(color: scheme.onErrorContainer),
                            ),
                          ),
                        ),
                      ],

                      const SizedBox(height: 24),
                      const Divider(),

                      // Manual Direct Access Token Fallback
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(l10n.loginTokenFallbackTitle),
                        subtitle: Text(l10n.loginTokenFallbackSubtitle),
                        trailing: Icon(
                          _showTokenFallback
                              ? Icons.expand_less
                              : Icons.expand_more,
                        ),
                        onTap: () => setState(
                          () => _showTokenFallback = !_showTokenFallback,
                        ),
                      ),

                      if (_showTokenFallback) ...[
                        const SizedBox(height: 8),
                        TextField(
                          controller: _tokenController,
                          enabled: !busy,
                          obscureText: _obscureToken,
                          autocorrect: false,
                          decoration: InputDecoration(
                            labelText: l10n.loginTokenLabel,
                            hintText: l10n.loginTokenHint,
                            prefixIcon: const Icon(Icons.vpn_key_outlined),
                            suffixIcon: IconButton(
                              tooltip: _obscureToken
                                  ? l10n.loginShowToken
                                  : l10n.loginHideToken,
                              icon: Icon(
                                _obscureToken
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                              ),
                              onPressed: () => setState(
                                () => _obscureToken = !_obscureToken,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: busy
                              ? null
                              : () async {
                                  final ok =
                                      await widget.app.loginWithAccessToken(
                                    rawInstanceUrl: _instanceController.text,
                                    accessToken: _tokenController.text,
                                  );
                                  if (ok &&
                                      widget.isAddingAccount &&
                                      context.mounted) {
                                    Navigator.of(context).pop(true);
                                  }
                                },
                          icon: const Icon(Icons.key),
                          label: Text(l10n.loginSignInToken),
                        ),
                      ],

                      if (!widget.isAddingAccount &&
                          savedAccounts.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        const Divider(),
                        const SizedBox(height: 8),
                        Semantics(
                          header: true,
                          child: Text(
                            l10n.loginSavedAccountsHeader,
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(height: 8),
                        for (final acc in savedAccounts)
                          Card(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            child: ListTile(
                              enabled: !busy,
                              leading: AccessibleAvatar(
                                imageUrl: acc.avatar,
                                displayName: acc.effectiveDisplayName,
                                radius: 18,
                              ),
                              title: Text(acc.effectiveDisplayName),
                              subtitle: Text(acc.fullHandle),
                              trailing: const Icon(Icons.login),
                              onTap: busy
                                  ? null
                                  : () => widget.app.switchAccount(acc.key),
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
