// Copyright (c) 2026 brokengoose <brokengoose@users.noreply.github.com>
// SPDX-License-Identifier: MIT

import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_theme.dart';
import '../../l10n/l10n.dart';
import '../../models/update_info.dart';

/// Dismissible banner displayed on the main screen when a newer version is available on GitHub.
class UpdateBanner extends StatelessWidget {
  const UpdateBanner({
    super.key,
    required this.update,
    required this.onDismiss,
  });

  final UpdateInfo update;
  final VoidCallback onDismiss;

  Future<void> _openReleaseUrl() async {
    final uri = Uri.tryParse(update.releaseUrl);
    if (uri != null) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fedi = context.fediColors;
    final l10n = context.l10n;
    return Semantics(
      liveRegion: true,
      container: true,
      label: l10n.updateBannerSemantics(
        update.latestVersion,
        update.currentVersion,
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: fedi.updateBannerBg,
          border: Border(
            bottom: BorderSide(
              color: fedi.cardBorder,
              width: fedi.isHighContrast ? 2 : 1,
            ),
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.system_update_alt, color: fedi.updateBannerFg),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.updateBannerTitle(update.latestVersion),
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: fedi.updateBannerFg,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  Text(
                    l10n.updateBannerSubtitle(update.currentVersion),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: fedi.updateBannerFg,
                        ),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: _openReleaseUrl,
              style: TextButton.styleFrom(
                foregroundColor: fedi.updateBannerFg,
              ),
              child: Text(
                l10n.commonDownload,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            IconButton(
              onPressed: onDismiss,
              tooltip: l10n.updateBannerDismissTooltip,
              color: fedi.updateBannerFg,
              icon: const Icon(Icons.close),
            ),
          ],
        ),
      ),
    );
  }
}
