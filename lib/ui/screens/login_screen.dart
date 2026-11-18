// Copyright (c) 2026 brokengoose <brokengoose@users.noreply.github.com>
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../core/theme/app_theme.dart';
import '../../state/app_controller.dart';
import 'settings_screen.dart';

/// Mastodon authentication screen supporting OAuth 2.0 (`ASWebAuthenticationSession` /
/// Custom Tabs) and a manual Direct Access Token fallback (Section 6.1).
class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    required this.app,
  });

  final AppController app;

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

    return ListenableBuilder(
      listenable: widget.app,
      builder: (context, _) {
        final busy = widget.app.isAuthenticating;
        final error = widget.app.authError;

        return Scaffold(
          appBar: AppBar(
            title: const Text(AppConstants.appName),
            actions: [
              IconButton(
                tooltip: 'Settings and Appearance',
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
                      Icon(
                        Icons.closed_caption_rounded,
                        size: 56,
                        color: scheme.primary,
                      ),
                      const SizedBox(height: 12),
                      Semantics(
                        header: true,
                        child: Text(
                          'Welcome to FediCaption',
                          textAlign: TextAlign.center,
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'An accessible Mastodon client with automatic AI alt-text generation and pre-post racial & gender bias checking.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(color: fedi.subtleText),
                      ),
                      const SizedBox(height: 28),

                      TextField(
                        controller: _instanceController,
                        enabled: !busy,
                        keyboardType: TextInputType.url,
                        autocorrect: false,
                        textInputAction: TextInputAction.done,
                        decoration: const InputDecoration(
                          labelText: 'Mastodon Server Domain',
                          hintText: 'mastodon.social',
                          prefixIcon: Icon(Icons.public),
                          helperText:
                              'Enter your Mastodon, Glitch-soc, Hometown, Pleroma, or Akkoma server.',
                        ),
                      ),

                      const SizedBox(height: 16),

                      FilledButton.icon(
                        onPressed: busy
                            ? null
                            : () => widget.app
                                .loginWithOAuth(_instanceController.text),
                        icon: busy
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.login),
                        label: Text(
                          busy
                              ? 'Signing in…'
                              : 'Sign in with Mastodon (OAuth 2.0)',
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
                        title: const Text('Direct Access Token Fallback'),
                        subtitle: const Text(
                          'Sign in with a personal access token from your Mastodon Development settings.',
                        ),
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
                            labelText: 'Access Token',
                            hintText: 'Paste Mastodon access token',
                            prefixIcon: const Icon(Icons.vpn_key_outlined),
                            suffixIcon: IconButton(
                              tooltip:
                                  _obscureToken ? 'Show token' : 'Hide token',
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
                              : () => widget.app.loginWithAccessToken(
                                    rawInstanceUrl: _instanceController.text,
                                    accessToken: _tokenController.text,
                                  ),
                          icon: const Icon(Icons.key),
                          label: const Text('Sign in with Access Token'),
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
