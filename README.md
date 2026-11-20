# FediCaption Mobile (iOS & Android)

**FediCaption Mobile** is an accessible, cross-platform Flutter Mastodon client for **iOS (iPhone)** and **Android**, featuring built-in **on-device AI** (Apple Foundation Models & Google Gemini Nano), automatic AI alt-text generation for images and videos, on-demand timeline media descriptions, embedded quoted Mastodon posts, and pre-post racial & gender bias checking.

> This project was generated with **Antigravity**.  
> Contributor: **brokengoose** (`brokengoose@users.noreply.github.com`)  
> License: [MIT](LICENSE)

---

## Key Features

### 1. Automatic AI Image & Video Alt-Text Generation
- Automatically scans images and videos upon attachment (from camera, photo library, or file picker) with configurable detail levels (`Concise`, `Descriptive`, `Detailed`), output language, draft-context sharing, and custom instructions.
- Enforces the exact prefix **`AI generated description: `**, strips redundant preambles and surrounding quotes, and truncates cleanly on word boundaries to match the Mastodon server's `description_limit`.
- **Video support**: Sends clips directly inline to Google Gemini when within payload limits, or extracts `3`, `4` (default), or `6` evenly spaced keyframes for frame-based and on-device vision models or larger videos.
- Per-attachment editable alt-text box with live character counter, status badge (`AI Scanning...`, `Alt-Text Ready`, `Missing Alt-Text`, `Error`), **Re-Scan with AI**, per-attachment detail level, built-in **Read Aloud (TTS)**, and **Remove**.
- **On-Demand Timeline Descriptions**: Clearly displays `ALT TEXT PROVIDED` vs `NO ALT TEXT` on timeline and quoted posts, with **Describe with AI** / **Re-Describe with AI** and **Read Aloud** buttons.

### 2. Built-In On-Device AI, Multi-Provider Cloud/LAN AI, & First-Time Setup Wizard
- Guided first-time **AI Setup Wizard** shown right after signing in to Mastodon, supporting:
  - **On-Device AI** *(default, zero network calls)* via `edge_gen_ai`:
    - **iPhone (iOS 26+/27+)**: Apple Foundation Models (Apple Intelligence)
    - **Android (Pixel 8+ & supported Samsung flagships)**: Google Gemini Nano via ML Kit GenAI & Android AICore (with release R8 ProGuard keep rules and one-tap model provisioning)
  - **Google Gemini API** (native image & inline video)
  - **OpenAI / OpenAI-Compatible API** (OpenAI, OpenRouter, LM Studio, vLLM, llama.cpp)
  - **Anthropic Claude API**
  - **Local Network Server** (Ollama `/api/tags` + `/api/chat` & LM Studio `/v1` on LAN)
  - **No AI** (manual alt-text, built-in Read Aloud, and deterministic offline bias heuristics)
- **Alphabetically sorted (A–Z) dynamic model drop-down picker** in both onboarding and Settings that queries the selected provider's live models endpoint, falling back cleanly to curated vision models when offline.

### 3. Pre-Post Racial & Gender Bias Checking
- Inspects **Post Text & Content Warning**, **Attachments (visual media + alt-text)**, **External Links** (fetches page title, meta description, and text excerpt), and **Referenced / Replied-to Mastodon Messages**.
- **Silent pass when clean**: Publishes immediately if no bias is detected.
- **Actionable review sheet when bias is found**: Displays a summary, exact location and bias type of each finding, and suggested inclusive alternate wording with one-tap **Use Suggested Wording in Composer** and **Use Suggested Wording & Publish Now** buttons.
- Includes a deterministic offline local heuristic checker as both an offline fallback and safety backstop.

### 4. Parallel Accessibility Rules & Bias Rules
- **Built-In On-Device Read Aloud Speed**: Configurable TTS speech-rate slider (`AVSpeechSynthesizer` on iOS, system `TextToSpeech` on Android).
- **Accessibility Rules** (`warn` [default] / `require` / `off`): Warns or requires alt-text on attached media before posting, with one-tap **Auto-Generate Missing Alt-Text with AI**.
- **Bias Rules** (`warn` [default] / `require` / `off`): Warns, enforces revision (hiding *Publish Anyway*), or disables pre-post bias checking.

### 5. Full Mastodon Client, Embedded Quotes, Clickable Links & Accessibility
- **OAuth 2.0** (`ASWebAuthenticationSession` on iOS / Custom Tabs on Android via `fedicaption://oauth-callback`, registering `https://github.com/brokengoose/FediCaptionMobile` as the OAuth app website) + **Direct Access Token** fallback, persisted in iOS Keychain / Android Keystore.
- **Dynamic Instance Limits**: Queries `/api/v2/instance` (with `/api/v1/instance` fallback) for actual server character limits (including Glitch-soc, Hometown, Pleroma, Akkoma), media limits, and alt-text limits. Counts both post body and Content Warning.
- **Timelines & Pagination**: Home, Local, Federated, Notifications, Bookmarks, Favorites, My Published Posts, and User Profiles with pull-to-refresh and infinite-scroll pagination.
- **Clickable Links, Mentions & Hashtags**: Renders Mastodon shortened HTML links, bare URLs, hashtags, and `@mentions` (navigating directly to user profiles) across posts, bios, notifications, and alt-text.
- **Embedded Quoted Posts**: Detects Mastodon posts starting with `RE: <url>` (and native `quote.quoted_status` payloads), strips the redundant prefix, resolves and caches the original post, and embeds it as an interactive **Quoted Post** window above the reply text (complete with clickable author, thread navigation, media alt-text, AI Describe, Read Aloud, and Retry on failure).
- **Clickable Profiles & Subscriptions**: Tap any avatar, display name, or handle to view their personal posts with prominent **Subscribe / Unsubscribe** and **Notifications bell** (`notify: true/false`) controls. Tap your own upper-left profile header to jump directly to your published posts.
- **Post Actions**: Clickable upper-right relative timestamp linking to the original post on its Mastodon server, Reply, Boost, Favorite, Bookmark, Thread View, Delete (with confirmation everywhere), and **Edit Own Posts** (including updating media alt-text via `PUT /api/v1/statuses/{id}` `media_attributes`).
- **Themes & Screen Readers**: Dark, Light, and **WCAG AAA High Contrast** themes with automatic live OS appearance & high-contrast detection, full VoiceOver/TalkBack live announcements, and `>= 48×48 dp` touch targets.
- **GitHub Version Check**: Checks GitHub Releases (and `main/VERSION` fallback) on startup and displays a dismissible **Update Available** banner when a newer version is published.

---

## Getting Started (Local Xcode & Android Studio)

### Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (`>= 3.50`, Dart `>= 3.14`, `material_ui`)
- **iOS**: macOS with Xcode & CocoaPods (`brew install cocoapods`), configured for the iOS `UIScene` lifecycle (`SceneDelegate.swift` + `UIApplicationSceneManifest`)
- **Android**: Android Studio with Android SDK (**minSdk 26+** for ML Kit GenAI / AICore on-device AI)

### Setup & Run
1. Install dependencies:
   ```bash
   flutter pub get
   ```
2. Run static analysis and tests:
   ```bash
   flutter analyze
   flutter test
   ```
3. Launch on iOS Simulator, Android Emulator, or a connected physical phone:
   ```bash
   flutter run
   ```
   *(On macOS Android Emulator, launch the AVD with `-audio coreaudio` for host TTS audio playback.)*
4. Build a release Android APK (includes R8 keep rules for ML Kit GenAI / AICore in `android/app/proguard-rules.pro`):
   ```bash
   flutter build apk --release
   ```

---

## Project Structure

```text
lib/
├── core/
│   ├── accessibility_announcer.dart     # VoiceOver & TalkBack live announcements
│   ├── constants.dart                   # App metadata, OAuth website, limits, prefix
│   ├── html_utils.dart                  # HTML-to-text, URL/punctuation parsing, RE: quote extraction
│   ├── media_utils.dart                 # Shared video extension & MIME type helpers
│   ├── time_utils.dart                  # Relative & accessible timestamps
│   └── theme/                           # Dark, Light, WCAG AAA High Contrast + OS auto-detect
├── models/                              # Mastodon, AI, Bias, Settings, Composer, Update models
├── services/
│   ├── ai/                              # AiModelCatalog, AiPromptBuilder, AiHttpAdapters
│   ├── ai_provider_service.dart         # Multi-provider AI facade (On-Device, Gemini, OpenAI, Claude, LAN)
│   ├── on_device_ai_service.dart        # Apple Foundation Models & Gemini Nano (ML Kit GenAI / AICore)
│   ├── bias_check_service.dart          # 4-component pre-post racial & gender bias analyzer
│   ├── local_bias_heuristics.dart       # Deterministic offline inclusive-language checker
│   ├── caption_formatter.dart           # Prefix enforcement, preamble cleanup, word-boundary truncation
│   ├── link_preview_fetcher.dart        # External link metadata & excerpt fetcher for bias review
│   ├── mastodon_service.dart            # Mastodon REST & OAuth 2.0 client
│   ├── storage_service.dart             # Keychain/Keystore secrets & SharedPreferences persistence
│   ├── tts_service.dart                 # Native AVSpeechSynthesizer / Android TTS controller
│   ├── update_check_service.dart        # GitHub release & VERSION checker
│   └── video_frame_extractor.dart       # Evenly spaced video keyframe extraction
├── state/
│   ├── app_controller.dart              # Top-level auth, settings, models & update coordinator
│   ├── composer_controller.dart         # Post/reply/edit composer state & pre-post workflow
│   ├── quote_cache_controller.dart      # Scoped bounded LRU cache for resolved RE: quoted posts
│   └── timeline_media_ai_controller.dart# Scoped bounded cache for on-demand timeline media captions
└── ui/
    ├── helpers/                         # StatusActionHandler (unified actions + delete confirmation)
    ├── screens/                         # Login, AiSetup, HomeShell, Timeline, Notifications, Profile,
    │                                    # Thread, Composer, Settings
    └── widgets/                         # StatusCard, QuotedStatusCard, StatusAuthorHeader,
                                         # MediaAttachmentCard, LinkifiedText, AiProviderConfigSection,
                                         # OnDeviceAiStatusCard, ComposerAttachmentTile,
                                         # BiasReviewSheet, MissingAltTextDialog, UpdateBanner, AccessibleAvatar
test/                                    # Unit & widget tests across models, services, controllers & UI
```
