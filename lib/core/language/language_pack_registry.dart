// Copyright (c) 2026 brokengoose <brokengoose@users.noreply.github.com>
// SPDX-License-Identifier: MIT

import 'bias_language_pack.dart';
import 'caption_language_pack.dart';
import 'language_registry.dart';
import 'packs/en_language_pack.dart';

/// Bundle of domain-specific language rules for a single language.
class AppLanguagePack {
  const AppLanguagePack({
    required this.languageCode,
    required this.caption,
    this.bias,
  });

  /// Canonical lowercase ISO 639-1 language code (e.g. `'en'`, `'es'`).
  final String languageCode;

  /// Caption formatting, prefix, and AI prompt examples for this language.
  final CaptionLanguagePack caption;

  /// Optional offline inclusive-language heuristic rules for this language.
  final BiasLanguagePack? bias;
}

/// Central registry of domain [AppLanguagePack] instances.
class LanguagePackRegistry {
  LanguagePackRegistry._();

  static final Map<String, AppLanguagePack> _packs = {'en': enLanguagePack};

  /// Unmodifiable list of registered ISO language codes.
  static List<String> get registeredLanguageCodes =>
      List.unmodifiable(_packs.keys);

  /// Registers or replaces the [AppLanguagePack] for [AppLanguagePack.languageCode].
  static void register(AppLanguagePack pack) {
    final code =
        LanguageRegistry.resolveCode(pack.languageCode) ??
        pack.languageCode.trim().toLowerCase();
    if (code.isEmpty) return;
    _packs[code] = pack;
  }

  /// Unregisters a non-default language pack (never removes `'en'`).
  static void unregister(String languageCode) {
    final code =
        LanguageRegistry.resolveCode(languageCode) ??
        languageCode.trim().toLowerCase();
    if (code == 'en') return;
    _packs.remove(code);
  }

  /// Resolves the [CaptionLanguagePack] for [languageNameOrCode], falling back to
  /// English if no language-specific caption pack is registered.
  static CaptionLanguagePack captionPackFor(String? languageNameOrCode) {
    final code = LanguageRegistry.resolveCode(languageNameOrCode) ?? 'en';
    final registered = _packs[code];
    if (registered != null) return registered.caption;

    // Preserve language script metadata (e.g. non-spaced CJK/Thai) even before a
    // dedicated caption pack is registered for that language.
    final info = LanguageRegistry.resolve(code);
    if (info != null && (!info.usesWordSpaces || !info.hasLetterCase)) {
      return CaptionLanguagePack(
        languageCode: info.code,
        captionPrefix: enCaptionLanguagePack.captionPrefix,
        redundantPrefixPatterns: enCaptionLanguagePack.redundantPrefixPatterns,
        quotePairs: enCaptionLanguagePack.quotePairs,
        forbiddenPrefixExamples: enCaptionLanguagePack.forbiddenPrefixExamples,
        capitalizeFirstLetter: info.hasLetterCase,
        usesWordSpaces: info.usesWordSpaces,
      );
    }

    return enCaptionLanguagePack;
  }

  /// Resolves the [BiasLanguagePack] for [languageNameOrCode].
  ///
  /// When [languageNameOrCode] is empty/null or [fallbackToEnglish] is `true`,
  /// falls back to the English bias pack. Otherwise returns `null` when no
  /// heuristic pack is registered for that language so non-English drafts are
  /// not falsely flagged by English-only regex rules.
  static BiasLanguagePack? biasPackFor(
    String? languageNameOrCode, {
    bool fallbackToEnglish = false,
  }) {
    if (languageNameOrCode == null || languageNameOrCode.trim().isEmpty) {
      return enBiasLanguagePack;
    }
    final code = LanguageRegistry.resolveCode(languageNameOrCode);
    if (code != null && _packs.containsKey(code)) {
      return _packs[code]!.bias ??
          (fallbackToEnglish ? enBiasLanguagePack : null);
    }
    return fallbackToEnglish ? enBiasLanguagePack : null;
  }
}
