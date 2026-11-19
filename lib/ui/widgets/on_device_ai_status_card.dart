// Copyright (c) 2026 brokengoose <brokengoose@users.noreply.github.com>
// SPDX-License-Identifier: MIT

import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_theme.dart';
import '../../state/app_controller.dart';

/// Displays live on-device AI capability (Apple Foundation Models on iPhone /
/// Google Gemini Nano via ML Kit GenAI & AICore on Pixel & Samsung flagships),
/// with one-tap model download and refresh controls.
class OnDeviceAiStatusCard extends StatelessWidget {
  const OnDeviceAiStatusCard({
    super.key,
    required this.app,
  });

  final AppController app;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fedi = context.fediColors;
    final status = app.onDeviceAiStatus;
    final checking = app.isCheckingOnDeviceAi;
    final downloading = app.isDownloadingOnDeviceModel;
    final error = app.onDeviceAiError;

    final (bg, fg, icon, badge) = status.isReady
        ? (
            fedi.altPresentBg,
            fedi.altPresentFg,
            Icons.check_circle_outline,
            'Ready on Device',
          )
        : status.isDownloadable
            ? (
                scheme.primaryContainer,
                scheme.onPrimaryContainer,
                Icons.download_for_offline_outlined,
                'Model Downloadable',
              )
            : status.isNotYetReady
                ? (
                    fedi.biasWarningBg,
                    fedi.biasWarningFg,
                    Icons.settings_suggest_outlined,
                    'Enable in System Settings',
                  )
                : (
                    fedi.altMissingBg,
                    fedi.altMissingFg,
                    Icons.info_outline,
                    'Unavailable on This Device',
                  );

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: fg,
          width: fedi.isHighContrast ? 2 : 1,
        ),
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
                  '${status.engineName} — $badge',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: fg,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            status.summaryMessage,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: fg),
          ),
          const SizedBox(height: 6),
          Text(
            status.diagnosticDetail,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: fg.withAlpha(220),
                ),
          ),
          if (error != null && error.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              error,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
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
                        ? 'Downloading Model…'
                        : 'Download On-Device Model',
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
                label: Text(checking ? 'Checking…' : 'Re-Check Device'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
