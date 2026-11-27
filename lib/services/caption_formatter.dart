// Copyright (c) 2026 brokengoose <brokengoose@users.noreply.github.com>
// SPDX-License-Identifier: MIT

import '../core/constants.dart';
import '../core/language/caption_language_pack.dart';
import '../core/language/language_pack_registry.dart';

/// Cleans raw AI vision responses, enforces the configured language's alt-text
/// prefix, and truncates cleanly on word boundaries.
class CaptionFormatter {
  CaptionFormatter._();

  /// Formats [rawText] into a clean screen-reader alt-text caption:
  /// 1. Strips surrounding quotation marks and redundant preambles/duplicate prefixes.
  /// 2. Prepends the active [CaptionLanguagePack.captionPrefix].
  /// 3. Truncates cleanly on a word boundary with `…` if exceeding [maxLength].
  static String format(
    String rawText, {
    int maxLength = AppConstants.defaultAltTextLimit,
    String? language,
    CaptionLanguagePack? pack,
  }) {
    final activePack = pack ?? LanguagePackRegistry.captionPackFor(language);
    var cleaned = rawText.trim();
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ');

    // Repeatedly strip outer quotes and redundant preambles until stable.
    var previous = '';
    while (cleaned != previous && cleaned.isNotEmpty) {
      previous = cleaned;
      cleaned = _stripSurroundingQuotes(cleaned, activePack.quotePairs).trim();

      for (final pattern in activePack.redundantPrefixPatterns) {
        final next = cleaned.replaceFirst(pattern, '').trim();
        if (next != cleaned) {
          cleaned = next;
        }
      }
      cleaned = _stripSurroundingQuotes(cleaned, activePack.quotePairs).trim();
    }

    if (activePack.capitalizeFirstLetter && cleaned.isNotEmpty) {
      final firstRune = String.fromCharCode(cleaned.runes.first);
      cleaned = firstRune.toUpperCase() + cleaned.substring(firstRune.length);
    }

    final prefixed = '${activePack.captionPrefix}$cleaned'.trimRight();
    return truncateOnWordBoundary(
      prefixed,
      maxLength,
      minSplit: activePack.captionPrefix.length,
      usesWordSpaces: activePack.usesWordSpaces,
    );
  }

  /// Truncates [text] to at most [maxLength] characters on a word boundary with `…`.
  static String truncateOnWordBoundary(
    String text,
    int maxLength, {
    int minSplit = AppConstants.aiCaptionPrefix.length,
    bool usesWordSpaces = true,
  }) {
    if (maxLength <= 0) return '';
    if (text.length <= maxLength) return text;
    if (maxLength == 1) return '…';

    var limit = maxLength - 1; // Reserve 1 char for ellipsis '…'
    // Avoid slicing inside a UTF-16 surrogate pair.
    if (limit > 0 && limit < text.length) {
      final prev = text.codeUnitAt(limit - 1);
      if (prev >= 0xD800 && prev <= 0xDBFF) {
        limit--;
      }
    }
    final slice = text.substring(0, limit);

    String base;
    if (!usesWordSpaces) {
      base = slice;
    } else {
      final lastSpace = slice.lastIndexOf(' ');
      // Keep word boundary unless no reasonable space exists after the prefix.
      if (lastSpace > minSplit) {
        base = slice.substring(0, lastSpace);
      } else if (lastSpace > 0 && maxLength <= minSplit + 4) {
        base = slice.substring(0, lastSpace);
      } else {
        base = slice;
      }
    }

    base = base.replaceFirst(RegExp(r'[\s,;:\-]+$'), '');
    return '$base…';
  }

  static String _stripSurroundingQuotes(
    String input,
    List<(String, String)> quotePairs,
  ) {
    if (input.length < 2) return input;
    for (final (open, close) in quotePairs) {
      if (input.startsWith(open) &&
          input.endsWith(close) &&
          input.length >= open.length + close.length) {
        return input.substring(open.length, input.length - close.length);
      }
    }
    return input;
  }
}
