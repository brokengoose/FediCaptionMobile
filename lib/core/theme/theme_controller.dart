// Copyright (c) 2026 brokengoose <brokengoose@users.noreply.github.com>
// SPDX-License-Identifier: MIT

import 'package:material_ui/material_ui.dart';

import '../../models/app_settings.dart';
import 'app_theme.dart';

/// Resolves the active theme (Dark, Light, or WCAG AAA High Contrast)
/// and reacts live to OS appearance & high-contrast changes when in System mode.
class ThemeController extends ChangeNotifier with WidgetsBindingObserver {
  ThemeController({ThemePreference initialPreference = ThemePreference.system})
    : _preference = initialPreference {
    WidgetsBinding.instance.addObserver(this);
    _syncFromPlatform();
  }

  ThemePreference _preference;
  Brightness _platformBrightness = Brightness.light;
  bool _platformHighContrast = false;

  ThemePreference get preference => _preference;
  Brightness get platformBrightness => _platformBrightness;
  bool get platformHighContrast => _platformHighContrast;

  /// Effective resolved theme choice based on user override or live OS mode.
  ResolvedTheme get effectiveTheme {
    switch (_preference) {
      case ThemePreference.dark:
        return ResolvedTheme.dark;
      case ThemePreference.light:
        return ResolvedTheme.light;
      case ThemePreference.highContrast:
        return ResolvedTheme.highContrast;
      case ThemePreference.system:
        if (_platformHighContrast) {
          return ResolvedTheme.highContrast;
        }
        return _platformBrightness == Brightness.dark
            ? ResolvedTheme.dark
            : ResolvedTheme.light;
    }
  }

  ThemeData get themeData {
    switch (effectiveTheme) {
      case ResolvedTheme.dark:
        return AppTheme.dark();
      case ResolvedTheme.light:
        return AppTheme.light();
      case ResolvedTheme.highContrast:
        return AppTheme.highContrast();
    }
  }

  void setPreference(ThemePreference preference) {
    if (_preference == preference) return;
    _preference = preference;
    notifyListeners();
  }

  void _syncFromPlatform() {
    final dispatcher = WidgetsBinding.instance.platformDispatcher;
    _platformBrightness = dispatcher.platformBrightness;
    _platformHighContrast = dispatcher.accessibilityFeatures.highContrast;
  }

  @override
  void didChangePlatformBrightness() {
    final nextBrightness =
        WidgetsBinding.instance.platformDispatcher.platformBrightness;
    if (nextBrightness != _platformBrightness) {
      _platformBrightness = nextBrightness;
      if (_preference == ThemePreference.system) {
        notifyListeners();
      }
    }
  }

  @override
  void didChangeAccessibilityFeatures() {
    final nextHighContrast = WidgetsBinding
        .instance
        .platformDispatcher
        .accessibilityFeatures
        .highContrast;
    if (nextHighContrast != _platformHighContrast) {
      _platformHighContrast = nextHighContrast;
      if (_preference == ThemePreference.system) {
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}

enum ResolvedTheme { light, dark, highContrast }
