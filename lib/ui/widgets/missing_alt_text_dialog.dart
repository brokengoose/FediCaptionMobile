// Copyright (c) 2026 brokengoose <brokengoose@users.noreply.github.com>
// SPDX-License-Identifier: MIT

import 'package:material_ui/material_ui.dart';

import '../../models/app_settings.dart';

enum MissingAltTextAction {
  autoGenerateWithAi,
  returnToComposer,
  postAnyway,
}

/// Dialog shown before publishing when one or more attachments lack alt-text
/// and Accessibility Rules policy is `warn` or `require` (Section 5.1).
class MissingAltTextDialog extends StatelessWidget {
  const MissingAltTextDialog({
    super.key,
    required this.missingCount,
    required this.policy,
  });

  final int missingCount;
  final PolicyMode policy;

  @override
  Widget build(BuildContext context) {
    final allowPostAnyway = policy == PolicyMode.warn;
    final plural = missingCount == 1 ? 'attachment is' : 'attachments are';

    return AlertDialog(
      icon: const Icon(Icons.closed_caption_disabled_outlined, size: 32),
      title: Text(
        policy == PolicyMode.require
            ? 'Alt-Text Required Before Posting'
            : 'Missing Media Alt-Text',
      ),
      content: Text(
        '$missingCount media $plural missing an alt-text description for blind and low-vision readers. '
        '${allowPostAnyway ? 'Would you like to auto-generate descriptions with AI before posting?' : 'Your Accessibility Rules policy requires alt-text on all attached media before posting.'}',
      ),
      actionsAlignment: MainAxisAlignment.end,
      actions: [
        FilledButton.icon(
          onPressed: () =>
              Navigator.of(context).pop(MissingAltTextAction.autoGenerateWithAi),
          icon: const Icon(Icons.auto_awesome),
          label: const Text('Auto-Generate Missing Alt-Text with AI'),
        ),
        OutlinedButton(
          onPressed: () =>
              Navigator.of(context).pop(MissingAltTextAction.returnToComposer),
          child: const Text('Edit in Composer'),
        ),
        if (allowPostAnyway)
          TextButton(
            onPressed: () =>
                Navigator.of(context).pop(MissingAltTextAction.postAnyway),
            child: const Text('Post Anyway'),
          ),
      ],
    );
  }
}
