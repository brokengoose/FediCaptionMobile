// Copyright (c) 2026 brokengoose <brokengoose@users.noreply.github.com>
// SPDX-License-Identifier: MIT

import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

/// Result of extracting a leading `RE: <url>` quote prefix from Mastodon HTML.
class LeadingQuoteMatch {
  const LeadingQuoteMatch({
    required this.quoteUrl,
    required this.remainingHtml,
  });

  final String quoteUrl;
  final String remainingHtml;
}

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

  /// Detects a Mastodon/Fediverse quote post that begins with `RE:` followed by a URL
  /// (either an `<a href="...">` tag or a bare `http://`/`https://` URL), and returns
  /// both the quoted URL and the remaining post HTML with the leading `RE: <url>` stripped.
  static LeadingQuoteMatch? extractLeadingQuote(String htmlContent) {
    if (htmlContent.trim().isEmpty) return null;

    final fragment = html_parser.parseFragment(htmlContent);

    // Find the first meaningful element/text block (usually <p> or top-level nodes).
    dom.Node? container;
    for (final node in fragment.nodes) {
      if (node is dom.Text && node.text.trim().isEmpty) continue;
      container = node;
      break;
    }
    if (container == null) return null;

    // Inspect either inside the first <p>/<div>/<span> or directly in the fragment.
    final bool isWrapperElement = container is dom.Element &&
        const {'p', 'div', 'span'}.contains(container.localName?.toLowerCase());
    final dom.Node targetParent = isWrapperElement ? container : fragment;

    final extractedUrl = _extractAndStripLeadingRePrefix(targetParent);
    if (extractedUrl == null || extractedUrl.isEmpty) {
      return null;
    }

    // Remove the wrapper <p>/<div>/<span> if it became empty after stripping `RE: <url>`.
    if (isWrapperElement && targetParent.text?.trim().isEmpty == true) {
      targetParent.remove();
    }

    return LeadingQuoteMatch(
      quoteUrl: extractedUrl,
      remainingHtml: fragment.outerHtml.trim(),
    );
  }

  static String? _extractAndStripLeadingRePrefix(dom.Node parent) {
    // Handle nested <span class="quote-inline">RE: <a href="...">...</a></span>
    final nonEmptyNodes = parent.nodes
        .where((n) => !(n is dom.Text && n.text.trim().isEmpty))
        .toList();
    if (nonEmptyNodes.isEmpty) return null;

    final first = nonEmptyNodes.first;
    if (first is dom.Element &&
        first.localName?.toLowerCase() == 'span' &&
        first.text.trimLeft().toUpperCase().startsWith('RE:')) {
      final innerUrl = _extractAndStripLeadingRePrefix(first);
      if (innerUrl != null) {
        if (first.text.trim().isEmpty) {
          first.remove();
          _stripLeadingBreaksAndWhitespace(parent);
        }
        return innerUrl;
      }
    }

    // Must begin with text matching `RE:` (case-insensitive).
    if (first is! dom.Text) return null;
    final rawFirstText = first.text;
    final reMatch = RegExp(r'^\s*RE\s*:\s*', caseSensitive: false)
        .firstMatch(rawFirstText);
    if (reMatch == null) return null;

    final afterRe = rawFirstText.substring(reMatch.end);

    // Case 1: `RE: https://...` directly inside the same text node.
    if (afterRe.trim().isNotEmpty) {
      final bareUrlMatch =
          RegExp(r'^(https?://[^\s<>()"\[\]]+)', caseSensitive: false)
              .firstMatch(afterRe.trimLeft());
      if (bareUrlMatch == null) return null;

      var url = bareUrlMatch.group(1) ?? '';
      while (url.isNotEmpty && '.,;:!?)\'"'.contains(url[url.length - 1])) {
        url = url.substring(0, url.length - 1);
      }
      if (url.isEmpty) return null;

      final trimmedLeft = afterRe.trimLeft();
      final remainder = trimmedLeft.substring(url.length).trimLeft();
      if (remainder.isEmpty) {
        first.remove();
        _stripLeadingBreaksAndWhitespace(parent);
      } else {
        first.text = remainder;
      }
      return url;
    }

    // Case 2: `RE: ` text node followed immediately by `<a href="https://...">`.
    final firstIdx = parent.nodes.indexOf(first);
    dom.Element? anchor;
    for (var i = firstIdx + 1; i < parent.nodes.length; i++) {
      final candidate = parent.nodes[i];
      if (candidate is dom.Text && candidate.text.trim().isEmpty) continue;
      if (candidate is dom.Element &&
          candidate.localName?.toLowerCase() == 'a') {
        anchor = candidate;
      }
      break;
    }
    if (anchor == null) return null;

    final href = (anchor.attributes['href'] ?? '').trim();
    final uri = Uri.tryParse(href);
    if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
      return null;
    }

    // Strip the `RE:` text node, anchor, and any immediate trailing <br> / whitespace.
    first.remove();
    anchor.remove();
    _stripLeadingBreaksAndWhitespace(parent);
    return href;
  }

  static void _stripLeadingBreaksAndWhitespace(dom.Node parent) {
    while (parent.nodes.isNotEmpty) {
      final head = parent.nodes.first;
      if (head is dom.Text) {
        final trimmed = head.text.trimLeft();
        if (trimmed.isEmpty) {
          head.remove();
          continue;
        }
        head.text = trimmed;
        break;
      }
      if (head is dom.Element && head.localName?.toLowerCase() == 'br') {
        head.remove();
        continue;
      }
      break;
    }
  }
}
