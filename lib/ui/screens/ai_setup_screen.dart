// Copyright (c) 2026 brokengoose <brokengoose@users.noreply.github.com>
// SPDX-License-Identifier: MIT

import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_theme.dart';
import '../../models/ai_models.dart';
import '../../state/app_controller.dart';
import '../widgets/ai_provider_config_section.dart';

/// First-time onboarding screen shown right after the user signs in to Mastodon,
/// letting them configure an AI provider (on-device, cloud API, local LAN server,
/// and alphabetically sorted model drop-down) or choose **No AI**.
class AiSetupScreen extends StatefulWidget {
  const AiSetupScreen({
    super.key,
    required this.app,
  });

  final AppController app;

  @override
  State<AiSetupScreen> createState() => _AiSetupScreenState();
}

class _AiSetupScreenState extends State<AiSetupScreen> {
  final GlobalKey<AiProviderConfigSectionState> _configKey =
      GlobalKey<AiProviderConfigSectionState>();

  bool _isSaving = false;

  Future<void> _finishSetup({bool forceNoAi = false}) async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    try {
      final configState = _configKey.currentState;
      final providerOverride = forceNoAi ? AiProviderType.none : null;
      final settings = configState?.buildSettings(
            providerOverride: providerOverride,
          ) ??
          widget.app.settings.copyWith(
            activeProvider:
                providerOverride ?? widget.app.settings.activeProvider,
          );
      final credentials =
          configState?.buildCredentials() ?? widget.app.credentials;

      await widget.app.completeAiSetup(
        settings: settings,
        credentials: credentials,
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fedi = context.fediColors;
    final account = widget.app.currentAccount;

    return ListenableBuilder(
      listenable: widget.app,
      builder: (context, _) {
        final isNone = widget.app.settings.activeProvider == AiProviderType.none;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Set Up AI'),
            automaticallyImplyLeading: false,
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Icon(
                        Icons.auto_awesome,
                        size: 48,
                        color: scheme.primary,
                      ),
                      const SizedBox(height: 12),
                      Semantics(
                        header: true,
                        child: Text(
                          'Configure AI Captioning & Bias Checking',
                          textAlign: TextAlign.center,
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        account != null
                            ? 'Signed in as ${account.handle}. Choose an AI provider to automatically generate accessible alt-text and check posts for racial or gender bias — or choose No AI to enter alt-text manually.'
                            : 'Choose an AI provider to automatically generate accessible alt-text and check posts for racial or gender bias — or choose No AI to enter alt-text manually.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(color: fedi.subtleText),
                      ),
                      const SizedBox(height: 24),

                      AiProviderConfigSection(
                        key: _configKey,
                        app: widget.app,
                        providerLabel: 'AI Provider',
                        modelHelperText:
                            'Sorted alphabetically. Tap Refresh after entering your key or URL.',
                        noAiNoticeText:
                            'FediCaption will not contact any AI service. You can still write alt-text manually, listen with Read Aloud, and use offline local bias heuristics. You can enable an AI provider later in Settings.',
                        showNoAiTitle: true,
                        enabled: !_isSaving,
                      ),

                      const SizedBox(height: 24),

                      FilledButton.icon(
                        onPressed: _isSaving ? null : () => _finishSetup(),
                        icon: Icon(isNone ? Icons.check : Icons.arrow_forward),
                        label: Text(
                          isNone
                              ? 'Continue with No AI'
                              : 'Save AI Settings & Continue',
                        ),
                      ),

                      if (!isNone) ...[
                        const SizedBox(height: 12),
                        OutlinedButton(
                          onPressed: _isSaving
                              ? null
                              : () => _finishSetup(forceNoAi: true),
                          child: const Text('Use No AI (Set Up Later)'),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
