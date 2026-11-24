// Copyright (c) 2026 brokengoose <brokengoose@users.noreply.github.com>
// SPDX-License-Identifier: MIT

import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants.dart';
import '../../core/language/language_registry.dart';
import '../../core/theme/app_theme.dart';
import '../../l10n/l10n.dart';
import '../../l10n/model_localizations.dart';
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
    final l10n = context.l10n;
    return ListenableBuilder(
      listenable: Listenable.merge([widget.app, widget.app.themeController]),
      builder: (context, _) {
        final s = widget.app.settings;
        final fedi = context.fediColors;
        final limits = widget.app.instanceLimits;
        final displayedSpeechRate = _draggingSpeechRate ?? s.ttsSpeechRate;
        final formattedSpeed = (displayedSpeechRate * 2).toStringAsFixed(2);
        const supportedLocales = AppLocalizations.supportedLocales;
        final supportedTags =
            supportedLocales.map((loc) => loc.toLanguageTag()).toSet();
        final selectedAppLocale = s.resolvedAppLocale != null
            ? resolveSupportedLocale(s.resolvedAppLocale).toLanguageTag()
            : null;
        final effectiveSelectedLocale =
            (selectedAppLocale != null && supportedTags.contains(selectedAppLocale))
                ? selectedAppLocale
                : null;
        final systemLanguageCode =
            WidgetsBinding.instance.platformDispatcher.locale.languageCode;
        final osModeLabel = widget.app.themeController.platformHighContrast
            ? l10n.settingsOsModeHighContrast
            : (widget.app.themeController.platformBrightness == Brightness.dark
                ? l10n.settingsOsModeDark
                : l10n.settingsOsModeLight);

        return Scaffold(
          appBar: AppBar(title: Text(l10n.settingsTitle)),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // === 1. AI Provider, API Keys & Dynamic Model Picker ===
              _SectionHeader(
                title: l10n.settingsSectionAi,
                icon: Icons.auto_awesome,
              ),
              const SizedBox(height: 8),

              AiProviderConfigSection(app: widget.app),

              const SizedBox(height: 24),
              const Divider(),

              // === 2. AI Captioning Preferences ===
              _SectionHeader(
                title: l10n.settingsSectionCaptioning,
                icon: Icons.closed_caption,
              ),
              const SizedBox(height: 8),

              DropdownButtonFormField<CaptionDetailLevel>(
                key: ValueKey('detail_${s.defaultDetailLevel.id}'),
                initialValue: s.defaultDetailLevel,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: l10n.settingsDefaultDetailLevel,
                ),
                items: CaptionDetailLevel.values
                    .map(
                      (lvl) => DropdownMenuItem(
                        value: lvl,
                        child: Text(
                          l10n.settingsDetailLevelItem(
                            lvl.localizedLabel(l10n),
                            lvl.localizedGuidance(l10n),
                          ),
                        ),
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
                decoration: InputDecoration(
                  labelText: l10n.settingsVideoKeyframesLabel,
                  helperText: l10n.settingsVideoKeyframesHelper,
                ),
                items: [
                  DropdownMenuItem(
                    value: 3,
                    child: Text(l10n.settingsVideoKeyframesOption(3)),
                  ),
                  DropdownMenuItem(
                    value: 4,
                    child: Text(l10n.settingsVideoKeyframesDefaultOption(4)),
                  ),
                  DropdownMenuItem(
                    value: 6,
                    child: Text(l10n.settingsVideoKeyframesOption(6)),
                  ),
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
                title: Text(l10n.settingsAutoGenerateTitle),
                subtitle: Text(l10n.settingsAutoGenerateSubtitle),
                value: s.autoGenerate,
                onChanged: (v) => widget.app.updateSettings(
                  s.copyWith(autoGenerate: v),
                  autoRefreshModels: false,
                ),
              ),

              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.settingsIncludePostContextTitle),
                subtitle: Text(l10n.settingsIncludePostContextSubtitle),
                value: s.includePostContext,
                onChanged: (v) => widget.app.updateSettings(
                  s.copyWith(includePostContext: v),
                  autoRefreshModels: false,
                ),
              ),

              const SizedBox(height: 8),

              TextField(
                controller: _languageCtrl,
                decoration: InputDecoration(
                  labelText: l10n.settingsCaptionLanguageLabel,
                  hintText: l10n.settingsCaptionLanguageHint,
                ),
                onChanged: (_) => _scheduleTextPrefsSave(),
              ),

              const SizedBox(height: 12),

              TextField(
                controller: _customInstructionsCtrl,
                maxLines: 3,
                minLines: 2,
                decoration: InputDecoration(
                  labelText: l10n.settingsCustomInstructionsLabel,
                  hintText: l10n.settingsCustomInstructionsHint,
                ),
                onChanged: (_) => _scheduleTextPrefsSave(),
              ),

              const SizedBox(height: 24),
              const Divider(),

              // === 3. Accessibility Rules ===
              _SectionHeader(
                title: l10n.settingsSectionAccessibility,
                icon: Icons.accessibility_new,
              ),
              const SizedBox(height: 8),
              Text(
                l10n.settingsTtsSpeedTitle(formattedSpeed),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              Text(
                l10n.settingsTtsSpeedSubtitle,
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
                label: l10n.settingsTtsSpeedLabel(formattedSpeed),
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
                l10n.settingsAltPolicyLabel,
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
                          title: Text(mode.localizedLabel(l10n)),
                          subtitle: Text(mode.localizedAltPolicySubtitle(l10n)),
                        ),
                      )
                      .toList(),
                ),
              ),

              const SizedBox(height: 16),
              const Divider(),

              // === 4. Bias Rules ===
              _SectionHeader(
                title: l10n.settingsSectionBias,
                icon: Icons.balance,
              ),
              const SizedBox(height: 4),
              Text(
                l10n.settingsBiasPolicyLabel,
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
                          title: Text(mode.localizedLabel(l10n)),
                          subtitle: Text(mode.localizedBiasPolicySubtitle(l10n)),
                        ),
                      )
                      .toList(),
                ),
              ),

              const SizedBox(height: 16),
              const Divider(),

              // === 5. Theme & Appearance ===
              _SectionHeader(
                title: l10n.settingsSectionAppearance,
                icon: Icons.contrast,
              ),
              const SizedBox(height: 4),
              Text(
                l10n.settingsDetectedOsMode(osModeLabel),
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
                          title: Text(pref.localizedLabel(l10n)),
                        ),
                      )
                      .toList(),
                ),
              ),
              if (supportedLocales.length > 1) ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<String?>(
                  key: ValueKey('app_locale_${effectiveSelectedLocale ?? 'sys'}'),
                  initialValue: effectiveSelectedLocale,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: l10n.settingsAppLanguageLabel,
                    helperText: l10n.settingsAppLanguageHelper,
                  ),
                  items: [
                    DropdownMenuItem<String?>(
                      value: null,
                      child: Text(
                        l10n.settingsAppLanguageSystemDefault(
                          LanguageRegistry.nativeNameFor(systemLanguageCode),
                        ),
                      ),
                    ),
                    for (final locale in supportedLocales)
                      DropdownMenuItem<String?>(
                        value: locale.toLanguageTag(),
                        child: Text(
                          LanguageRegistry.nativeNameFor(locale.languageCode),
                        ),
                      ),
                  ],
                  onChanged: (next) {
                    widget.app.updateSettings(
                      s.copyWith(
                        appLocale: next,
                        clearAppLocale: next == null,
                      ),
                      autoRefreshModels: false,
                    );
                  },
                ),
              ],

              const SizedBox(height: 16),
              const Divider(),

              // === 6. Connected Server & About ===
              _SectionHeader(
                title: l10n.settingsSectionAccount,
                icon: Icons.info_outline,
              ),
              const SizedBox(height: 8),
              if (widget.app.isAuthenticated) ...[
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    l10n.settingsAccountTitle(
                      widget.app.currentAccount!.effectiveDisplayName,
                      widget.app.currentAccount!.handle,
                    ),
                  ),
                  subtitle: Text(
                    l10n.settingsAccountSubtitle(
                      widget.app.session!.instanceUrl,
                      limits.maxCharacters,
                      limits.maxMediaAttachments,
                      limits.altTextLimit,
                    ),
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
                  label: Text(l10n.settingsSignOut),
                ),
                const SizedBox(height: 12),
              ],
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  l10n.settingsAboutTitle(
                    AppConstants.appName,
                    AppConstants.appVersion,
                  ),
                ),
                subtitle: Text(
                  l10n.settingsAboutSubtitle(AppConstants.contributorName),
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
