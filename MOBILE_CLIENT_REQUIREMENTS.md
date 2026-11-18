# Mobile Mastodon Client Requirements Specification (iOS & Android)

This document specifies the functional, accessibility, AI, and UX requirements for building the mobile version (**iPhone / iOS** and **Android**) of **FediCaption**, an accessible Mastodon client with automatic AI alt-text generation and pre-post racial and gender bias checking.

Another project or coding agent can use this specification directly as its starting blueprint.

---

## 1. Project Identity, Attribution & Repository Metadata

- **Target Platforms**: iOS (iPhone) and Android (e.g., via React Native / Expo, Flutter, Kotlin Multiplatform, or native SwiftUI + Jetpack Compose).
- **Contributor Attribution**: All project metadata, package manifests, license headers, and Git commits should list GitHub username **`brokengoose`** (`brokengoose <brokengoose@users.noreply.github.com>`) as the contributor.
- **README Attribution**: The `README.md` file should explicitly mention that the project was generated with **Antigravity**.
- **OAuth Application Website**: When registering the OAuth 2.0 application with a Mastodon instance (`POST /api/v1/apps`), the `website` field **must** point to the project's GitHub repository page (e.g., `https://github.com/brokengoose/<repo-name>`) rather than `https://joinmastodon.org`.

---

## 2. Core Feature: AI-Powered Image & Video Alt-Text Generation

When a user attaches an image or video to a post (from their mobile camera, photo library, or file picker), the client must automatically scan the media with AI and populate the alt-text field with a description helpful for blind and low-vision users.

### 2.1 Required Caption Format & Prefix
- **Mandatory Prefix**: Every AI-generated caption **must** begin with the exact prefix:
  ```text
  AI generated description: 
  ```
- **Output Cleaning**: Strip surrounding quotation marks, redundant preambles (such as `"Image of"`, `"Photo of"`, `"Video of"`, `"Alt text:"`, or `"Description:"`), and any duplicate `"AI generated description:"` or `"Automatically generated description:"` prefixes before prepending `"AI generated description: "`.
- **Length Enforcement**: Truncate cleanly on a word boundary with an ellipsis (`…`) if the description exceeds the Mastodon server's alt-text character limit (default `1500` characters, or the server-queried `description_limit`).

### 2.2 Image & Video Analysis
- **Images**: Send the attached image (resized/compressed if needed for mobile bandwidth) to the active AI vision model.
- **Videos**:
  - Extract a configurable number of evenly spaced keyframes from the video (options: `3`, `4` [default], or `6` keyframes) to send to vision models.
  - For providers that natively support inline video (such as Google Gemini), support sending the video clip directly when within payload limits, falling back to extracted keyframes for larger videos or frame-based providers.
- **Accessibility Prompting**:
  - Prompt the AI to write for blind and low-vision screen-reader users: describe the primary subject, action, setting, emotional tone, important visual details, and transcribe any visible text (signs, screenshots, memes, captions) verbatim.
  - For videos, synthesize the sequence of keyframes into a cohesive description of the motion, narrative progression, and scene changes rather than listing frames one by one.

### 2.3 Caption Controls & Detail Levels
- **Detail Levels**:
  - `concise`: 1–2 sentences (150–300 characters)
  - `descriptive` (Default): 2–4 sentences (300–700 characters)
  - `detailed`: Comprehensive description (600–1200 characters) including layout, lighting, colors, and full text transcription
- **Per-Attachment Controls**:
  - Editable alt-text text area with live character counter (`current / max chars`).
  - Status badge (`AI Scanning...`, `Alt-Text Ready`, `Missing Alt-Text`, or `Error`).
  - **Re-Scan with AI** button and per-attachment detail-level selector.
  - **Read Aloud (TTS)** button to preview how the alt-text sounds via native iOS/Android text-to-speech.
  - **Remove** attachment button.
- **Additional AI Captioning Settings**:
  - Toggle to automatically scan media immediately upon attachment (`auto_generate`, default `true`).
  - Toggle to pass the draft post text to the AI for better subject/name context (`include_post_context`, default `true`).
  - Configurable output language (`language`, default `"English"`).
  - Optional custom instructions field (`custom_instructions`, e.g., recurring pet names or style preferences).

### 2.4 On-Demand AI Descriptions in Timelines
- On timeline posts that contain media attachments:
  - Display whether author alt-text is present (`ALT TEXT PROVIDED` vs. `NO ALT TEXT`) and show the alt-text in an accessible, expandable/readable box.
  - Provide a **Describe with AI** (or **Re-Describe with AI**) button on timeline media so blind users can generate an AI description on the fly for posts whose authors forgot to include alt-text.
  - Provide a **Read Aloud** button to speak the alt-text using device TTS.

---

## 3. AI Providers & Dynamic Model Drop-Down Selection

### 3.1 Supported AI Providers
Support both remote cloud APIs (via API key) and local/self-hosted vision servers (over LAN or tunnel):
1. **Google Gemini API** (`gemini`): Native image and inline video support (`https://generativelanguage.googleapis.com/v1beta`).
2. **OpenAI / OpenAI-Compatible API** (`openai`): Works with OpenAI (`https://api.openai.com/v1`) as well as self-hosted LM Studio, vLLM, llama.cpp, or OpenRouter endpoints.
3. **Anthropic Claude API** (`anthropic`): Claude vision models (`https://api.anthropic.com/v1/messages`).
4. **Local** (`local`): On-device AI, if it's capable of analyzing images.

### 3.2 Dynamic Model Drop-Down List in Settings
- In the **Settings & API Keys** section, the model name field for each provider **must be a drop-down picker/select list** rather than a plain text input field.
- Whenever possible (when opening Settings, switching providers, updating an API key or server URL, or tapping **Refresh Models**), query the provider for its list of available models:
  - **Gemini**: `GET https://generativelanguage.googleapis.com/v1beta/models?key={api_key}` (filter to generative models supporting `generateContent`).
  - **OpenAI / Compatible**: `GET {base_url}/models` (filter out non-chat/utility models like Whisper, TTS, and embeddings on `api.openai.com`; prioritize vision-capable models).
  - **Anthropic**: `GET https://api.anthropic.com/v1/models` (with `x-api-key` and `anthropic-version: 2023-06-01` headers).
  - **Local** as appropriate
- If the provider cannot be reached yet (e.g., before an API key is entered or when offline), populate the drop-down with sensible default vision models so the user can always select a model.

---

## 4. Pre-Post Racial & Gender Bias Checking

Before publishing a post (or saving an edited post), the client must check the post and its associated context for explicit or implicit **racial or gender bias**.

### 4.1 Components Checked
The pre-post bias check must inspect all of the following:
1. **Post Contents**: The main post text and any Content Warning / Spoiler text (`spoiler_text`).
2. **Attachments**: Both the visual media (attached images or video keyframes) and their alt-text descriptions.
3. **Links**: Extract any `http://` or `https://` URLs from the post text, fetch the linked page's title, meta description, and text excerpt, and check the linked content for racial or gender bias.
4. **Referenced Messages**: Any message being replied to (`in_reply_to_id` parent status) or any Mastodon post referenced/linked in the draft (including its author, content warning, text, and media alt-text).

### 4.2 Publishing Flow & User Summary
- **If NO bias is detected**:
  - **Publish immediately** without stopping or showing a confirmation dialog to the user.
- **If bias IS detected**:
  - Pause publishing and present a **Pre-Post Racial & Gender Bias Review** sheet/modal with:
    1. A **brief summary** of what was checked and what was found.
    2. **Where the bias was found**: List each finding with its specific location (`Post Text`, `Content Warning`, `Attachment 1`, `Link (https://...)`, or `Referenced Message (@user)`), the bias type (`Implicit Racial Bias`, `Implicit Gender Bias`, etc.), and a concise explanation.
    3. **Suggested Alternate Wording**: If the main text of the post is biased, display suggested alternate wording that is less biased and more inclusive, along with one-tap buttons to:
       - **Use Suggested Wording in Composer** (replaces composer text for further editing)
       - **Use Suggested Wording & Publish Now**
- **Fallback**: Include a deterministic local heuristic check for common gender-exclusive and racially loaded terms (e.g., `mankind` → `humanity`, `manpower` → `workforce`, `chairman` → `chairperson`, `policeman` → `police officer`, `fireman` → `firefighter`, `hey guys` → `everyone`, `husbands and wives` → `spouses and partners`, `whitelist/blacklist` → `allowlist/blocklist`, `master/slave` → `primary/replica`, `grandfathered` → `legacy-exempted`) so bias detection still functions if the AI endpoint is offline.

---

## 5. Accessibility Rules & Bias Rules in Settings

Settings must include two parallel policy sections:

### 5.1 Accessibility Rules
- **Pre-Post Alt-Text Policy**:
  - `warn` (**Default**): Warn before posting uncaptioned media, with buttons to auto-generate missing alt-text with AI or "Post Anyway".
  - `require`: Strictly require alt-text on all attached media before posting (blocks posting until alt-text is provided).
  - `off`: Do not warn about missing alt-text.

### 5.2 Bias Rules
- **Pre-Post Bias Policy**:
  - `warn` (**Default**): Warn about racial or gender bias before posting; allow the user to edit, apply suggested wording, or "Publish Anyway".
  - `require`: Require posts with detected bias to be corrected before posting (hides "Publish Anyway" until the bias is resolved).
  - `off`: Do not warn at all (skips the pre-post bias check and posts immediately).

---

## 6. Mastodon Protocol, Timelines & Social Features

### 6.1 Authentication
- Support **OAuth 2.0** authorization (`POST /api/v1/apps`, `/oauth/authorize`, `POST /oauth/token`) using deep links / custom URL schemes or an in-app browser session (`ASWebAuthenticationSession` on iOS / Custom Tabs on Android), plus a manual **Direct Access Token** fallback.
- Persist credentials securely on-device (iOS Keychain / Android EncryptedSharedPreferences or Keystore).

### 6.2 Dynamic Instance Character & Media Limits
- Query the connected Mastodon server's instance metadata (`GET /api/v2/instance` with fallback to `GET /api/v1/instance`).
- Extract and enforce the server's actual limits instead of assuming a hardcoded 500-character limit:
  - **Maximum post length**: Check `configuration.statuses.max_characters`, falling back to `max_toot_chars` or `max_characters` (for Glitch-soc, Hometown, Pleroma, Akkoma), and finally `500` if unspecified.
  - **Maximum media attachments**: Check `configuration.statuses.max_media_attachments` (default `4`).
  - **Alt-text character limit**: Check `configuration.media_attachments.description_limit` (default `1500`).
- Include both the post body and any Content Warning (`spoiler_text`) in the live remaining-character counter.

### 6.3 Timelines & Navigation
- Support switching between:
  - **Home Timeline** (`GET /api/v1/timelines/home`)
  - **Local Timeline** (`GET /api/v1/timelines/public?local=true`)
  - **Federated Timeline** (`GET /api/v1/timelines/public`)
  - **Notifications** (`GET /api/v1/notifications`)
  - **Bookmarks** (`GET /api/v1/bookmarks`)
  - **Favorites** (`GET /api/v1/favourites`)
  - **My Published Posts** (`GET /api/v1/accounts/{my_id}/statuses`)

### 6.4 Clickable User Profiles & Subscribe Option
- **Viewing Another User's Personal Posts**:
  - Tapping on any user's avatar, display name, or handle on a post (including boost banners and notifications) navigates to that user's personal posts timeline (`GET /api/v1/accounts/{id}/statuses`).
  - Fetch the user's profile (`GET /api/v1/accounts/{id}`) and relationship (`GET /api/v1/accounts/relationships?id[]={id}`).
  - Display a prominent **Subscribe / Unsubscribe** (`Follow` / `Unfollow` via `POST /api/v1/accounts/{id}/follow` and `unfollow`) button and a **Notifications bell toggle** (`notify: true/false`) near the top of the timeline/page.
- **Viewing Own Posts from Logged-In Profile Header**:
  - The logged-in user's profile picture and username/handle must be displayed in the upper-left / top profile area.
  - Tapping the logged-in user's profile picture or username immediately displays the user's own published posts.

### 6.5 Post Interactions, Permalink Timestamp & Editing Own Posts
- **Timestamp Link to Original Post**:
  - Each post in the timeline displays its relative timestamp in the upper-right corner.
  - That timestamp **must be a clickable link** to the original post on its Mastodon server (`status.url` or `status.uri`) that opens in a new browser tab / external browser.
- **Standard Post Actions**:
  - Reply, Boost / Unboost, Favorite / Unfavorite, Bookmark / Unbookmark, View Conversation Thread (`GET /api/v1/statuses/{id}/context`), and Delete own post (`DELETE /api/v1/statuses/{id}`).
- **Edit Button on Own Posts**:
  - Display an **Edit** button on all posts authored by the logged-in user.
  - Tapping **Edit** fetches the post's raw source text and content warning (`GET /api/v1/statuses/{id}/source`), loads the text, content warning, language, and existing media attachments (including their current alt-text) into the composer, and allows the user to edit the text, edit or re-scan media alt-text with AI, and save changes via `PUT /api/v1/statuses/{id}` (passing `media_attributes` with `{ id, description }` so updated alt-text is saved on Mastodon).

---

## 7. Theme Detection & Mobile Accessibility UX

### 7.1 Themes & Automatic System Mode Detection
- Provide three theme choices:
  1. **Dark Theme**
  2. **Light Theme**
  3. **High Contrast (WCAG AAA)**
- **System Mode Default**:
  - If the user has not explicitly chosen a theme, automatically detect which appearance mode the mobile operating system is using (Dark Mode, Light Mode, or High Contrast / Increased Contrast accessibility setting) and default to that.
  - Listen for live OS appearance changes and update the theme automatically unless the user has explicitly selected a theme override.

### 7.2 Screen Reader & Motor Accessibility
- Full compatibility with **iOS VoiceOver** and **Android TalkBack**:
  - Announce asynchronous events (AI caption generation progress/completion, bias check alerts, timeline loads, post published confirmations) via accessibility live regions / announcements.
  - Provide explicit accessibility labels and states (`selected`, `checked`, `busy`, `expanded`) on all interactive controls.
  - Ensure all touch targets meet minimum accessible sizes (at least `44×44 pt` on iOS / `48×48 dp` on Android).

---

## 8. GitHub Version Check & Update Notification

- Store the client's semantic version string (e.g., `1.0.0`).
- On startup, check the client's version number against the project's GitHub repository (`https://api.github.com/repos/brokengoose/<repo-name>/releases/latest` and/or the version file on the `main` branch).
- If a newer version is available on GitHub (`latest_version > current_version`), display a prominent, dismissible **"Update Available"** notification banner on the main screen of the client with a link to view/download the update on GitHub.
