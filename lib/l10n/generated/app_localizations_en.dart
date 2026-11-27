// Copyright (c) 2026 brokengoose <brokengoose@users.noreply.github.com>
// SPDX-License-Identifier: MIT

// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appLoadingLabel => 'Loading FediCaption';

  @override
  String get appIconSemanticLabel => 'FediCaption app icon';

  @override
  String get commonRetry => 'Retry';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonClose => 'Close';

  @override
  String get commonDelete => 'Delete';

  @override
  String get commonDownload => 'Download';

  @override
  String get commonShow => 'Show';

  @override
  String get commonHide => 'Hide';

  @override
  String get commonShowMore => 'Show More';

  @override
  String get commonUserFallback => 'user';

  @override
  String get loginSettingsTooltip => 'Settings and Appearance';

  @override
  String get loginElephantSemanticLabel =>
      'FediCaption cartoon elephant wearing dark sunglasses';

  @override
  String get loginWelcomeTitle => 'Welcome to FediCaption';

  @override
  String get loginTagline =>
      'An accessible Mastodon client with automatic AI alt-text generation and pre-post racial & gender bias checking.';

  @override
  String get loginExistingAccountWarningTitle =>
      'Existing Mastodon Account Required';

  @override
  String get loginExistingAccountWarningBody =>
      'Signing in through FediCaption will not create a new account. You must already have an account on a Mastodon server. If you don\'t have one yet, you can create an account on your chosen Mastodon server\'s website.';

  @override
  String get loginServerDomainLabel => 'Mastodon Server Domain';

  @override
  String get loginServerDomainHint => 'mastodon.social';

  @override
  String get loginServerDomainHelper =>
      'Enter your Mastodon, Glitch-soc, Hometown, Pleroma, or Akkoma server.';

  @override
  String get loginSigningIn => 'Signing in…';

  @override
  String get loginSignInOAuth => 'Sign in with Mastodon (OAuth 2.0)';

  @override
  String get loginTokenFallbackTitle => 'Direct Access Token Fallback';

  @override
  String get loginTokenFallbackSubtitle =>
      'Sign in with a personal access token from your Mastodon Development settings.';

  @override
  String get loginTokenLabel => 'Access Token';

  @override
  String get loginTokenHint => 'Paste Mastodon access token';

  @override
  String get loginShowToken => 'Show token';

  @override
  String get loginHideToken => 'Hide token';

  @override
  String get loginSignInToken => 'Sign in with Access Token';

  @override
  String get oauthLandingTitle => 'FediCaption Sign-In Complete';

  @override
  String get oauthLandingHeading => 'Signed in to FediCaption';

  @override
  String get oauthLandingBody =>
      'Authorization succeeded. You can close this browser tab and return to FediCaption.';

  @override
  String get authErrorInvalidInstance =>
      'Please enter a valid Mastodon server domain (e.g. mastodon.social).';

  @override
  String get authErrorCancelled => 'Authorization was cancelled.';

  @override
  String get authErrorMissingInstanceAndToken =>
      'Both server URL and access token are required.';

  @override
  String authErrorExpiredSession(String error) {
    return 'Saved session expired or server unreachable: $error';
  }

  @override
  String authAnnounceSignedIn(String displayName, String instanceUrl) {
    return 'Signed in as $displayName on $instanceUrl.';
  }

  @override
  String get authAnnounceSignedOut => 'Signed out of Mastodon.';

  @override
  String get aiSetupTitle => 'Set Up AI';

  @override
  String get aiSetupHeading => 'Configure AI Captioning & Bias Checking';

  @override
  String aiSetupIntroWithHandle(String handle) {
    return 'Signed in as $handle. Choose an AI provider to automatically generate accessible alt-text and check posts for racial or gender bias — or choose No AI to enter alt-text manually.';
  }

  @override
  String get aiSetupIntroWithoutHandle =>
      'Choose an AI provider to automatically generate accessible alt-text and check posts for racial or gender bias — or choose No AI to enter alt-text manually.';

  @override
  String get aiSetupDetectingOnDevice => 'Checking on-device AI availability…';

  @override
  String get aiSetupProviderLabel => 'AI Provider';

  @override
  String get aiSetupModelHelper =>
      'Sorted alphabetically. Tap Refresh after entering your key or URL.';

  @override
  String get aiSetupNoAiDefaultNotice =>
      'On-device AI is not available on this device, so No AI is selected by default. You can choose a Cloud API or Local AI server above, or continue with No AI (manual alt-text, Read Aloud, and offline bias heuristics) and enable AI later in Settings.';

  @override
  String get aiSetupNoAiSelectedNotice =>
      'FediCaption will not contact any AI service. You can still write alt-text manually, listen with Read Aloud, and use offline local bias heuristics. You can enable an AI provider later in Settings.';

  @override
  String get aiSetupContinueNoAi => 'Continue with No AI';

  @override
  String get aiSetupSaveAndContinue => 'Save AI Settings & Continue';

  @override
  String get aiSetupUseNoAiLater => 'Use No AI (Set Up Later)';

  @override
  String aiSetupAnnounceCompleteWithAi(String providerName) {
    return 'AI setup complete using $providerName.';
  }

  @override
  String get aiSetupAnnounceCompleteNoAi =>
      'Setup complete with No AI selected. Manual alt-text and offline bias heuristics are active.';

  @override
  String get aiConfigActiveProviderLabel => 'Active AI Provider';

  @override
  String get aiConfigModelHelper =>
      'Sorted alphabetically. Select a vision-capable model.';

  @override
  String get aiConfigNoAiNotice =>
      'AI is disabled (\"No AI\"). Alt-text can be entered manually, Read Aloud remains available, and pre-post bias checks use offline local heuristics.';

  @override
  String get aiConfigGeminiApiKeyLabel => 'Google Gemini API Key';

  @override
  String get aiConfigGeminiApiKeyHint => 'AIza…';

  @override
  String get aiConfigOpenAiBaseUrlLabel => 'OpenAI-Compatible Base URL';

  @override
  String get aiConfigOpenAiBaseUrlHelper =>
      'Supports OpenAI, OpenRouter, LM Studio, vLLM, or llama.cpp.';

  @override
  String get aiConfigOpenAiApiKeyLabel =>
      'API Key (Optional for local servers)';

  @override
  String get aiConfigOpenAiApiKeyHint => 'sk-…';

  @override
  String get aiConfigAnthropicApiKeyLabel => 'Anthropic API Key';

  @override
  String get aiConfigAnthropicApiKeyHint => 'sk-ant-…';

  @override
  String get aiConfigLocalBaseUrlLabel =>
      'Local AI Server URL (Ollama / LM Studio LAN)';

  @override
  String aiConfigLocalBaseUrlHelper(String defaultUrl) {
    return 'Default: $defaultUrl. Use your computer\'s LAN IP for Ollama (port 11434/v1) or LM Studio (port 1234/v1).';
  }

  @override
  String get aiConfigLocalApiKeyLabel => 'Optional LAN Server Token / Key';

  @override
  String get aiConfigLocalApiKeyHint => 'Leave blank if not required';

  @override
  String get aiConfigNoAiSelectedTitle => 'No AI Selected';

  @override
  String get aiConfigModelDropdownLabel => 'AI Model (A–Z)';

  @override
  String get aiConfigFetchingModelsHelper =>
      'Fetching available models from provider…';

  @override
  String get aiConfigRefreshModelsTooltip => 'Refresh Models';

  @override
  String get aiConfigShowApiKey => 'Show API key';

  @override
  String get aiConfigHideApiKey => 'Hide API key';

  @override
  String onDeviceAiStatusHeader(String engineName, String badge) {
    return '$engineName — $badge';
  }

  @override
  String get onDeviceAiBadgeReady => 'Ready on Device';

  @override
  String get onDeviceAiBadgeDownloadable => 'Model Downloadable';

  @override
  String get onDeviceAiBadgeNotYetReady => 'Enable in System Settings';

  @override
  String get onDeviceAiBadgeUnavailable => 'Unavailable on This Device';

  @override
  String get onDeviceAiDownloadingModelButton => 'Downloading Model…';

  @override
  String get onDeviceAiDownloadModelButton => 'Download On-Device Model';

  @override
  String get onDeviceAiCheckingButton => 'Checking…';

  @override
  String get onDeviceAiRecheckButton => 'Re-Check Device';

  @override
  String get onDeviceAiAnnounceDownloading => 'Downloading on-device AI model.';

  @override
  String get onDeviceAiAnnounceDownloadFailed =>
      'Failed to download on-device AI model.';

  @override
  String get onDeviceAiEngineWeb => 'Web (no OS on-device model)';

  @override
  String get onDeviceAiEngineApple => 'Apple Foundation Models';

  @override
  String get onDeviceAiEngineGeminiNano =>
      'Google Gemini Nano (ML Kit GenAI / AICore)';

  @override
  String get onDeviceAiEngineGeneric => 'On-Device AI';

  @override
  String onDeviceAiSummaryReadyBoth(String engineName) {
    return 'Ready on this device ($engineName) — supports on-device image captioning and bias checking with zero network calls.';
  }

  @override
  String onDeviceAiSummaryReadyDescriberOnly(String engineName) {
    return 'On-device image description ready ($engineName). Bias checking will use offline heuristics.';
  }

  @override
  String onDeviceAiSummaryReadyPromptOnly(String engineName) {
    return 'On-device text & multimodal prompting ready ($engineName).';
  }

  @override
  String onDeviceAiSummaryDownloadable(String engineName) {
    return 'Supported on this device ($engineName). Tap \"Download On-Device Model\" to provision the OS-managed model.';
  }

  @override
  String onDeviceAiSummaryNotYetReady(String engineName) {
    return 'Supported on this device ($engineName), but not yet enabled. Turn on Apple Intelligence / device AI in system Settings.';
  }

  @override
  String onDeviceAiSummaryUnavailable(String engineName) {
    return 'Not available on this device or simulator ($engineName requires supported iPhone/Pixel/Samsung flagship hardware). You can use a Cloud API, Local LAN server, or No AI.';
  }

  @override
  String onDeviceAiDiagnosticDetail(
    String promptAvailability,
    String promptDiagnostic,
    String imageAvailability,
    String imageDiagnostic,
  ) {
    return 'Prompt API: $promptAvailability$promptDiagnostic\nImage Description API: $imageAvailability$imageDiagnostic';
  }

  @override
  String get aiProviderOnDeviceLabel =>
      'On-Device AI (Apple Intelligence / Gemini Nano)';

  @override
  String get aiProviderGeminiLabel => 'Google Gemini API';

  @override
  String get aiProviderOpenAiLabel => 'OpenAI / Compatible API';

  @override
  String get aiProviderAnthropicLabel => 'Anthropic Claude API';

  @override
  String get aiProviderLocalLabel =>
      'Local Network Server (Ollama / LM Studio LAN)';

  @override
  String get aiProviderNoneLabel =>
      'No AI (Manual Alt-Text & Offline Heuristics)';

  @override
  String get aiModelOnDeviceAuto =>
      'On-Device Auto (Vision Prompt + Image Describer)';

  @override
  String get aiModelOnDeviceDescriber =>
      'On-Device Image Describer (Fast Alt-Text)';

  @override
  String get aiModelOnDevicePrompt =>
      'On-Device Multimodal Prompt (Custom Detail & Bias)';

  @override
  String get detailLevelConciseLabel => 'Concise';

  @override
  String get detailLevelConciseGuidance => '1-2 sentences (150-300 characters)';

  @override
  String get detailLevelDescriptiveLabel => 'Descriptive';

  @override
  String get detailLevelDescriptiveGuidance =>
      '2-4 sentences (300-700 characters)';

  @override
  String get detailLevelDetailedLabel => 'Detailed';

  @override
  String get detailLevelDetailedGuidance =>
      'Comprehensive (600-1200 characters) including layout, lighting, colors, and full text transcription';

  @override
  String get policyModeWarnLabel => 'Warn (Default)';

  @override
  String get policyModeRequireLabel => 'Require';

  @override
  String get policyModeOffLabel => 'Off';

  @override
  String get altPolicyWarnSubtitle =>
      'Warn before posting uncaptioned media, with options to auto-generate with AI or post anyway.';

  @override
  String get altPolicyRequireSubtitle =>
      'Strictly require alt-text on all attached media before posting.';

  @override
  String get altPolicyOffSubtitle => 'Do not warn about missing alt-text.';

  @override
  String get biasPolicyWarnSubtitle =>
      'Warn about racial or gender bias before posting; allow editing, suggested wording, or \"Publish Anyway\".';

  @override
  String get biasPolicyRequireSubtitle =>
      'Require detected racial or gender bias to be resolved before posting (hides \"Publish Anyway\").';

  @override
  String get biasPolicyOffSubtitle =>
      'Skip pre-post racial & gender bias checking and publish immediately.';

  @override
  String get themeSystemLabel => 'System Default (Auto-Detect)';

  @override
  String get themeDarkLabel => 'Dark Theme';

  @override
  String get themeLightLabel => 'Light Theme';

  @override
  String get themeHighContrastLabel => 'High Contrast (WCAG AAA)';

  @override
  String get postVisibilityPublicLabel => 'Public';

  @override
  String get postVisibilityPublicDesc =>
      'Visible to everyone and shown in public timelines';

  @override
  String get postVisibilityUnlistedLabel => 'Unlisted';

  @override
  String get postVisibilityUnlistedDesc =>
      'Visible to everyone, but omitted from public timelines';

  @override
  String get postVisibilityPrivateLabel => 'Followers Only';

  @override
  String get postVisibilityPrivateDesc => 'Visible only to your followers';

  @override
  String get postVisibilityDirectLabel => 'Mentioned Only';

  @override
  String get postVisibilityDirectDesc => 'Visible only to mentioned users';

  @override
  String get attachmentStatusScanning => 'AI Scanning...';

  @override
  String get attachmentStatusReady => 'Alt-Text Ready';

  @override
  String get attachmentStatusMissingAltText => 'Missing Alt-Text';

  @override
  String get attachmentStatusError => 'Error';

  @override
  String get timelineHomeShort => 'Home';

  @override
  String get timelineHomeFull => 'Home Timeline';

  @override
  String get timelineLocalShort => 'Local';

  @override
  String get timelineLocalFull => 'Local Timeline';

  @override
  String get timelineFederatedShort => 'Federated';

  @override
  String get timelineFederatedFull => 'Federated Timeline';

  @override
  String get timelineAlertsShort => 'Alerts';

  @override
  String get timelineNotificationsFull => 'Notifications';

  @override
  String get timelineBookmarksShort => 'Bookmarks';

  @override
  String get timelineFavoritesShort => 'Favorites';

  @override
  String get timelineMyPostsShort => 'My Posts';

  @override
  String get timelineMyPostsFull => 'My Published Posts';

  @override
  String homeAnnounceSwitchedTimeline(String title) {
    return 'Switched to $title.';
  }

  @override
  String homeProfileHeaderSemantics(String displayName, String handle) {
    return '$displayName, $handle. Tap to view your own published posts.';
  }

  @override
  String homeProfileHeaderTip(String handle) {
    return 'View your own published posts as $handle (g u)';
  }

  @override
  String get homeSearchTooltip =>
      'Search cached posts and alt-text offline (/)';

  @override
  String get homeShortcutsTooltip => 'View keyboard navigation shortcuts (?)';

  @override
  String homeSettingsTooltip(String shortcut) {
    return 'Open Settings & AI Configuration ($shortcut)';
  }

  @override
  String get homeDrawerSettings => 'Settings & AI Configuration';

  @override
  String get homeNavHomeTip =>
      'Home timeline — posts from people you follow (g h)';

  @override
  String get homeNavLocalTip =>
      'Local timeline — public posts from your server (g l)';

  @override
  String get homeNavFederatedTip =>
      'Federated timeline — public posts across the Fediverse (g p)';

  @override
  String get homeNavNotificationsTip =>
      'Notifications — replies, mentions, boosts, and follows (g n)';

  @override
  String get homeNavBookmarksTip =>
      'Bookmarks — posts you saved privately (g b)';

  @override
  String get homeNavFavoritesTip => 'Favorites — posts you liked (g f)';

  @override
  String get homeNavMyPostsTip =>
      'My Published Posts — your own Mastodon posts (g u)';

  @override
  String homeComposeTip(String shortcut) {
    return 'Compose a new Mastodon post (n or $shortcut)';
  }

  @override
  String get homeComposeLabel => 'Post';

  @override
  String searchHint(int count) {
    return 'Search $count cached posts & alt-text…';
  }

  @override
  String get searchClearTooltip => 'Clear search';

  @override
  String searchAnnounceResults(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count matching cached posts',
      one: '1 matching cached post',
      zero: 'No matching cached posts',
    );
    return '$_temp0';
  }

  @override
  String searchEmptyTitle(int count) {
    return 'Offline Local Search ($count cached posts)';
  }

  @override
  String get searchEmptyDescription =>
      'Searches post text, Content Warnings, authors, and media alt-text locally on your device without placing any search load on your Mastodon server.';

  @override
  String searchNoResults(String query) {
    return 'No cached posts match \"$query\".';
  }

  @override
  String updateBannerSemantics(String latestVersion, String currentVersion) {
    return 'Update available: FediCaption version $latestVersion. Currently on $currentVersion.';
  }

  @override
  String updateBannerTitle(String latestVersion) {
    return 'Update Available: v$latestVersion';
  }

  @override
  String updateBannerSubtitle(String currentVersion) {
    return 'You are running v$currentVersion. View the latest release on GitHub.';
  }

  @override
  String get updateBannerDismissTooltip => 'Dismiss update notification';

  @override
  String updateAnnounceAvailable(String latestVersion) {
    return 'Update available: FediCaption version $latestVersion is now on GitHub.';
  }

  @override
  String timelineAnnouncePostSelection(
    int index,
    int total,
    String authorName,
    String preview,
  ) {
    return 'Post $index of $total by $authorName. $preview';
  }

  @override
  String timelineAnnounceUpToDate(String title) {
    return '$title is up to date.';
  }

  @override
  String timelineAnnounceLoadedNew(int count, String title) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Loaded $count new posts in $title.',
      one: 'Loaded 1 new post in $title.',
    );
    return '$_temp0';
  }

  @override
  String timelineAnnounceLoadedInitial(String title, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count posts',
      one: '1 post',
    );
    return '$title loaded with $_temp0.';
  }

  @override
  String timelineEmptyMessage(String title) {
    return 'No posts in $title yet.';
  }

  @override
  String get threadTitle => 'Conversation Thread';

  @override
  String threadRepliesHeader(int count) {
    return 'Replies ($count)';
  }

  @override
  String threadAnnounceSelection(int index, int total, String authorName) {
    return 'Post $index of $total by $authorName.';
  }

  @override
  String threadAnnounceLoaded(int ancestorsCount, int repliesCount) {
    String _temp0 = intl.Intl.pluralLogic(
      ancestorsCount,
      locale: localeName,
      other: '$ancestorsCount earlier posts',
      one: '1 earlier post',
    );
    String _temp1 = intl.Intl.pluralLogic(
      repliesCount,
      locale: localeName,
      other: '$repliesCount replies',
      one: '1 reply',
    );
    return 'Conversation loaded with $_temp0 and $_temp1.';
  }

  @override
  String get notificationsEmpty => 'No notifications yet.';

  @override
  String get notificationsMediaPostPlaceholder => '(Media post)';

  @override
  String get notificationsOpenThreadTip =>
      'Open conversation thread for this post (Enter)';

  @override
  String notificationsAnnounceSelection(int index, int total, String summary) {
    return 'Notification $index of $total: $summary.';
  }

  @override
  String get notificationsAnnounceUpToDate => 'Notifications are up to date.';

  @override
  String notificationsAnnounceLoadedNew(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Loaded $count new notifications.',
      one: 'Loaded 1 new notification.',
    );
    return '$_temp0';
  }

  @override
  String notificationsAnnounceLoadedInitial(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Loaded $count notifications.',
      one: 'Loaded 1 notification.',
    );
    return '$_temp0';
  }

  @override
  String notificationMentionSummary(String author) {
    return '$author mentioned you';
  }

  @override
  String notificationReblogSummary(String author) {
    return '$author boosted your post';
  }

  @override
  String notificationFavouriteSummary(String author) {
    return '$author favorited your post';
  }

  @override
  String notificationFollowSummary(String author) {
    return '$author followed you';
  }

  @override
  String notificationFollowRequestSummary(String author) {
    return '$author requested to follow you';
  }

  @override
  String notificationStatusSummary(String author) {
    return '$author published a new post';
  }

  @override
  String notificationUpdateSummary(String author) {
    return '$author edited a post';
  }

  @override
  String notificationPollSummary(String author) {
    return '$author: a poll you participated in has ended';
  }

  @override
  String notificationQuoteSummary(String author) {
    return '$author quoted your post';
  }

  @override
  String notificationQuotedUpdateSummary(String author) {
    return '$author edited a post you quoted';
  }

  @override
  String notificationGenericSummary(String author, String type) {
    return '$author ($type)';
  }

  @override
  String avatarViewProfileSemantics(String displayName) {
    return 'View profile and posts by $displayName';
  }

  @override
  String linkMentionSemantics(String handle) {
    return 'Mention $handle';
  }

  @override
  String linkUrlSemantics(String label) {
    return 'Link $label';
  }

  @override
  String get profileTitle => 'Profile';

  @override
  String get profileFollowsYou => 'Follows you';

  @override
  String profileSubscribeSemantics(String displayName) {
    return 'Subscribe to $displayName';
  }

  @override
  String profileUnsubscribeSemantics(String displayName) {
    return 'Unsubscribe from $displayName';
  }

  @override
  String get profileRequestedSemantics => 'Follow request pending';

  @override
  String get profileSubscribe => 'Subscribe';

  @override
  String get profileUnsubscribe => 'Unsubscribe';

  @override
  String get profileRequested => 'Requested';

  @override
  String profileEnableNotifySemantics(String displayName) {
    return 'Enable post notifications for $displayName';
  }

  @override
  String profileDisableNotifySemantics(String displayName) {
    return 'Disable post notifications for $displayName';
  }

  @override
  String get profileNotifyOnTooltip => 'Notifications On (tap to disable)';

  @override
  String get profileNotifyOffTooltip => 'Notifications Off (tap to enable)';

  @override
  String profilePostsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Posts',
      one: '1 Post',
    );
    return '$_temp0';
  }

  @override
  String profileFollowingCount(int count) {
    return '$count Following';
  }

  @override
  String profileFollowersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Followers',
      one: '1 Follower',
    );
    return '$_temp0';
  }

  @override
  String get profileEmptyPosts => 'No posts published yet.';

  @override
  String profileAnnounceLoaded(String displayName, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count posts',
      one: '1 post',
    );
    return 'Loaded profile for $displayName with $_temp0.';
  }

  @override
  String profileAnnounceSubscribed(String displayName) {
    return 'Subscribed to $displayName.';
  }

  @override
  String profileAnnounceFollowRequested(String displayName) {
    return 'Follow request sent to $displayName.';
  }

  @override
  String profileAnnounceUnsubscribed(String displayName) {
    return 'Unsubscribed from $displayName.';
  }

  @override
  String profileErrorSubscription(String error) {
    return 'Failed to update subscription: $error';
  }

  @override
  String profileAnnounceNotifyEnabled(String displayName) {
    return 'Notifications enabled for $displayName.';
  }

  @override
  String profileAnnounceNotifyDisabled(String displayName) {
    return 'Notifications disabled for $displayName.';
  }

  @override
  String profileErrorNotifications(String error) {
    return 'Failed to update notifications: $error';
  }

  @override
  String statusBoostedSemantics(String displayName) {
    return 'Boosted by $displayName. Tap to view profile.';
  }

  @override
  String statusBoostedTip(String displayName) {
    return 'View profile of $displayName (who boosted this post)';
  }

  @override
  String statusBoostedLabel(String displayName) {
    return '$displayName boosted';
  }

  @override
  String get statusOpenThreadTip => 'Open post and conversation thread (Enter)';

  @override
  String statusEditedAt(String relativeTime) {
    return 'Edited $relativeTime';
  }

  @override
  String statusReplySemantics(String displayName, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count replies',
      one: '1 reply',
    );
    return 'Reply to $displayName ($_temp0)';
  }

  @override
  String statusUnboostSemantics(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count boosts',
      one: '1 boost',
    );
    return 'Unboost post ($_temp0)';
  }

  @override
  String statusBoostSemantics(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count boosts',
      one: '1 boost',
    );
    return 'Boost post ($_temp0)';
  }

  @override
  String statusUnfavoriteSemantics(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count favorites',
      one: '1 favorite',
    );
    return 'Unfavorite post ($_temp0)';
  }

  @override
  String statusFavoriteSemantics(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count favorites',
      one: '1 favorite',
    );
    return 'Favorite post ($_temp0)';
  }

  @override
  String get statusRemoveBookmarkSemantics => 'Remove bookmark';

  @override
  String get statusBookmarkSemantics => 'Bookmark post';

  @override
  String get statusThreadActionLabel => 'Thread';

  @override
  String get statusThreadActionSemantics => 'View conversation thread';

  @override
  String get statusEditActionLabel => 'Edit';

  @override
  String get statusEditActionSemantics => 'Edit your post and media alt text';

  @override
  String get statusDeleteActionSemantics => 'Delete your post';

  @override
  String statusAnnounceTranslated(String language, String engineName) {
    return 'Post translated to $language using $engineName.';
  }

  @override
  String get statusReadAloudPostSemantics => 'Read post and all alt text aloud';

  @override
  String get statusStopReadingPostSemantics => 'Stop reading post aloud';

  @override
  String get statusReadAloudPostTip =>
      'Read this post and all its alt-text aloud using text-to-speech';

  @override
  String get statusStopReadingPostTip => 'Stop reading this post aloud';

  @override
  String statusReadAloudContentWarning(String spoilerText) {
    return 'Content warning: $spoilerText';
  }

  @override
  String statusReadAloudImageAlt(String altText) {
    return 'Image description: $altText';
  }

  @override
  String statusReadAloudVideoAlt(String altText) {
    return 'Video description: $altText';
  }

  @override
  String statusReadAloudImageAltNumbered(int index, String altText) {
    return 'Image $index description: $altText';
  }

  @override
  String statusReadAloudVideoAltNumbered(int index, String altText) {
    return 'Video $index description: $altText';
  }

  @override
  String statusReadAloudQuotedPost(String author) {
    return 'Quoted post by $author';
  }

  @override
  String statusHeaderSemantics(String displayName, String handle) {
    return '$displayName, $handle. Tap to view posts.';
  }

  @override
  String statusQuotedTimestampSemantics(String verboseTime) {
    return 'Quoted post from $verboseTime. Open original post in external browser.';
  }

  @override
  String statusTimestampSemantics(String verboseTime) {
    return 'Posted $verboseTime. Open original post in external browser.';
  }

  @override
  String statusTimestampTip(String verboseTime) {
    return 'Open original post in web browser ($verboseTime)';
  }

  @override
  String cwBannerText(String spoilerText) {
    return 'CW: $spoilerText';
  }

  @override
  String get cwHideSemantics => 'Hide content behind content warning';

  @override
  String get cwShowSemantics => 'Show content behind content warning';

  @override
  String get cwHideTip => 'Hide post content behind Content Warning (x)';

  @override
  String get cwShowTip => 'Reveal post content behind Content Warning (x)';

  @override
  String get quotedPostLoading => 'Loading quoted post…';

  @override
  String get quotedPostLoadError => 'Quoted post could not be loaded in-app';

  @override
  String quotedPostSemantics(String displayName, String handle) {
    return 'Quoted post by $displayName, $handle.';
  }

  @override
  String get quotedPostBadge => 'Quoted Post';

  @override
  String translationTranslatingStatus(
    String sourceLanguage,
    String targetLanguage,
  ) {
    return 'Translating from $sourceLanguage to $targetLanguage…';
  }

  @override
  String translationTranslatedStatus(String sourceLanguage, String engineName) {
    return 'Translated from $sourceLanguage via $engineName';
  }

  @override
  String translationWrittenInStatus(String sourceLanguage) {
    return 'Written in $sourceLanguage';
  }

  @override
  String translationShowOriginalTip(String sourceLanguage) {
    return 'Switch back to the original $sourceLanguage post and alt-text';
  }

  @override
  String translationShowTranslatedTip(String targetLanguage) {
    return 'Show the translated $targetLanguage post and alt-text';
  }

  @override
  String get translationShowOriginalButton => 'Show Original';

  @override
  String get translationShowTranslatedButton => 'Show Translation';

  @override
  String translationTranslateTip(String sourceLanguage, String targetLanguage) {
    return 'Translate this $sourceLanguage post and its media alt-text into $targetLanguage on-device';
  }

  @override
  String translationTranslateButton(String targetLanguage) {
    return 'Translate to $targetLanguage';
  }

  @override
  String get mediaVideoBadge => 'VIDEO';

  @override
  String mediaVideoWithAltSemantics(String altText) {
    return 'Video: $altText Tap to play video.';
  }

  @override
  String mediaImageWithAltSemantics(String altText) {
    return 'Image: $altText Tap to view full image.';
  }

  @override
  String get mediaVideoNoAltSemantics =>
      'Video with no alt text provided. Tap to play video.';

  @override
  String get mediaImageNoAltSemantics =>
      'Image with no alt text provided. Tap to view full image.';

  @override
  String get mediaVideoOpenTip => 'Play embedded video in full-screen player';

  @override
  String get mediaImageOpenTip =>
      'View full-size image with zoom and share options';

  @override
  String get mediaAltProvidedBadge => 'ALT TEXT PROVIDED';

  @override
  String get mediaNoAltBadge => 'NO ALT TEXT';

  @override
  String get mediaCollapseAltSemantics => 'Collapse alt text box';

  @override
  String get mediaExpandAltSemantics => 'Expand alt text box';

  @override
  String get mediaAuthorAltTranslatedHeading => 'Author Alt-Text (Translated):';

  @override
  String get mediaAuthorAltHeading => 'Author Alt-Text:';

  @override
  String get mediaOnDemandAiHeading => 'On-Demand AI Description:';

  @override
  String get mediaDescribingSemantics => 'Generating AI description';

  @override
  String get mediaRedescribeSemantics => 'Re-describe media with AI';

  @override
  String get mediaDescribeSemantics => 'Describe media with AI';

  @override
  String get mediaDescribeTip =>
      'Generate an AI alt-text description for this media attachment';

  @override
  String get mediaDescribingButton => 'Describing…';

  @override
  String get mediaRedescribeButton => 'Re-Describe with AI';

  @override
  String get mediaDescribeButton => 'Describe with AI';

  @override
  String get mediaStopReadingSemantics => 'Stop reading alt text aloud';

  @override
  String get mediaReadAloudSemantics => 'Read alt text aloud';

  @override
  String get mediaStopReadingTip => 'Stop reading alt-text aloud';

  @override
  String get mediaReadAloudTip =>
      'Read this alt-text description aloud using text-to-speech';

  @override
  String get mediaStopReadingButton => 'Stop Reading';

  @override
  String get mediaReadAloudButton => 'Read Aloud';

  @override
  String get mediaAiAnnounceGenerating =>
      'Generating AI description for media.';

  @override
  String mediaAiAnnounceReady(String caption) {
    return 'AI description ready. $caption';
  }

  @override
  String get mediaAiAnnounceFailed => 'Failed to generate AI description.';

  @override
  String get imageViewerTitle => 'Full Image';

  @override
  String get imageViewerCloseTooltip => 'Close full-screen image';

  @override
  String get imageViewerShareTooltip => 'Share or save image';

  @override
  String get imageViewerInvalidUrl => 'Invalid image URL.';

  @override
  String get imageViewerAnnounceShare => 'Opening share menu.';

  @override
  String imageViewerShareError(String error) {
    return 'Could not share image: $error';
  }

  @override
  String imageViewerWithAltSemantics(String altText) {
    return 'Full image: $altText Long press to share or save.';
  }

  @override
  String get imageViewerNoAltSemantics =>
      'Full image with no alt text provided. Long press to share or save.';

  @override
  String get imageViewerLoadError => 'Could not load full image.';

  @override
  String get videoPlayerInvalidUrl => 'Invalid video URL.';

  @override
  String videoPlayerError(String error) {
    return 'Could not play video: $error';
  }

  @override
  String get videoPlayerAnnouncePlayingVideo => 'Playing video.';

  @override
  String get videoPlayerAnnouncePaused => 'Paused.';

  @override
  String get videoPlayerAnnouncePlaying => 'Playing.';

  @override
  String get videoPlayerAnnounceMuted => 'Muted.';

  @override
  String get videoPlayerAnnounceUnmuted => 'Unmuted.';

  @override
  String get videoPlayerCloseTooltip => 'Close video player';

  @override
  String get videoPlayerTitleGifv => 'GIF Video';

  @override
  String get videoPlayerTitleVideo => 'Video';

  @override
  String get videoPlayerOpenBrowserTooltip => 'Open video in browser';

  @override
  String get videoPlayerOpenBrowserButton => 'Open in Browser';

  @override
  String get videoPlayerPauseTooltip => 'Pause';

  @override
  String get videoPlayerPlayTooltip => 'Play';

  @override
  String get videoPlayerUnmuteTooltip => 'Unmute';

  @override
  String get videoPlayerMuteTooltip => 'Mute';

  @override
  String get videoPlayerSeekSemantics => 'Playback position';

  @override
  String get videoPlayerSeekHint =>
      'Use left and right arrow keys to skip 5 seconds';

  @override
  String videoPlayerPositionValue(String position, String duration) {
    return '$position of $duration';
  }

  @override
  String get composerCheckingBias => 'Checking Bias…';

  @override
  String get composerSaving => 'Saving…';

  @override
  String get composerPublishing => 'Publishing…';

  @override
  String get composerSaveChanges => 'Save Changes';

  @override
  String get composerPublish => 'Publish';

  @override
  String get composerTitleEdit => 'Edit Post';

  @override
  String get composerTitleReply => 'Reply';

  @override
  String get composerTitleNew => 'Compose Post';

  @override
  String composerEditSubmitTip(String shortcut) {
    return 'Save your edited post and alt-text ($shortcut)';
  }

  @override
  String composerPublishSubmitTip(String shortcut) {
    return 'Check accessibility and bias rules, then publish post ($shortcut)';
  }

  @override
  String composerReplyingTo(String handle) {
    return 'Replying to $handle';
  }

  @override
  String get composerCwSwitchTitle => 'Content Warning / Spoiler';

  @override
  String get composerCwSwitchSubtitle =>
      'Included in character counter and pre-post bias check.';

  @override
  String get composerCwLabel => 'Content Warning';

  @override
  String get composerCwHint => 'Brief summary or topic warning';

  @override
  String get composerBodyLabel => 'What is on your mind?';

  @override
  String get composerBodyHint => 'Write your Mastodon post…';

  @override
  String composerCharsRemainingSemantics(int remaining, int maxCharacters) {
    return '$remaining characters remaining out of $maxCharacters maximum.';
  }

  @override
  String composerCharsCounter(int used, int maxCharacters, int remaining) {
    return '$used / $maxCharacters chars ($remaining remaining)';
  }

  @override
  String get composerVisibilityLabel => 'Post Visibility';

  @override
  String composerVisibilityItem(String label, String description) {
    return '$label — $description';
  }

  @override
  String composerAttachmentsHeader(int count, int maxCount) {
    return 'Media Attachments ($count / $maxCount)';
  }

  @override
  String get composerCameraTip =>
      'Take a photo with your camera and auto-generate alt-text';

  @override
  String get composerCameraLabel => 'Camera';

  @override
  String get composerPhotoLibraryTip =>
      'Choose a photo from your library (EXIF stripped & resized automatically)';

  @override
  String get composerPhotoLibraryLabel => 'Photo Library';

  @override
  String get composerVideoTip =>
      'Choose a video to attach and auto-generate alt-text';

  @override
  String get composerVideoLabel => 'Video';

  @override
  String get composerFilePickerTip =>
      'Pick an image or video file from disk (EXIF stripped & resized automatically)';

  @override
  String get composerFilePickerLabel => 'File Picker';

  @override
  String composerAttachmentVideoLabel(int index) {
    return 'Attachment $index (Video)';
  }

  @override
  String composerAttachmentImageLabel(int index) {
    return 'Attachment $index (Image)';
  }

  @override
  String composerRemoveAttachmentTooltip(int index) {
    return 'Remove attachment $index';
  }

  @override
  String get composerAltTextLabel => 'Alt-Text Description';

  @override
  String get composerAltTextHintVideo =>
      'Describe this video for screen-reader users…';

  @override
  String get composerAltTextHintImage =>
      'Describe this image for screen-reader users…';

  @override
  String composerAltTextCounterHelper(int current, int max) {
    return '$current / $max chars';
  }

  @override
  String get composerDetailLevelLabel => 'Detail Level';

  @override
  String get composerRescanButton => 'Re-Scan with AI';

  @override
  String get composerScanningButton => 'AI Scanning…';

  @override
  String composerErrorFallbackEditSource(String error) {
    return 'Loaded fallback post text (could not fetch raw source: $error)';
  }

  @override
  String composerErrorMaxMedia(int maxMedia) {
    return 'Maximum of $maxMedia media attachments reached.';
  }

  @override
  String get composerErrorNotSignedIn => 'Not signed in to Mastodon.';

  @override
  String composerAnnounceScanningVideo(int index) {
    return 'AI scanning video attachment $index.';
  }

  @override
  String composerAnnounceScanningImage(int index) {
    return 'AI scanning image attachment $index.';
  }

  @override
  String composerAnnounceAltReady(int index) {
    return 'Alt-text ready for attachment $index.';
  }

  @override
  String composerAnnounceAltError(int index) {
    return 'Error generating alt-text for attachment $index.';
  }

  @override
  String get composerAnnounceCheckingBias =>
      'Checking post, media, links, and context for racial or gender bias.';

  @override
  String composerAnnounceBiasReview(String summary) {
    return 'Pre-post bias review: $summary';
  }

  @override
  String get composerAnnounceUpdated => 'Post updated successfully.';

  @override
  String get composerAnnouncePublished => 'Post published successfully.';

  @override
  String get composerAnnouncePublishFailed => 'Failed to publish post.';

  @override
  String get missingAltTextTitleRequire => 'Alt-Text Required Before Posting';

  @override
  String get missingAltTextTitleWarn => 'Missing Media Alt-Text';

  @override
  String missingAltTextBodyWarnAi(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count media attachments are missing an alt-text description for blind and low-vision readers. Would you like to auto-generate descriptions with AI before posting?',
      one: '1 media attachment is missing an alt-text description for blind and low-vision readers. Would you like to auto-generate descriptions with AI before posting?',
    );
    return '$_temp0';
  }

  @override
  String missingAltTextBodyWarnManual(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count media attachments are missing an alt-text description for blind and low-vision readers. Would you like to add alt-text in the composer before posting?',
      one: '1 media attachment is missing an alt-text description for blind and low-vision readers. Would you like to add alt-text in the composer before posting?',
    );
    return '$_temp0';
  }

  @override
  String missingAltTextBodyRequire(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count media attachments are missing an alt-text description for blind and low-vision readers. Your Accessibility Rules policy requires alt-text on all attached media before posting.',
      one: '1 media attachment is missing an alt-text description for blind and low-vision readers. Your Accessibility Rules policy requires alt-text on all attached media before posting.',
    );
    return '$_temp0';
  }

  @override
  String get missingAltTextAutoGenerateButton =>
      'Auto-Generate Missing Alt-Text with AI';

  @override
  String get missingAltTextEditButton => 'Edit in Composer';

  @override
  String get missingAltTextPostAnywayButton => 'Post Anyway';

  @override
  String get biasReviewTitle => 'Pre-Post Racial & Gender Bias Review';

  @override
  String get biasReviewCloseTooltip => 'Close and return to composer';

  @override
  String get biasReviewSummaryTitle => 'Summary';

  @override
  String biasReviewCheckedComponents(String components) {
    return 'Checked: $components';
  }

  @override
  String get biasReviewLocalFallbackNote =>
      'Note: Analyzed using offline local bias heuristics.';

  @override
  String biasReviewFindingsHeader(int count) {
    return 'Where Bias Was Found ($count)';
  }

  @override
  String biasReviewExcerpt(String excerpt) {
    return 'Excerpt: \"$excerpt\"';
  }

  @override
  String get biasReviewSuggestedWordingTitle => 'Suggested Alternate Wording';

  @override
  String get biasReviewUseSuggestedAndPublishButton =>
      'Use Suggested Wording & Publish Now';

  @override
  String get biasReviewUseSuggestedButton =>
      'Use Suggested Wording in Composer';

  @override
  String get biasReviewReturnToComposerButton => 'Return to Composer to Edit';

  @override
  String get biasReviewPublishAnywayButton => 'Publish Anyway';

  @override
  String get biasReviewRequireNotice =>
      'Your Bias Rules policy is set to Require: please revise the post before publishing.';

  @override
  String get biasComponentPostText => 'Post Text';

  @override
  String get biasComponentContentWarning => 'Content Warning';

  @override
  String biasComponentAttachment(int index) {
    return 'Attachment $index';
  }

  @override
  String biasComponentLink(String url) {
    return 'Link ($url)';
  }

  @override
  String biasComponentReferencedMessage(String handle) {
    return 'Referenced Message (@$handle)';
  }

  @override
  String get biasSummaryClean => 'No racial or gender bias detected.';

  @override
  String get biasSummaryLocalClean =>
      'No racial or gender bias detected via local check.';

  @override
  String biasSummaryLocalFindings(String checkedLabel, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count potential racial or gender bias issues',
      one: '1 potential racial or gender bias issue',
    );
    return 'Checked $checkedLabel (offline heuristic check) and found $_temp0.';
  }

  @override
  String biasSummaryAiFallbackBias(String checkedLabel) {
    return 'Checked $checkedLabel and detected potential racial or gender bias.';
  }

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsSectionAi => 'AI Provider & API Keys';

  @override
  String get settingsSectionCaptioning => 'AI Alt-Text Captioning';

  @override
  String get settingsDefaultDetailLevel => 'Default Detail Level';

  @override
  String settingsDetailLevelItem(String label, String guidance) {
    return '$label — $guidance';
  }

  @override
  String get settingsVideoKeyframesLabel => 'Video Keyframes to Extract';

  @override
  String get settingsVideoKeyframesHelper =>
      'Used for frame-based models or videos exceeding Gemini inline limits.';

  @override
  String settingsVideoKeyframesOption(int count) {
    return '$count keyframes';
  }

  @override
  String settingsVideoKeyframesDefaultOption(int count) {
    return '$count keyframes (Default)';
  }

  @override
  String get settingsAutoGenerateTitle => 'Auto-Generate Alt-Text on Attach';

  @override
  String get settingsAutoGenerateSubtitle =>
      'Automatically scan images and videos as soon as they are attached.';

  @override
  String get settingsIncludePostContextTitle =>
      'Include Draft Post Text as Context';

  @override
  String get settingsIncludePostContextSubtitle =>
      'Helps the AI identify names, events, or subjects mentioned in your draft.';

  @override
  String get settingsCaptionLanguageLabel => 'Caption Output Language';

  @override
  String get settingsCaptionLanguageHint => 'English';

  @override
  String get settingsCustomInstructionsLabel =>
      'Custom Instructions (Optional)';

  @override
  String get settingsCustomInstructionsHint =>
      'e.g. Our orange tabby cat is named Marmalade; prefer plain objective tone.';

  @override
  String get settingsSectionAccessibility => 'Accessibility Rules';

  @override
  String settingsTtsSpeedTitle(String speed) {
    return 'Built-in On-Device Read Aloud Speed (${speed}x)';
  }

  @override
  String get settingsTtsSpeedSubtitle =>
      'Uses your device\'s built-in TTS engine (AVSpeechSynthesizer on Apple platforms, Google/Samsung TTS on Android, SAPI on Windows, Speech Dispatcher / eSpeak on Linux).';

  @override
  String settingsTtsSpeedLabel(String speed) {
    return '${speed}x';
  }

  @override
  String get settingsAltPolicyLabel => 'Pre-Post Alt-Text Policy';

  @override
  String get settingsSectionBias => 'Bias Rules';

  @override
  String get settingsBiasPolicyLabel => 'Pre-Post Racial & Gender Bias Policy';

  @override
  String get settingsSectionAppearance => 'Appearance & Theme';

  @override
  String settingsDetectedOsMode(String mode) {
    return 'Detected OS mode: $mode';
  }

  @override
  String get settingsOsModeHighContrast => 'High Contrast';

  @override
  String get settingsOsModeDark => 'Dark';

  @override
  String get settingsOsModeLight => 'Light';

  @override
  String get settingsAppLanguageLabel => 'App Interface Language';

  @override
  String settingsAppLanguageSystemDefault(String localeName) {
    return 'System Default ($localeName)';
  }

  @override
  String get settingsAppLanguageHelper =>
      'Choose the language used for menus, buttons, and accessibility labels.';

  @override
  String get settingsSectionAccount => 'Account & Server Info';

  @override
  String settingsAccountTitle(String displayName, String handle) {
    return '$displayName ($handle)';
  }

  @override
  String settingsAccountSubtitle(
    String instanceUrl,
    int maxChars,
    int maxMedia,
    int altLimit,
  ) {
    return 'Server: $instanceUrl\nMax post length: $maxChars chars · Max media: $maxMedia · Alt-text limit: $altLimit chars';
  }

  @override
  String get settingsSignOut => 'Sign Out';

  @override
  String settingsAboutTitle(String appName, String appVersion) {
    return '$appName v$appVersion';
  }

  @override
  String settingsAboutSubtitle(String contributorName) {
    return 'Contributor: $contributorName · Generated with Antigravity';
  }

  @override
  String get shortcutsTitle => 'Keyboard Shortcuts';

  @override
  String shortcutsOrKeyCombo(String primary, String alternate) {
    return '$primary  or  $alternate';
  }

  @override
  String get shortcutsSectionNavigation => 'Post Navigation';

  @override
  String get shortcutsNextPost => 'Next post';

  @override
  String get shortcutsPreviousPost => 'Previous post';

  @override
  String get shortcutsScrollPage => 'Scroll up / down one page';

  @override
  String get shortcutsScrollToTop => 'Jump to top of list';

  @override
  String get shortcutsOpenPost => 'Open selected post / thread';

  @override
  String get shortcutsEscape => 'Go back or close viewer';

  @override
  String get shortcutsSectionActions => 'Selected Post Actions';

  @override
  String get shortcutsReply => 'Reply to selected post';

  @override
  String get shortcutsFavorite => 'Favorite / unfavorite';

  @override
  String get shortcutsBoost => 'Boost / unboost';

  @override
  String get shortcutsBookmark => 'Bookmark / unbookmark';

  @override
  String get shortcutsToggleCw => 'Expand / collapse Content Warning';

  @override
  String get shortcutsOpenProfile => 'Open author profile';

  @override
  String get shortcutsSectionTimelines => 'Switch Timelines';

  @override
  String get shortcutsHomeTimeline => 'Home timeline';

  @override
  String get shortcutsLocalTimeline => 'Local timeline';

  @override
  String get shortcutsFederatedTimeline => 'Federated timeline';

  @override
  String get shortcutsNotificationsTimeline => 'Notifications / Alerts';

  @override
  String get shortcutsBookmarksTimeline => 'Bookmarks';

  @override
  String get shortcutsFavoritesTimeline => 'Favorites';

  @override
  String get shortcutsMyPostsTimeline => 'My Published Posts';

  @override
  String get shortcutsSectionApp => 'App & Composer';

  @override
  String get shortcutsComposeNew => 'Compose new post';

  @override
  String get shortcutsPublishPost => 'Publish post (in Composer)';

  @override
  String get shortcutsLocalSearch => 'Offline local search';

  @override
  String get shortcutsRefresh => 'Refresh current view';

  @override
  String get shortcutsOpenSettings => 'Open Settings';

  @override
  String get shortcutsShowHelp => 'Show this help sheet';

  @override
  String get actionAnnounceBoosted => 'Post boosted.';

  @override
  String get actionAnnounceUnboosted => 'Boost removed.';

  @override
  String actionErrorBoost(String error) {
    return 'Could not update boost: $error';
  }

  @override
  String get actionAnnounceFavorited => 'Post favorited.';

  @override
  String get actionAnnounceUnfavorited => 'Removed from favorites.';

  @override
  String actionErrorFavorite(String error) {
    return 'Could not update favorite: $error';
  }

  @override
  String get actionAnnounceBookmarked => 'Post bookmarked.';

  @override
  String get actionAnnounceUnbookmarked => 'Bookmark removed.';

  @override
  String actionErrorBookmark(String error) {
    return 'Could not update bookmark: $error';
  }

  @override
  String get actionDeleteTitle => 'Delete Post?';

  @override
  String get actionDeleteConfirmBody =>
      'This will permanently delete your post from your Mastodon server.';

  @override
  String get actionAnnounceDeleted => 'Post deleted.';

  @override
  String actionErrorDelete(String error) {
    return 'Failed to delete post: $error';
  }

  @override
  String get timeCompactNow => 'now';

  @override
  String timeCompactMinutes(int count) {
    return '${count}m';
  }

  @override
  String timeCompactHours(int count) {
    return '${count}h';
  }

  @override
  String timeCompactDays(int count) {
    return '${count}d';
  }

  @override
  String timeCompactMonths(int count) {
    return '${count}mo';
  }

  @override
  String timeCompactYears(int count) {
    return '${count}y';
  }

  @override
  String get timeAccessibleJustNow => 'just now';

  @override
  String timeAccessibleMinutesAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count minutes ago',
      one: '1 minute ago',
    );
    return '$_temp0';
  }

  @override
  String timeAccessibleHoursAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count hours ago',
      one: '1 hour ago',
    );
    return '$_temp0';
  }

  @override
  String timeAccessibleDaysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days ago',
      one: '1 day ago',
    );
    return '$_temp0';
  }

  @override
  String get loginAddAccountTitle => 'Add Mastodon Account';

  @override
  String get loginSavedAccountsHeader => 'Saved Accounts';

  @override
  String authAnnounceSwitchedAccount(String displayName, String handle) {
    return 'Switched active account to $displayName ($handle).';
  }

  @override
  String get accountsSheetTitle => 'Accounts';

  @override
  String accountsSheetSubtitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count accounts signed in',
      one: '1 account signed in',
    );
    return '$_temp0';
  }

  @override
  String get accountsActiveBadge => 'Active';

  @override
  String get accountsAddButton => 'Add Account';

  @override
  String accountsSwitchTooltip(String handle) {
    return 'Switch account (active: $handle)';
  }

  @override
  String get accountsManageTooltip => 'Switch or add Mastodon account';

  @override
  String get accountsSwitchOrAddLabel => 'Switch / Add Account';

  @override
  String accountsSignOutAccountTooltip(String handle) {
    return 'Sign out of $handle';
  }

  @override
  String accountsSwitchError(String error) {
    return 'Could not switch account: $error';
  }

  @override
  String get settingsAddAccount => 'Add Account';

  @override
  String get settingsSwitchToAccount => 'Switch';

  @override
  String get settingsActiveAccountBadge => 'Active';
}
