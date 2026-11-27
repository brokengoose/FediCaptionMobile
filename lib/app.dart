// Copyright (c) 2026 brokengoose <brokengoose@users.noreply.github.com>
// SPDX-License-Identifier: MIT

import 'dart:async';

import 'package:material_ui/material_ui.dart';

import 'core/constants.dart';
import 'l10n/l10n.dart';
import 'state/app_controller.dart';
import 'ui/screens/ai_setup_screen.dart';
import 'ui/screens/home_shell.dart';
import 'ui/screens/login_screen.dart';

/// Root widget for FediCaption Mobile.
class FediCaptionApp extends StatefulWidget {
  const FediCaptionApp({super.key, this.controller});

  final AppController? controller;

  @override
  State<FediCaptionApp> createState() => _FediCaptionAppState();
}

class _FediCaptionAppState extends State<FediCaptionApp> {
  late AppController _app;
  late bool _ownsController;
  late bool _isInitializing;
  late bool _needsAiSetup;
  late bool _isAuthenticated;
  Locale? _resolvedLocale;
  late ThemeData _themeData;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _app = widget.controller ?? AppController();
    _attachListeners();
    _syncRootSnapshot(assignOnly: true);
    unawaited(_app.initialize());
  }

  @override
  void didUpdateWidget(covariant FediCaptionApp oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      _detachListeners();
      if (_ownsController) {
        _app.dispose();
      }
      _ownsController = widget.controller == null;
      _app = widget.controller ?? AppController();
      _attachListeners();
      _syncRootSnapshot(assignOnly: true);
      if (_ownsController) {
        unawaited(_app.initialize());
      }
    }
  }

  void _attachListeners() {
    _app.addListener(_onAppOrThemeChanged);
    _app.themeController.addListener(_onAppOrThemeChanged);
  }

  void _detachListeners() {
    _app.removeListener(_onAppOrThemeChanged);
    _app.themeController.removeListener(_onAppOrThemeChanged);
  }

  bool _syncRootSnapshot({bool assignOnly = false}) {
    final nextInitializing = _app.isInitializing;
    final nextNeedsAiSetup = _app.needsAiSetup;
    final nextAuthenticated = _app.isAuthenticated;
    final nextLocale = _app.settings.resolvedAppLocale;
    final nextTheme = _app.themeController.themeData;

    final changed =
        assignOnly ||
        nextInitializing != _isInitializing ||
        nextNeedsAiSetup != _needsAiSetup ||
        nextAuthenticated != _isAuthenticated ||
        nextLocale != _resolvedLocale ||
        nextTheme != _themeData;
    if (changed) {
      _isInitializing = nextInitializing;
      _needsAiSetup = nextNeedsAiSetup;
      _isAuthenticated = nextAuthenticated;
      _resolvedLocale = nextLocale;
      _themeData = nextTheme;
    }
    return changed;
  }

  void _onAppOrThemeChanged() {
    if (mounted && _syncRootSnapshot()) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _detachListeners();
    if (_ownsController) {
      _app.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: _themeData,
      locale: _resolvedLocale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: _isInitializing
          ? const _SplashScreen()
          : (_needsAiSetup
                ? AiSetupScreen(app: _app)
                : (!_isAuthenticated
                      ? LoginScreen(app: _app)
                      : HomeShell(app: _app))),
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      body: Center(
        child: Semantics(
          label: l10n.appLoadingLabel,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Image.asset(
                  'assets/icon/app_icon.png',
                  width: 84,
                  height: 84,
                  semanticLabel: l10n.appIconSemanticLabel,
                ),
              ),
              const SizedBox(height: 16),
              const CircularProgressIndicator(),
            ],
          ),
        ),
      ),
    );
  }
}
