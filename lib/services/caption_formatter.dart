// Copyright (c) 2026 brokengoose <brokengoose@users.noreply.github.com>
// SPDX-License-Identifier: MIT

import '../core/constants.dart';

/// Cleans raw AI vision responses, enforces the mandatory
/// `AI generated description: ` prefix, and truncates cleanly on word boundaries.
class CaptionFormatter {
  CaptionFormatter._();

  static final List<RegExp> _redundantPrefixes = [
    RegExp(r'^ai[\s\-]+generated\s+description\s*[:\-–—]?\s*', caseSensitive: false),
    RegExp(
      r'^automatically[\s\-]+generated\s+description\s*[:\-–—]?\s*',
      caseSensitive: false,
    ),
    RegExp(r'^auto[\s\-]+generated\s+description\s*[:\-–—]?\s*', caseSensitive: false),
    RegExp(r'^alt[\s\-]?text\s*[:\-–—]\s*', caseSensitive: false),
    RegExp(r'^description\s*[:\-–—]\s*', caseSensitive: false),
    RegExp(r'^caption\s*[:\-–—]\s*', caseSensitive: false),
    RegExp(r'^here\s+is\s+(a|the)\s+(description|caption|alt[\s\-]?text)\s*(of\s+the\s+(image|photo|video))?\s*[:\-–—]\s*', caseSensitive: false),
    RegExp(r'^(an?\s+)?(image|photo|photograph|picture|video|clip)\s+of\s+', caseSensitive: false),
  ];

  /// Formats [rawText] into a clean screen-reader alt-text caption:
  /// 1. Strips surrounding quotation marks and redundant preambles/duplicate prefixes.
  /// 2. Prepends exact `AI generated description: `.
  /// 3. Truncates cleanly on a word boundary with `…` if exceeding [maxLength].
  static String format(
    String rawText, {
    int maxLength = AppConstants.defaultAltTextLimit,
  }) {
    var cleaned = rawText.trim();
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ');

    // Repeatedly strip outer quotes and redundant preambles until stable.
    var previous = '';
    while (cleaned != previous && cleaned.isNotEmpty) {
      previous = cleaned;
      cleaned = _stripSurroundingQuotes(cleaned).trim();

      for (final pattern in _redundantPrefixes) {
        final next = cleaned.replaceFirst(pattern, '').trim();
        if (next != cleaned) {
          cleaned = next;
        }
      }
      cleaned = _stripSurroundingQuotes(cleaned).trim();
    }

    if (cleaned.isNotEmpty) {
      cleaned = cleaned[0].toUpperCase() + cleaned.substring(1);
    }

    final prefixed = '${AppConstants.aiCaptionPrefix}$cleaned'.trimRight();
    return truncateOnWordBoundary(prefixed, maxLength);
  }

  /// Truncates [text] to at most [maxLength] characters on a word boundary with `…`.
  static String truncateOnWordBoundary(String text, int maxLength) {
    if (maxLength <= 0) return '';
    if (text.length <= maxLength) return text;
    if (maxLength == 1) return '…';

    final limit = maxLength - 1; // Reserve 1 char for ellipsis '…'
    final slice = text.substring(0, limit);
    final lastSpace = slice.lastIndexOf(' ');

    // Keep word boundary unless no reasonable space exists after the prefix.
    const minSplit = AppConstants.aiCaptionPrefix.length;
    String base;
    if (lastSpace > minSplit) {
      base = slice.substring(0, lastSpace);
    } else if (lastSpace > 0 && maxLength <= minSplit + 4) {
      base = slice.substring(0, lastSpace);
    } else {
      base = slice;
    }

    base = base.replaceFirst(RegExp(r'[\s,;:\-]+$'), '');
    return '$base…';
  }

  static String _stripSurroundingQuotes(String input) {
    if (input.length < 2) return input;
    const pairs = [
      ('"', '"'),
      ("'", "'"),
      ('“', '”'),
      ('‘', '’'),
      ('`', '`'),
    ];
    for (final (open, close) in pairs) {
      if (input.startsWith(open) && input.endsWith(close)) {
        return input.substring(open.length, input.length - close.length);
      }
    }
    return input;
  }
}
