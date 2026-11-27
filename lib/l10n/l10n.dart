// Copyright (c) 2026 brokengoose <brokengoose@users.noreply.github.com>
// SPDX-License-Identifier: MIT

import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart' as intl;

import '../core/language/bias_language_pack.dart';
import 'generated/app_localizations.dart';
import 'generated/app_localizations_en.dart';

export 'generated/app_localizations.dart';
export 'generated/app_localizations_en.dart';

/// Convenient accessor for [AppLocalizations] inside widgets, falling back to
/// English if a test pumps a widget without `localizationsDelegates`.
extension BuildContextL10n on BuildContext {
  AppLocalizations get l10n =>
      AppLocalizations.of(this) ?? AppLocalizationsEn();
}

/// Resolves [preferred] (or the current platform locale) against
/// [AppLocalizations.supportedLocales], falling back cleanly to English.
Locale resolveSupportedLocale([Locale? preferred]) {
  final target = preferred ?? PlatformDispatcher.instance.locale;
  const supported = AppLocalizations.supportedLocales;

  for (final candidate in supported) {
    if (candidate.languageCode == target.languageCode &&
        candidate.scriptCode == target.scriptCode &&
        candidate.countryCode == target.countryCode) {
      return candidate;
    }
  }
  for (final candidate in supported) {
    if (candidate.languageCode == target.languageCode &&
        candidate.countryCode != null &&
        candidate.countryCode == target.countryCode) {
      return candidate;
    }
  }
  for (final candidate in supported) {
    if (candidate.languageCode == target.languageCode) {
      return candidate;
    }
  }
  return supported.contains(const Locale('en'))
      ? const Locale('en')
      : supported.first;
}

/// Loads [AppLocalizations] synchronously for services/controllers that do not
/// hold a [BuildContext] (for example, `AccessibilityAnnouncer` calls).
AppLocalizations resolveAppLocalizations([Locale? preferred]) {
  return lookupAppLocalizations(resolveSupportedLocale(preferred));
}

/// Returns the writing direction (`ltr` or `rtl`) for [locale] (or the current
/// platform locale).
TextDirection resolveTextDirection([Locale? locale]) {
  final target = locale ?? PlatformDispatcher.instance.locale;
  return intl.Bidi.isRtlLanguage(target.languageCode)
      ? TextDirection.rtl
      : TextDirection.ltr;
}

/// Builds localized [BiasComponentLabels] from [l10n] so pre-post bias
/// findings and summaries match the active UI language.
BiasComponentLabels biasComponentLabelsFrom(AppLocalizations l10n) {
  return BiasComponentLabels(
    postText: l10n.biasComponentPostText,
    contentWarning: l10n.biasComponentContentWarning,
    attachmentLabel: l10n.biasComponentAttachment,
    linkLabel: l10n.biasComponentLink,
    referencedMessageLabel: l10n.biasComponentReferencedMessage,
    cleanSummary: l10n.biasSummaryClean,
    localCleanSummary: l10n.biasSummaryLocalClean,
    findingsSummary: l10n.biasSummaryLocalFindings,
    aiFallbackBiasSummary: l10n.biasSummaryAiFallbackBias,
    aiFallbackCleanSummary: l10n.biasSummaryClean,
  );
}
