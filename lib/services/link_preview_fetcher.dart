// Copyright (c) 2026 brokengoose <brokengoose@users.noreply.github.com>
// SPDX-License-Identifier: MIT

import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;

import '../core/constants.dart';
import '../models/bias_models.dart';

/// Fetches external web pages linked in a draft post and extracts title,
/// meta description, and a clean text excerpt for pre-post bias analysis.
class LinkPreviewFetcher {
  LinkPreviewFetcher({http.Client? client})
      : _client = client ?? http.Client(),
        _ownsClient = client == null;

  final http.Client _client;
  final bool _ownsClient;

  static const int _maxHtmlChars = 120000;
  static const int _maxExcerptChars = 1500;

  /// Closes the internally owned HTTP client (no-op if an external client was injected).
  void dispose() {
    if (_ownsClient) {
      _client.close();
    }
  }

  Future<LinkedPageExcerpt?> fetch(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
      return null;
    }

    try {
      final res = await _client
          .get(
            uri,
            headers: const {
              'User-Agent':
                  'FediCaptionMobile/${AppConstants.appVersion} (+${AppConstants.repositoryUrl})',
              'Accept': 'text/html,application/xhtml+xml,text/plain;q=0.9,*/*;q=0.1',
            },
          )
          .timeout(const Duration(seconds: 8));

      if (res.statusCode < 200 || res.statusCode >= 300) {
        return null;
      }

      final contentType = (res.headers['content-type'] ?? '').toLowerCase();
      if (contentType.isNotEmpty &&
          !contentType.contains('html') &&
          !contentType.contains('text/plain') &&
          !contentType.contains('xml')) {
        return null;
      }

      final rawBody = res.body.length > _maxHtmlChars
          ? res.body.substring(0, _maxHtmlChars)
          : res.body;

      return parseHtmlExcerpt(url, rawBody);
    } catch (_) {
      return null;
    }
  }

  /// Parses title, meta description, and main body text excerpt from raw HTML.
  static LinkedPageExcerpt parseHtmlExcerpt(String url, String htmlBody) {
    final doc = html_parser.parse(htmlBody);

    final title = (doc.querySelector('title')?.text ?? '').trim();

    String metaDescription = '';
    for (final meta in doc.querySelectorAll('meta')) {
      final name = (meta.attributes['name'] ?? '').toLowerCase();
      final property = (meta.attributes['property'] ?? '').toLowerCase();
      if (name == 'description' ||
          property == 'og:description' ||
          name == 'twitter:description') {
        final content = (meta.attributes['content'] ?? '').trim();
        if (content.isNotEmpty) {
          metaDescription = content;
          break;
        }
      }
    }

    // Strip non-content tags before extracting body excerpt.
    for (final tag in doc.querySelectorAll('script, style, noscript, svg, nav, footer')) {
      tag.remove();
    }

    final rawText = (doc.body?.text ?? doc.documentElement?.text ?? '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    final excerpt = rawText.length > _maxExcerptChars
        ? '${rawText.substring(0, _maxExcerptChars)}…'
        : rawText;

    return LinkedPageExcerpt(
      url: url,
      title: title,
      metaDescription: metaDescription,
      textExcerpt: excerpt,
    );
  }
}
