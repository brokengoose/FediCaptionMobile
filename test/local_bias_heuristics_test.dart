// Copyright (c) 2026 brokengoose <brokengoose@users.noreply.github.com>
// SPDX-License-Identifier: MIT

import 'package:fedicaption_mobile/models/bias_models.dart';
import 'package:fedicaption_mobile/services/local_bias_heuristics.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LocalBiasHeuristics', () {
    test('returns clean result for inclusive neutral text', () {
      final result = LocalBiasHeuristics.evaluate(
        input: const BiasCheckInput(
          postText: 'Hey everyone, our firefighters and police officers did great work today!',
        ),
      );
      expect(result.hasBias, isFalse);
      expect(result.findings, isEmpty);
      expect(result.suggestedAlternateWording, isNull);
    });

    test('detects required gender-exclusive and racially loaded terms and suggests alternate wording', () {
      final result = LocalBiasHeuristics.evaluate(
        input: const BiasCheckInput(
          postText:
              'Hey guys, the chairman asked manpower to update the whitelist and master/slave config for mankind.',
        ),
      );

      expect(result.hasBias, isTrue);
      expect(result.usedLocalFallback, isTrue);
      expect(result.findings.length, greaterThanOrEqualTo(5));
      expect(result.suggestedAlternateWording, isNotNull);
      expect(
        result.suggestedAlternateWording,
        'Hey everyone, the chairperson asked workforce to update the allowlist and primary/replica config for humanity.',
      );
    });

    test('checks Content Warning, Attachments, Links, and Referenced Messages with accurate locations', () {
      final result = LocalBiasHeuristics.evaluate(
        input: const BiasCheckInput(
          postText: 'Sharing this update.',
          spoilerText: 'Discussion about grandfathered policies',
          attachments: [
            BiasAttachmentInput(
              index: 1,
              altText: 'A fireman and policeman standing beside a truck.',
              isVideo: false,
            ),
          ],
          referencedStatuses: [
            ReferencedStatusContext(
              authorHandle: 'alice@example.social',
              contentText: 'Inviting all husbands and wives to the banquet.',
            ),
          ],
        ),
        links: const [
          LinkedPageExcerpt(
            url: 'https://example.org/article',
            title: 'Blacklist Rules Explained',
            metaDescription: '',
            textExcerpt: '',
          ),
        ],
      );

      expect(result.hasBias, isTrue);
      final locations = result.findings.map((f) => f.location).toSet();
      expect(locations, contains('Content Warning'));
      expect(locations, contains('Attachment 1'));
      expect(locations, contains('Link (https://example.org/article)'));
      expect(locations, contains('Referenced Message (@alice@example.social)'));
      // Main post text itself had no bias, so no rewrite needed.
      expect(result.suggestedAlternateWording, isNull);
    });
  });
}
