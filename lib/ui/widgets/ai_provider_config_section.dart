// Copyright (c) 2026 brokengoose <brokengoose@users.noreply.github.com>
// SPDX-License-Identifier: MIT

import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../../core/constants.dart';
import '../../core/theme/app_theme.dart';
import '../../l10n/l10n.dart';
import '../../l10n/model_localizations.dart';
import '../../models/ai_models.dart';
import '../../models/app_settings.dart';
import '../../services/ai_provider_service.dart';
import '../../state/app_controller.dart';
import 'on_device_ai_status_card.dart';

/// Shared AI provider configuration form used by both [AiSetupScreen] (first-time
/// onboarding) and [SettingsScreen].
///
/// Consolidates provider selection, [OnDeviceAiStatusCard], API keys & server URLs,
/// unified debounced persistence + single model refresh (preventing lost URL edits
/// or duplicate concurrent requests), `"No AI"` guidance, and the alphabetically
/// sorted dynamic model drop-down picker.
class AiProviderConfigSection extends StatefulWidget {
  const AiProviderConfigSection({
    super.key,
    required this.app,
    this.providerLabel,
    this.modelHelperText,
    this.noAiNoticeText,
    this.showNoAiTitle = false,
    this.enabled = true,
    this.skipInitialRefresh = false,
    this.onProviderChanged,
  });

  final AppController app;
  final String? providerLabel;
  final String? modelHelperText;
  final String? noAiNoticeText;
  final bool showNoAiTitle;
  final bool enabled;

  /// When `true`, skips the post-frame `refreshOnDeviceAiStatus` and
  /// `refreshModelsFor` calls (used when the parent handles detection first).
  final bool skipInitialRefresh;
  final ValueChanged<AiProviderType>? onProviderChanged;

  @override
  State<AiProviderConfigSection> createState() =>
      AiProviderConfigSectionState();
}

class AiProviderConfigSectionState extends State<AiProviderConfigSection> {
  late final TextEditingController _geminiKeyCtrl;
  late final TextEditingController _openAiKeyCtrl;
  late final TextEditingController _openAiUrlCtrl;
  late final TextEditingController _anthropicKeyCtrl;
  late final TextEditingController _localUrlCtrl;
  late final TextEditingController _localKeyCtrl;

  bool _obscureApiKey = true;
  Timer? _saveDebounce;

  @override
  void initState() {
    super.initState();
    final s = widget.app.settings;
    final c = widget.app.credentials;
    _geminiKeyCtrl = TextEditingController(text: c.geminiApiKey);
    _openAiKeyCtrl = TextEditingController(text: c.openAiApiKey);
    _openAiUrlCtrl = TextEditingController(text: s.openAiBaseUrl);
    _anthropicKeyCtrl = TextEditingController(text: c.anthropicApiKey);
    _localUrlCtrl = TextEditingController(text: s.localBaseUrl);
    _localKeyCtrl = TextEditingController(text: c.localApiKey);

    if (!widget.skipInitialRefresh) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        widget.app.refreshOnDeviceAiStatus();
        if (widget.app.settings.activeProvider != AiProviderType.none) {
          widget.app.refreshModelsFor(widget.app.settings.activeProvider);
        }
      });
    }
  }

  @override
  void dispose() {
    // Flush (not drop) a key/URL typed just before leaving. Snapshot inputs
    // before the controllers are disposed and save on the next event-loop
    // turn so AppController listeners aren't notified mid-unmount.
    if (_saveDebounce?.isActive ?? false) {
      _saveDebounce!.cancel();
      final app = widget.app;
      final credentials = buildCredentials();
      final openAiUrl = _openAiUrlCtrl.text.trim();
      final localUrl = _localUrlCtrl.text.trim();
      Future(() async {
        await app.updateCredentials(credentials);
        // Merge onto settings as they are at save time so a sibling flush
        // (e.g. Settings' language field) isn't overwritten by a stale copy.
        await app.updateSettings(
          _withBaseUrls(app.settings, openAiUrl: openAiUrl, localUrl: localUrl),
          autoRefreshModels: false,
        );
      });
    }
    _geminiKeyCtrl.dispose();
    _openAiKeyCtrl.dispose();
    _openAiUrlCtrl.dispose();
    _anthropicKeyCtrl.dispose();
    _localUrlCtrl.dispose();
    _localKeyCtrl.dispose();
    super.dispose();
  }

  /// Snapshot of all current API key fields.
  AiCredentials buildCredentials() {
    return AiCredentials(
      geminiApiKey: _geminiKeyCtrl.text.trim(),
      openAiApiKey: _openAiKeyCtrl.text.trim(),
      anthropicApiKey: _anthropicKeyCtrl.text.trim(),
      localApiKey: _localKeyCtrl.text.trim(),
    );
  }

  /// Snapshot of settings merged with the current base URL fields (and optional provider override).
  AppSettings buildSettings({AiProviderType? providerOverride}) {
    final base = widget.app.settings;
    return _withBaseUrls(
      base.copyWith(activeProvider: providerOverride ?? base.activeProvider),
      openAiUrl: _openAiUrlCtrl.text.trim(),
      localUrl: _localUrlCtrl.text.trim(),
    );
  }

  static AppSettings _withBaseUrls(
    AppSettings base, {
    required String openAiUrl,
    required String localUrl,
  }) {
    return base.copyWith(
      openAiBaseUrl: openAiUrl.isEmpty
          ? AppConstants.openAiDefaultBaseUrl
          : openAiUrl,
      localBaseUrl: localUrl.isEmpty
          ? AppConstants.localDefaultBaseUrl
          : localUrl,
    );
  }

  /// Debounces saving BOTH credentials and base URLs together before triggering
  /// a single model discovery request, preventing concurrent edits from cancelling
  /// each other or firing duplicate fetches.
  void _scheduleSyncAndRefresh(AiProviderType provider) {
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 650), () async {
      await _persistInputsAndRefresh(provider);
    });
  }

  Future<void> _persistInputsAndRefresh(AiProviderType provider) async {
    await widget.app.updateCredentials(buildCredentials());
    await widget.app.updateSettings(buildSettings(), autoRefreshModels: false);
    if (provider != AiProviderType.none) {
      await widget.app.refreshModelsFor(provider);
    }
  }

  Future<void> _handleProviderChange(AiProviderType next) async {
    _saveDebounce?.cancel();
    await widget.app.updateCredentials(buildCredentials());
    await widget.app.updateSettings(
      buildSettings(providerOverride: next),
      autoRefreshModels: false,
    );
    widget.onProviderChanged?.call(next);
    if (next != AiProviderType.none) {
      await widget.app.refreshModelsFor(next);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fedi = context.fediColors;
    final l10n = context.l10n;
    final effectiveProviderLabel =
        widget.providerLabel ?? l10n.aiConfigActiveProviderLabel;
    final effectiveModelHelper =
        widget.modelHelperText ?? l10n.aiConfigModelHelper;
    final effectiveNoAiNotice =
        widget.noAiNoticeText ?? l10n.aiConfigNoAiNotice;

    return ListenableBuilder(
      listenable: widget.app,
      builder: (context, _) {
        final s = widget.app.settings;
        final activeProvider = s.activeProvider;
        final isNone = activeProvider == AiProviderType.none;
        final isLoadingModels =
            !isNone && widget.app.isLoadingModels(activeProvider);
        final rawModels = isNone
            ? const <AiModelOption>[]
            : widget.app.modelsFor(activeProvider);
        final selectedModel = s.modelForProvider(activeProvider);

        // Guarantee DropdownButtonFormField always contains the currently selected value
        // and stays strictly sorted alphabetically.
        final dropdownModels = List<AiModelOption>.from(rawModels);
        if (!isNone &&
            selectedModel.isNotEmpty &&
            !dropdownModels.any((m) => m.id == selectedModel)) {
          dropdownModels.add(
            AiModelOption(id: selectedModel, displayName: selectedModel),
          );
        }
        final sortedModels = AiProviderService.sortAlphabetically(
          dropdownModels,
        );
        final effectiveModel = sortedModels.any((m) => m.id == selectedModel)
            ? selectedModel
            : (sortedModels.isNotEmpty ? sortedModels.first.id : null);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<AiProviderType>(
              key: ValueKey('ai_provider_${activeProvider.id}'),
              initialValue: activeProvider,
              isExpanded: true,
              decoration: InputDecoration(labelText: effectiveProviderLabel),
              items: AiProviderType.values
                  .map(
                    (p) => DropdownMenuItem(
                      value: p,
                      child: Text(p.localizedDisplayName(l10n)),
                    ),
                  )
                  .toList(),
              onChanged: widget.enabled
                  ? (next) {
                      if (next != null) _handleProviderChange(next);
                    }
                  : null,
            ),

            const SizedBox(height: 12),

            if (activeProvider == AiProviderType.onDevice)
              OnDeviceAiStatusCard(app: widget.app),

            if (activeProvider == AiProviderType.gemini)
              _buildApiKeyField(
                controller: _geminiKeyCtrl,
                label: l10n.aiConfigGeminiApiKeyLabel,
                hint: l10n.aiConfigGeminiApiKeyHint,
                l10n: l10n,
                onChanged: (_) =>
                    _scheduleSyncAndRefresh(AiProviderType.gemini),
              ),

            if (activeProvider == AiProviderType.openai) ...[
              TextField(
                controller: _openAiUrlCtrl,
                enabled: widget.enabled,
                keyboardType: TextInputType.url,
                autocorrect: false,
                onChanged: (_) =>
                    _scheduleSyncAndRefresh(AiProviderType.openai),
                decoration: InputDecoration(
                  labelText: l10n.aiConfigOpenAiBaseUrlLabel,
                  hintText: AppConstants.openAiDefaultBaseUrl,
                  helperText: l10n.aiConfigOpenAiBaseUrlHelper,
                  helperMaxLines: 4,
                ),
              ),
              const SizedBox(height: 12),
              _buildApiKeyField(
                controller: _openAiKeyCtrl,
                label: l10n.aiConfigOpenAiApiKeyLabel,
                hint: l10n.aiConfigOpenAiApiKeyHint,
                l10n: l10n,
                onChanged: (_) =>
                    _scheduleSyncAndRefresh(AiProviderType.openai),
              ),
            ],

            if (activeProvider == AiProviderType.anthropic)
              _buildApiKeyField(
                controller: _anthropicKeyCtrl,
                label: l10n.aiConfigAnthropicApiKeyLabel,
                hint: l10n.aiConfigAnthropicApiKeyHint,
                l10n: l10n,
                onChanged: (_) =>
                    _scheduleSyncAndRefresh(AiProviderType.anthropic),
              ),

            if (activeProvider == AiProviderType.local) ...[
              TextField(
                controller: _localUrlCtrl,
                enabled: widget.enabled,
                keyboardType: TextInputType.url,
                autocorrect: false,
                onChanged: (_) => _scheduleSyncAndRefresh(AiProviderType.local),
                decoration: InputDecoration(
                  labelText: l10n.aiConfigLocalBaseUrlLabel,
                  hintText: AppConstants.localDefaultBaseUrl,
                  helperText: l10n.aiConfigLocalBaseUrlHelper(
                    AppConstants.localDefaultBaseUrl,
                  ),
                  helperMaxLines: 5,
                ),
              ),
              const SizedBox(height: 12),
              _buildApiKeyField(
                controller: _localKeyCtrl,
                label: l10n.aiConfigLocalApiKeyLabel,
                hint: l10n.aiConfigLocalApiKeyHint,
                l10n: l10n,
                onChanged: (_) => _scheduleSyncAndRefresh(AiProviderType.local),
              ),
            ],

            const SizedBox(height: 12),

            if (isNone)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest.withAlpha(115),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: fedi.cardBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (widget.showNoAiTitle) ...[
                      Text(
                        l10n.aiConfigNoAiSelectedTitle,
                        style: Theme.of(context).textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                    ],
                    Text(
                      effectiveNoAiNotice,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              )
            else
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      key: ValueKey(
                        'ai_model_${activeProvider.id}_${effectiveModel ?? ''}',
                      ),
                      initialValue: effectiveModel,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: l10n.aiConfigModelDropdownLabel,
                        helperText: isLoadingModels
                            ? l10n.aiConfigFetchingModelsHelper
                            : effectiveModelHelper,
                        helperMaxLines: 4,
                      ),
                      items: sortedModels
                          .map(
                            (m) => DropdownMenuItem(
                              value: m.id,
                              child: Text(
                                m.localizedDisplayName(l10n),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: widget.enabled
                          ? (modelId) {
                              if (modelId != null) {
                                widget.app.updateSettings(
                                  s.withModelForProvider(
                                    activeProvider,
                                    modelId,
                                  ),
                                  autoRefreshModels: false,
                                );
                              }
                            }
                          : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: IconButton.filledTonal(
                      tooltip: l10n.aiConfigRefreshModelsTooltip,
                      onPressed: (!widget.enabled || isLoadingModels)
                          ? null
                          : () {
                              _saveDebounce?.cancel();
                              _persistInputsAndRefresh(activeProvider);
                            },
                      icon: isLoadingModels
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.refresh),
                    ),
                  ),
                ],
              ),
          ],
        );
      },
    );
  }

  Widget _buildApiKeyField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required AppLocalizations l10n,
    required ValueChanged<String> onChanged,
  }) {
    return TextField(
      controller: controller,
      enabled: widget.enabled,
      obscureText: _obscureApiKey,
      autocorrect: false,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        suffixIcon: IconButton(
          tooltip: _obscureApiKey
              ? l10n.aiConfigShowApiKey
              : l10n.aiConfigHideApiKey,
          icon: Icon(_obscureApiKey ? Icons.visibility : Icons.visibility_off),
          onPressed: () => setState(() => _obscureApiKey = !_obscureApiKey),
        ),
      ),
    );
  }
}
