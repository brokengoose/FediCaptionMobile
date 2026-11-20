// Copyright (c) 2026 brokengoose <brokengoose@users.noreply.github.com>
// SPDX-License-Identifier: MIT

import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants.dart';
import '../../core/theme/app_theme.dart';
import '../../models/ai_models.dart';
import '../../models/app_settings.dart';
import '../../state/app_controller.dart';
import '../widgets/ai_provider_config_section.dart';

/// Settings screen providing:
/// - AI provider selection, API keys / server URLs, and dynamic model drop-down picker
/// - AI Captioning preferences (detail level, video keyframes, auto-generate, post context, language, custom instructions)
/// - Parallel Accessibility Rules (TTS speed + alt-text policy) and Bias Rules sections
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
  late final TextEditingController _languageCtrl;
  late final TextEditingController _customInstructionsCtrl;

  Timer? _textPrefsDebounce;
  double? _draggingSpeechRate;

  @override
  void initState() {
    super.initState();
    final s = widget.app.settings;
    _languageCtrl = TextEditingController(text: s.language);
    _customInstructionsCtrl = TextEditingController(text: s.customInstructions);
  }

  @override
  void dispose() {
    _textPrefsDebounce?.cancel();
    _languageCtrl.dispose();
    _customInstructionsCtrl.dispose();
    super.dispose();
  }

  /// Debounces persisting caption language and custom instructions so typing
  /// does not write SharedPreferences or rebuild the app on every keystroke.
  void _scheduleTextPrefsSave() {
    _textPrefsDebounce?.cancel();
    _textPrefsDebounce = Timer(const Duration(milliseconds: 500), () {
      final lang = _languageCtrl.text.trim();
      widget.app.updateSettings(
        widget.app.settings.copyWith(
          language: lang.isEmpty ? 'English' : lang,
          customInstructions: _customInstructionsCtrl.text,
        ),
        autoRefreshModels: false,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([widget.app, widget.app.themeController]),
      builder: (context, _) {
        final s = widget.app.settings;
        final fedi = context.fediColors;
        final limits = widget.app.instanceLimits;
        final displayedSpeechRate = _draggingSpeechRate ?? s.ttsSpeechRate;

        return Scaffold(
          appBar: AppBar(title: const Text('Settings')),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // === 1. AI Provider, API Keys & Dynamic Model Picker ===
              const _SectionHeader(
                title: 'AI Provider & API Keys',
                icon: Icons.auto_awesome,
              ),
              const SizedBox(height: 8),

              AiProviderConfigSection(app: widget.app),

              const SizedBox(height: 24),
              const Divider(),

              // === 2. AI Captioning Preferences ===
              const _SectionHeader(
                title: 'AI Alt-Text Captioning',
                icon: Icons.closed_caption,
              ),
              const SizedBox(height: 8),

              DropdownButtonFormField<CaptionDetailLevel>(
                key: ValueKey('detail_${s.defaultDetailLevel.id}'),
                initialValue: s.defaultDetailLevel,
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
                      autoRefreshModels: false,
                    );
                  }
                },
              ),

              const SizedBox(height: 12),

              DropdownButtonFormField<int>(
                key: ValueKey('keyframes_${s.videoKeyframeCount}'),
                initialValue: s.videoKeyframeCount,
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
                      autoRefreshModels: false,
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
                onChanged: (v) => widget.app.updateSettings(
                  s.copyWith(autoGenerate: v),
                  autoRefreshModels: false,
                ),
              ),

              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Include Draft Post Text as Context'),
                subtitle: const Text(
                  'Helps the AI identify names, events, or subjects mentioned in your draft.',
                ),
                value: s.includePostContext,
                onChanged: (v) => widget.app.updateSettings(
                  s.copyWith(includePostContext: v),
                  autoRefreshModels: false,
                ),
              ),

              const SizedBox(height: 8),

              TextField(
                controller: _languageCtrl,
                decoration: const InputDecoration(
                  labelText: 'Caption Output Language',
                  hintText: 'English',
                ),
                onChanged: (_) => _scheduleTextPrefsSave(),
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
                onChanged: (_) => _scheduleTextPrefsSave(),
              ),

              const SizedBox(height: 24),
              const Divider(),

              // === 3. Accessibility Rules ===
              const _SectionHeader(
                title: 'Accessibility Rules',
                icon: Icons.accessibility_new,
              ),
              const SizedBox(height: 8),
              Text(
                'Built-in On-Device Read Aloud Speed (${(displayedSpeechRate * 2).toStringAsFixed(2)}x)',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              Text(
                'Uses your phone\'s built-in on-device TTS engine (AVSpeechSynthesizer on iPhone, Google/Samsung TTS on Android).',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: fedi.subtleText),
              ),
              Slider(
                value: displayedSpeechRate,
                min: 0.25,
                max: 1.0,
                divisions: 15,
                label: '${(displayedSpeechRate * 2).toStringAsFixed(2)}x',
                onChanged: (next) =>
                    setState(() => _draggingSpeechRate = next),
                onChangeEnd: (next) {
                  setState(() => _draggingSpeechRate = null);
                  widget.app.updateSettings(
                    s.copyWith(ttsSpeechRate: next),
                    autoRefreshModels: false,
                  );
                },
              ),
              const SizedBox(height: 8),
              Text(
                'Pre-Post Alt-Text Policy',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: fedi.subtleText),
              ),
              const SizedBox(height: 8),
              RadioGroup<PolicyMode>(
                groupValue: s.altTextPolicy,
                onChanged: (next) {
                  if (next != null) {
                    widget.app.updateSettings(
                      s.copyWith(altTextPolicy: next),
                      autoRefreshModels: false,
                    );
                  }
                },
                child: Column(
                  children: PolicyMode.values
                      .map(
                        (mode) => RadioListTile<PolicyMode>(
                          contentPadding: EdgeInsets.zero,
                          value: mode,
                          title: Text(mode.label),
                          subtitle: Text(_altPolicySubtitle(mode)),
                        ),
                      )
                      .toList(),
                ),
              ),

              const SizedBox(height: 16),
              const Divider(),

              // === 4. Bias Rules ===
              const _SectionHeader(
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
              RadioGroup<PolicyMode>(
                groupValue: s.biasPolicy,
                onChanged: (next) {
                  if (next != null) {
                    widget.app.updateSettings(
                      s.copyWith(biasPolicy: next),
                      autoRefreshModels: false,
                    );
                  }
                },
                child: Column(
                  children: PolicyMode.values
                      .map(
                        (mode) => RadioListTile<PolicyMode>(
                          contentPadding: EdgeInsets.zero,
                          value: mode,
                          title: Text(mode.label),
                          subtitle: Text(_biasPolicySubtitle(mode)),
                        ),
                      )
                      .toList(),
                ),
              ),

              const SizedBox(height: 16),
              const Divider(),

              // === 5. Theme & Appearance ===
              const _SectionHeader(
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
              RadioGroup<ThemePreference>(
                groupValue: s.themePreference,
                onChanged: (next) {
                  if (next != null) {
                    widget.app.updateSettings(
                      s.copyWith(themePreference: next),
                      autoRefreshModels: false,
                    );
                  }
                },
                child: Column(
                  children: ThemePreference.values
                      .map(
                        (pref) => RadioListTile<ThemePreference>(
                          contentPadding: EdgeInsets.zero,
                          value: pref,
                          title: Text(pref.label),
                        ),
                      )
                      .toList(),
                ),
              ),

              const SizedBox(height: 16),
              const Divider(),

              // === 6. Connected Server & About ===
              const _SectionHeader(
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
