// Copyright (c) 2026 brokengoose <brokengoose@users.noreply.github.com>
// SPDX-License-Identifier: MIT

import 'package:fedicaption_mobile/core/constants.dart';
import 'package:fedicaption_mobile/services/caption_formatter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CaptionFormatter', () {
    test('prepends exact mandatory prefix', () {
      final result = CaptionFormatter.format('A red fox sitting in fresh snow.');
      expect(
        result,
        '${AppConstants.aiCaptionPrefix}A red fox sitting in fresh snow.',
      );
    });

    test('strips surrounding quotes and redundant preambles', () {
      expect(
        CaptionFormatter.format('"Image of a golden retriever catching a ball."'),
        'AI generated description: A golden retriever catching a ball.',
      );
      expect(
        CaptionFormatter.format('Alt text: Photo of a sunset over calm water.'),
        'AI generated description: A sunset over calm water.',
      );
      expect(
        CaptionFormatter.format('Video of dancers practicing on a bright stage.'),
        'AI generated description: Dancers practicing on a bright stage.',
      );
      expect(
        CaptionFormatter.format('Description: "A handwritten café menu sign."'),
        'AI generated description: A handwritten café menu sign.',
      );
    });

    test('deduplicates repeated AI generated description prefixes', () {
      expect(
        CaptionFormatter.format(
          'AI generated description: Automatically generated description: A cat sleeping on a keyboard.',
        ),
        'AI generated description: A cat sleeping on a keyboard.',
      );
    });

    test('truncates cleanly on word boundary with ellipsis when exceeding maxLength', () {
      final longInput =
          'A bustling community farmers market with dozens of colorful produce stalls, fresh flowers, and hand-painted wooden price signs.';
      final formatted = CaptionFormatter.format(longInput, maxLength: 80);

      expect(formatted.startsWith(AppConstants.aiCaptionPrefix), isTrue);
      expect(formatted.length, lessThanOrEqualTo(80));
      expect(formatted.endsWith('…'), isTrue);
      // Must not end mid-word like "colo…"
      expect(formatted.contains('colorf…'), isFalse);
    });
  });
}
