// Copyright (c) 2026 brokengoose <brokengoose@users.noreply.github.com>
// SPDX-License-Identifier: MIT

import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_theme.dart';
import '../../models/app_settings.dart';
import '../../models/bias_models.dart';

enum BiasReviewAction {
  editInComposer,
  useSuggestedInComposer,
  useSuggestedAndPublishNow,
  publishAnyway,
}

/// Modal sheet presented ONLY when racial or gender bias is detected before publishing
/// (Sections 4.2 and 5.2).
class BiasReviewSheet extends StatelessWidget {
  const BiasReviewSheet({
    super.key,
    required this.result,
    required this.policy,
  });

  final BiasCheckResult result;
  final PolicyMode policy;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fedi = context.fediColors;
    final hasSuggestion =
        (result.suggestedAlternateWording ?? '').trim().isNotEmpty;
    final allowPublishAnyway = policy == PolicyMode.warn;

    return SafeArea(
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.82,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) {
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
                child: Row(
                  children: [
                    Icon(Icons.balance, color: fedi.biasWarningFg),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Semantics(
                        header: true,
                        child: Text(
                          'Pre-Post Racial & Gender Bias Review',
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context)
                          .pop(BiasReviewAction.editInComposer),
                      tooltip: 'Close and return to composer',
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16),
                  children: [
                    // 1. Brief Summary
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: fedi.biasWarningBg,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: fedi.biasWarningFg,
                          width: fedi.isHighContrast ? 2 : 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Summary',
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: fedi.biasWarningFg,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            result.summary,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(color: fedi.biasWarningFg),
                          ),
                          if (result.checkedComponents.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              'Checked: ${result.checkedComponents.join(', ')}',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelMedium
                                  ?.copyWith(color: fedi.biasWarningFg),
                            ),
                          ],
                          if (result.usedLocalFallback) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Note: Analyzed using offline local bias heuristics.',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(color: fedi.biasWarningFg),
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // 2. Where the bias was found
                    Semantics(
                      header: true,
                      child: Text(
                        'Where Bias Was Found (${result.findings.length})',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 8),

                    for (final finding in result.findings)
                      Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Wrap(
                                spacing: 8,
                                runSpacing: 6,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Chip(
                                    label: Text(
                                      finding.location,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  Chip(
                                    backgroundColor: fedi.biasWarningBg,
                                    label: Text(
                                      finding.biasType,
                                      style: TextStyle(
                                        color: fedi.biasWarningFg,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                ],
                              ),
                              if (finding.excerpt != null &&
                                  finding.excerpt!.trim().isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text(
                                  'Excerpt: "${finding.excerpt}"',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        fontStyle: FontStyle.italic,
                                        color: fedi.subtleText,
                                      ),
                                ),
                              ],
                              const SizedBox(height: 6),
                              Text(
                                finding.explanation,
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ],
                          ),
                        ),
                      ),

                    // 3. Suggested Alternate Wording
                    if (hasSuggestion) ...[
                      const SizedBox(height: 12),
                      Semantics(
                        header: true,
                        child: Text(
                          'Suggested Alternate Wording',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: fedi.altPresentBg,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: fedi.altPresentFg,
                            width: fedi.isHighContrast ? 2 : 1,
                          ),
                        ),
                        child: SelectableText(
                          result.suggestedAlternateWording!,
                          style:
                              Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    color: fedi.altPresentFg,
                                  ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: () => Navigator.of(context)
                            .pop(BiasReviewAction.useSuggestedAndPublishNow),
                        icon: const Icon(Icons.send),
                        label: const Text('Use Suggested Wording & Publish Now'),
                      ),
                      const SizedBox(height: 8),
                      FilledButton.tonalIcon(
                        onPressed: () => Navigator.of(context)
                            .pop(BiasReviewAction.useSuggestedInComposer),
                        icon: const Icon(Icons.edit_note),
                        label: const Text('Use Suggested Wording in Composer'),
                      ),
                    ],

                    const SizedBox(height: 12),

                    OutlinedButton.icon(
                      onPressed: () => Navigator.of(context)
                          .pop(BiasReviewAction.editInComposer),
                      icon: const Icon(Icons.arrow_back),
                      label: const Text('Return to Composer to Edit'),
                    ),

                    if (allowPublishAnyway) ...[
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () => Navigator.of(context)
                            .pop(BiasReviewAction.publishAnyway),
                        style: TextButton.styleFrom(
                          foregroundColor: scheme.error,
                        ),
                        child: const Text('Publish Anyway'),
                      ),
                    ] else ...[
                      const SizedBox(height: 10),
                      Text(
                        'Your Bias Rules policy is set to Require: please revise the post before publishing.',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: scheme.error),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
