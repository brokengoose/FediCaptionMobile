// Copyright (c) 2026 brokengoose <brokengoose@users.noreply.github.com>
// SPDX-License-Identifier: MIT

import 'dart:convert';

import 'package:fedicaption_mobile/models/ai_models.dart';
import 'package:fedicaption_mobile/models/app_settings.dart';
import 'package:fedicaption_mobile/models/bias_models.dart';
import 'package:fedicaption_mobile/services/ai_provider_service.dart';
import 'package:fedicaption_mobile/services/bias_check_service.dart';
import 'package:fedicaption_mobile/services/link_preview_fetcher.dart';
import 'package:fedicaption_mobile/services/mastodon_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('BiasCheckService', () {
    test('falls back to local heuristics and checks linked webpage title/description when AI is offline', () async {
      final linkClient = MockClient((request) async {
        if (request.url.toString() == 'https://example.org/post') {
          return http.Response(
            '<html><head><title>Updating the Whitelist</title>'
            '<meta name="description" content="Legacy blacklist policy notes.">'
            '</head><body><p>Read more about grandfathered accounts.</p></body></html>',
            200,
            headers: {'content-type': 'text/html; charset=utf-8'},
          );
        }
        return http.Response('Not found', 404);
      });

      final offlineAiClient = MockClient((_) async {
        throw Exception('Network unreachable');
      });

      final service = BiasCheckService(
        aiProviderService: AiProviderService(client: offlineAiClient),
        linkPreviewFetcher: LinkPreviewFetcher(client: linkClient),
        mastodonService: MastodonService(client: offlineAiClient),
      );

      final result = await service.checkDraft(
        input: const BiasCheckInput(
          postText: 'Hey guys, check out https://example.org/post',
        ),
        settings: const AppSettings(activeProvider: AiProviderType.gemini),
        credentials: const AiCredentials(geminiApiKey: 'key'),
      );

      expect(result.hasBias, isTrue);
      expect(result.usedLocalFallback, isTrue);
      expect(
        result.findings.any((f) => f.location == 'Post Text'),
        isTrue,
      );
      expect(
        result.findings.any(
          (f) => f.location == 'Link (https://example.org/post)',
        ),
        isTrue,
      );
      expect(
        result.suggestedAlternateWording,
        'Hey everyone, check out https://example.org/post',
      );
    });

    test('parses AI JSON with trailing commas and merges local backstop for "bitching"', () async {
      final aiClient = MockClient((_) async {
        return http.Response(
          '{"candidates":[{"content":{"parts":[{"text":"```json\\n{\\"has_bias\\": false, \\"summary\\": \\"No bias.\\", \\"findings\\": [],}\\n```"}]}}]}',
          200,
        );
      });

      final service = BiasCheckService(
        aiProviderService: AiProviderService(client: aiClient),
        linkPreviewFetcher: LinkPreviewFetcher(client: aiClient),
        mastodonService: MastodonService(client: aiClient),
      );

      final result = await service.checkDraft(
        input: const BiasCheckInput(
          postText: 'Quit bitching about the rain.',
        ),
        settings: const AppSettings(activeProvider: AiProviderType.gemini),
        credentials: const AiCredentials(geminiApiKey: 'key'),
      );

      expect(result.hasBias, isTrue);
      expect(
        result.findings.any((f) => f.excerpt?.toLowerCase() == 'bitching'),
        isTrue,
      );
      expect(
        result.suggestedAlternateWording,
        'Quit complaining about the rain.',
      );
    });

    test('tolerates loosely typed AI JSON instead of silently falling back', () async {
      // has_bias as a string and a numeric excerpt used to throw on `as` casts,
      // discarding the AI result in favour of the local heuristics.
      final aiJson = jsonEncode({
        'has_bias': 'true',
        'summary': 'Possible bias.',
        'findings': [
          {
            'location': 'Post Text',
            'bias_type': 'Implicit Gender Bias',
            'explanation': 'Assumes the engineer is a man.',
            'excerpt': 42,
          },
        ],
        'suggested_alternate_wording': null,
      });
      final aiClient = MockClient((_) async {
        return http.Response(
          jsonEncode({
            'candidates': [
              {
                'content': {
                  'parts': [
                    {'text': aiJson},
                  ],
                },
              },
            ],
          }),
          200,
        );
      });

      final service = BiasCheckService(
        aiProviderService: AiProviderService(client: aiClient),
        linkPreviewFetcher: LinkPreviewFetcher(client: aiClient),
        mastodonService: MastodonService(client: aiClient),
      );

      final result = await service.checkDraft(
        input: const BiasCheckInput(
          postText: 'Ask the engineer what he thinks.',
        ),
        settings: const AppSettings(activeProvider: AiProviderType.gemini),
        credentials: const AiCredentials(geminiApiKey: 'key'),
      );

      expect(result.usedLocalFallback, isFalse);
      expect(result.hasBias, isTrue);
      expect(result.summary, 'Possible bias.');
      expect(
        result.findings.single.excerpt,
        '42',
      );
    });

    test('sends the Gemini API key in a header, never in the URL', () async {
      final seen = <http.BaseRequest>[];
      final aiClient = MockClient((request) async {
        seen.add(request);
        return http.Response('{"candidates":[]}', 500);
      });
      final service = BiasCheckService(
        aiProviderService: AiProviderService(client: aiClient),
        linkPreviewFetcher: LinkPreviewFetcher(client: aiClient),
        mastodonService: MastodonService(client: aiClient),
      );

      await service.checkDraft(
        input: const BiasCheckInput(postText: 'Hello'),
        settings: const AppSettings(activeProvider: AiProviderType.gemini),
        credentials: const AiCredentials(geminiApiKey: 'secret-gemini-key'),
      );

      final gemini = seen.where(
        (r) => r.url.host.contains('generativelanguage'),
      );
      expect(gemini, isNotEmpty);
      for (final r in gemini) {
        expect(r.url.toString(), isNot(contains('secret-gemini-key')));
        expect(r.headers['x-goog-api-key'], 'secret-gemini-key');
      }
    });
  });
}
