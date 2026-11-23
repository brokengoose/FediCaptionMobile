// Copyright (c) 2026 brokengoose <brokengoose@users.noreply.github.com>
// SPDX-License-Identifier: MIT

import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_theme.dart';
import '../../services/translation_service.dart';

/// Compact, accessible banner displayed at the top of an opened post when the
/// post's language differs from the user's operating system language.
class PostTranslationBanner extends StatelessWidget {
  const PostTranslationBanner({
    super.key,
    required this.sourceLanguageCode,
    required this.targetLanguageCode,
    required this.isTranslating,
    required this.showingTranslation,
    required this.onTranslate,
    required this.onToggleOriginal,
    this.translationResult,
    this.errorMessage,
  });

  final String sourceLanguageCode;
  final String targetLanguageCode;
  final bool isTranslating;
  final bool showingTranslation;
  final VoidCallback onTranslate;
  final VoidCallback onToggleOriginal;
  final PostTranslationResult? translationResult;
  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fedi = context.fediColors;
    final srcName = TranslationService.languageDisplayName(sourceLanguageCode);
    final tgtName = TranslationService.languageDisplayName(targetLanguageCode);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.8),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.translate, size: 18, color: scheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isTranslating
                      ? 'Translating from $srcName to $tgtName…'
                      : translationResult != null && showingTranslation
                          ? 'Translated from $srcName via ${translationResult!.engineName}'
                          : 'Written in $srcName',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: fedi.subtleText,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
              const SizedBox(width: 8),
              if (isTranslating)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else if (translationResult != null)
                TextButton(
                  onPressed: onToggleOriginal,
                  child: Text(
                    showingTranslation ? 'Show Original' : 'Show Translation',
                  ),
                )
              else
                FilledButton.tonalIcon(
                  onPressed: onTranslate,
                  icon: const Icon(Icons.translate, size: 16),
                  label: Text('Translate to $tgtName'),
                ),
            ],
          ),
          if (errorMessage != null && !isTranslating) ...[
            const SizedBox(height: 6),
            Semantics(
              liveRegion: true,
              child: Text(
                errorMessage!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.error,
                    ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
