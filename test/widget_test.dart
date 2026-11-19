// Copyright (c) 2026 brokengoose <brokengoose@users.noreply.github.com>
// SPDX-License-Identifier: MIT

import 'package:fedicaption_mobile/core/theme/app_theme.dart';
import 'package:fedicaption_mobile/models/app_settings.dart';
import 'package:fedicaption_mobile/models/bias_models.dart';
import 'package:fedicaption_mobile/ui/widgets/bias_review_sheet.dart';
import 'package:fedicaption_mobile/ui/widgets/missing_alt_text_dialog.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const sampleResult = BiasCheckResult(
    hasBias: true,
    summary: 'Checked Post Text and found 1 potential gender bias issue.',
    checkedComponents: ['Post Text'],
    findings: [
      BiasFinding(
        location: 'Post Text',
        biasType: 'Implicit Gender Bias',
        explanation: '"hey guys" uses a male-default plural; consider "hey everyone".',
        excerpt: 'Hey guys',
      ),
    ],
    suggestedAlternateWording: 'Hey everyone, welcome to the community!',
  );

  group('BiasReviewSheet policy behavior', () {
    testWidgets('shows Publish Anyway and suggestion buttons when policy is warn', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(
            body: BiasReviewSheet(
              result: sampleResult,
              policy: PolicyMode.warn,
            ),
          ),
        ),
      );

      expect(find.text('Pre-Post Racial & Gender Bias Review'), findsOneWidget);
      expect(find.text('Post Text'), findsOneWidget);
      expect(find.text('Implicit Gender Bias'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('Publish Anyway'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Use Suggested Wording in Composer'), findsOneWidget);
      expect(find.text('Use Suggested Wording & Publish Now'), findsOneWidget);
      expect(find.text('Publish Anyway'), findsOneWidget);
    });

    testWidgets('hides Publish Anyway when policy is require', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.highContrast(),
          home: const Scaffold(
            body: BiasReviewSheet(
              result: sampleResult,
              policy: PolicyMode.require,
            ),
          ),
        ),
      );

      await tester.scrollUntilVisible(
        find.text('Return to Composer to Edit'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Publish Anyway'), findsNothing);
      expect(find.text('Use Suggested Wording & Publish Now'), findsOneWidget);
    });
  });

  group('MissingAltTextDialog policy behavior', () {
    testWidgets('shows Post Anyway when policy is warn and hides it when require', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark(),
          home: const Scaffold(
            body: MissingAltTextDialog(
              missingCount: 2,
              policy: PolicyMode.warn,
            ),
          ),
        ),
      );

      expect(find.text('Auto-Generate Missing Alt-Text with AI'), findsOneWidget);
      expect(find.text('Post Anyway'), findsOneWidget);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark(),
          home: const Scaffold(
            body: MissingAltTextDialog(
              missingCount: 2,
              policy: PolicyMode.require,
            ),
          ),
        ),
      );

      expect(find.text('Auto-Generate Missing Alt-Text with AI'), findsOneWidget);
      expect(find.text('Post Anyway'), findsNothing);
    });
  });
}
