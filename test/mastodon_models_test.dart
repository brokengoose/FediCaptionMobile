// Copyright (c) 2026 brokengoose <brokengoose@users.noreply.github.com>
// SPDX-License-Identifier: MIT

import 'package:fedicaption_mobile/core/html_utils.dart';
import 'package:fedicaption_mobile/core/media_utils.dart';
import 'package:fedicaption_mobile/models/app_settings.dart';
import 'package:fedicaption_mobile/models/mastodon_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('InstanceLimits', () {
    test('parses Mastodon v2 configuration limits', () {
      final limits = InstanceLimits.fromInstanceJson({
        'title': 'Accessibility.social',
        'configuration': {
          'statuses': {'max_characters': 1000, 'max_media_attachments': 6},
          'media_attachments': {'description_limit': 2000},
          'translation': {'enabled': true},
        },
      });

      expect(limits.maxCharacters, 1000);
      expect(limits.maxMediaAttachments, 6);
      expect(limits.altTextLimit, 2000);
      expect(limits.translationEnabled, isTrue);
    });

    test('falls back to Glitch-soc/Pleroma max_toot_chars and defaults', () {
      final glitchLimits = InstanceLimits.fromInstanceJson({
        'max_toot_chars': 5000,
      });
      expect(glitchLimits.maxCharacters, 5000);
      expect(glitchLimits.maxMediaAttachments, 4);
      expect(glitchLimits.altTextLimit, 1500);
      expect(glitchLimits.translationEnabled, isFalse);

      final defaultLimits = InstanceLimits.fromInstanceJson({});
      expect(defaultLimits.maxCharacters, 500);
      expect(defaultLimits.maxMediaAttachments, 4);
      expect(defaultLimits.altTextLimit, 1500);
      expect(defaultLimits.translationEnabled, isFalse);
    });

    test('MastodonStatusTranslation parses HTML content, spoiler, provider, and alt-text', () {
      final translated = MastodonStatusTranslation.fromJson({
        'content': '<p>Hello <a href="https://example.com">world</a>!</p>',
        'spoiler_text': 'Translated CW',
        'detected_source_language': 'es',
        'provider': 'DeepL.com',
        'media_attachments': [
          {'id': 'att-1', 'description': 'A sleeping orange tabby cat'},
          {'id': '', 'description': 'Ignored empty id'},
        ],
      });

      expect(translated.plainContent, 'Hello world!');
      expect(translated.spoilerText, 'Translated CW');
      expect(translated.detectedSourceLanguage, 'es');
      expect(translated.provider, 'DeepL.com');
      expect(translated.mediaDescriptions, {
        'att-1': 'A sleeping orange tabby cat',
      });
    });
  });

  group('HtmlUtils', () {
    test('converts Mastodon HTML to clean plain text', () {
      const html =
          '<p>Hello <a href="https://example.com">world</a>!<br>Line two.</p>';
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

    test('extractLeadingQuote detects RE: followed by anchor or bare URL', () {
      final pQuote = HtmlUtils.extractLeadingQuote(
        '<p>RE: <a href="https://mastodon.social/@alice/12345">https://mastodon.social/@alice/12345</a></p><p>Great point!</p>',
      );
      expect(pQuote, isNotNull);
      expect(pQuote!.quoteUrl, 'https://mastodon.social/@alice/12345');
      expect(HtmlUtils.htmlToPlainText(pQuote.remainingHtml), 'Great point!');

      final inlineSpanQuote = HtmlUtils.extractLeadingQuote(
        '<p><span class="quote-inline">RE: <a href="https://hachyderm.io/@bob/999">link</a></span><br>My commentary</p>',
      );
      expect(inlineSpanQuote, isNotNull);
      expect(inlineSpanQuote!.quoteUrl, 'https://hachyderm.io/@bob/999');
      expect(
        HtmlUtils.htmlToPlainText(inlineSpanQuote.remainingHtml),
        'My commentary',
      );

      final bareUrlQuote = HtmlUtils.extractLeadingQuote(
        '<p>re: https://fosstodon.org/@carol/777 Look at this</p>',
      );
      expect(bareUrlQuote, isNotNull);
      expect(bareUrlQuote!.quoteUrl, 'https://fosstodon.org/@carol/777');
      expect(
        HtmlUtils.htmlToPlainText(bareUrlQuote.remainingHtml),
        'Look at this',
      );

      final nonQuote = HtmlUtils.extractLeadingQuote(
        '<p>RE: meeting notes from today without a link</p>',
      );
      expect(nonQuote, isNull);

      final regularUrl = HtmlUtils.extractLeadingQuote(
        '<p>Check out <a href="https://mastodon.social/@alice/12345">this post</a></p>',
      );
      expect(regularUrl, isNull);
    });
  });

  group('MastodonStatus native quote parsing', () {
    test('parses nested quote.quoted_status object', () {
      final status = MastodonStatus.fromJson({
        'id': '200',
        'created_at': '2026-11-19T12:00:00Z',
        'content': '<p>RE: <a href="https://example.social/@orig/100">link</a></p><p>Adding context</p>',
        'account': {
          'id': '2',
          'username': 'quoter',
          'acct': 'quoter',
          'display_name': 'Quoter',
          'avatar': '',
        },
        'quote': {
          'state': 'accepted',
          'quoted_status': {
            'id': '100',
            'created_at': '2026-11-19T11:00:00Z',
            'content': '<p>Original post text</p>',
            'account': {
              'id': '1',
              'username': 'orig',
              'acct': 'orig@example.social',
              'display_name': 'Original Author',
              'avatar': '',
            },
          },
        },
      });

      expect(status.quotedStatus, isNotNull);
      expect(status.quotedStatus!.id, '100');
      expect(status.quotedStatus!.plainText, 'Original post text');
    });
  });

  group('Model helpers & settings migration', () {
    test('MastodonMention.toStubAccount creates an account stub for profile navigation', () {
      const mention = MastodonMention(
        id: '42',
        username: 'alice',
        acct: 'alice@example.social',
        url: 'https://example.social/@alice',
      );
      final stub = mention.toStubAccount();
      expect(stub.id, '42');
      expect(stub.username, 'alice');
      expect(stub.handle, '@alice@example.social');
      expect(stub.url, 'https://example.social/@alice');
    });

    test(
      'MastodonNotification describes Mastodon 4.5+ quote notification types',
      () {
        final account = MastodonAccount.fromJson(const {
          'id': '1',
          'username': 'alice',
          'acct': 'alice',
          'display_name': 'Alice',
          'avatar': '',
        });
        final quoteNotif = MastodonNotification(
          id: 'n1',
          type: 'quote',
          createdAt: DateTime.utc(2026, 11, 20),
          account: account,
        );
        final quotedUpdateNotif = MastodonNotification(
          id: 'n2',
          type: 'quoted_update',
          createdAt: DateTime.utc(2026, 11, 20),
          account: account,
        );
        expect(quoteNotif.actionDescription, 'quoted your post');
        expect(quotedUpdateNotif.actionDescription, 'edited a post you quoted');
      },
    );

    test('MediaUtils detects video paths and infers MIME types', () {
      expect(MediaUtils.isVideoFilePath('/tmp/clip.MOV'), isTrue);
      expect(MediaUtils.isVideoFilePath('/tmp/photo.webp'), isFalse);
      expect(
        MediaUtils.guessMimeType('clip.mov', isVideo: true),
        'video/quicktime',
      );
      expect(
        MediaUtils.guessMimeType('clip.webm', isVideo: true),
        'video/webm',
      );
      expect(
        MediaUtils.guessMimeType('photo.png', isVideo: false),
        'image/png',
      );
      expect(
        MediaUtils.guessMimeType('photo.gif', isVideo: false),
        'image/gif',
      );
      expect(
        MediaUtils.guessMimeType('photo.jpg', isVideo: false),
        'image/jpeg',
      );
    });

    test('AppSettings.fromJson migrates removed legacy on-device-fallback localModel', () {
      final migrated = AppSettings.fromJson(const {
        'activeProvider': 'local',
        'localModel': 'on-device-fallback',
      });
      expect(migrated.localModel, 'llama3.2-vision');
    });
  });
}
