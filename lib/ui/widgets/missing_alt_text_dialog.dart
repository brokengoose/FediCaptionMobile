// Copyright (c) 2026 brokengoose <brokengoose@users.noreply.github.com>
// SPDX-License-Identifier: MIT

import 'package:material_ui/material_ui.dart';

import '../../l10n/l10n.dart';
import '../../models/app_settings.dart';

enum MissingAltTextAction { autoGenerateWithAi, returnToComposer, postAnyway }

/// Dialog shown before publishing when one or more attachments lack alt-text
/// and Accessibility Rules policy is `warn` or `require`.
class MissingAltTextDialog extends StatelessWidget {
  const MissingAltTextDialog({
    super.key,
    required this.missingCount,
    required this.policy,
    this.aiEnabled = true,
  });

  final int missingCount;
  final PolicyMode policy;
  final bool aiEnabled;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final allowPostAnyway = policy == PolicyMode.warn;
    final body = allowPostAnyway
        ? (aiEnabled
              ? l10n.missingAltTextBodyWarnAi(missingCount)
              : l10n.missingAltTextBodyWarnManual(missingCount))
        : l10n.missingAltTextBodyRequire(missingCount);

    return AlertDialog(
      icon: const Icon(Icons.closed_caption_disabled_outlined, size: 32),
      title: Text(
        policy == PolicyMode.require
            ? l10n.missingAltTextTitleRequire
            : l10n.missingAltTextTitleWarn,
      ),
      content: Text(body),
      actionsAlignment: MainAxisAlignment.end,
      actions: [
        if (aiEnabled)
          FilledButton.icon(
            onPressed: () =>
                Navigator.of(context)
                    .pop(MissingAltTextAction.autoGenerateWithAi),
            icon: const Icon(Icons.auto_awesome),
            label: Text(l10n.missingAltTextAutoGenerateButton),
          ),
        OutlinedButton(
          onPressed: () =>
              Navigator.of(context).pop(MissingAltTextAction.returnToComposer),
          child: Text(l10n.missingAltTextEditButton),
        ),
        if (allowPostAnyway)
          TextButton(
            onPressed: () =>
                Navigator.of(context).pop(MissingAltTextAction.postAnyway),
            child: Text(l10n.missingAltTextPostAnywayButton),
          ),
      ],
    );
  }
}
