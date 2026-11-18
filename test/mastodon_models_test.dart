// Copyright (c) 2026 brokengoose <brokengoose@users.noreply.github.com>
// SPDX-License-Identifier: MIT

import 'package:fedicaption_mobile/core/html_utils.dart';
import 'package:fedicaption_mobile/models/mastodon_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('InstanceLimits', () {
    test('parses Mastodon v2 configuration limits', () {
      final limits = InstanceLimits.fromInstanceJson({
        'title': 'Accessibility.social',
        'configuration': {
          'statuses': {
            'max_characters': 1000,
            'max_media_attachments': 6,
          },
          'media_attachments': {
            'description_limit': 2000,
          },
        },
      });

      expect(limits.maxCharacters, 1000);
      expect(limits.maxMediaAttachments, 6);
      expect(limits.altTextLimit, 2000);
    });

    test('falls back to Glitch-soc/Pleroma max_toot_chars and defaults', () {
      final glitchLimits = InstanceLimits.fromInstanceJson({
        'max_toot_chars': 5000,
      });
      expect(glitchLimits.maxCharacters, 5000);
      expect(glitchLimits.maxMediaAttachments, 4);
      expect(glitchLimits.altTextLimit, 1500);

      final defaultLimits = InstanceLimits.fromInstanceJson({});
      expect(defaultLimits.maxCharacters, 500);
      expect(defaultLimits.maxMediaAttachments, 4);
      expect(defaultLimits.altTextLimit, 1500);
    });
  });

  group('HtmlUtils', () {
    test('converts Mastodon HTML to clean plain text', () {
      const html = '<p>Hello <a href="https://example.com">world</a>!<br>Line two.</p>';
      expect(HtmlUtils.htmlToPlainText(html), 'Hello world!\nLine two.');
    });

    test('extracts clean URLs and detects Mastodon status links', () {
      const text =
          'Read https://example.org/news. Also see https://mastodon.social/@brokengoose/1122334455!';
      final urls = HtmlUtils.extractUrls(text);
      expect(urls, [
        'https://example.org/news',
        'https://mastodon.social/@brokengoose/1122334455',
      ]);
      expect(HtmlUtils.looksLikeMastodonStatusUrl(urls[0]), isFalse);
      expect(HtmlUtils.looksLikeMastodonStatusUrl(urls[1]), isTrue);
    });
  });
}
