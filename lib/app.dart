// Copyright (c) 2026 brokengoose <brokengoose@users.noreply.github.com>
// SPDX-License-Identifier: MIT

import 'package:material_ui/material_ui.dart';

import 'core/constants.dart';
import 'state/app_controller.dart';
import 'ui/screens/ai_setup_screen.dart';
import 'ui/screens/home_shell.dart';
import 'ui/screens/login_screen.dart';

/// Root widget for FediCaption Mobile.
class FediCaptionApp extends StatefulWidget {
  const FediCaptionApp({
    super.key,
    this.controller,
  });

  final AppController? controller;

  @override
  State<FediCaptionApp> createState() => _FediCaptionAppState();
}

class _FediCaptionAppState extends State<FediCaptionApp> {
  late final AppController _app;
  late final bool _ownsController;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _app = widget.controller ?? AppController();
    _app.initialize();
  }

  @override
  void dispose() {
    if (_ownsController) {
      _app.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([_app, _app.themeController]),
      builder: (context, _) {
        return MaterialApp(
          title: AppConstants.appName,
          debugShowCheckedModeBanner: false,
          theme: _app.themeController.themeData,
          home: _app.isInitializing
              ? const _SplashScreen()
              : (!_app.isAuthenticated
                  ? LoginScreen(app: _app)
                  : (_app.needsAiSetup
                      ? AiSetupScreen(app: _app)
                      : HomeShell(app: _app))),
        );
      },
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Semantics(
          label: 'Loading FediCaption',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Image.asset(
                  'assets/icon/app_icon.png',
                  width: 84,
                  height: 84,
                  semanticLabel: 'FediCaption app icon',
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
