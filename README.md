# FediCaption Mobile (iOS & Android)

**FediCaption Mobile** is an accessible, cross-platform Flutter Mastodon client for **iOS (iPhone)** and **Android**, featuring automatic AI alt-text generation for images and videos, on-demand timeline media descriptions, and pre-post racial & gender bias checking.

> This project was generated with **Antigravity**.  
> Contributor: **brokengoose** (`brokengoose@users.noreply.github.com`)  
> License: [MIT](LICENSE)

---

## Key Features

### 1. Automatic AI Image & Video Alt-Text Generation
- Automatically scans images and videos upon attachment (from camera, photo library, or file picker) with configurable detail levels (`Concise`, `Descriptive`, `Detailed`), output language, draft-context sharing, and custom instructions.
- Enforces the exact prefix **`AI generated description: `**, strips redundant preambles and surrounding quotes, and truncates cleanly on word boundaries to match the Mastodon server's `description_limit`.
- **Video support**: Sends clips directly inline to Google Gemini when within payload limits, or extracts `3`, `4` (default), or `6` evenly spaced keyframes for frame-based vision models and larger videos.
- Per-attachment editable alt-text box with live character counter, status badge (`AI Scanning...`, `Alt-Text Ready`, `Missing Alt-Text`, `Error`), **Re-Scan with AI**, per-attachment detail level, **Read Aloud (TTS)**, and **Remove**.
- **On-Demand Timeline Descriptions**: Clearly displays `ALT TEXT PROVIDED` vs `NO ALT TEXT` on timeline posts, with **Describe with AI** / **Re-Describe with AI** and **Read Aloud** buttons.

### 2. Multi-Provider AI & Dynamic Model Drop-Downs
- Supports:
  - **Google Gemini API** (native image & inline video)
  - **OpenAI / OpenAI-Compatible API** (OpenAI, OpenRouter, LM Studio, vLLM, llama.cpp)
  - **Anthropic Claude API**
  - **Local AI** (Ollama / LM Studio on LAN + on-device heuristic fallback)
- Dynamic model **drop-down picker** in Settings that queries the selected provider's live models endpoint whenever opening Settings, switching providers, updating API keys/URLs, or tapping **Refresh Models**, falling back cleanly to curated default vision models when offline.

### 3. Pre-Post Racial & Gender Bias Checking
- Inspects **Post Text & Content Warning**, **Attachments (visual media + alt-text)**, **External Links** (fetches page title, meta description, and text excerpt), and **Referenced / Replied-to Mastodon Messages**.
- **Silent pass when clean**: Publishes immediately if no bias is detected.
- **Actionable review sheet when bias is found**: Displays a summary, exact location and bias type of each finding, and suggested inclusive alternate wording with one-tap **Use Suggested Wording in Composer** and **Use Suggested Wording & Publish Now** buttons.
- Includes a deterministic offline local heuristic fallback for common gender-exclusive and racially loaded terms.

### 4. Parallel Accessibility Rules & Bias Rules
- **Accessibility Rules** (`warn` [default] / `require` / `off`): Warns or requires alt-text on attached media before posting, with one-tap **Auto-Generate Missing Alt-Text with AI**.
- **Bias Rules** (`warn` [default] / `require` / `off`): Warns, enforces revision (hiding *Publish Anyway*), or disables pre-post bias checking.

### 5. Full Mastodon Client, Accessibility & Update Checker
- **OAuth 2.0** (`ASWebAuthenticationSession` on iOS / Custom Tabs on Android via `fedicaption://oauth-callback`, registering `https://github.com/brokengoose/FediCaptionMobile` as the OAuth app website) + **Direct Access Token** fallback, persisted in iOS Keychain / Android Keystore.
- **Dynamic Instance Limits**: Queries `/api/v2/instance` (with `/api/v1/instance` fallback) for actual server character limits (including Glitch-soc, Hometown, Pleroma, Akkoma), media limits, and alt-text limits. Counts both post body and Content Warning.
- **Timelines**: Home, Local, Federated, Notifications, Bookmarks, Favorites, and My Published Posts.
- **Clickable Profiles & Subscriptions**: Tap any avatar, display name, or handle to view their personal posts with prominent **Subscribe / Unsubscribe** and **Notifications bell** (`notify: true/false`) controls. Tap your own upper-left profile header to jump directly to your published posts.
- **Post Actions**: Clickable upper-right relative timestamp linking to the original post on its Mastodon server, Reply, Boost, Favorite, Bookmark, Thread View, Delete, and **Edit Own Posts** (including updating media alt-text via `PUT /api/v1/statuses/{id}` `media_attributes`).
- **Themes & Screen Readers**: Dark, Light, and **WCAG AAA High Contrast** themes with automatic live OS appearance & high-contrast detection, full VoiceOver/TalkBack live announcements, and `>= 48×48 dp` touch targets.
- **GitHub Version Check**: Checks GitHub Releases (and `main/VERSION` fallback) on startup and displays a dismissible **Update Available** banner when a newer version is published.

---

## Getting Started (Local Xcode & Android Studio)

### Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (`>= 3.24`, Dart `>= 3.4`)
- **iOS**: macOS with Xcode & CocoaPods (`brew install cocoapods`)
- **Android**: Android Studio with Android SDK (minSdk 23+)

### Setup & Run
1. Generate any missing native Xcode/Gradle wrapper scaffolding (preserves `lib/`, `test/`, `AndroidManifest.xml`, `Info.plist`, and `pubspec.yaml`):
   ```bash
   flutter create . --org io.github.brokengoose --project-name fedicaption_mobile --platforms=ios,android
   ```
   *(If prompted or if `flutter create` overwrites platform manifests, verify `ios/Runner/Info.plist` retains `CFBundleURLTypes` for `fedicaption` and `android/app/src/main/AndroidManifest.xml` retains `com.linusu.flutter_web_auth_2.CallbackActivity` via `git diff`.)*
2. Install dependencies:
   ```bash
   flutter pub get
   ```
3. Run unit tests:
   ```bash
   flutter test
   ```
4. Launch on iOS Simulator or Android Emulator:
   ```bash
   flutter run
   ```

---

## Project Structure

```text
lib/
├── core/
│   ├── constants.dart               # App metadata, OAuth website, limits, prefix
│   ├── accessibility_announcer.dart # VoiceOver & TalkBack announcements
│   ├── html_utils.dart              # HTML-to-text & URL/Fediverse link extraction
│   ├── time_utils.dart              # Relative & accessible timestamps
│   └── theme/                       # Dark, Light, WCAG AAA High Contrast + OS auto-detect
├── models/                          # Mastodon, AI, Bias, Settings, Composer, Update models
├── services/                        # Mastodon API, AI providers, CaptionFormatter, VideoFrameExtractor,
│                                    # LocalBiasHeuristics, LinkPreviewFetcher, BiasCheckService, TTS, UpdateCheck
├── state/                           # AppController & ComposerController
└── ui/
    ├── screens/                     # Login, HomeShell, Timeline, Notifications, Profile, Thread, Composer, Settings
    └── widgets/                     # StatusCard, MediaAttachmentCard, ComposerAttachmentTile,
                                     # BiasReviewSheet, MissingAltTextDialog, UpdateBanner, AccessibleAvatar
test/                                # Unit tests for formatting, bias heuristics, AI providers, Mastodon API & updates
```
