// Copyright (c) 2026 brokengoose <brokengoose@users.noreply.github.com>
// SPDX-License-Identifier: MIT

import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_theme.dart';
import '../../l10n/l10n.dart';
import '../../models/ai_models.dart';
import '../../state/app_controller.dart';
import '../widgets/ai_provider_config_section.dart';

/// First-time onboarding screen shown on initial launch before Mastodon account setup,
/// letting them configure an AI provider (on-device, cloud API, local LAN server,
/// and alphabetically sorted model drop-down) or choose **No AI**.
class AiSetupScreen extends StatefulWidget {
  const AiSetupScreen({super.key, required this.app});

  final AppController app;

  @override
  State<AiSetupScreen> createState() => _AiSetupScreenState();
}

class _AiSetupScreenState extends State<AiSetupScreen> {
  final GlobalKey<AiProviderConfigSectionState> _configKey =
      GlobalKey<AiProviderConfigSectionState>();

  bool _isDetectingOnDeviceAi = true;
  bool _userChangedProvider = false;
  bool _defaultedToNoAi = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(_detectInitialProvider());
      }
    });
  }

  Future<void> _detectInitialProvider() async {
    final status = await widget.app.refreshOnDeviceAiStatus();
    if (!mounted) return;

    final currentProvider = widget.app.settings.activeProvider;
    final canAutoDefault =
        !_userChangedProvider &&
        !widget.app.settings.aiSetupCompleted &&
        (currentProvider == AiProviderType.onDevice ||
            currentProvider == AiProviderType.none);

    var defaultedNoAi = false;
    if (canAutoDefault) {
      final recommended = status.isUsable
          ? AiProviderType.onDevice
          : AiProviderType.none;
      widget.app.selectInitialSetupProvider(recommended);
      defaultedNoAi = recommended == AiProviderType.none;
    }

    setState(() {
      _defaultedToNoAi = defaultedNoAi;
      _isDetectingOnDeviceAi = false;
    });

    final effectiveProvider = widget.app.settings.activeProvider;
    if (effectiveProvider != AiProviderType.none) {
      unawaited(widget.app.refreshModelsFor(effectiveProvider));
    }
  }

  Future<void> _finishSetup({bool forceNoAi = false}) async {
    if (_isSaving || _isDetectingOnDeviceAi) return;
    setState(() => _isSaving = true);
    try {
      final configState = _configKey.currentState;
      final providerOverride = forceNoAi ? AiProviderType.none : null;
      final settings =
          configState?.buildSettings(providerOverride: providerOverride) ??
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
    final l10n = context.l10n;
    final account = widget.app.currentAccount;

    return ListenableBuilder(
      listenable: widget.app,
      builder: (context, _) {
        final isNone =
            widget.app.settings.activeProvider == AiProviderType.none;
        final controlsDisabled = _isSaving || _isDetectingOnDeviceAi;
        final noAiNotice = _defaultedToNoAi
            ? l10n.aiSetupNoAiDefaultNotice
            : l10n.aiSetupNoAiSelectedNotice;

        return Scaffold(
          appBar: AppBar(
            title: Text(l10n.aiSetupTitle),
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
                      Icon(Icons.auto_awesome, size: 48, color: scheme.primary),
                      const SizedBox(height: 12),
                      Semantics(
                        header: true,
                        child: Text(
                          l10n.aiSetupHeading,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        account != null
                            ? l10n.aiSetupIntroWithHandle(account.handle)
                            : l10n.aiSetupIntroWithoutHandle,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium
                            ?.copyWith(color: fedi.subtleText),
                      ),
                      const SizedBox(height: 24),

                      if (_isDetectingOnDeviceAi)
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: scheme.surfaceContainerHighest.withAlpha(
                              115,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: fedi.cardBorder),
                          ),
                          child: Row(
                            children: [
                              const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(l10n.aiSetupDetectingOnDevice),
                              ),
                            ],
                          ),
                        )
                      else
                        AiProviderConfigSection(
                          key: _configKey,
                          app: widget.app,
                          providerLabel: l10n.aiSetupProviderLabel,
                          modelHelperText: l10n.aiSetupModelHelper,
                          noAiNoticeText: noAiNotice,
                          showNoAiTitle: true,
                          skipInitialRefresh: true,
                          enabled: !controlsDisabled,
                          onProviderChanged: (_) {
                            setState(() {
                              _userChangedProvider = true;
                              _defaultedToNoAi = false;
                            });
                          },
                        ),

                      const SizedBox(height: 24),

                      FilledButton.icon(
                        onPressed: controlsDisabled
                            ? null
                            : () => _finishSetup(),
                        icon: Icon(isNone ? Icons.check : Icons.arrow_forward),
                        label: Text(
                          isNone
                              ? l10n.aiSetupContinueNoAi
                              : l10n.aiSetupSaveAndContinue,
                        ),
                      ),

                      if (!isNone) ...[
                        const SizedBox(height: 12),
                        OutlinedButton(
                          onPressed: controlsDisabled
                              ? null
                              : () => _finishSetup(forceNoAi: true),
                          child: Text(l10n.aiSetupUseNoAiLater),
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
