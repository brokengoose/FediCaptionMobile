// Copyright (c) 2026 brokengoose <brokengoose@users.noreply.github.com>
// SPDX-License-Identifier: MIT

import 'package:fedicaption_mobile/core/theme/app_theme.dart';
import 'package:fedicaption_mobile/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// Pumps [home] inside a [MaterialApp] configured with FediCaption's
/// [AppLocalizations] delegates, theme extensions, and optional [locale] or
/// forced [textDirection] (e.g. `TextDirection.rtl` layout verification).
Widget localizedTestApp({
  required Widget home,
  ThemeData? theme,
  Locale? locale,
  TextDirection? textDirection,
}) {
  return MaterialApp(
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    theme: theme ?? AppTheme.light(),
    home: textDirection != null
        ? Directionality(textDirection: textDirection, child: home)
        : home,
  );
}
