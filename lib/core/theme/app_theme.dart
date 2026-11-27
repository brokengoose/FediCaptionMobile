// Copyright (c) 2026 brokengoose <brokengoose@users.noreply.github.com>
// SPDX-License-Identifier: MIT

import 'package:material_ui/material_ui.dart';

import '../constants.dart';

/// Semantic theme extension for status badges, alt-text banners, and bias alerts.
@immutable
class FediCaptionColors extends ThemeExtension<FediCaptionColors> {
  const FediCaptionColors({
    required this.altPresentBg,
    required this.altPresentFg,
    required this.altMissingBg,
    required this.altMissingFg,
    required this.biasWarningBg,
    required this.biasWarningFg,
    required this.updateBannerBg,
    required this.updateBannerFg,
    required this.cardBorder,
    required this.subtleText,
    required this.isHighContrast,
  });

  final Color altPresentBg;
  final Color altPresentFg;
  final Color altMissingBg;
  final Color altMissingFg;
  final Color biasWarningBg;
  final Color biasWarningFg;
  final Color updateBannerBg;
  final Color updateBannerFg;
  final Color cardBorder;
  final Color subtleText;
  final bool isHighContrast;

  @override
  FediCaptionColors copyWith({
    Color? altPresentBg,
    Color? altPresentFg,
    Color? altMissingBg,
    Color? altMissingFg,
    Color? biasWarningBg,
    Color? biasWarningFg,
    Color? updateBannerBg,
    Color? updateBannerFg,
    Color? cardBorder,
    Color? subtleText,
    bool? isHighContrast,
  }) {
    return FediCaptionColors(
      altPresentBg: altPresentBg ?? this.altPresentBg,
      altPresentFg: altPresentFg ?? this.altPresentFg,
      altMissingBg: altMissingBg ?? this.altMissingBg,
      altMissingFg: altMissingFg ?? this.altMissingFg,
      biasWarningBg: biasWarningBg ?? this.biasWarningBg,
      biasWarningFg: biasWarningFg ?? this.biasWarningFg,
      updateBannerBg: updateBannerBg ?? this.updateBannerBg,
      updateBannerFg: updateBannerFg ?? this.updateBannerFg,
      cardBorder: cardBorder ?? this.cardBorder,
      subtleText: subtleText ?? this.subtleText,
      isHighContrast: isHighContrast ?? this.isHighContrast,
    );
  }

  @override
  FediCaptionColors lerp(ThemeExtension<FediCaptionColors>? other, double t) {
    if (other is! FediCaptionColors) return this;
    return FediCaptionColors(
      altPresentBg: Color.lerp(altPresentBg, other.altPresentBg, t)!,
      altPresentFg: Color.lerp(altPresentFg, other.altPresentFg, t)!,
      altMissingBg: Color.lerp(altMissingBg, other.altMissingBg, t)!,
      altMissingFg: Color.lerp(altMissingFg, other.altMissingFg, t)!,
      biasWarningBg: Color.lerp(biasWarningBg, other.biasWarningBg, t)!,
      biasWarningFg: Color.lerp(biasWarningFg, other.biasWarningFg, t)!,
      updateBannerBg: Color.lerp(updateBannerBg, other.updateBannerBg, t)!,
      updateBannerFg: Color.lerp(updateBannerFg, other.updateBannerFg, t)!,
      cardBorder: Color.lerp(cardBorder, other.cardBorder, t)!,
      subtleText: Color.lerp(subtleText, other.subtleText, t)!,
      isHighContrast: t < 0.5 ? isHighContrast : other.isHighContrast,
    );
  }
}

/// Builds the three required themes: Dark, Light, and High Contrast (WCAG AAA).
class AppTheme {
  AppTheme._();

  static const _minButtonSize = Size(
    AppConstants.minTouchTargetSize,
    AppConstants.minTouchTargetSize,
  );

  static ThemeData light() {
    const scheme = ColorScheme.light(
      primary: Color(0xFF3E4EB8),
      onPrimary: Colors.white,
      primaryContainer: Color(0xFFE0E4FF),
      onPrimaryContainer: Color(0xFF101C6B),
      secondary: Color(0xFF006A6A),
      onSecondary: Colors.white,
      surface: Color(0xFFF8F9FC),
      onSurface: Color(0xFF14171F),
      surfaceContainerHighest: Color(0xFFE8ECF4),
      error: Color(0xFFB3261E),
      onError: Colors.white,
      outline: Color(0xFF6B7280),
    );

    return _buildTheme(
      scheme: scheme,
      borderWidth: 1.0,
      extraColors: const FediCaptionColors(
        altPresentBg: Color(0xFFE6F4EA),
        altPresentFg: Color(0xFF0D5C2B),
        altMissingBg: Color(0xFFFCE8E6),
        altMissingFg: Color(0xFFA50E0E),
        biasWarningBg: Color(0xFFFFF4E5),
        biasWarningFg: Color(0xFF7A3E00),
        updateBannerBg: Color(0xFFE0E7FF),
        updateBannerFg: Color(0xFF1E3A8A),
        cardBorder: Color(0xFFD5DBE7),
        subtleText: Color(0xFF4B5563),
        isHighContrast: false,
      ),
    );
  }

  static ThemeData dark() {
    const scheme = ColorScheme.dark(
      primary: Color(0xFF93A8FF),
      onPrimary: Color(0xFF0D1642),
      primaryContainer: Color(0xFF28357A),
      onPrimaryContainer: Color(0xFFE4E8FF),
      secondary: Color(0xFF56D6CE),
      onSecondary: Color(0xFF003735),
      surface: Color(0xFF12151E),
      onSurface: Color(0xFFF1F4F9),
      surfaceContainerHighest: Color(0xFF1F2433),
      error: Color(0xFFFFB4AB),
      onError: Color(0xFF690005),
      outline: Color(0xFF8C94A8),
    );

    return _buildTheme(
      scheme: scheme,
      borderWidth: 1.0,
      extraColors: const FediCaptionColors(
        altPresentBg: Color(0xFF113821),
        altPresentFg: Color(0xFF8CE0A9),
        altMissingBg: Color(0xFF471515),
        altMissingFg: Color(0xFFFFB3B3),
        biasWarningBg: Color(0xFF3E2808),
        biasWarningFg: Color(0xFFFFD68A),
        updateBannerBg: Color(0xFF1E2959),
        updateBannerFg: Color(0xFFD6E0FF),
        cardBorder: Color(0xFF2E3548),
        subtleText: Color(0xFFB3BCCF),
        isHighContrast: false,
      ),
    );
  }

  /// WCAG AAA High Contrast Theme (>= 7:1 contrast ratio across text and controls).
  static ThemeData highContrast() {
    const scheme = ColorScheme.dark(
      primary: Color(0xFFFFFF00), // Yellow on pure black (> 19:1)
      onPrimary: Color(0xFF000000),
      primaryContainer: Color(0xFF00FFFF), // Cyan accent (> 16:1)
      onPrimaryContainer: Color(0xFF000000),
      secondary: Color(0xFF00FF88),
      onSecondary: Color(0xFF000000),
      surface: Color(0xFF000000),
      onSurface: Color(0xFFFFFFFF), // White on black (21:1)
      surfaceContainerHighest: Color(0xFF121212),
      error: Color(0xFFFF6E6E),
      onError: Color(0xFF000000),
      outline: Color(0xFFFFFFFF),
    );

    return _buildTheme(
      scheme: scheme,
      borderWidth: 2.0,
      extraColors: const FediCaptionColors(
        altPresentBg: Color(0xFF000000),
        altPresentFg: Color(0xFF00FF88),
        altMissingBg: Color(0xFF000000),
        altMissingFg: Color(0xFFFF8080),
        biasWarningBg: Color(0xFF000000),
        biasWarningFg: Color(0xFFFFFF00),
        updateBannerBg: Color(0xFFFFFF00),
        updateBannerFg: Color(0xFF000000),
        cardBorder: Color(0xFFFFFFFF),
        subtleText: Color(0xFFE6E6E6),
        isHighContrast: true,
      ),
    );
  }

  static ThemeData _buildTheme({
    required ColorScheme scheme,
    required double borderWidth,
    required FediCaptionColors extraColors,
  }) {
    final borderRadius = BorderRadius.circular(12);
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      visualDensity: VisualDensity.standard,
      extensions: [extraColors],
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: extraColors.isHighContrast ? 0 : 1,
        shape: extraColors.isHighContrast
            ? Border(bottom: BorderSide(color: scheme.outline, width: 2))
            : null,
      ),
      cardTheme: CardThemeData(
        color: extraColors.isHighContrast
            ? scheme.surface
            : scheme.surfaceContainerHighest.withAlpha(115),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: borderRadius,
          side: BorderSide(color: extraColors.cardBorder, width: borderWidth),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: extraColors.isHighContrast
            ? scheme.surface
            : scheme.surfaceContainerHighest.withAlpha(102),
        border: OutlineInputBorder(
          borderRadius: borderRadius,
          borderSide: BorderSide(color: scheme.outline, width: borderWidth),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: borderRadius,
          borderSide: BorderSide(color: scheme.outline, width: borderWidth),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: borderRadius,
          borderSide: BorderSide(
            color: scheme.primary,
            width: extraColors.isHighContrast ? 3.0 : 2.0,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: _minButtonSize,
          shape: RoundedRectangleBorder(borderRadius: borderRadius),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: _minButtonSize,
          side: BorderSide(color: scheme.outline, width: borderWidth),
          shape: RoundedRectangleBorder(borderRadius: borderRadius),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: _minButtonSize,
          shape: RoundedRectangleBorder(borderRadius: borderRadius),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(minimumSize: _minButtonSize),
      ),
      dividerTheme: DividerThemeData(
        color: extraColors.cardBorder,
        thickness: borderWidth,
      ),
      tooltipTheme: TooltipThemeData(
        waitDuration: const Duration(milliseconds: 350),
        showDuration: const Duration(seconds: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        margin: const EdgeInsets.symmetric(horizontal: 12),
        textStyle: TextStyle(
          color: extraColors.isHighContrast
              ? Colors.black
              : scheme.onInverseSurface,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        decoration: BoxDecoration(
          color: extraColors.isHighContrast
              ? const Color(0xFFFFFF00)
              : scheme.inverseSurface,
          borderRadius: BorderRadius.circular(8),
          border: extraColors.isHighContrast
              ? Border.all(color: Colors.white, width: 2)
              : null,
        ),
      ),
    );
  }
}

extension FediCaptionThemeContext on BuildContext {
  FediCaptionColors get fediColors =>
      Theme.of(this).extension<FediCaptionColors>() ??
      AppTheme.light().extension<FediCaptionColors>()!;
}
