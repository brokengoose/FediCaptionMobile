// Copyright (c) 2026 brokengoose <brokengoose@users.noreply.github.com>
// SPDX-License-Identifier: MIT

import 'package:html/parser.dart' as html_parser;

/// HTML parsing and URL extraction utilities for Mastodon statuses and link previews.
class HtmlUtils {
  HtmlUtils._();

  static final RegExp _urlRegex = RegExp(
    r'https?://[^\s<>()"\[\]]+',
    caseSensitive: false,
  );

  /// Converts Mastodon status HTML into readable plain text with paragraph breaks.
  static String htmlToPlainText(String htmlContent) {
    if (htmlContent.trim().isEmpty) return '';

    final normalized = htmlContent
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'</p>\s*<p[^>]*>', caseSensitive: false), '\n\n')
        .replaceAll(RegExp(r'</(p|div|li|blockquote)>', caseSensitive: false), '\n');

    final document = html_parser.parse(normalized);
    final rawText = document.body?.text ?? document.documentElement?.text ?? '';

    return rawText
        .replaceAll('\r\n', '\n')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
  }

  /// Extracts unique `http://` and `https://` URLs from plain text.
  static List<String> extractUrls(String text) {
    final seen = <String>{};
    final result = <String>[];
    for (final match in _urlRegex.allMatches(text)) {
      var url = match.group(0) ?? '';
      // Trim trailing punctuation that commonly terminates sentences.
      while (url.isNotEmpty && '.,;:!?)\'"'.contains(url[url.length - 1])) {
        url = url.substring(0, url.length - 1);
      }
      if (url.isNotEmpty && seen.add(url)) {
        result.add(url);
      }
    }
    return result;
  }

  /// Heuristically determines whether a URL looks like a Mastodon/Fediverse status URL.
  static bool looksLikeMastodonStatusUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme || !uri.hasAuthority) return false;
    final segments = uri.pathSegments;
    // Matches /@username/1234567890 or /users/username/statuses/1234567890
    if (segments.length >= 2 &&
        segments[0].startsWith('@') &&
        RegExp(r'^\d+$').hasMatch(segments[1])) {
      return true;
    }
    if (segments.length >= 4 &&
        segments[0] == 'users' &&
        segments[2] == 'statuses') {
      return true;
    }
    if (segments.length >= 2 && segments[0] == 'notice') {
      return true;
    }
    return false;
  }
}
