// Copyright (c) 2026 brokengoose <brokengoose@users.noreply.github.com>
// SPDX-License-Identifier: MIT

import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_theme.dart';
import '../../l10n/l10n.dart';
import '../../l10n/model_localizations.dart';
import '../../state/app_controller.dart';

/// Displays live on-device AI capability (Apple Foundation Models on iPhone /
/// Google Gemini Nano via ML Kit GenAI & AICore on Pixel & Samsung flagships),
/// with one-tap model download and refresh controls.
class OnDeviceAiStatusCard extends StatelessWidget {
  const OnDeviceAiStatusCard({super.key, required this.app});

  final AppController app;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fedi = context.fediColors;
    final l10n = context.l10n;
    final status = app.onDeviceAiStatus;
    final checking = app.isCheckingOnDeviceAi;
    final downloading = app.isDownloadingOnDeviceModel;
    final error = app.onDeviceAiError;

    final (bg, fg, icon, badge) = status.isReady
        ? (
            fedi.altPresentBg,
            fedi.altPresentFg,
            Icons.check_circle_outline,
            l10n.onDeviceAiBadgeReady,
          )
        : status.isDownloadable
        ? (
            scheme.primaryContainer,
            scheme.onPrimaryContainer,
            Icons.download_for_offline_outlined,
            l10n.onDeviceAiBadgeDownloadable,
          )
        : status.isNotYetReady
        ? (
            fedi.biasWarningBg,
            fedi.biasWarningFg,
            Icons.settings_suggest_outlined,
            l10n.onDeviceAiBadgeNotYetReady,
          )
        : (
            fedi.altMissingBg,
            fedi.altMissingFg,
            Icons.info_outline,
            l10n.onDeviceAiBadgeUnavailable,
          );

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: fg, width: fedi.isHighContrast ? 2 : 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: fg),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.onDeviceAiStatusHeader(
                    status.localizedEngineName(l10n),
                    badge,
                  ),
                  style: Theme.of(context).textTheme.titleSmall
                      ?.copyWith(color: fg, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            status.localizedSummaryMessage(l10n),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: fg),
          ),
          const SizedBox(height: 6),
          Text(
            status.localizedDiagnosticDetail(l10n),
            style: Theme.of(context).textTheme.labelSmall
                ?.copyWith(color: fg.withAlpha(220)),
          ),
          if (error != null && error.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              error,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: scheme.error),
            ),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (status.isDownloadable)
                FilledButton.icon(
                  onPressed: downloading ? null : app.downloadOnDeviceModel,
                  icon: downloading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.download),
                  label: Text(
                    downloading
                        ? l10n.onDeviceAiDownloadingModelButton
                        : l10n.onDeviceAiDownloadModelButton,
                  ),
                ),
              OutlinedButton.icon(
                onPressed: checking ? null : app.refreshOnDeviceAiStatus,
                style: OutlinedButton.styleFrom(
                  foregroundColor: fg,
                  side: BorderSide(color: fg),
                ),
                icon: checking
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: fg,
                        ),
                      )
                    : const Icon(Icons.refresh, size: 18),
                label: Text(
                  checking
                      ? l10n.onDeviceAiCheckingButton
                      : l10n.onDeviceAiRecheckButton,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
