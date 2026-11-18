// Copyright (c) 2026 brokengoose <brokengoose@users.noreply.github.com>
// SPDX-License-Identifier: MIT

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants.dart';
import '../../core/theme/app_theme.dart';
import '../../models/ai_models.dart';
import '../../models/app_settings.dart';
import '../../state/app_controller.dart';

/// Settings screen implementing:
/// - AI provider selection, API keys / server URLs, and **dynamic model drop-down picker**
/// - AI Captioning preferences (detail level, video keyframes, auto-generate, post context, language, custom instructions)
/// - Parallel **Accessibility Rules** and **Bias Rules** sections
/// - Theme selection (System Auto-Detect, Dark, Light, WCAG AAA High Contrast)
/// - Account info, dynamic instance limits, and GitHub attribution
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.app,
  });

  final AppController app;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _geminiKeyCtrl;
  late final TextEditingController _openAiKeyCtrl;
  late final TextEditingController _openAiUrlCtrl;
  late final TextEditingController _anthropicKeyCtrl;
  late final TextEditingController _localUrlCtrl;
  late final TextEditingController _localKeyCtrl;
  late final TextEditingController _languageCtrl;
  late final TextEditingController _customInstructionsCtrl;

  bool _obscureApiKey = true;
  Timer? _debounceTimer;

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
    _languageCtrl = TextEditingController(text: s.language);
    _customInstructionsCtrl = TextEditingController(text: s.customInstructions);

    // Dynamically query provider models whenever Settings is opened (Section 3.2).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.app.refreshModelsFor(widget.app.settings.activeProvider);
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _geminiKeyCtrl.dispose();
    _openAiKeyCtrl.dispose();
    _openAiUrlCtrl.dispose();
    _anthropicKeyCtrl.dispose();
    _localUrlCtrl.dispose();
    _localKeyCtrl.dispose();
    _languageCtrl.dispose();
    _customInstructionsCtrl.dispose();
    super.dispose();
  }

  void _scheduleCredentialSave(AiProviderType provider) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 650), () async {
      await widget.app.updateCredentials(
        AiCredentials(
          geminiApiKey: _geminiKeyCtrl.text.trim(),
          openAiApiKey: _openAiKeyCtrl.text.trim(),
          anthropicApiKey: _anthropicKeyCtrl.text.trim(),
          localApiKey: _localKeyCtrl.text.trim(),
        ),
        refreshProvider: provider,
      );
    });
  }

  void _scheduleBaseUrlSave(AiProviderType provider) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 650), () async {
      await widget.app.updateSettings(
        widget.app.settings.copyWith(
          openAiBaseUrl: _openAiUrlCtrl.text.trim(),
          localBaseUrl: _localUrlCtrl.text.trim(),
        ),
      );
      await widget.app.refreshModelsFor(provider);
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([widget.app, widget.app.themeController]),
      builder: (context, _) {
        final s = widget.app.settings;
        final activeProvider = s.activeProvider;
        final isLoadingModels = widget.app.isLoadingModels(activeProvider);
        final rawModels = widget.app.modelsFor(activeProvider);
        final selectedModel = s.modelForProvider(activeProvider);

        // Guarantee DropdownButtonFormField always contains the currently selected value.
        final dropdownModels = List<AiModelOption>.from(rawModels);
        if (!dropdownModels.any((m) => m.id == selectedModel)) {
          dropdownModels.insert(
            0,
            AiModelOption(id: selectedModel, displayName: selectedModel),
          );
        }

        final fedi = context.fediColors;
        final limits = widget.app.instanceLimits;

        return Scaffold(
          appBar: AppBar(title: const Text('Settings')),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // === 1. Settings & API Keys ===
              _SectionHeader(
                title: 'AI Provider & API Keys',
                icon: Icons.auto_awesome,
              ),
              const SizedBox(height: 8),

              DropdownButtonFormField<AiProviderType>(
                value: activeProvider,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Active AI Provider',
                ),
                items: AiProviderType.values
                    .map(
                      (p) => DropdownMenuItem(
                        value: p,
                        child: Text(p.displayName),
                      ),
                    )
                    .toList(),
                onChanged: (next) {
                  if (next != null) {
                    widget.app.updateSettings(s.copyWith(activeProvider: next));
                  }
                },
              ),

              const SizedBox(height: 12),

              // Provider-specific URL & API Key fields
              if (activeProvider == AiProviderType.gemini)
                _buildApiKeyField(
                  controller: _geminiKeyCtrl,
                  label: 'Google Gemini API Key',
                  hint: 'AIza…',
                  onChanged: (_) =>
                      _scheduleCredentialSave(AiProviderType.gemini),
                ),

              if (activeProvider == AiProviderType.openai) ...[
                TextField(
                  controller: _openAiUrlCtrl,
                  keyboardType: TextInputType.url,
                  autocorrect: false,
                  onChanged: (_) => _scheduleBaseUrlSave(AiProviderType.openai),
                  decoration: const InputDecoration(
                    labelText: 'OpenAI-Compatible Base URL',
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
                  onChanged: (_) =>
                      _scheduleCredentialSave(AiProviderType.openai),
                ),
              ],

              if (activeProvider == AiProviderType.anthropic)
                _buildApiKeyField(
                  controller: _anthropicKeyCtrl,
                  label: 'Anthropic API Key',
                  hint: 'sk-ant-…',
                  onChanged: (_) =>
                      _scheduleCredentialSave(AiProviderType.anthropic),
                ),

              if (activeProvider == AiProviderType.local) ...[
                TextField(
                  controller: _localUrlCtrl,
                  keyboardType: TextInputType.url,
                  autocorrect: false,
                  onChanged: (_) => _scheduleBaseUrlSave(AiProviderType.local),
                  decoration: const InputDecoration(
                    labelText: 'Local AI Server URL (Ollama / LM Studio LAN)',
                    hintText: 'http://192.168.1.50:11434',
                    helperText:
                        'Use your computer\'s LAN IP for Ollama (port 11434) or LM Studio (port 1234/v1).',
                  ),
                ),
                const SizedBox(height: 12),
                _buildApiKeyField(
                  controller: _localKeyCtrl,
                  label: 'Optional LAN Server Token / Key',
                  hint: 'Leave blank if not required',
                  onChanged: (_) =>
                      _scheduleCredentialSave(AiProviderType.local),
                ),
              ],

              const SizedBox(height: 12),

              // Dynamic Model Drop-Down Picker (Section 3.2 — NEVER a plain text input)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: selectedModel,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: 'AI Model',
                        helperText: isLoadingModels
                            ? 'Fetching available models from provider…'
                            : 'Select a vision-capable model from the provider.',
                      ),
                      items: dropdownModels
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
                          widget.app.updateSettings(
                            s.withModelForProvider(activeProvider, modelId),
                          );
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
                          : () => widget.app.refreshModelsFor(activeProvider),
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

              const SizedBox(height: 24),
              const Divider(),

              // === 2. AI Captioning Preferences ===
              _SectionHeader(
                title: 'AI Alt-Text Captioning',
                icon: Icons.closed_caption,
              ),
              const SizedBox(height: 8),

              DropdownButtonFormField<CaptionDetailLevel>(
                value: s.defaultDetailLevel,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Default Detail Level',
                ),
                items: CaptionDetailLevel.values
                    .map(
                      (lvl) => DropdownMenuItem(
                        value: lvl,
                        child: Text('${lvl.label} — ${lvl.guidance}'),
                      ),
                    )
                    .toList(),
                onChanged: (next) {
                  if (next != null) {
                    widget.app.updateSettings(
                      s.copyWith(defaultDetailLevel: next),
                    );
                  }
                },
              ),

              const SizedBox(height: 12),

              DropdownButtonFormField<int>(
                value: s.videoKeyframeCount,
                decoration: const InputDecoration(
                  labelText: 'Video Keyframes to Extract',
                  helperText:
                      'Used for frame-based models or videos exceeding Gemini inline limits.',
                ),
                items: const [
                  DropdownMenuItem(value: 3, child: Text('3 keyframes')),
                  DropdownMenuItem(
                    value: 4,
                    child: Text('4 keyframes (Default)'),
                  ),
                  DropdownMenuItem(value: 6, child: Text('6 keyframes')),
                ],
                onChanged: (count) {
                  if (count != null) {
                    widget.app.updateSettings(
                      s.copyWith(videoKeyframeCount: count),
                    );
                  }
                },
              ),

              const SizedBox(height: 8),

              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Auto-Generate Alt-Text on Attach'),
                subtitle: const Text(
                  'Automatically scan images and videos as soon as they are attached.',
                ),
                value: s.autoGenerate,
                onChanged: (v) =>
                    widget.app.updateSettings(s.copyWith(autoGenerate: v)),
              ),

              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Include Draft Post Text as Context'),
                subtitle: const Text(
                  'Helps the AI identify names, events, or subjects mentioned in your draft.',
                ),
                value: s.includePostContext,
                onChanged: (v) => widget.app
                    .updateSettings(s.copyWith(includePostContext: v)),
              ),

              const SizedBox(height: 8),

              TextField(
                controller: _languageCtrl,
                decoration: const InputDecoration(
                  labelText: 'Caption Output Language',
                  hintText: 'English',
                ),
                onChanged: (val) => widget.app.updateSettings(
                  s.copyWith(language: val.trim().isEmpty ? 'English' : val.trim()),
                ),
              ),

              const SizedBox(height: 12),

              TextField(
                controller: _customInstructionsCtrl,
                maxLines: 3,
                minLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Custom Instructions (Optional)',
                  hintText:
                      'e.g. Our orange tabby cat is named Marmalade; prefer plain objective tone.',
                ),
                onChanged: (val) => widget.app
                    .updateSettings(s.copyWith(customInstructions: val)),
              ),

              const SizedBox(height: 24),
              const Divider(),

              // === 3. Accessibility Rules (Section 5.1) ===
              _SectionHeader(
                title: 'Accessibility Rules',
                icon: Icons.accessibility_new,
              ),
              const SizedBox(height: 4),
              Text(
                'Pre-Post Alt-Text Policy',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: fedi.subtleText),
              ),
              const SizedBox(height: 8),
              ...PolicyMode.values.map(
                (mode) => RadioListTile<PolicyMode>(
                  contentPadding: EdgeInsets.zero,
                  value: mode,
                  groupValue: s.altTextPolicy,
                  title: Text(mode.label),
                  subtitle: Text(_altPolicySubtitle(mode)),
                  onChanged: (next) {
                    if (next != null) {
                      widget.app.updateSettings(s.copyWith(altTextPolicy: next));
                    }
                  },
                ),
              ),

              const SizedBox(height: 16),
              const Divider(),

              // === 4. Bias Rules (Section 5.2) ===
              _SectionHeader(
                title: 'Bias Rules',
                icon: Icons.balance,
              ),
              const SizedBox(height: 4),
              Text(
                'Pre-Post Racial & Gender Bias Policy',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: fedi.subtleText),
              ),
              const SizedBox(height: 8),
              ...PolicyMode.values.map(
                (mode) => RadioListTile<PolicyMode>(
                  contentPadding: EdgeInsets.zero,
                  value: mode,
                  groupValue: s.biasPolicy,
                  title: Text(mode.label),
                  subtitle: Text(_biasPolicySubtitle(mode)),
                  onChanged: (next) {
                    if (next != null) {
                      widget.app.updateSettings(s.copyWith(biasPolicy: next));
                    }
                  },
                ),
              ),

              const SizedBox(height: 16),
              const Divider(),

              // === 5. Theme & Appearance (Section 7.1) ===
              _SectionHeader(
                title: 'Appearance & Theme',
                icon: Icons.contrast,
              ),
              const SizedBox(height: 4),
              Text(
                'Detected OS mode: ${widget.app.themeController.platformHighContrast ? 'High Contrast' : (widget.app.themeController.platformBrightness == Brightness.dark ? 'Dark' : 'Light')}',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: fedi.subtleText),
              ),
              const SizedBox(height: 8),
              ...ThemePreference.values.map(
                (pref) => RadioListTile<ThemePreference>(
                  contentPadding: EdgeInsets.zero,
                  value: pref,
                  groupValue: s.themePreference,
                  title: Text(pref.label),
                  onChanged: (next) {
                    if (next != null) {
                      widget.app.updateSettings(
                        s.copyWith(themePreference: next),
                      );
                    }
                  },
                ),
              ),

              const SizedBox(height: 16),
              const Divider(),

              // === 6. Connected Server & About ===
              _SectionHeader(
                title: 'Account & Server Info',
                icon: Icons.info_outline,
              ),
              const SizedBox(height: 8),
              if (widget.app.isAuthenticated) ...[
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    '${widget.app.currentAccount!.effectiveDisplayName} (${widget.app.currentAccount!.handle})',
                  ),
                  subtitle: Text(
                    'Server: ${widget.app.session!.instanceUrl}\n'
                    'Max post length: ${limits.maxCharacters} chars · '
                    'Max media: ${limits.maxMediaAttachments} · '
                    'Alt-text limit: ${limits.altTextLimit} chars',
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () async {
                    await widget.app.logout();
                    if (context.mounted) {
                      Navigator.of(context).popUntil((r) => r.isFirst);
                    }
                  },
                  icon: const Icon(Icons.logout),
                  label: const Text('Sign Out'),
                ),
                const SizedBox(height: 12),
              ],
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  '${AppConstants.appName} v${AppConstants.appVersion}',
                ),
                subtitle: const Text(
                  'Contributor: ${AppConstants.contributorName} · Generated with Antigravity',
                ),
                trailing: const Icon(Icons.open_in_new),
                onTap: () => launchUrl(
                  Uri.parse(AppConstants.repositoryUrl),
                  mode: LaunchMode.externalApplication,
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  Widget _buildApiKeyField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required ValueChanged<String> onChanged,
  }) {
    return TextField(
      controller: controller,
      obscureText: _obscureApiKey,
      autocorrect: false,
      onChanged: onChanged,
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

  String _altPolicySubtitle(PolicyMode mode) {
    switch (mode) {
      case PolicyMode.warn:
        return 'Warn before posting uncaptioned media, with options to auto-generate with AI or post anyway.';
      case PolicyMode.require:
        return 'Strictly require alt-text on all attached media before posting.';
      case PolicyMode.off:
        return 'Do not warn about missing alt-text.';
    }
  }

  String _biasPolicySubtitle(PolicyMode mode) {
    switch (mode) {
      case PolicyMode.warn:
        return 'Warn about racial or gender bias before posting; allow editing, suggested wording, or "Publish Anyway".';
      case PolicyMode.require:
        return 'Require detected racial or gender bias to be resolved before posting (hides "Publish Anyway").';
      case PolicyMode.off:
        return 'Skip pre-post racial & gender bias checking and publish immediately.';
    }
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.icon,
  });

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Row(
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            title,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
