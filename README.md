# FediCaption Mobile (iOS, Android, macOS, Windows & Linux)

**FediCaption Mobile** is an accessible, cross-platform Flutter Mastodon client for **iOS (iPhone/iPad)**, **Android**, **macOS (Universal Intel & Apple Silicon)**, **Windows (`x64` & `ARM64`)**, and **Linux (`x64` & `ARM64`)**, featuring built-in **on-device AI** (Apple Foundation Models & Google Gemini Nano), multi-provider cloud/LAN AI, automatic AI alt-text generation for images and videos, on-demand timeline media descriptions, full-post & per-media **Read Aloud (TTS)**, multi-backend post & alt-text translation, embedded quoted posts, standard Mastodon keyboard shortcuts, and pre-post racial & gender bias checking.

> This project was generated with **Antigravity**.  
> Contributor: **brokengoose** (`brokengoose@users.noreply.github.com`)  
> License: [MIT](LICENSE)

---

## Platform Support

| Platform | Target / Packaging | On-Device AI (`edge_gen_ai`) | Translation Backends | Read Aloud (TTS) & Video | Auth & Secret Storage |
| --- | --- | --- | --- | --- | --- |
| **iOS** | iOS 15.0+ (`UIScene`, iPhone/iPad) | Apple Foundation Models (iOS 26+) | On-Device AI → Apple Translation (iOS 18+) → Configured AI → Mastodon API | `AVSpeechSynthesizer` / `video_player` | `ASWebAuthenticationSession` / iOS Keychain |
| **Android** | API 26+ (Android 8.0+, APK) | Google Gemini Nano via ML Kit GenAI & AICore (Pixel 8+ & supported Samsung flagships) | On-Device AI → ML Kit Translation → Configured AI → Mastodon API | System `TextToSpeech` / `video_player` | Chrome Custom Tabs / Android Keystore |
| **macOS** | macOS 12.0+ Universal (`x86_64` + `arm64`, `.app`) | Apple Foundation Models (Apple Silicon, macOS 26+; unavailable on Intel) | On-Device AI (Apple Silicon) → Apple Translation (macOS 15+) → Configured AI → Mastodon API | `AVSpeechSynthesizer` / `video_player` | `ASWebAuthenticationSession` / Sandboxed app prefs |
| **Windows** | Windows 10/11 (`x64` & `ARM64`, portable ZIP / `.exe`) | Not available on Windows OS | Configured AI Provider (Gemini/OpenAI/Anthropic/LAN) → Mastodon API | Windows SAPI / Windows Media Foundation (`video_player_win`) & native CryptoAPI TLS (`crypt32.lib`) | Default browser RFC 8252 loopback OAuth / Windows Credential Manager |
| **Linux** | Portable GTK3 (`x64` & `ARM64`/`aarch64`, `.tar.gz`) | Not available on Linux OS | Configured AI Provider (Gemini/OpenAI/Anthropic/LAN) → Mastodon API | `spd-say` → `espeak-ng` → `espeak` (optional) / **`libmpv` (required)** (`video_player_media_kit`) | Default browser RFC 8252 loopback OAuth / `libsecret` keyring (with fallback) |

---

## Key Features

### 1. Automatic AI Image & Video Alt-Text Generation + Full-Post Read Aloud
- Automatically scans images and videos upon attachment (from camera, photo library, or file picker) with configurable detail levels (`Concise`, `Descriptive`, `Detailed`), output language, draft-context sharing, and custom instructions.
- Enforces the mandatory caption prefix (**`AI generated description: `** by default), strips redundant preambles and surrounding quotes, and truncates cleanly on word boundaries (or grapheme-safe boundaries for non-spaced scripts) to match the Mastodon server's `description_limit`.
- **Video support**: Sends clips directly inline to Google Gemini when within payload limits, or extracts `3`, `4` (default), or `6` evenly spaced keyframes for frame-based and on-device vision models or larger videos.
- Per-attachment editable alt-text box with live character counter, status badge (`AI Scanning...`, `Alt-Text Ready`, `Missing Alt-Text`, `Error`), **Re-Scan with AI**, per-attachment detail level, built-in **Read Aloud (TTS)**, and **Remove**.
- **On-Demand Timeline Descriptions & Full-Post Read Aloud**: Clearly displays `ALT TEXT PROVIDED` vs `NO ALT TEXT` on timeline and quoted posts with **Describe with AI** / **Re-Describe with AI** and per-media **Read Aloud**. Opening any individual post (`ThreadScreen`) also shows a top-of-post **Read Aloud** button that reads the Content Warning, post text, all media alt-text descriptions (AI / translated / author), and embedded quoted posts together.

### 2. Supported AI Providers & Smart First-Time Setup Wizard
- Guided first-time **AI Setup Wizard** shown on first launch before Mastodon account setup automatically probes whether OS on-device AI is available or downloadable on the current device — defaulting to **On-Device AI** when supported (e.g. eligible iPhone, Pixel/Samsung, or Apple Silicon Mac) and **No AI** otherwise (e.g. Intel Macs, Windows, Linux, or unsupported hardware), while allowing manual switching to any provider:
  - **On-Device AI** *(zero network calls)* via `edge_gen_ai`:
    - **Apple Foundation Models (Apple Intelligence)** on iOS 26+/27+ and Apple Silicon macOS 26+
    - **Google Gemini Nano** via ML Kit GenAI & Android AICore on Pixel 8+ and supported Samsung flagships (with R8 ProGuard keep rules and in-app model download provisioning)
  - **Google Gemini API** (cloud vision & native inline video)
  - **OpenAI / OpenAI-Compatible API** (OpenAI, OpenRouter, LM Studio, vLLM, llama.cpp)
  - **Anthropic Claude API**
  - **Local Network Server** (Ollama `/api/tags` + `/api/chat` and LM Studio `/v1` on localhost or LAN)
  - **No AI** (manual alt-text, built-in Read Aloud, Mastodon server translation when supported, and deterministic offline bias heuristics)
- **Alphabetically sorted (A–Z) dynamic model drop-down picker** in both onboarding and Settings that queries the selected provider's live models endpoint, falling back to curated vision models when offline.

### 3. Multi-Backend Post & Alt-Text Translation
- When viewing a post whose language differs from your UI/OS language, FediCaption offers top-of-post translation covering Content Warnings, post text, and media alt-text.
- Automatically chains native/local backends (`On-Device AI` → Apple `Translation` framework on iOS 18+/macOS 15+ → Google `ML Kit Translation` on Android → your configured `AI Provider`) with automatic fallback to **Mastodon's built-in server translation endpoint** (`POST /api/v1/statuses/:id/translate`) when enabled on your instance — enabling seamless translation across desktop (Windows & Linux) as well as mobile.

### 4. Pre-Post Racial & Gender Bias Checking
- Inspects **Post Text & Content Warning**, **Attachments (visual media + alt-text)**, **External Links** (fetches page title, meta description, and text excerpt), and **Referenced / Replied-to Mastodon Messages**.
- **Silent pass when clean**: Publishes immediately if no bias is detected.
- **Actionable review sheet when bias is found**: Displays a summary, exact location and bias type of each finding, and suggested inclusive alternate wording with one-tap **Use Suggested Wording in Composer** and **Use Suggested Wording & Publish Now** buttons.
- Includes a deterministic offline local heuristic checker (`LocalBiasHeuristics`) as both an offline fallback and safety backstop (and avoids firing English-only regex rules on non-English drafts without a matching bias pack).

### 5. Parallel Accessibility Rules & Bias Rules
- **Built-In On-Device Read Aloud Speed**: Configurable TTS speech-rate slider (`AVSpeechSynthesizer` on iOS/macOS, system `TextToSpeech` on Android, Windows SAPI, and `spd-say` / `espeak-ng` / `espeak` on Linux).
- **Accessibility Rules** (`warn` [default] / `require` / `off`): Warns or requires alt-text on attached media before posting, with one-tap **Auto-Generate Missing Alt-Text with AI**.
- **Bias Rules** (`warn` [default] / `require` / `off`): Warns, enforces revision (hiding *Publish Anyway*), or disables pre-post bias checking.

### 6. Full Mastodon Client, Embedded Quotes, Keyboard Navigation & Accessibility
- **OAuth 2.0 + Direct Token Fallback**: `ASWebAuthenticationSession` on iOS/macOS, Chrome Custom Tabs on Android (`fedicaption://oauth-callback`), and default-browser RFC 8252 loopback (`http://127.0.0.1:43823/oauth-callback`) on Windows & Linux (registering `https://github.com/brokengoose/FediCaptionMobile` as the OAuth app website), plus **Direct Access Token** fallback.
- **Dynamic Instance Limits**: Queries `/api/v2/instance` (with `/api/v1/instance` fallback) for actual server character limits (including Glitch-soc, Hometown, Pleroma, Akkoma), media limits, alt-text limits, and translation availability. Counts both post body and Content Warning.
- **Timelines, Offline Search & Keyboard Shortcuts**: Home, Local, Federated, Notifications, Bookmarks, Favorites, My Published Posts, and User Profiles with pull-to-refresh, infinite-scroll pagination, instant offline search (`/`) over cached posts & alt-text, and full Mastodon keyboard navigation (`j`/`k`, `g h/l/p/n/b/f/u`, `?` help sheet).
- **Embedded Quoted Posts**: Detects Mastodon posts starting with `RE: <url>` (and native `quote.quoted_status` payloads), strips the redundant prefix, resolves and caches the original post, and embeds it as an interactive **Quoted Post** window above the reply text (complete with clickable author, thread navigation, media alt-text, AI Describe, Read Aloud, and Retry on failure).
- **Clickable Links, Mentions, Profiles & Actions**: Clickable upper-right relative timestamp linking to the original post on its Mastodon server, avatar/name profile navigation with **Subscribe / Unsubscribe** and **Notifications bell** (`notify`), Reply, Boost, Favorite, Bookmark, Thread View, Delete (with confirmation everywhere), and **Edit Own Posts** (including updating media alt-text via `PUT /api/v1/statuses/{id}`).
- **Themes, Screen Readers & Update Check**: Dark, Light, and **WCAG AAA High Contrast** themes with live OS appearance/high-contrast detection, full VoiceOver/TalkBack/desktop screen-reader announcements, `>= 48×48 dp` touch targets, and startup GitHub release update checking.

### 7. Multi-Language & Localization Architecture
- **UI & Accessibility Localization (`lib/l10n/`)**: All menus, dialogs, screen-reader labels, VoiceOver/TalkBack live announcements, relative timestamps, and bias component labels use Flutter `gen-l10n` ARB catalogs (`lib/l10n/arb/app_en.arb`) with full bidirectional (`LTR`/`RTL`) layout support.
- **Pluggable Domain Language Packs (`lib/core/language/`)**: Central `LanguageRegistry` (52 languages with native endonyms, BCP-47 TTS locales, word-spacing/casing flags, and script detection) plus `LanguagePackRegistry` (`CaptionLanguagePack` & `BiasLanguagePack`) separate language-specific caption prefixes, LLM prompt cleanup rules, and offline inclusive-language heuristics from core services.
- Want to translate FediCaption or add caption/bias rules for another language? See the step-by-step guide in [docs/ADDING_A_LANGUAGE.md](docs/ADDING_A_LANGUAGE.md).

---

## Getting Started & Prerequisites

### Prerequisites by Platform

- **Common (building from source)**:
  - [Flutter SDK](https://docs.flutter.dev/get-started/install) (`>= 3.50`, Dart `>= 3.14`, `material_ui`)
- **iOS**:
  - macOS with Xcode & CocoaPods (`brew install cocoapods`), configured for the iOS `UIScene` lifecycle (`SceneDelegate.swift` + `UIApplicationSceneManifest`, deployment target **iOS 15.0+**)
- **Android**:
  - Android Studio with Android SDK (**minSdk 26+** / Android 8.0+, required for ML Kit GenAI / AICore on-device AI)
- **macOS**:
  - macOS with Xcode & CocoaPods (`brew install cocoapods`), targeting **macOS 12.0+** (Universal `x86_64` Intel + `arm64` Apple Silicon)
- **Windows (`x64` & `ARM64`)**:
  - **Runtime (end users)**: Windows 10 or Windows 11 (`x64` or native `ARM64` for Snapdragon / Copilot+ PCs). No Edge WebView2 Runtime is required — OAuth opens in your default browser, video uses Windows Media Foundation (`video_player_win`), TTS uses Windows SAPI, and TLS uses the native Windows Certificate Store (`crypt32.lib`).
  - **Building from source**: Visual Studio 2022 (or Visual Studio Build Tools) with the **Desktop development with C++** workload (MSVC C++17 toolchain, CMake `>= 3.14`, Windows SDK; plus **MSVC C++ ARM64 build tools** and **C++ ATL for ARM64** when building for `ARM64`) and `flutter config --enable-windows-desktop` (also built automatically in CI for both `x64` and `ARM64` via [.github/workflows/windows-build.yml](.github/workflows/windows-build.yml), called from [ci.yml](.github/workflows/ci.yml)).
- **Linux (`x64` & `ARM64` / `aarch64`)**:
  - **Runtime (end users)**:
    - **`libmpv` is required to launch** (`video_player_media_kit` links `libmpv` at startup for video & GIFV playback):
      - Ubuntu 24.04+ / Debian 12+: `sudo apt install libmpv2`
      - Older Ubuntu / Debian: `sudo apt install libmpv1`
      - Fedora: `sudo dnf install mpv-libs`
      - Arch Linux: `sudo pacman -S mpv`
    - **GTK3 / WebKit2GTK runtime libraries** (normally pre-installed on standard GNOME/Ubuntu desktops; install on minimal distros if missing):
      - Debian/Ubuntu: `sudo apt install libwebkit2gtk-4.1-0 libsecret-1-0 libepoxy0 libgtk-3-0`
      - Fedora: `sudo dnf install webkit2gtk4.1 libsecret libepoxy gtk3`
      - Arch Linux: `sudo pacman -S webkit2gtk-4.1 libsecret libepoxy gtk3`
    - **Optional runtime packages**: `speech-dispatcher` and/or `espeak-ng` for Read Aloud TTS; `gnome-keyring` or `kwallet` (`org.freedesktop.secrets`) for encrypted credential storage (falls back automatically if absent).
    - Portable `.tar.gz` bundles include `./install-desktop-entry.sh` to add an app icon and desktop menu entry.
  - **Building from source**: `flutter config --enable-linux-desktop` plus the build dependencies used in [.github/workflows/linux-build.yml](.github/workflows/linux-build.yml):
    ```bash
    sudo apt-get update && sudo apt-get install -y \
      clang cmake ninja-build pkg-config \
      libgtk-3-dev liblzma-dev \
      libsecret-1-dev libjsoncpp-dev \
      libwebkit2gtk-4.1-dev libsoup-3.0-dev \
      libmpv-dev mpv libepoxy-dev
    ```

### Setup & Run
1. Install dependencies (and generate localization files if needed):
   ```bash
   flutter pub get
   flutter gen-l10n
   ```
2. Run the same checks as CI (formatting, static analysis, tests, version consistency):
   ```bash
   dart format --output=none --set-exit-if-changed lib test
   flutter analyze
   flutter test
   ./scripts/check_versions.sh
   ```
   CI uses the exact Flutter release pinned in [`.flutter-version`](.flutter-version); the minimum supported SDK is declared in `pubspec.yaml`. When bumping the app version, update `VERSION`, `version:` in `pubspec.yaml`, and `AppConstants.appVersion` together (the script checks they match).
3. Launch on iOS Simulator, Android Emulator, connected phone, or desktop (`macos`, `windows`, `linux`):
   ```bash
   flutter run
   flutter run -d macos
   flutter run -d windows
   flutter run -d linux
   ```
   *(On macOS Android Emulator, launch the AVD with `-audio coreaudio` for host TTS audio playback.)*
4. Build release desktop bundles locally (or let GitHub Actions build Windows & Linux: [.github/workflows/ci.yml](.github/workflows/ci.yml) verifies the code, compile-checks Android/iOS/macOS, then calls [windows-build.yml](.github/workflows/windows-build.yml) and [linux-build.yml](.github/workflows/linux-build.yml) and attaches the bundles to the GitHub Release on `v*` tags):
   ```bash
   flutter build macos --release
   flutter build windows --release
   flutter build linux --release
   ```
5. Build a release Android APK (includes R8 keep rules for ML Kit GenAI / AICore in `android/app/proguard-rules.pro`):
   ```bash
   flutter build apk --release
   ```
6. Rebuild, boot the Android emulator (with CoreAudio for TTS), install, and launch in one step (macOS):
   ```bash
   ./scripts/run_android_emulator.sh
   ```

---

## Project Structure

```text
.github/workflows/                       # CI: ci.yml (verify + platform checks + release) calling linux-build.yml / windows-build.yml
docs/ADDING_A_LANGUAGE.md                # Contributor guide for UI translations & domain language packs
lib/
├── core/
│   ├── accessibility_announcer.dart     # VoiceOver, TalkBack & desktop live announcements
│   ├── constants.dart                   # App metadata, OAuth website, limits, prefix
│   ├── html_utils.dart                  # HTML-to-text, URL/punctuation parsing, RE: quote extraction
│   ├── language/                        # LanguageRegistry, LanguagePackRegistry & pluggable packs
│   ├── media_utils.dart                 # Shared video extension & MIME type helpers
│   ├── post_read_aloud_builder.dart     # Full-post + alt-text + quote speech script assembler
│   ├── time_utils.dart                  # Localized relative & accessible timestamps
│   └── theme/                           # Dark, Light, WCAG AAA High Contrast + OS auto-detect
├── l10n/
│   ├── arb/                             # Flutter gen-l10n ARB templates (app_en.arb)
│   ├── generated/                       # Generated AppLocalizations classes
│   ├── l10n.dart                        # context.l10n, locale/RTL & bias label helpers
│   └── model_localizations.dart         # Localized labels for models, enums & notifications
├── models/                              # Mastodon, AI, Bias, Settings, Composer, Update models
├── services/
│   ├── ai/                              # AiModelCatalog, AiPromptBuilder, AiHttpAdapters
│   ├── ai_provider_service.dart         # Multi-provider AI facade (On-Device, Gemini, OpenAI, Claude, LAN)
│   ├── bias_check_service.dart          # 4-component pre-post racial & gender bias analyzer
│   ├── caption_formatter.dart           # Prefix enforcement, preamble cleanup, word-boundary truncation
│   ├── image_upload_optimizer.dart      # Client-side image resize & EXIF-stripping upload prep
│   ├── link_preview_fetcher.dart        # External link metadata & excerpt fetcher for bias review
│   ├── local_bias_heuristics.dart       # Deterministic offline inclusive-language checker
│   ├── mastodon_service.dart            # Mastodon REST, OAuth 2.0 & translation client
│   ├── media_cache_service.dart         # Bounded on-disk cache for timeline images
│   ├── on_device_ai_service.dart        # Apple Foundation Models & Gemini Nano (ML Kit GenAI / AICore)
│   ├── storage_service.dart             # Keychain/Keystore/libsecret secrets & SharedPreferences storage
│   ├── translation_service.dart         # Multi-backend on-device, AI provider & Mastodon translation
│   ├── tts_service.dart                 # Cross-platform TTS (AVSpeech, Android TTS, SAPI, spd-say/espeak)
│   ├── update_check_service.dart        # GitHub release & VERSION checker
│   ├── video_frame_extractor.dart       # Evenly spaced video keyframe extraction
│   └── windows_tls_trust.dart           # Windows Certificate Store / CryptoAPI SSL chain bridge
├── state/
│   ├── app_controller.dart              # Top-level auth, settings, models & update coordinator
│   ├── composer_controller.dart         # Post/reply/edit composer state & pre-post workflow
│   ├── quote_cache_controller.dart      # Scoped bounded LRU cache for resolved RE: quoted posts
│   ├── timeline_cache_controller.dart   # Scoped cache for timelines, notifications & offline search
│   └── timeline_media_ai_controller.dart# Scoped bounded cache for on-demand timeline media captions
└── ui/
    ├── helpers/                         # StatusActionHandler & KeyboardNavHelper / ShortcutsDialog
    ├── screens/                         # Login, AiSetup, HomeShell, Timeline, Notifications, Profile,
    │                                    # Thread, Composer, Settings, LocalSearch, ImageViewer, VideoPlayer
    └── widgets/                         # StatusCard, QuotedStatusCard, StatusAuthorHeader,
                                         # MediaAttachmentCard, PostTranslationBanner, LinkifiedText,
                                         # AiProviderConfigSection, OnDeviceAiStatusCard,
                                         # ComposerAttachmentTile, BiasReviewSheet, MissingAltTextDialog,
                                         # UpdateBanner, AccessibleAvatar, AccessibleTip, DiskCachedNetworkImage
test/                                    # Unit & widget tests across models, services, controllers & UI
```
