// Copyright (c) 2026 brokengoose <brokengoose@users.noreply.github.com>
// SPDX-License-Identifier: MIT

import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../../core/constants.dart';
import '../../core/theme/app_theme.dart';
import '../../models/ai_models.dart';
import '../../models/app_settings.dart';
import '../../services/ai_provider_service.dart';
import '../../state/app_controller.dart';
import '../widgets/on_device_ai_status_card.dart';

/// First-time onboarding screen shown right after the user signs in to Mastodon,
/// letting them configure an AI provider (API key, server URL, and alphabetically
/// sorted model drop-down) or choose **No AI**.
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
  late AiProviderType _selectedProvider;
  late String _selectedModel;

  late final TextEditingController _geminiKeyCtrl;
  late final TextEditingController _openAiKeyCtrl;
  late final TextEditingController _openAiUrlCtrl;
  late final TextEditingController _anthropicKeyCtrl;
  late final TextEditingController _localUrlCtrl;
  late final TextEditingController _localKeyCtrl;

  bool _obscureApiKey = true;
  bool _isSaving = false;
  Timer? _refreshDebounce;

  @override
  void initState() {
    super.initState();
    final s = widget.app.settings;
    final c = widget.app.credentials;
    _selectedProvider = s.activeProvider;
    _selectedModel = s.modelForProvider(_selectedProvider);

    _geminiKeyCtrl = TextEditingController(text: c.geminiApiKey);
    _openAiKeyCtrl = TextEditingController(text: c.openAiApiKey);
    _openAiUrlCtrl = TextEditingController(text: s.openAiBaseUrl);
    _anthropicKeyCtrl = TextEditingController(text: c.anthropicApiKey);
    _localUrlCtrl = TextEditingController(text: s.localBaseUrl);
    _localKeyCtrl = TextEditingController(text: c.localApiKey);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.app.refreshOnDeviceAiStatus();
      if (_selectedProvider != AiProviderType.none) {
        widget.app.refreshModelsFor(_selectedProvider);
      }
    });
  }

  @override
  void dispose() {
    _refreshDebounce?.cancel();
    _geminiKeyCtrl.dispose();
    _openAiKeyCtrl.dispose();
    _openAiUrlCtrl.dispose();
    _anthropicKeyCtrl.dispose();
    _localUrlCtrl.dispose();
    _localKeyCtrl.dispose();
    super.dispose();
  }

  AiCredentials _currentCredentials() {
    return AiCredentials(
      geminiApiKey: _geminiKeyCtrl.text.trim(),
      openAiApiKey: _openAiKeyCtrl.text.trim(),
      anthropicApiKey: _anthropicKeyCtrl.text.trim(),
      localApiKey: _localKeyCtrl.text.trim(),
    );
  }

  AppSettings _currentSettings({AiProviderType? providerOverride}) {
    final provider = providerOverride ?? _selectedProvider;
    var updated = widget.app.settings.copyWith(
      activeProvider: provider,
      openAiBaseUrl: _openAiUrlCtrl.text.trim().isEmpty
          ? AppConstants.openAiDefaultBaseUrl
          : _openAiUrlCtrl.text.trim(),
      localBaseUrl: _localUrlCtrl.text.trim().isEmpty
          ? AppConstants.localDefaultBaseUrl
          : _localUrlCtrl.text.trim(),
    );
    if (provider != AiProviderType.none && _selectedModel.isNotEmpty) {
      updated = updated.withModelForProvider(provider, _selectedModel);
    }
    return updated;
  }

  void _scheduleModelRefresh() {
    if (_selectedProvider == AiProviderType.none) return;
    _refreshDebounce?.cancel();
    _refreshDebounce = Timer(const Duration(milliseconds: 650), () async {
      await widget.app.updateCredentials(_currentCredentials());
      await widget.app.updateSettings(_currentSettings());
      await widget.app.refreshModelsFor(_selectedProvider);
      if (!mounted) return;
      final models = widget.app.modelsFor(_selectedProvider);
      if (models.isNotEmpty && !models.any((m) => m.id == _selectedModel)) {
        setState(() => _selectedModel = models.first.id);
      }
    });
  }

  Future<void> _onProviderChanged(AiProviderType next) async {
    setState(() {
      _selectedProvider = next;
      _selectedModel = widget.app.settings.modelForProvider(next);
    });
    if (next != AiProviderType.none) {
      await widget.app.updateSettings(_currentSettings());
      await widget.app.refreshModelsFor(next);
      if (!mounted) return;
      final models = widget.app.modelsFor(next);
      if (models.isNotEmpty && !models.any((m) => m.id == _selectedModel)) {
        setState(() => _selectedModel = models.first.id);
      }
    }
  }

  Future<void> _finishSetup({bool forceNoAi = false}) async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    try {
      final provider = forceNoAi ? AiProviderType.none : _selectedProvider;
      await widget.app.completeAiSetup(
        settings: _currentSettings(providerOverride: provider),
        credentials: _currentCredentials(),
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
        final isNone = _selectedProvider == AiProviderType.none;
        final isLoadingModels =
            !isNone && widget.app.isLoadingModels(_selectedProvider);
        final rawModels = isNone
            ? const <AiModelOption>[]
            : widget.app.modelsFor(_selectedProvider);

        final dropdownModels = List<AiModelOption>.from(rawModels);
        if (!isNone &&
            _selectedModel.isNotEmpty &&
            !dropdownModels.any((m) => m.id == _selectedModel)) {
          dropdownModels.add(
            AiModelOption(id: _selectedModel, displayName: _selectedModel),
          );
        }
        final sortedModels = AiProviderService.sortAlphabetically(dropdownModels);
        final effectiveModel = sortedModels.any((m) => m.id == _selectedModel)
            ? _selectedModel
            : (sortedModels.isNotEmpty ? sortedModels.first.id : '');

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

                      DropdownButtonFormField<AiProviderType>(
                        key: ValueKey('setup_provider_${_selectedProvider.id}'),
                        initialValue: _selectedProvider,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'AI Provider',
                        ),
                        items: AiProviderType.values
                            .map(
                              (p) => DropdownMenuItem(
                                value: p,
                                child: Text(p.displayName),
                              ),
                            )
                            .toList(),
                        onChanged: _isSaving
                            ? null
                            : (next) {
                                if (next != null) _onProviderChanged(next);
                              },
                      ),

                      const SizedBox(height: 16),

                      if (_selectedProvider == AiProviderType.onDevice)
                        OnDeviceAiStatusCard(app: widget.app),

                      if (_selectedProvider == AiProviderType.gemini)
                        _buildApiKeyField(
                          controller: _geminiKeyCtrl,
                          label: 'Google Gemini API Key',
                          hint: 'AIza…',
                        ),

                      if (_selectedProvider == AiProviderType.openai) ...[
                        TextField(
                          controller: _openAiUrlCtrl,
                          keyboardType: TextInputType.url,
                          autocorrect: false,
                          onChanged: (_) => _scheduleModelRefresh(),
                          decoration: const InputDecoration(
                            labelText: 'OpenAI-Compatible Server URL / Path',
                            hintText: AppConstants.openAiDefaultBaseUrl,
                            helperText:
                                'Supports OpenAI, OpenRouter, LM Studio, vLLM, or llama.cpp.',
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildApiKeyField(
                          controller: _openAiKeyCtrl,
                          label: 'API Key (Optional for local servers)',
                          hint: 'sk-…',
                        ),
                      ],

                      if (_selectedProvider == AiProviderType.anthropic)
                        _buildApiKeyField(
                          controller: _anthropicKeyCtrl,
                          label: 'Anthropic API Key',
                          hint: 'sk-ant-…',
                        ),

                      if (_selectedProvider == AiProviderType.local) ...[
                        TextField(
                          controller: _localUrlCtrl,
                          keyboardType: TextInputType.url,
                          autocorrect: false,
                          onChanged: (_) => _scheduleModelRefresh(),
                          decoration: const InputDecoration(
                            labelText: 'Local AI Server URL (Ollama / LM Studio)',
                            hintText: 'http://192.168.1.50:11434',
                            helperText:
                                'Enter your Ollama (port 11434) or LM Studio (port 1234/v1) LAN URL.',
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildApiKeyField(
                          controller: _localKeyCtrl,
                          label: 'Optional LAN Server Key / Token',
                          hint: 'Leave blank if not required',
                        ),
                      ],

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
                              Text(
                                'No AI Selected',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleSmall
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'FediCaption will not contact any AI service. You can still write alt-text manually, listen with Read Aloud, and use offline local bias heuristics. You can enable an AI provider later in Settings.',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ],
                          ),
                        )
                      else ...[
                        const SizedBox(height: 12),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                key: ValueKey(
                                  'setup_model_${_selectedProvider.id}_$effectiveModel',
                                ),
                                initialValue: effectiveModel.isNotEmpty
                                    ? effectiveModel
                                    : null,
                                isExpanded: true,
                                decoration: InputDecoration(
                                  labelText: 'AI Model (A–Z)',
                                  helperText: isLoadingModels
                                      ? 'Fetching available models…'
                                      : 'Sorted alphabetically. Tap Refresh after entering your key or URL.',
                                ),
                                items: sortedModels
                                    .map(
                                      (m) => DropdownMenuItem(
                                        value: m.id,
                                        child: Text(
                                          m.displayName,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (modelId) {
                                  if (modelId != null) {
                                    setState(() => _selectedModel = modelId);
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: IconButton.filledTonal(
                                tooltip: 'Refresh Models',
                                onPressed: isLoadingModels
                                    ? null
                                    : () async {
                                        await widget.app.updateCredentials(
                                          _currentCredentials(),
                                        );
                                        await widget.app
                                            .updateSettings(_currentSettings());
                                        await widget.app
                                            .refreshModelsFor(_selectedProvider);
                                      },
                                icon: isLoadingModels
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.refresh),
                              ),
                            ),
                          ],
                        ),
                      ],

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

  Widget _buildApiKeyField({
    required TextEditingController controller,
    required String label,
    required String hint,
  }) {
    return TextField(
      controller: controller,
      obscureText: _obscureApiKey,
      autocorrect: false,
      onChanged: (_) => _scheduleModelRefresh(),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        suffixIcon: IconButton(
          tooltip: _obscureApiKey ? 'Show API key' : 'Hide API key',
          icon: Icon(
            _obscureApiKey ? Icons.visibility : Icons.visibility_off,
          ),
          onPressed: () => setState(() => _obscureApiKey = !_obscureApiKey),
        ),
      ),
    );
  }
}
