// Copyright (c) 2026 brokengoose <brokengoose@users.noreply.github.com>
// SPDX-License-Identifier: MIT

import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;

import '../core/constants.dart';
import '../models/bias_models.dart';

/// Fetches external web pages linked in a draft post and extracts title,
/// meta description, and a clean text excerpt for pre-post bias analysis.
///
/// Server-friendly behavior:
/// - Streams response headers first and immediately aborts non-HTML/text files
///   (such as large PDFs, videos, or archives) without downloading the body
/// - Caps downloaded body bytes at [maxDownloadBytes] (128 KB)
/// - Caches parsed excerpts in a bounded 15-minute LRU cache so repeated bias
///   checks while editing a draft do not re-hit external servers
class LinkPreviewFetcher {
  LinkPreviewFetcher({
    http.Client? client,
    this.maxDownloadBytes = 128 * 1024,
    this.cacheTtl = const Duration(minutes: 15),
    this.maxCacheEntries = 60,
  }) : _client = client ?? http.Client(),
       _ownsClient = client == null;

  final http.Client _client;
  final bool _ownsClient;
  final int maxDownloadBytes;
  final Duration cacheTtl;
  final int maxCacheEntries;

  static const int _maxHtmlChars = 120000;
  static const int _maxExcerptChars = 1500;

  final LinkedHashMap<
    String,
    ({LinkedPageExcerpt? excerpt, DateTime fetchedAt})
  >
  _cache = LinkedHashMap();

  /// Closes the internally owned HTTP client (no-op if an external client was injected).
  void dispose() {
    _cache.clear();
    if (_ownsClient) {
      _client.close();
    }
  }

  Future<LinkedPageExcerpt?> fetch(String url) async {
    final trimmed = url.trim();
    final uri = Uri.tryParse(trimmed);
    if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
      return null;
    }

    final cached = _cache[trimmed];
    if (cached != null &&
        DateTime.now().difference(cached.fetchedAt) < cacheTtl) {
      _cache.remove(trimmed);
      _cache[trimmed] = cached;
      return cached.excerpt;
    }

    try {
      final request = http.Request('GET', uri)
        ..headers.addAll(const {
          'User-Agent':
              'FediCaption/${AppConstants.appVersion} (+${AppConstants.repositoryUrl})',
          'Accept':
              'text/html,application/xhtml+xml,text/plain;q=0.9,*/*;q=0.1',
        });

      final streamed = await _client
          .send(request)
          .timeout(const Duration(seconds: 8));

      if (streamed.statusCode < 200 || streamed.statusCode >= 300) {
        await streamed.stream.drain<void>().catchError((_) {});
        _putCache(trimmed, null);
        return null;
      }

      final contentType = (streamed.headers['content-type'] ?? '')
          .toLowerCase();
      if (contentType.isNotEmpty &&
          !contentType.contains('html') &&
          !contentType.contains('text/plain') &&
          !contentType.contains('xml')) {
        // Abort stream immediately without downloading non-text binaries.
        final sub = streamed.stream.listen((_) {});
        await sub.cancel();
        _putCache(trimmed, null);
        return null;
      }

      final bytes = await _readBoundedBytes(streamed.stream, maxDownloadBytes);
      final rawString = utf8.decode(bytes, allowMalformed: true);
      final rawBody = rawString.length > _maxHtmlChars
          ? rawString.substring(0, _maxHtmlChars)
          : rawString;

      final excerpt = parseHtmlExcerpt(trimmed, rawBody);
      _putCache(trimmed, excerpt);
      return excerpt;
    } catch (_) {
      return null;
    }
  }

  Future<List<int>> _readBoundedBytes(http.ByteStream stream, int limit) async {
    final buffer = <int>[];
    final completer = Completer<List<int>>();
    late StreamSubscription<List<int>> sub;

    sub = stream.listen(
      (chunk) {
        final remaining = limit - buffer.length;
        if (remaining <= 0) {
          sub.cancel();
          if (!completer.isCompleted) completer.complete(buffer);
          return;
        }
        if (chunk.length <= remaining) {
          buffer.addAll(chunk);
        } else {
          buffer.addAll(chunk.sublist(0, remaining));
          sub.cancel();
          if (!completer.isCompleted) completer.complete(buffer);
        }
      },
      onDone: () {
        if (!completer.isCompleted) completer.complete(buffer);
      },
      onError: (Object err) {
        if (!completer.isCompleted) {
          if (buffer.isNotEmpty) {
            completer.complete(buffer);
          } else {
            completer.completeError(err);
          }
        }
      },
      cancelOnError: true,
    );

    return completer.future.timeout(
      const Duration(seconds: 8),
      onTimeout: () async {
        await sub.cancel();
        return buffer;
      },
    );
  }

  void _putCache(String url, LinkedPageExcerpt? excerpt) {
    _cache.remove(url);
    _cache[url] = (excerpt: excerpt, fetchedAt: DateTime.now());
    while (_cache.length > maxCacheEntries) {
      _cache.remove(_cache.keys.first);
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
    for (final tag in doc.querySelectorAll(
      'script, style, noscript, svg, nav, footer',
    )) {
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
