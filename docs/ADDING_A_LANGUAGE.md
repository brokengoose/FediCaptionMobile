# Adding a Language to FediCaption Mobile

FediCaption separates **app interface localization** (UI strings, accessibility labels, announcements, and timestamps) from **domain language rules** (alt-text caption formatting, inclusive-language heuristics, TTS locale mapping, and script metadata).

This separation lets contributors translate the app UI purely through standard Flutter ARB files, while optionally adding tailored captioning and bias rules for any language.

---

## Architecture Overview

- **`lib/l10n/` (UI & Accessibility Localization via `gen-l10n`)**
  - `lib/l10n/arb/app_en.arb` — Template ARB catalog for all screens, widgets, dialogs, screen-reader semantics, announcements, relative timestamps, and bias UI labels.
  - `lib/l10n/l10n.dart` — `BuildContext.l10n`, `resolveSupportedLocale`, `resolveAppLocalizations`, `resolveTextDirection`, and `biasComponentLabelsFrom`.
  - `lib/l10n/model_localizations.dart` — Localized labels for models and enums (`PolicyMode`, `ThemePreference`, `AiProviderType`, `CaptionDetailLevel`, `TimelineType`, `PostVisibility`, `AttachmentStatus`, `MastodonNotification`, `OnDeviceAiStatus`, `AiModelOption`).
  - `lib/l10n/generated/` — Generated `AppLocalizations` classes produced by `flutter gen-l10n`.
- **`lib/core/language/` (Domain Language Metadata & Pluggable Packs)**
  - `language_registry.dart` (`LanguageRegistry`) — Catalog of 52 languages with canonical ISO 639 codes, English names, native endonyms, aliases, BCP-47 default TTS locales, typography flags (`usesWordSpaces`, `hasLetterCase`), and offline Unicode script detection.
  - `caption_language_pack.dart` (`CaptionLanguagePack`) — Per-language AI alt-text prefix, redundant LLM preamble regexes, quote pairs, prompt negative examples, capitalization, and word-spacing behavior.
  - `bias_language_pack.dart` (`BiasLanguagePack`, `BiasHeuristicRule`, `BiasComponentLabels`) — Per-language offline inclusive-language heuristic rules, AI prompt examples, and localized component labels.
  - `packs/en_language_pack.dart` — Default English caption and bias rules.
  - `language_pack_registry.dart` (`LanguagePackRegistry`) — Registry pairing language codes with `AppLanguagePack` bundles.

---

## Part 1: Translating the App UI

1. **Create the ARB translation file**
   Copy `lib/l10n/arb/app_en.arb` to `lib/l10n/arb/app_<locale>.arb` (for example `app_es.arb`, `app_ja.arb`, or `app_pt_BR.arb`).

2. **Set `@@locale`**
   Update the top key of the new file to match the target locale:
   ```json
   {
     "@@locale": "es",
     ...
   }
   ```

3. **Translate values while preserving ICU syntax**
   - Keep every `{placeholder}` name (such as `{author}`, `{count}`, `{language}`) unchanged.
   - Preserve ICU plural syntax (`{count, plural, =1{...} other{...}}`) and adjust plural categories (`=0`, `=1`, `=2`, `few`, `many`, `other`) if required by the target language.
   - You can omit `@metadata` description blocks in non-template ARB files or update descriptions for translators.

4. **Generate localization code & check coverage**
   Run:
   ```bash
   flutter gen-l10n
   ```
   Verify `lib/l10n/untranslated.json` is `{}` (or contains only intentional fallback strings).

5. **What happens automatically once generated**
   - `AppLocalizations.supportedLocales` includes the new locale, and `FediCaptionApp` automatically matches the OS locale.
   - **Settings → App Interface Language** automatically appears once `AppLocalizations.supportedLocales.length > 1`, allowing users to stay on **System Default** or pick a specific UI language (persisted in `AppSettings.appLocale`).
   - Bidirectional layouts (`EdgeInsetsDirectional`, `BorderDirectional`, `AlignmentDirectional`) and `AccessibilityAnnouncer.defaultTextDirection` automatically switch to RTL when an RTL locale (`ar`, `he`, `fa`, `ur`, etc.) is active.

---

## Part 2: Adding a Domain Language Pack (Optional)

You do **not** need a domain pack just to translate the app UI. Create one if you want a localized AI alt-text prefix, language-specific LLM preamble cleanup, or offline inclusive-language heuristic rules for posts drafted in that language.

1. **Verify metadata in `LanguageRegistry`**
   Check `lib/core/language/language_registry.dart`. If your language is not already among the built-in entries, add a `LanguageInfo` record defining:
   - `code`: Canonical lowercase ISO 639-1/639-2 code
   - `englishName`: Name used in AI prompts
   - `nativeName`: Native endonym shown in selectors
   - `defaultTtsLocale`: Default BCP-47 tag for text-to-speech
   - `usesWordSpaces`: Set `false` for non-spaced scripts (Japanese, Chinese, Thai, etc.) so `CaptionFormatter.truncateOnWordBoundary` truncates cleanly by character/grapheme
   - `hasLetterCase`: Set `false` for unicameral scripts so `CaptionFormatter` skips `.toUpperCase()` on the first character

2. **Create `lib/core/language/packs/<lang>_language_pack.dart`**
   Model it after `lib/core/language/packs/en_language_pack.dart`:
   ```dart
   import '../bias_language_pack.dart';
   import '../caption_language_pack.dart';
   import '../language_pack_registry.dart';

   final CaptionLanguagePack esCaptionLanguagePack = CaptionLanguagePack(
     languageCode: 'es',
     captionPrefix: 'Descripción generada por IA: ',
     redundantPrefixPatterns: [
       RegExp(r'^descripci[oó]n\s+generada\s+por\s+ia\s*:\s*', caseSensitive: false),
       RegExp(r'^foto\s+de\s+', caseSensitive: false),
     ],
     forbiddenPrefixExamples: const [
       'Foto de',
       'Descripción generada por IA:',
     ],
   );

   const AppLanguagePack esLanguagePack = AppLanguagePack(
     languageCode: 'es',
     caption: esCaptionLanguagePack,
     // Optionally attach a BiasLanguagePack for offline heuristic rules:
     // bias: esBiasLanguagePack,
   );
   ```
   > **Note on Bias Heuristics:** When a post has no registered `BiasLanguagePack` for its language, `LocalBiasHeuristics` safely avoids firing English-only regex rules, preventing false positives on non-English drafts while multimodal AI bias review still analyzes the post and responds in the user's UI language.

3. **Register the pack in `LanguagePackRegistry`**
   Add `<lang>: <lang>LanguagePack` to `LanguagePackRegistry._packs` in `lib/core/language/language_pack_registry.dart`.

---

## Part 3: Native Platform Metadata (Optional)

Flutter's `gen-l10n` handles all in-app UI strings. If you also want OS-level permission dialogs or app metadata translated:

- **iOS / macOS**: Add `<lang>.lproj/InfoPlist.strings` under `ios/Runner/` and `macos/Runner/` to localize keys such as `NSCameraUsageDescription` and `NSPhotoLibraryUsageDescription`.
- **Android**: Add `android/app/src/main/res/values-<lang>/strings.xml` for native Android string resources if needed.

---

## Part 4: Verification Checklist

Before opening a pull request:

1. Regenerate localizations and verify no untranslated keys remain:
   ```bash
   flutter gen-l10n
   cat lib/l10n/untranslated.json
   ```
2. Run static analysis:
   ```bash
   flutter analyze
   ```
3. Run the test suite (including `test/language_architecture_test.dart`):
   ```bash
   flutter test
   ```
4. For RTL languages (`ar`, `he`, etc.) or verbose European translations, pump key widgets under `localizedTestApp` (`test/helpers/test_app.dart`) with `locale` / `textDirection: TextDirection.rtl` to verify there are no text overflows or layout issues.
