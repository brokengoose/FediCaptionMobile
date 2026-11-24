// Copyright (c) 2026 brokengoose <brokengoose@users.noreply.github.com>
// SPDX-License-Identifier: MIT

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('en')];

  /// Screen reader label on the startup loading screen
  ///
  /// In en, this message translates to:
  /// **'Loading FediCaption'**
  String get appLoadingLabel;

  /// Semantic description for the FediCaption launcher icon
  ///
  /// In en, this message translates to:
  /// **'FediCaption app icon'**
  String get appIconSemanticLabel;

  /// No description provided for @commonRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get commonRetry;

  /// No description provided for @commonCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// No description provided for @commonClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get commonClose;

  /// No description provided for @commonDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get commonDelete;

  /// No description provided for @commonDownload.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get commonDownload;

  /// No description provided for @commonShow.
  ///
  /// In en, this message translates to:
  /// **'Show'**
  String get commonShow;

  /// No description provided for @commonHide.
  ///
  /// In en, this message translates to:
  /// **'Hide'**
  String get commonHide;

  /// No description provided for @commonShowMore.
  ///
  /// In en, this message translates to:
  /// **'Show More'**
  String get commonShowMore;

  /// Generic fallback noun when an account display name is unavailable
  ///
  /// In en, this message translates to:
  /// **'user'**
  String get commonUserFallback;

  /// No description provided for @loginSettingsTooltip.
  ///
  /// In en, this message translates to:
  /// **'Settings and Appearance'**
  String get loginSettingsTooltip;

  /// No description provided for @loginElephantSemanticLabel.
  ///
  /// In en, this message translates to:
  /// **'FediCaption cartoon elephant wearing dark sunglasses'**
  String get loginElephantSemanticLabel;

  /// No description provided for @loginWelcomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Welcome to FediCaption'**
  String get loginWelcomeTitle;

  /// No description provided for @loginTagline.
  ///
  /// In en, this message translates to:
  /// **'An accessible Mastodon client with automatic AI alt-text generation and pre-post racial & gender bias checking.'**
  String get loginTagline;

  /// No description provided for @loginServerDomainLabel.
  ///
  /// In en, this message translates to:
  /// **'Mastodon Server Domain'**
  String get loginServerDomainLabel;

  /// No description provided for @loginServerDomainHint.
  ///
  /// In en, this message translates to:
  /// **'mastodon.social'**
  String get loginServerDomainHint;

  /// No description provided for @loginServerDomainHelper.
  ///
  /// In en, this message translates to:
  /// **'Enter your Mastodon, Glitch-soc, Hometown, Pleroma, or Akkoma server.'**
  String get loginServerDomainHelper;

  /// No description provided for @loginSigningIn.
  ///
  /// In en, this message translates to:
  /// **'Signing in…'**
  String get loginSigningIn;

  /// No description provided for @loginSignInOAuth.
  ///
  /// In en, this message translates to:
  /// **'Sign in with Mastodon (OAuth 2.0)'**
  String get loginSignInOAuth;

  /// No description provided for @loginTokenFallbackTitle.
  ///
  /// In en, this message translates to:
  /// **'Direct Access Token Fallback'**
  String get loginTokenFallbackTitle;

  /// No description provided for @loginTokenFallbackSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in with a personal access token from your Mastodon Development settings.'**
  String get loginTokenFallbackSubtitle;

  /// No description provided for @loginTokenLabel.
  ///
  /// In en, this message translates to:
  /// **'Access Token'**
  String get loginTokenLabel;

  /// No description provided for @loginTokenHint.
  ///
  /// In en, this message translates to:
  /// **'Paste Mastodon access token'**
  String get loginTokenHint;

  /// No description provided for @loginShowToken.
  ///
  /// In en, this message translates to:
  /// **'Show token'**
  String get loginShowToken;

  /// No description provided for @loginHideToken.
  ///
  /// In en, this message translates to:
  /// **'Hide token'**
  String get loginHideToken;

  /// No description provided for @loginSignInToken.
  ///
  /// In en, this message translates to:
  /// **'Sign in with Access Token'**
  String get loginSignInToken;

  /// No description provided for @oauthLandingTitle.
  ///
  /// In en, this message translates to:
  /// **'FediCaption Sign-In Complete'**
  String get oauthLandingTitle;

  /// No description provided for @oauthLandingHeading.
  ///
  /// In en, this message translates to:
  /// **'Signed in to FediCaption'**
  String get oauthLandingHeading;

  /// No description provided for @oauthLandingBody.
  ///
  /// In en, this message translates to:
  /// **'Authorization succeeded. You can close this browser tab and return to FediCaption.'**
  String get oauthLandingBody;

  /// No description provided for @authErrorInvalidInstance.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid Mastodon server domain (e.g. mastodon.social).'**
  String get authErrorInvalidInstance;

  /// No description provided for @authErrorCancelled.
  ///
  /// In en, this message translates to:
  /// **'Authorization was cancelled.'**
  String get authErrorCancelled;

  /// No description provided for @authErrorMissingInstanceAndToken.
  ///
  /// In en, this message translates to:
  /// **'Both server URL and access token are required.'**
  String get authErrorMissingInstanceAndToken;

  /// No description provided for @authErrorExpiredSession.
  ///
  /// In en, this message translates to:
  /// **'Saved session expired or server unreachable: {error}'**
  String authErrorExpiredSession(String error);

  /// No description provided for @authAnnounceSignedIn.
  ///
  /// In en, this message translates to:
  /// **'Signed in as {displayName} on {instanceUrl}.'**
  String authAnnounceSignedIn(String displayName, String instanceUrl);

  /// No description provided for @authAnnounceSignedOut.
  ///
  /// In en, this message translates to:
  /// **'Signed out of Mastodon.'**
  String get authAnnounceSignedOut;

  /// No description provided for @aiSetupTitle.
  ///
  /// In en, this message translates to:
  /// **'Set Up AI'**
  String get aiSetupTitle;

  /// No description provided for @aiSetupHeading.
  ///
  /// In en, this message translates to:
  /// **'Configure AI Captioning & Bias Checking'**
  String get aiSetupHeading;

  /// No description provided for @aiSetupIntroWithHandle.
  ///
  /// In en, this message translates to:
  /// **'Signed in as {handle}. Choose an AI provider to automatically generate accessible alt-text and check posts for racial or gender bias — or choose No AI to enter alt-text manually.'**
  String aiSetupIntroWithHandle(String handle);

  /// No description provided for @aiSetupIntroWithoutHandle.
  ///
  /// In en, this message translates to:
  /// **'Choose an AI provider to automatically generate accessible alt-text and check posts for racial or gender bias — or choose No AI to enter alt-text manually.'**
  String get aiSetupIntroWithoutHandle;

  /// No description provided for @aiSetupDetectingOnDevice.
  ///
  /// In en, this message translates to:
  /// **'Checking on-device AI availability…'**
  String get aiSetupDetectingOnDevice;

  /// No description provided for @aiSetupProviderLabel.
  ///
  /// In en, this message translates to:
  /// **'AI Provider'**
  String get aiSetupProviderLabel;

  /// No description provided for @aiSetupModelHelper.
  ///
  /// In en, this message translates to:
  /// **'Sorted alphabetically. Tap Refresh after entering your key or URL.'**
  String get aiSetupModelHelper;

  /// No description provided for @aiSetupNoAiDefaultNotice.
  ///
  /// In en, this message translates to:
  /// **'On-device AI is not available on this device, so No AI is selected by default. You can choose a Cloud API or Local AI server above, or continue with No AI (manual alt-text, Read Aloud, and offline bias heuristics) and enable AI later in Settings.'**
  String get aiSetupNoAiDefaultNotice;

  /// No description provided for @aiSetupNoAiSelectedNotice.
  ///
  /// In en, this message translates to:
  /// **'FediCaption will not contact any AI service. You can still write alt-text manually, listen with Read Aloud, and use offline local bias heuristics. You can enable an AI provider later in Settings.'**
  String get aiSetupNoAiSelectedNotice;

  /// No description provided for @aiSetupContinueNoAi.
  ///
  /// In en, this message translates to:
  /// **'Continue with No AI'**
  String get aiSetupContinueNoAi;

  /// No description provided for @aiSetupSaveAndContinue.
  ///
  /// In en, this message translates to:
  /// **'Save AI Settings & Continue'**
  String get aiSetupSaveAndContinue;

  /// No description provided for @aiSetupUseNoAiLater.
  ///
  /// In en, this message translates to:
  /// **'Use No AI (Set Up Later)'**
  String get aiSetupUseNoAiLater;

  /// No description provided for @aiSetupAnnounceCompleteWithAi.
  ///
  /// In en, this message translates to:
  /// **'AI setup complete using {providerName}.'**
  String aiSetupAnnounceCompleteWithAi(String providerName);

  /// No description provided for @aiSetupAnnounceCompleteNoAi.
  ///
  /// In en, this message translates to:
  /// **'Setup complete with No AI selected. Manual alt-text and offline bias heuristics are active.'**
  String get aiSetupAnnounceCompleteNoAi;

  /// No description provided for @aiConfigActiveProviderLabel.
  ///
  /// In en, this message translates to:
  /// **'Active AI Provider'**
  String get aiConfigActiveProviderLabel;

  /// No description provided for @aiConfigModelHelper.
  ///
  /// In en, this message translates to:
  /// **'Sorted alphabetically. Select a vision-capable model.'**
  String get aiConfigModelHelper;

  /// No description provided for @aiConfigNoAiNotice.
  ///
  /// In en, this message translates to:
  /// **'AI is disabled (\"No AI\"). Alt-text can be entered manually, Read Aloud remains available, and pre-post bias checks use offline local heuristics.'**
  String get aiConfigNoAiNotice;

  /// No description provided for @aiConfigGeminiApiKeyLabel.
  ///
  /// In en, this message translates to:
  /// **'Google Gemini API Key'**
  String get aiConfigGeminiApiKeyLabel;

  /// No description provided for @aiConfigGeminiApiKeyHint.
  ///
  /// In en, this message translates to:
  /// **'AIza…'**
  String get aiConfigGeminiApiKeyHint;

  /// No description provided for @aiConfigOpenAiBaseUrlLabel.
  ///
  /// In en, this message translates to:
  /// **'OpenAI-Compatible Base URL'**
  String get aiConfigOpenAiBaseUrlLabel;

  /// No description provided for @aiConfigOpenAiBaseUrlHelper.
  ///
  /// In en, this message translates to:
  /// **'Supports OpenAI, OpenRouter, LM Studio, vLLM, or llama.cpp.'**
  String get aiConfigOpenAiBaseUrlHelper;

  /// No description provided for @aiConfigOpenAiApiKeyLabel.
  ///
  /// In en, this message translates to:
  /// **'API Key (Optional for local servers)'**
  String get aiConfigOpenAiApiKeyLabel;

  /// No description provided for @aiConfigOpenAiApiKeyHint.
  ///
  /// In en, this message translates to:
  /// **'sk-…'**
  String get aiConfigOpenAiApiKeyHint;

  /// No description provided for @aiConfigAnthropicApiKeyLabel.
  ///
  /// In en, this message translates to:
  /// **'Anthropic API Key'**
  String get aiConfigAnthropicApiKeyLabel;

  /// No description provided for @aiConfigAnthropicApiKeyHint.
  ///
  /// In en, this message translates to:
  /// **'sk-ant-…'**
  String get aiConfigAnthropicApiKeyHint;

  /// No description provided for @aiConfigLocalBaseUrlLabel.
  ///
  /// In en, this message translates to:
  /// **'Local AI Server URL (Ollama / LM Studio LAN)'**
  String get aiConfigLocalBaseUrlLabel;

  /// No description provided for @aiConfigLocalBaseUrlHelper.
  ///
  /// In en, this message translates to:
  /// **'Default: {defaultUrl}. Use your computer\'s LAN IP for Ollama (port 11434/v1) or LM Studio (port 1234/v1).'**
  String aiConfigLocalBaseUrlHelper(String defaultUrl);

  /// No description provided for @aiConfigLocalApiKeyLabel.
  ///
  /// In en, this message translates to:
  /// **'Optional LAN Server Token / Key'**
  String get aiConfigLocalApiKeyLabel;

  /// No description provided for @aiConfigLocalApiKeyHint.
  ///
  /// In en, this message translates to:
  /// **'Leave blank if not required'**
  String get aiConfigLocalApiKeyHint;

  /// No description provided for @aiConfigNoAiSelectedTitle.
  ///
  /// In en, this message translates to:
  /// **'No AI Selected'**
  String get aiConfigNoAiSelectedTitle;

  /// No description provided for @aiConfigModelDropdownLabel.
  ///
  /// In en, this message translates to:
  /// **'AI Model (A–Z)'**
  String get aiConfigModelDropdownLabel;

  /// No description provided for @aiConfigFetchingModelsHelper.
  ///
  /// In en, this message translates to:
  /// **'Fetching available models from provider…'**
  String get aiConfigFetchingModelsHelper;

  /// No description provided for @aiConfigRefreshModelsTooltip.
  ///
  /// In en, this message translates to:
  /// **'Refresh Models'**
  String get aiConfigRefreshModelsTooltip;

  /// No description provided for @aiConfigShowApiKey.
  ///
  /// In en, this message translates to:
  /// **'Show API key'**
  String get aiConfigShowApiKey;

  /// No description provided for @aiConfigHideApiKey.
  ///
  /// In en, this message translates to:
  /// **'Hide API key'**
  String get aiConfigHideApiKey;

  /// No description provided for @onDeviceAiStatusHeader.
  ///
  /// In en, this message translates to:
  /// **'{engineName} — {badge}'**
  String onDeviceAiStatusHeader(String engineName, String badge);

  /// No description provided for @onDeviceAiBadgeReady.
  ///
  /// In en, this message translates to:
  /// **'Ready on Device'**
  String get onDeviceAiBadgeReady;

  /// No description provided for @onDeviceAiBadgeDownloadable.
  ///
  /// In en, this message translates to:
  /// **'Model Downloadable'**
  String get onDeviceAiBadgeDownloadable;

  /// No description provided for @onDeviceAiBadgeNotYetReady.
  ///
  /// In en, this message translates to:
  /// **'Enable in System Settings'**
  String get onDeviceAiBadgeNotYetReady;

  /// No description provided for @onDeviceAiBadgeUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Unavailable on This Device'**
  String get onDeviceAiBadgeUnavailable;

  /// No description provided for @onDeviceAiDownloadingModelButton.
  ///
  /// In en, this message translates to:
  /// **'Downloading Model…'**
  String get onDeviceAiDownloadingModelButton;

  /// No description provided for @onDeviceAiDownloadModelButton.
  ///
  /// In en, this message translates to:
  /// **'Download On-Device Model'**
  String get onDeviceAiDownloadModelButton;

  /// No description provided for @onDeviceAiCheckingButton.
  ///
  /// In en, this message translates to:
  /// **'Checking…'**
  String get onDeviceAiCheckingButton;

  /// No description provided for @onDeviceAiRecheckButton.
  ///
  /// In en, this message translates to:
  /// **'Re-Check Device'**
  String get onDeviceAiRecheckButton;

  /// No description provided for @onDeviceAiAnnounceDownloading.
  ///
  /// In en, this message translates to:
  /// **'Downloading on-device AI model.'**
  String get onDeviceAiAnnounceDownloading;

  /// No description provided for @onDeviceAiAnnounceDownloadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to download on-device AI model.'**
  String get onDeviceAiAnnounceDownloadFailed;

  /// No description provided for @onDeviceAiEngineWeb.
  ///
  /// In en, this message translates to:
  /// **'Web (no OS on-device model)'**
  String get onDeviceAiEngineWeb;

  /// No description provided for @onDeviceAiEngineApple.
  ///
  /// In en, this message translates to:
  /// **'Apple Foundation Models'**
  String get onDeviceAiEngineApple;

  /// No description provided for @onDeviceAiEngineGeminiNano.
  ///
  /// In en, this message translates to:
  /// **'Google Gemini Nano (ML Kit GenAI / AICore)'**
  String get onDeviceAiEngineGeminiNano;

  /// No description provided for @onDeviceAiEngineGeneric.
  ///
  /// In en, this message translates to:
  /// **'On-Device AI'**
  String get onDeviceAiEngineGeneric;

  /// No description provided for @onDeviceAiSummaryReadyBoth.
  ///
  /// In en, this message translates to:
  /// **'Ready on this device ({engineName}) — supports on-device image captioning and bias checking with zero network calls.'**
  String onDeviceAiSummaryReadyBoth(String engineName);

  /// No description provided for @onDeviceAiSummaryReadyDescriberOnly.
  ///
  /// In en, this message translates to:
  /// **'On-device image description ready ({engineName}). Bias checking will use offline heuristics.'**
  String onDeviceAiSummaryReadyDescriberOnly(String engineName);

  /// No description provided for @onDeviceAiSummaryReadyPromptOnly.
  ///
  /// In en, this message translates to:
  /// **'On-device text & multimodal prompting ready ({engineName}).'**
  String onDeviceAiSummaryReadyPromptOnly(String engineName);

  /// No description provided for @onDeviceAiSummaryDownloadable.
  ///
  /// In en, this message translates to:
  /// **'Supported on this device ({engineName}). Tap \"Download On-Device Model\" to provision the OS-managed model.'**
  String onDeviceAiSummaryDownloadable(String engineName);

  /// No description provided for @onDeviceAiSummaryNotYetReady.
  ///
  /// In en, this message translates to:
  /// **'Supported on this device ({engineName}), but not yet enabled. Turn on Apple Intelligence / device AI in system Settings.'**
  String onDeviceAiSummaryNotYetReady(String engineName);

  /// No description provided for @onDeviceAiSummaryUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Not available on this device or simulator ({engineName} requires supported iPhone/Pixel/Samsung flagship hardware). You can use a Cloud API, Local LAN server, or No AI.'**
  String onDeviceAiSummaryUnavailable(String engineName);

  /// No description provided for @onDeviceAiDiagnosticDetail.
  ///
  /// In en, this message translates to:
  /// **'Prompt API: {promptAvailability}{promptDiagnostic}\nImage Description API: {imageAvailability}{imageDiagnostic}'**
  String onDeviceAiDiagnosticDetail(
      String promptAvailability,
      String promptDiagnostic,
      String imageAvailability,
      String imageDiagnostic);

  /// No description provided for @aiProviderOnDeviceLabel.
  ///
  /// In en, this message translates to:
  /// **'On-Device AI (Apple Intelligence / Gemini Nano)'**
  String get aiProviderOnDeviceLabel;

  /// No description provided for @aiProviderGeminiLabel.
  ///
  /// In en, this message translates to:
  /// **'Google Gemini API'**
  String get aiProviderGeminiLabel;

  /// No description provided for @aiProviderOpenAiLabel.
  ///
  /// In en, this message translates to:
  /// **'OpenAI / Compatible API'**
  String get aiProviderOpenAiLabel;

  /// No description provided for @aiProviderAnthropicLabel.
  ///
  /// In en, this message translates to:
  /// **'Anthropic Claude API'**
  String get aiProviderAnthropicLabel;

  /// No description provided for @aiProviderLocalLabel.
  ///
  /// In en, this message translates to:
  /// **'Local Network Server (Ollama / LM Studio LAN)'**
  String get aiProviderLocalLabel;

  /// No description provided for @aiProviderNoneLabel.
  ///
  /// In en, this message translates to:
  /// **'No AI (Manual Alt-Text & Offline Heuristics)'**
  String get aiProviderNoneLabel;

  /// No description provided for @aiModelOnDeviceAuto.
  ///
  /// In en, this message translates to:
  /// **'On-Device Auto (Vision Prompt + Image Describer)'**
  String get aiModelOnDeviceAuto;

  /// No description provided for @aiModelOnDeviceDescriber.
  ///
  /// In en, this message translates to:
  /// **'On-Device Image Describer (Fast Alt-Text)'**
  String get aiModelOnDeviceDescriber;

  /// No description provided for @aiModelOnDevicePrompt.
  ///
  /// In en, this message translates to:
  /// **'On-Device Multimodal Prompt (Custom Detail & Bias)'**
  String get aiModelOnDevicePrompt;

  /// No description provided for @detailLevelConciseLabel.
  ///
  /// In en, this message translates to:
  /// **'Concise'**
  String get detailLevelConciseLabel;

  /// No description provided for @detailLevelConciseGuidance.
  ///
  /// In en, this message translates to:
  /// **'1-2 sentences (150-300 characters)'**
  String get detailLevelConciseGuidance;

  /// No description provided for @detailLevelDescriptiveLabel.
  ///
  /// In en, this message translates to:
  /// **'Descriptive'**
  String get detailLevelDescriptiveLabel;

  /// No description provided for @detailLevelDescriptiveGuidance.
  ///
  /// In en, this message translates to:
  /// **'2-4 sentences (300-700 characters)'**
  String get detailLevelDescriptiveGuidance;

  /// No description provided for @detailLevelDetailedLabel.
  ///
  /// In en, this message translates to:
  /// **'Detailed'**
  String get detailLevelDetailedLabel;

  /// No description provided for @detailLevelDetailedGuidance.
  ///
  /// In en, this message translates to:
  /// **'Comprehensive (600-1200 characters) including layout, lighting, colors, and full text transcription'**
  String get detailLevelDetailedGuidance;

  /// No description provided for @policyModeWarnLabel.
  ///
  /// In en, this message translates to:
  /// **'Warn (Default)'**
  String get policyModeWarnLabel;

  /// No description provided for @policyModeRequireLabel.
  ///
  /// In en, this message translates to:
  /// **'Require'**
  String get policyModeRequireLabel;

  /// No description provided for @policyModeOffLabel.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get policyModeOffLabel;

  /// No description provided for @altPolicyWarnSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Warn before posting uncaptioned media, with options to auto-generate with AI or post anyway.'**
  String get altPolicyWarnSubtitle;

  /// No description provided for @altPolicyRequireSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Strictly require alt-text on all attached media before posting.'**
  String get altPolicyRequireSubtitle;

  /// No description provided for @altPolicyOffSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Do not warn about missing alt-text.'**
  String get altPolicyOffSubtitle;

  /// No description provided for @biasPolicyWarnSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Warn about racial or gender bias before posting; allow editing, suggested wording, or \"Publish Anyway\".'**
  String get biasPolicyWarnSubtitle;

  /// No description provided for @biasPolicyRequireSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Require detected racial or gender bias to be resolved before posting (hides \"Publish Anyway\").'**
  String get biasPolicyRequireSubtitle;

  /// No description provided for @biasPolicyOffSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Skip pre-post racial & gender bias checking and publish immediately.'**
  String get biasPolicyOffSubtitle;

  /// No description provided for @themeSystemLabel.
  ///
  /// In en, this message translates to:
  /// **'System Default (Auto-Detect)'**
  String get themeSystemLabel;

  /// No description provided for @themeDarkLabel.
  ///
  /// In en, this message translates to:
  /// **'Dark Theme'**
  String get themeDarkLabel;

  /// No description provided for @themeLightLabel.
  ///
  /// In en, this message translates to:
  /// **'Light Theme'**
  String get themeLightLabel;

  /// No description provided for @themeHighContrastLabel.
  ///
  /// In en, this message translates to:
  /// **'High Contrast (WCAG AAA)'**
  String get themeHighContrastLabel;

  /// No description provided for @postVisibilityPublicLabel.
  ///
  /// In en, this message translates to:
  /// **'Public'**
  String get postVisibilityPublicLabel;

  /// No description provided for @postVisibilityPublicDesc.
  ///
  /// In en, this message translates to:
  /// **'Visible to everyone and shown in public timelines'**
  String get postVisibilityPublicDesc;

  /// No description provided for @postVisibilityUnlistedLabel.
  ///
  /// In en, this message translates to:
  /// **'Unlisted'**
  String get postVisibilityUnlistedLabel;

  /// No description provided for @postVisibilityUnlistedDesc.
  ///
  /// In en, this message translates to:
  /// **'Visible to everyone, but omitted from public timelines'**
  String get postVisibilityUnlistedDesc;

  /// No description provided for @postVisibilityPrivateLabel.
  ///
  /// In en, this message translates to:
  /// **'Followers Only'**
  String get postVisibilityPrivateLabel;

  /// No description provided for @postVisibilityPrivateDesc.
  ///
  /// In en, this message translates to:
  /// **'Visible only to your followers'**
  String get postVisibilityPrivateDesc;

  /// No description provided for @postVisibilityDirectLabel.
  ///
  /// In en, this message translates to:
  /// **'Mentioned Only'**
  String get postVisibilityDirectLabel;

  /// No description provided for @postVisibilityDirectDesc.
  ///
  /// In en, this message translates to:
  /// **'Visible only to mentioned users'**
  String get postVisibilityDirectDesc;

  /// No description provided for @attachmentStatusScanning.
  ///
  /// In en, this message translates to:
  /// **'AI Scanning...'**
  String get attachmentStatusScanning;

  /// No description provided for @attachmentStatusReady.
  ///
  /// In en, this message translates to:
  /// **'Alt-Text Ready'**
  String get attachmentStatusReady;

  /// No description provided for @attachmentStatusMissingAltText.
  ///
  /// In en, this message translates to:
  /// **'Missing Alt-Text'**
  String get attachmentStatusMissingAltText;

  /// No description provided for @attachmentStatusError.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get attachmentStatusError;

  /// No description provided for @timelineHomeShort.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get timelineHomeShort;

  /// No description provided for @timelineHomeFull.
  ///
  /// In en, this message translates to:
  /// **'Home Timeline'**
  String get timelineHomeFull;

  /// No description provided for @timelineLocalShort.
  ///
  /// In en, this message translates to:
  /// **'Local'**
  String get timelineLocalShort;

  /// No description provided for @timelineLocalFull.
  ///
  /// In en, this message translates to:
  /// **'Local Timeline'**
  String get timelineLocalFull;

  /// No description provided for @timelineFederatedShort.
  ///
  /// In en, this message translates to:
  /// **'Federated'**
  String get timelineFederatedShort;

  /// No description provided for @timelineFederatedFull.
  ///
  /// In en, this message translates to:
  /// **'Federated Timeline'**
  String get timelineFederatedFull;

  /// No description provided for @timelineAlertsShort.
  ///
  /// In en, this message translates to:
  /// **'Alerts'**
  String get timelineAlertsShort;

  /// No description provided for @timelineNotificationsFull.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get timelineNotificationsFull;

  /// No description provided for @timelineBookmarksShort.
  ///
  /// In en, this message translates to:
  /// **'Bookmarks'**
  String get timelineBookmarksShort;

  /// No description provided for @timelineFavoritesShort.
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get timelineFavoritesShort;

  /// No description provided for @timelineMyPostsShort.
  ///
  /// In en, this message translates to:
  /// **'My Posts'**
  String get timelineMyPostsShort;

  /// No description provided for @timelineMyPostsFull.
  ///
  /// In en, this message translates to:
  /// **'My Published Posts'**
  String get timelineMyPostsFull;

  /// No description provided for @homeAnnounceSwitchedTimeline.
  ///
  /// In en, this message translates to:
  /// **'Switched to {title}.'**
  String homeAnnounceSwitchedTimeline(String title);

  /// No description provided for @homeProfileHeaderSemantics.
  ///
  /// In en, this message translates to:
  /// **'{displayName}, {handle}. Tap to view your own published posts.'**
  String homeProfileHeaderSemantics(String displayName, String handle);

  /// No description provided for @homeProfileHeaderTip.
  ///
  /// In en, this message translates to:
  /// **'View your own published posts as {handle} (g u)'**
  String homeProfileHeaderTip(String handle);

  /// No description provided for @homeSearchTooltip.
  ///
  /// In en, this message translates to:
  /// **'Search cached posts and alt-text offline (/)'**
  String get homeSearchTooltip;

  /// No description provided for @homeShortcutsTooltip.
  ///
  /// In en, this message translates to:
  /// **'View keyboard navigation shortcuts (?)'**
  String get homeShortcutsTooltip;

  /// No description provided for @homeSettingsTooltip.
  ///
  /// In en, this message translates to:
  /// **'Open Settings & AI Configuration (⌘,)'**
  String get homeSettingsTooltip;

  /// No description provided for @homeDrawerSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings & AI Configuration'**
  String get homeDrawerSettings;

  /// No description provided for @homeNavHomeTip.
  ///
  /// In en, this message translates to:
  /// **'Home timeline — posts from people you follow (g h)'**
  String get homeNavHomeTip;

  /// No description provided for @homeNavLocalTip.
  ///
  /// In en, this message translates to:
  /// **'Local timeline — public posts from your server (g l)'**
  String get homeNavLocalTip;

  /// No description provided for @homeNavFederatedTip.
  ///
  /// In en, this message translates to:
  /// **'Federated timeline — public posts across the Fediverse (g p)'**
  String get homeNavFederatedTip;

  /// No description provided for @homeNavNotificationsTip.
  ///
  /// In en, this message translates to:
  /// **'Notifications — replies, mentions, boosts, and follows (g n)'**
  String get homeNavNotificationsTip;

  /// No description provided for @homeNavBookmarksTip.
  ///
  /// In en, this message translates to:
  /// **'Bookmarks — posts you saved privately (g b)'**
  String get homeNavBookmarksTip;

  /// No description provided for @homeNavFavoritesTip.
  ///
  /// In en, this message translates to:
  /// **'Favorites — posts you liked (g f)'**
  String get homeNavFavoritesTip;

  /// No description provided for @homeNavMyPostsTip.
  ///
  /// In en, this message translates to:
  /// **'My Published Posts — your own Mastodon posts (g u)'**
  String get homeNavMyPostsTip;

  /// No description provided for @homeComposeTip.
  ///
  /// In en, this message translates to:
  /// **'Compose a new Mastodon post (n or ⌘N)'**
  String get homeComposeTip;

  /// No description provided for @homeComposeLabel.
  ///
  /// In en, this message translates to:
  /// **'Post'**
  String get homeComposeLabel;

  /// No description provided for @searchHint.
  ///
  /// In en, this message translates to:
  /// **'Search {count} cached posts & alt-text…'**
  String searchHint(int count);

  /// No description provided for @searchClearTooltip.
  ///
  /// In en, this message translates to:
  /// **'Clear search'**
  String get searchClearTooltip;

  /// No description provided for @searchEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Offline Local Search ({count} cached posts)'**
  String searchEmptyTitle(int count);

  /// No description provided for @searchEmptyDescription.
  ///
  /// In en, this message translates to:
  /// **'Searches post text, Content Warnings, authors, and media alt-text locally on your device without placing any search load on your Mastodon server.'**
  String get searchEmptyDescription;

  /// No description provided for @searchNoResults.
  ///
  /// In en, this message translates to:
  /// **'No cached posts match \"{query}\".'**
  String searchNoResults(String query);

  /// No description provided for @updateBannerSemantics.
  ///
  /// In en, this message translates to:
  /// **'Update available: FediCaption version {latestVersion}. Currently on {currentVersion}.'**
  String updateBannerSemantics(String latestVersion, String currentVersion);

  /// No description provided for @updateBannerTitle.
  ///
  /// In en, this message translates to:
  /// **'Update Available: v{latestVersion}'**
  String updateBannerTitle(String latestVersion);

  /// No description provided for @updateBannerSubtitle.
  ///
  /// In en, this message translates to:
  /// **'You are running v{currentVersion}. View the latest release on GitHub.'**
  String updateBannerSubtitle(String currentVersion);

  /// No description provided for @updateBannerDismissTooltip.
  ///
  /// In en, this message translates to:
  /// **'Dismiss update notification'**
  String get updateBannerDismissTooltip;

  /// No description provided for @updateAnnounceAvailable.
  ///
  /// In en, this message translates to:
  /// **'Update available: FediCaption version {latestVersion} is now on GitHub.'**
  String updateAnnounceAvailable(String latestVersion);

  /// No description provided for @timelineAnnouncePostSelection.
  ///
  /// In en, this message translates to:
  /// **'Post {index} of {total} by {authorName}. {preview}'**
  String timelineAnnouncePostSelection(
      int index, int total, String authorName, String preview);

  /// No description provided for @timelineAnnounceUpToDate.
  ///
  /// In en, this message translates to:
  /// **'{title} is up to date.'**
  String timelineAnnounceUpToDate(String title);

  /// No description provided for @timelineAnnounceLoadedNew.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Loaded 1 new post in {title}.} other{Loaded {count} new posts in {title}.}}'**
  String timelineAnnounceLoadedNew(int count, String title);

  /// No description provided for @timelineAnnounceLoadedInitial.
  ///
  /// In en, this message translates to:
  /// **'{title} loaded with {count, plural, =1{1 post} other{{count} posts}}.'**
  String timelineAnnounceLoadedInitial(String title, int count);

  /// No description provided for @timelineEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'No posts in {title} yet.'**
  String timelineEmptyMessage(String title);

  /// No description provided for @threadTitle.
  ///
  /// In en, this message translates to:
  /// **'Conversation Thread'**
  String get threadTitle;

  /// No description provided for @threadRepliesHeader.
  ///
  /// In en, this message translates to:
  /// **'Replies ({count})'**
  String threadRepliesHeader(int count);

  /// No description provided for @threadAnnounceSelection.
  ///
  /// In en, this message translates to:
  /// **'Post {index} of {total} by {authorName}.'**
  String threadAnnounceSelection(int index, int total, String authorName);

  /// No description provided for @threadAnnounceLoaded.
  ///
  /// In en, this message translates to:
  /// **'Conversation loaded with {ancestorsCount, plural, =1{1 earlier post} other{{ancestorsCount} earlier posts}} and {repliesCount, plural, =1{1 reply} other{{repliesCount} replies}}.'**
  String threadAnnounceLoaded(int ancestorsCount, int repliesCount);

  /// No description provided for @notificationsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No notifications yet.'**
  String get notificationsEmpty;

  /// No description provided for @notificationsMediaPostPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'(Media post)'**
  String get notificationsMediaPostPlaceholder;

  /// No description provided for @notificationsOpenThreadTip.
  ///
  /// In en, this message translates to:
  /// **'Open conversation thread for this post (Enter)'**
  String get notificationsOpenThreadTip;

  /// No description provided for @notificationsAnnounceSelection.
  ///
  /// In en, this message translates to:
  /// **'Notification {index} of {total}: {summary}.'**
  String notificationsAnnounceSelection(int index, int total, String summary);

  /// No description provided for @notificationsAnnounceUpToDate.
  ///
  /// In en, this message translates to:
  /// **'Notifications are up to date.'**
  String get notificationsAnnounceUpToDate;

  /// No description provided for @notificationsAnnounceLoadedNew.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Loaded 1 new notification.} other{Loaded {count} new notifications.}}'**
  String notificationsAnnounceLoadedNew(int count);

  /// No description provided for @notificationsAnnounceLoadedInitial.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Loaded 1 notification.} other{Loaded {count} notifications.}}'**
  String notificationsAnnounceLoadedInitial(int count);

  /// No description provided for @notificationMentionSummary.
  ///
  /// In en, this message translates to:
  /// **'{author} mentioned you'**
  String notificationMentionSummary(String author);

  /// No description provided for @notificationReblogSummary.
  ///
  /// In en, this message translates to:
  /// **'{author} boosted your post'**
  String notificationReblogSummary(String author);

  /// No description provided for @notificationFavouriteSummary.
  ///
  /// In en, this message translates to:
  /// **'{author} favorited your post'**
  String notificationFavouriteSummary(String author);

  /// No description provided for @notificationFollowSummary.
  ///
  /// In en, this message translates to:
  /// **'{author} followed you'**
  String notificationFollowSummary(String author);

  /// No description provided for @notificationFollowRequestSummary.
  ///
  /// In en, this message translates to:
  /// **'{author} requested to follow you'**
  String notificationFollowRequestSummary(String author);

  /// No description provided for @notificationStatusSummary.
  ///
  /// In en, this message translates to:
  /// **'{author} published a new post'**
  String notificationStatusSummary(String author);

  /// No description provided for @notificationUpdateSummary.
  ///
  /// In en, this message translates to:
  /// **'{author} edited a post'**
  String notificationUpdateSummary(String author);

  /// No description provided for @notificationPollSummary.
  ///
  /// In en, this message translates to:
  /// **'{author}: a poll you participated in has ended'**
  String notificationPollSummary(String author);

  /// No description provided for @notificationQuoteSummary.
  ///
  /// In en, this message translates to:
  /// **'{author} quoted your post'**
  String notificationQuoteSummary(String author);

  /// No description provided for @notificationQuotedUpdateSummary.
  ///
  /// In en, this message translates to:
  /// **'{author} edited a post you quoted'**
  String notificationQuotedUpdateSummary(String author);

  /// No description provided for @notificationGenericSummary.
  ///
  /// In en, this message translates to:
  /// **'{author} ({type})'**
  String notificationGenericSummary(String author, String type);

  /// No description provided for @avatarViewProfileSemantics.
  ///
  /// In en, this message translates to:
  /// **'View profile and posts by {displayName}'**
  String avatarViewProfileSemantics(String displayName);

  /// No description provided for @linkMentionSemantics.
  ///
  /// In en, this message translates to:
  /// **'Mention {handle}'**
  String linkMentionSemantics(String handle);

  /// No description provided for @linkUrlSemantics.
  ///
  /// In en, this message translates to:
  /// **'Link {label}'**
  String linkUrlSemantics(String label);

  /// No description provided for @profileTitle.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profileTitle;

  /// No description provided for @profileFollowsYou.
  ///
  /// In en, this message translates to:
  /// **'Follows you'**
  String get profileFollowsYou;

  /// No description provided for @profileSubscribeSemantics.
  ///
  /// In en, this message translates to:
  /// **'Subscribe to {displayName}'**
  String profileSubscribeSemantics(String displayName);

  /// No description provided for @profileUnsubscribeSemantics.
  ///
  /// In en, this message translates to:
  /// **'Unsubscribe from {displayName}'**
  String profileUnsubscribeSemantics(String displayName);

  /// No description provided for @profileRequestedSemantics.
  ///
  /// In en, this message translates to:
  /// **'Follow request pending'**
  String get profileRequestedSemantics;

  /// No description provided for @profileSubscribe.
  ///
  /// In en, this message translates to:
  /// **'Subscribe'**
  String get profileSubscribe;

  /// No description provided for @profileUnsubscribe.
  ///
  /// In en, this message translates to:
  /// **'Unsubscribe'**
  String get profileUnsubscribe;

  /// No description provided for @profileRequested.
  ///
  /// In en, this message translates to:
  /// **'Requested'**
  String get profileRequested;

  /// No description provided for @profileEnableNotifySemantics.
  ///
  /// In en, this message translates to:
  /// **'Enable post notifications for {displayName}'**
  String profileEnableNotifySemantics(String displayName);

  /// No description provided for @profileDisableNotifySemantics.
  ///
  /// In en, this message translates to:
  /// **'Disable post notifications for {displayName}'**
  String profileDisableNotifySemantics(String displayName);

  /// No description provided for @profileNotifyOnTooltip.
  ///
  /// In en, this message translates to:
  /// **'Notifications On (tap to disable)'**
  String get profileNotifyOnTooltip;

  /// No description provided for @profileNotifyOffTooltip.
  ///
  /// In en, this message translates to:
  /// **'Notifications Off (tap to enable)'**
  String get profileNotifyOffTooltip;

  /// No description provided for @profilePostsCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 Post} other{{count} Posts}}'**
  String profilePostsCount(int count);

  /// No description provided for @profileFollowingCount.
  ///
  /// In en, this message translates to:
  /// **'{count} Following'**
  String profileFollowingCount(int count);

  /// No description provided for @profileFollowersCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 Follower} other{{count} Followers}}'**
  String profileFollowersCount(int count);

  /// No description provided for @profileEmptyPosts.
  ///
  /// In en, this message translates to:
  /// **'No posts published yet.'**
  String get profileEmptyPosts;

  /// No description provided for @profileAnnounceLoaded.
  ///
  /// In en, this message translates to:
  /// **'Loaded profile for {displayName} with {count, plural, =1{1 post} other{{count} posts}}.'**
  String profileAnnounceLoaded(String displayName, int count);

  /// No description provided for @profileAnnounceSubscribed.
  ///
  /// In en, this message translates to:
  /// **'Subscribed to {displayName}.'**
  String profileAnnounceSubscribed(String displayName);

  /// No description provided for @profileAnnounceUnsubscribed.
  ///
  /// In en, this message translates to:
  /// **'Unsubscribed from {displayName}.'**
  String profileAnnounceUnsubscribed(String displayName);

  /// No description provided for @profileErrorSubscription.
  ///
  /// In en, this message translates to:
  /// **'Failed to update subscription: {error}'**
  String profileErrorSubscription(String error);

  /// No description provided for @profileAnnounceNotifyEnabled.
  ///
  /// In en, this message translates to:
  /// **'Notifications enabled for {displayName}.'**
  String profileAnnounceNotifyEnabled(String displayName);

  /// No description provided for @profileAnnounceNotifyDisabled.
  ///
  /// In en, this message translates to:
  /// **'Notifications disabled for {displayName}.'**
  String profileAnnounceNotifyDisabled(String displayName);

  /// No description provided for @profileErrorNotifications.
  ///
  /// In en, this message translates to:
  /// **'Failed to update notifications: {error}'**
  String profileErrorNotifications(String error);

  /// No description provided for @statusBoostedSemantics.
  ///
  /// In en, this message translates to:
  /// **'Boosted by {displayName}. Tap to view profile.'**
  String statusBoostedSemantics(String displayName);

  /// No description provided for @statusBoostedTip.
  ///
  /// In en, this message translates to:
  /// **'View profile of {displayName} (who boosted this post)'**
  String statusBoostedTip(String displayName);

  /// No description provided for @statusBoostedLabel.
  ///
  /// In en, this message translates to:
  /// **'{displayName} boosted'**
  String statusBoostedLabel(String displayName);

  /// No description provided for @statusOpenThreadTip.
  ///
  /// In en, this message translates to:
  /// **'Open post and conversation thread (Enter)'**
  String get statusOpenThreadTip;

  /// No description provided for @statusEditedAt.
  ///
  /// In en, this message translates to:
  /// **'Edited {relativeTime}'**
  String statusEditedAt(String relativeTime);

  /// No description provided for @statusReplySemantics.
  ///
  /// In en, this message translates to:
  /// **'Reply to {displayName} ({count, plural, =1{1 reply} other{{count} replies}})'**
  String statusReplySemantics(String displayName, int count);

  /// No description provided for @statusUnboostSemantics.
  ///
  /// In en, this message translates to:
  /// **'Unboost post ({count, plural, =1{1 boost} other{{count} boosts}})'**
  String statusUnboostSemantics(int count);

  /// No description provided for @statusBoostSemantics.
  ///
  /// In en, this message translates to:
  /// **'Boost post ({count, plural, =1{1 boost} other{{count} boosts}})'**
  String statusBoostSemantics(int count);

  /// No description provided for @statusUnfavoriteSemantics.
  ///
  /// In en, this message translates to:
  /// **'Unfavorite post ({count, plural, =1{1 favorite} other{{count} favorites}})'**
  String statusUnfavoriteSemantics(int count);

  /// No description provided for @statusFavoriteSemantics.
  ///
  /// In en, this message translates to:
  /// **'Favorite post ({count, plural, =1{1 favorite} other{{count} favorites}})'**
  String statusFavoriteSemantics(int count);

  /// No description provided for @statusRemoveBookmarkSemantics.
  ///
  /// In en, this message translates to:
  /// **'Remove bookmark'**
  String get statusRemoveBookmarkSemantics;

  /// No description provided for @statusBookmarkSemantics.
  ///
  /// In en, this message translates to:
  /// **'Bookmark post'**
  String get statusBookmarkSemantics;

  /// No description provided for @statusThreadActionLabel.
  ///
  /// In en, this message translates to:
  /// **'Thread'**
  String get statusThreadActionLabel;

  /// No description provided for @statusThreadActionSemantics.
  ///
  /// In en, this message translates to:
  /// **'View conversation thread'**
  String get statusThreadActionSemantics;

  /// No description provided for @statusEditActionLabel.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get statusEditActionLabel;

  /// No description provided for @statusEditActionSemantics.
  ///
  /// In en, this message translates to:
  /// **'Edit your post and media alt text'**
  String get statusEditActionSemantics;

  /// No description provided for @statusDeleteActionSemantics.
  ///
  /// In en, this message translates to:
  /// **'Delete your post'**
  String get statusDeleteActionSemantics;

  /// No description provided for @statusAnnounceTranslated.
  ///
  /// In en, this message translates to:
  /// **'Post translated to {language} using {engineName}.'**
  String statusAnnounceTranslated(String language, String engineName);

  /// No description provided for @statusReadAloudPostSemantics.
  ///
  /// In en, this message translates to:
  /// **'Read post and all alt text aloud'**
  String get statusReadAloudPostSemantics;

  /// No description provided for @statusStopReadingPostSemantics.
  ///
  /// In en, this message translates to:
  /// **'Stop reading post aloud'**
  String get statusStopReadingPostSemantics;

  /// No description provided for @statusReadAloudPostTip.
  ///
  /// In en, this message translates to:
  /// **'Read this post and all its alt-text aloud using text-to-speech'**
  String get statusReadAloudPostTip;

  /// No description provided for @statusStopReadingPostTip.
  ///
  /// In en, this message translates to:
  /// **'Stop reading this post aloud'**
  String get statusStopReadingPostTip;

  /// No description provided for @statusReadAloudContentWarning.
  ///
  /// In en, this message translates to:
  /// **'Content warning: {spoilerText}'**
  String statusReadAloudContentWarning(String spoilerText);

  /// No description provided for @statusReadAloudImageAlt.
  ///
  /// In en, this message translates to:
  /// **'Image description: {altText}'**
  String statusReadAloudImageAlt(String altText);

  /// No description provided for @statusReadAloudVideoAlt.
  ///
  /// In en, this message translates to:
  /// **'Video description: {altText}'**
  String statusReadAloudVideoAlt(String altText);

  /// No description provided for @statusReadAloudImageAltNumbered.
  ///
  /// In en, this message translates to:
  /// **'Image {index} description: {altText}'**
  String statusReadAloudImageAltNumbered(int index, String altText);

  /// No description provided for @statusReadAloudVideoAltNumbered.
  ///
  /// In en, this message translates to:
  /// **'Video {index} description: {altText}'**
  String statusReadAloudVideoAltNumbered(int index, String altText);

  /// No description provided for @statusReadAloudQuotedPost.
  ///
  /// In en, this message translates to:
  /// **'Quoted post by {author}'**
  String statusReadAloudQuotedPost(String author);

  /// No description provided for @statusHeaderSemantics.
  ///
  /// In en, this message translates to:
  /// **'{displayName}, {handle}. Tap to view posts.'**
  String statusHeaderSemantics(String displayName, String handle);

  /// No description provided for @statusQuotedTimestampSemantics.
  ///
  /// In en, this message translates to:
  /// **'Quoted post from {verboseTime}. Open original post in external browser.'**
  String statusQuotedTimestampSemantics(String verboseTime);

  /// No description provided for @statusTimestampSemantics.
  ///
  /// In en, this message translates to:
  /// **'Posted {verboseTime}. Open original post in external browser.'**
  String statusTimestampSemantics(String verboseTime);

  /// No description provided for @statusTimestampTip.
  ///
  /// In en, this message translates to:
  /// **'Open original post in web browser ({verboseTime})'**
  String statusTimestampTip(String verboseTime);

  /// No description provided for @cwBannerText.
  ///
  /// In en, this message translates to:
  /// **'CW: {spoilerText}'**
  String cwBannerText(String spoilerText);

  /// No description provided for @cwHideSemantics.
  ///
  /// In en, this message translates to:
  /// **'Hide content behind content warning'**
  String get cwHideSemantics;

  /// No description provided for @cwShowSemantics.
  ///
  /// In en, this message translates to:
  /// **'Show content behind content warning'**
  String get cwShowSemantics;

  /// No description provided for @cwHideTip.
  ///
  /// In en, this message translates to:
  /// **'Hide post content behind Content Warning (x)'**
  String get cwHideTip;

  /// No description provided for @cwShowTip.
  ///
  /// In en, this message translates to:
  /// **'Reveal post content behind Content Warning (x)'**
  String get cwShowTip;

  /// No description provided for @quotedPostLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading quoted post…'**
  String get quotedPostLoading;

  /// No description provided for @quotedPostLoadError.
  ///
  /// In en, this message translates to:
  /// **'Quoted post could not be loaded in-app'**
  String get quotedPostLoadError;

  /// No description provided for @quotedPostSemantics.
  ///
  /// In en, this message translates to:
  /// **'Quoted post by {displayName}, {handle}.'**
  String quotedPostSemantics(String displayName, String handle);

  /// No description provided for @quotedPostBadge.
  ///
  /// In en, this message translates to:
  /// **'Quoted Post'**
  String get quotedPostBadge;

  /// No description provided for @translationTranslatingStatus.
  ///
  /// In en, this message translates to:
  /// **'Translating from {sourceLanguage} to {targetLanguage}…'**
  String translationTranslatingStatus(
      String sourceLanguage, String targetLanguage);

  /// No description provided for @translationTranslatedStatus.
  ///
  /// In en, this message translates to:
  /// **'Translated from {sourceLanguage} via {engineName}'**
  String translationTranslatedStatus(String sourceLanguage, String engineName);

  /// No description provided for @translationWrittenInStatus.
  ///
  /// In en, this message translates to:
  /// **'Written in {sourceLanguage}'**
  String translationWrittenInStatus(String sourceLanguage);

  /// No description provided for @translationShowOriginalTip.
  ///
  /// In en, this message translates to:
  /// **'Switch back to the original {sourceLanguage} post and alt-text'**
  String translationShowOriginalTip(String sourceLanguage);

  /// No description provided for @translationShowTranslatedTip.
  ///
  /// In en, this message translates to:
  /// **'Show the translated {targetLanguage} post and alt-text'**
  String translationShowTranslatedTip(String targetLanguage);

  /// No description provided for @translationShowOriginalButton.
  ///
  /// In en, this message translates to:
  /// **'Show Original'**
  String get translationShowOriginalButton;

  /// No description provided for @translationShowTranslatedButton.
  ///
  /// In en, this message translates to:
  /// **'Show Translation'**
  String get translationShowTranslatedButton;

  /// No description provided for @translationTranslateTip.
  ///
  /// In en, this message translates to:
  /// **'Translate this {sourceLanguage} post and its media alt-text into {targetLanguage} on-device'**
  String translationTranslateTip(String sourceLanguage, String targetLanguage);

  /// No description provided for @translationTranslateButton.
  ///
  /// In en, this message translates to:
  /// **'Translate to {targetLanguage}'**
  String translationTranslateButton(String targetLanguage);

  /// No description provided for @mediaVideoBadge.
  ///
  /// In en, this message translates to:
  /// **'VIDEO'**
  String get mediaVideoBadge;

  /// No description provided for @mediaVideoWithAltSemantics.
  ///
  /// In en, this message translates to:
  /// **'Video: {altText} Tap to play video.'**
  String mediaVideoWithAltSemantics(String altText);

  /// No description provided for @mediaImageWithAltSemantics.
  ///
  /// In en, this message translates to:
  /// **'Image: {altText} Tap to view full image.'**
  String mediaImageWithAltSemantics(String altText);

  /// No description provided for @mediaVideoNoAltSemantics.
  ///
  /// In en, this message translates to:
  /// **'Video with no alt text provided. Tap to play video.'**
  String get mediaVideoNoAltSemantics;

  /// No description provided for @mediaImageNoAltSemantics.
  ///
  /// In en, this message translates to:
  /// **'Image with no alt text provided. Tap to view full image.'**
  String get mediaImageNoAltSemantics;

  /// No description provided for @mediaVideoOpenTip.
  ///
  /// In en, this message translates to:
  /// **'Play embedded video in full-screen player'**
  String get mediaVideoOpenTip;

  /// No description provided for @mediaImageOpenTip.
  ///
  /// In en, this message translates to:
  /// **'View full-size image with zoom and share options'**
  String get mediaImageOpenTip;

  /// No description provided for @mediaAltProvidedBadge.
  ///
  /// In en, this message translates to:
  /// **'ALT TEXT PROVIDED'**
  String get mediaAltProvidedBadge;

  /// No description provided for @mediaNoAltBadge.
  ///
  /// In en, this message translates to:
  /// **'NO ALT TEXT'**
  String get mediaNoAltBadge;

  /// No description provided for @mediaCollapseAltSemantics.
  ///
  /// In en, this message translates to:
  /// **'Collapse alt text box'**
  String get mediaCollapseAltSemantics;

  /// No description provided for @mediaExpandAltSemantics.
  ///
  /// In en, this message translates to:
  /// **'Expand alt text box'**
  String get mediaExpandAltSemantics;

  /// No description provided for @mediaAuthorAltTranslatedHeading.
  ///
  /// In en, this message translates to:
  /// **'Author Alt-Text (Translated):'**
  String get mediaAuthorAltTranslatedHeading;

  /// No description provided for @mediaAuthorAltHeading.
  ///
  /// In en, this message translates to:
  /// **'Author Alt-Text:'**
  String get mediaAuthorAltHeading;

  /// No description provided for @mediaOnDemandAiHeading.
  ///
  /// In en, this message translates to:
  /// **'On-Demand AI Description:'**
  String get mediaOnDemandAiHeading;

  /// No description provided for @mediaDescribingSemantics.
  ///
  /// In en, this message translates to:
  /// **'Generating AI description'**
  String get mediaDescribingSemantics;

  /// No description provided for @mediaRedescribeSemantics.
  ///
  /// In en, this message translates to:
  /// **'Re-describe media with AI'**
  String get mediaRedescribeSemantics;

  /// No description provided for @mediaDescribeSemantics.
  ///
  /// In en, this message translates to:
  /// **'Describe media with AI'**
  String get mediaDescribeSemantics;

  /// No description provided for @mediaDescribeTip.
  ///
  /// In en, this message translates to:
  /// **'Generate an AI alt-text description for this media attachment'**
  String get mediaDescribeTip;

  /// No description provided for @mediaDescribingButton.
  ///
  /// In en, this message translates to:
  /// **'Describing…'**
  String get mediaDescribingButton;

  /// No description provided for @mediaRedescribeButton.
  ///
  /// In en, this message translates to:
  /// **'Re-Describe with AI'**
  String get mediaRedescribeButton;

  /// No description provided for @mediaDescribeButton.
  ///
  /// In en, this message translates to:
  /// **'Describe with AI'**
  String get mediaDescribeButton;

  /// No description provided for @mediaStopReadingSemantics.
  ///
  /// In en, this message translates to:
  /// **'Stop reading alt text aloud'**
  String get mediaStopReadingSemantics;

  /// No description provided for @mediaReadAloudSemantics.
  ///
  /// In en, this message translates to:
  /// **'Read alt text aloud'**
  String get mediaReadAloudSemantics;

  /// No description provided for @mediaStopReadingTip.
  ///
  /// In en, this message translates to:
  /// **'Stop reading alt-text aloud'**
  String get mediaStopReadingTip;

  /// No description provided for @mediaReadAloudTip.
  ///
  /// In en, this message translates to:
  /// **'Read this alt-text description aloud using text-to-speech'**
  String get mediaReadAloudTip;

  /// No description provided for @mediaStopReadingButton.
  ///
  /// In en, this message translates to:
  /// **'Stop Reading'**
  String get mediaStopReadingButton;

  /// No description provided for @mediaReadAloudButton.
  ///
  /// In en, this message translates to:
  /// **'Read Aloud'**
  String get mediaReadAloudButton;

  /// No description provided for @mediaAiAnnounceGenerating.
  ///
  /// In en, this message translates to:
  /// **'Generating AI description for media.'**
  String get mediaAiAnnounceGenerating;

  /// No description provided for @mediaAiAnnounceReady.
  ///
  /// In en, this message translates to:
  /// **'AI description ready. {caption}'**
  String mediaAiAnnounceReady(String caption);

  /// No description provided for @mediaAiAnnounceFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to generate AI description.'**
  String get mediaAiAnnounceFailed;

  /// No description provided for @imageViewerTitle.
  ///
  /// In en, this message translates to:
  /// **'Full Image'**
  String get imageViewerTitle;

  /// No description provided for @imageViewerCloseTooltip.
  ///
  /// In en, this message translates to:
  /// **'Close full-screen image'**
  String get imageViewerCloseTooltip;

  /// No description provided for @imageViewerShareTooltip.
  ///
  /// In en, this message translates to:
  /// **'Share or save image'**
  String get imageViewerShareTooltip;

  /// No description provided for @imageViewerInvalidUrl.
  ///
  /// In en, this message translates to:
  /// **'Invalid image URL.'**
  String get imageViewerInvalidUrl;

  /// No description provided for @imageViewerAnnounceShare.
  ///
  /// In en, this message translates to:
  /// **'Opening share menu.'**
  String get imageViewerAnnounceShare;

  /// No description provided for @imageViewerShareError.
  ///
  /// In en, this message translates to:
  /// **'Could not share image: {error}'**
  String imageViewerShareError(String error);

  /// No description provided for @imageViewerWithAltSemantics.
  ///
  /// In en, this message translates to:
  /// **'Full image: {altText} Long press to share or save.'**
  String imageViewerWithAltSemantics(String altText);

  /// No description provided for @imageViewerNoAltSemantics.
  ///
  /// In en, this message translates to:
  /// **'Full image with no alt text provided. Long press to share or save.'**
  String get imageViewerNoAltSemantics;

  /// No description provided for @imageViewerLoadError.
  ///
  /// In en, this message translates to:
  /// **'Could not load full image.'**
  String get imageViewerLoadError;

  /// No description provided for @videoPlayerInvalidUrl.
  ///
  /// In en, this message translates to:
  /// **'Invalid video URL.'**
  String get videoPlayerInvalidUrl;

  /// No description provided for @videoPlayerError.
  ///
  /// In en, this message translates to:
  /// **'Could not play video: {error}'**
  String videoPlayerError(String error);

  /// No description provided for @videoPlayerAnnouncePlayingVideo.
  ///
  /// In en, this message translates to:
  /// **'Playing video.'**
  String get videoPlayerAnnouncePlayingVideo;

  /// No description provided for @videoPlayerAnnouncePaused.
  ///
  /// In en, this message translates to:
  /// **'Paused.'**
  String get videoPlayerAnnouncePaused;

  /// No description provided for @videoPlayerAnnouncePlaying.
  ///
  /// In en, this message translates to:
  /// **'Playing.'**
  String get videoPlayerAnnouncePlaying;

  /// No description provided for @videoPlayerAnnounceMuted.
  ///
  /// In en, this message translates to:
  /// **'Muted.'**
  String get videoPlayerAnnounceMuted;

  /// No description provided for @videoPlayerAnnounceUnmuted.
  ///
  /// In en, this message translates to:
  /// **'Unmuted.'**
  String get videoPlayerAnnounceUnmuted;

  /// No description provided for @videoPlayerCloseTooltip.
  ///
  /// In en, this message translates to:
  /// **'Close video player'**
  String get videoPlayerCloseTooltip;

  /// No description provided for @videoPlayerTitleGifv.
  ///
  /// In en, this message translates to:
  /// **'GIF Video'**
  String get videoPlayerTitleGifv;

  /// No description provided for @videoPlayerTitleVideo.
  ///
  /// In en, this message translates to:
  /// **'Video'**
  String get videoPlayerTitleVideo;

  /// No description provided for @videoPlayerOpenBrowserTooltip.
  ///
  /// In en, this message translates to:
  /// **'Open video in browser'**
  String get videoPlayerOpenBrowserTooltip;

  /// No description provided for @videoPlayerOpenBrowserButton.
  ///
  /// In en, this message translates to:
  /// **'Open in Browser'**
  String get videoPlayerOpenBrowserButton;

  /// No description provided for @videoPlayerPauseTooltip.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get videoPlayerPauseTooltip;

  /// No description provided for @videoPlayerPlayTooltip.
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get videoPlayerPlayTooltip;

  /// No description provided for @videoPlayerUnmuteTooltip.
  ///
  /// In en, this message translates to:
  /// **'Unmute'**
  String get videoPlayerUnmuteTooltip;

  /// No description provided for @videoPlayerMuteTooltip.
  ///
  /// In en, this message translates to:
  /// **'Mute'**
  String get videoPlayerMuteTooltip;

  /// No description provided for @composerCheckingBias.
  ///
  /// In en, this message translates to:
  /// **'Checking Bias…'**
  String get composerCheckingBias;

  /// No description provided for @composerSaving.
  ///
  /// In en, this message translates to:
  /// **'Saving…'**
  String get composerSaving;

  /// No description provided for @composerPublishing.
  ///
  /// In en, this message translates to:
  /// **'Publishing…'**
  String get composerPublishing;

  /// No description provided for @composerSaveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save Changes'**
  String get composerSaveChanges;

  /// No description provided for @composerPublish.
  ///
  /// In en, this message translates to:
  /// **'Publish'**
  String get composerPublish;

  /// No description provided for @composerTitleEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit Post'**
  String get composerTitleEdit;

  /// No description provided for @composerTitleReply.
  ///
  /// In en, this message translates to:
  /// **'Reply'**
  String get composerTitleReply;

  /// No description provided for @composerTitleNew.
  ///
  /// In en, this message translates to:
  /// **'Compose Post'**
  String get composerTitleNew;

  /// No description provided for @composerEditSubmitTip.
  ///
  /// In en, this message translates to:
  /// **'Save your edited post and alt-text (⌘Enter)'**
  String get composerEditSubmitTip;

  /// No description provided for @composerPublishSubmitTip.
  ///
  /// In en, this message translates to:
  /// **'Check accessibility and bias rules, then publish post (⌘Enter)'**
  String get composerPublishSubmitTip;

  /// No description provided for @composerReplyingTo.
  ///
  /// In en, this message translates to:
  /// **'Replying to {handle}'**
  String composerReplyingTo(String handle);

  /// No description provided for @composerCwSwitchTitle.
  ///
  /// In en, this message translates to:
  /// **'Content Warning / Spoiler'**
  String get composerCwSwitchTitle;

  /// No description provided for @composerCwSwitchSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Included in character counter and pre-post bias check.'**
  String get composerCwSwitchSubtitle;

  /// No description provided for @composerCwLabel.
  ///
  /// In en, this message translates to:
  /// **'Content Warning'**
  String get composerCwLabel;

  /// No description provided for @composerCwHint.
  ///
  /// In en, this message translates to:
  /// **'Brief summary or topic warning'**
  String get composerCwHint;

  /// No description provided for @composerBodyLabel.
  ///
  /// In en, this message translates to:
  /// **'What is on your mind?'**
  String get composerBodyLabel;

  /// No description provided for @composerBodyHint.
  ///
  /// In en, this message translates to:
  /// **'Write your Mastodon post…'**
  String get composerBodyHint;

  /// No description provided for @composerCharsRemainingSemantics.
  ///
  /// In en, this message translates to:
  /// **'{remaining} characters remaining out of {maxCharacters} maximum.'**
  String composerCharsRemainingSemantics(int remaining, int maxCharacters);

  /// No description provided for @composerCharsCounter.
  ///
  /// In en, this message translates to:
  /// **'{used} / {maxCharacters} chars ({remaining} remaining)'**
  String composerCharsCounter(int used, int maxCharacters, int remaining);

  /// No description provided for @composerVisibilityLabel.
  ///
  /// In en, this message translates to:
  /// **'Post Visibility'**
  String get composerVisibilityLabel;

  /// No description provided for @composerVisibilityItem.
  ///
  /// In en, this message translates to:
  /// **'{label} — {description}'**
  String composerVisibilityItem(String label, String description);

  /// No description provided for @composerAttachmentsHeader.
  ///
  /// In en, this message translates to:
  /// **'Media Attachments ({count} / {maxCount})'**
  String composerAttachmentsHeader(int count, int maxCount);

  /// No description provided for @composerCameraTip.
  ///
  /// In en, this message translates to:
  /// **'Take a photo with your camera and auto-generate alt-text'**
  String get composerCameraTip;

  /// No description provided for @composerCameraLabel.
  ///
  /// In en, this message translates to:
  /// **'Camera'**
  String get composerCameraLabel;

  /// No description provided for @composerPhotoLibraryTip.
  ///
  /// In en, this message translates to:
  /// **'Choose a photo from your library (EXIF stripped & resized automatically)'**
  String get composerPhotoLibraryTip;

  /// No description provided for @composerPhotoLibraryLabel.
  ///
  /// In en, this message translates to:
  /// **'Photo Library'**
  String get composerPhotoLibraryLabel;

  /// No description provided for @composerVideoTip.
  ///
  /// In en, this message translates to:
  /// **'Choose a video to attach and auto-generate alt-text'**
  String get composerVideoTip;

  /// No description provided for @composerVideoLabel.
  ///
  /// In en, this message translates to:
  /// **'Video'**
  String get composerVideoLabel;

  /// No description provided for @composerFilePickerTip.
  ///
  /// In en, this message translates to:
  /// **'Pick an image or video file from disk (EXIF stripped & resized automatically)'**
  String get composerFilePickerTip;

  /// No description provided for @composerFilePickerLabel.
  ///
  /// In en, this message translates to:
  /// **'File Picker'**
  String get composerFilePickerLabel;

  /// No description provided for @composerAttachmentVideoLabel.
  ///
  /// In en, this message translates to:
  /// **'Attachment {index} (Video)'**
  String composerAttachmentVideoLabel(int index);

  /// No description provided for @composerAttachmentImageLabel.
  ///
  /// In en, this message translates to:
  /// **'Attachment {index} (Image)'**
  String composerAttachmentImageLabel(int index);

  /// No description provided for @composerRemoveAttachmentTooltip.
  ///
  /// In en, this message translates to:
  /// **'Remove attachment {index}'**
  String composerRemoveAttachmentTooltip(int index);

  /// No description provided for @composerAltTextLabel.
  ///
  /// In en, this message translates to:
  /// **'Alt-Text Description'**
  String get composerAltTextLabel;

  /// No description provided for @composerAltTextHintVideo.
  ///
  /// In en, this message translates to:
  /// **'Describe this video for screen-reader users…'**
  String get composerAltTextHintVideo;

  /// No description provided for @composerAltTextHintImage.
  ///
  /// In en, this message translates to:
  /// **'Describe this image for screen-reader users…'**
  String get composerAltTextHintImage;

  /// No description provided for @composerAltTextCounterHelper.
  ///
  /// In en, this message translates to:
  /// **'{current} / {max} chars'**
  String composerAltTextCounterHelper(int current, int max);

  /// No description provided for @composerDetailLevelLabel.
  ///
  /// In en, this message translates to:
  /// **'Detail Level'**
  String get composerDetailLevelLabel;

  /// No description provided for @composerRescanButton.
  ///
  /// In en, this message translates to:
  /// **'Re-Scan with AI'**
  String get composerRescanButton;

  /// No description provided for @composerScanningButton.
  ///
  /// In en, this message translates to:
  /// **'AI Scanning…'**
  String get composerScanningButton;

  /// No description provided for @composerErrorFallbackEditSource.
  ///
  /// In en, this message translates to:
  /// **'Loaded fallback post text (could not fetch raw source: {error})'**
  String composerErrorFallbackEditSource(String error);

  /// No description provided for @composerErrorMaxMedia.
  ///
  /// In en, this message translates to:
  /// **'Maximum of {maxMedia} media attachments reached.'**
  String composerErrorMaxMedia(int maxMedia);

  /// No description provided for @composerErrorNotSignedIn.
  ///
  /// In en, this message translates to:
  /// **'Not signed in to Mastodon.'**
  String get composerErrorNotSignedIn;

  /// No description provided for @composerAnnounceScanningVideo.
  ///
  /// In en, this message translates to:
  /// **'AI scanning video attachment {index}.'**
  String composerAnnounceScanningVideo(int index);

  /// No description provided for @composerAnnounceScanningImage.
  ///
  /// In en, this message translates to:
  /// **'AI scanning image attachment {index}.'**
  String composerAnnounceScanningImage(int index);

  /// No description provided for @composerAnnounceAltReady.
  ///
  /// In en, this message translates to:
  /// **'Alt-text ready for attachment {index}.'**
  String composerAnnounceAltReady(int index);

  /// No description provided for @composerAnnounceAltError.
  ///
  /// In en, this message translates to:
  /// **'Error generating alt-text for attachment {index}.'**
  String composerAnnounceAltError(int index);

  /// No description provided for @composerAnnounceCheckingBias.
  ///
  /// In en, this message translates to:
  /// **'Checking post, media, links, and context for racial or gender bias.'**
  String get composerAnnounceCheckingBias;

  /// No description provided for @composerAnnounceBiasReview.
  ///
  /// In en, this message translates to:
  /// **'Pre-post bias review: {summary}'**
  String composerAnnounceBiasReview(String summary);

  /// No description provided for @composerAnnounceUpdated.
  ///
  /// In en, this message translates to:
  /// **'Post updated successfully.'**
  String get composerAnnounceUpdated;

  /// No description provided for @composerAnnouncePublished.
  ///
  /// In en, this message translates to:
  /// **'Post published successfully.'**
  String get composerAnnouncePublished;

  /// No description provided for @composerAnnouncePublishFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to publish post.'**
  String get composerAnnouncePublishFailed;

  /// No description provided for @missingAltTextTitleRequire.
  ///
  /// In en, this message translates to:
  /// **'Alt-Text Required Before Posting'**
  String get missingAltTextTitleRequire;

  /// No description provided for @missingAltTextTitleWarn.
  ///
  /// In en, this message translates to:
  /// **'Missing Media Alt-Text'**
  String get missingAltTextTitleWarn;

  /// No description provided for @missingAltTextBodyWarnAi.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 media attachment is missing an alt-text description for blind and low-vision readers. Would you like to auto-generate descriptions with AI before posting?} other{{count} media attachments are missing an alt-text description for blind and low-vision readers. Would you like to auto-generate descriptions with AI before posting?}}'**
  String missingAltTextBodyWarnAi(int count);

  /// No description provided for @missingAltTextBodyWarnManual.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 media attachment is missing an alt-text description for blind and low-vision readers. Would you like to add alt-text in the composer before posting?} other{{count} media attachments are missing an alt-text description for blind and low-vision readers. Would you like to add alt-text in the composer before posting?}}'**
  String missingAltTextBodyWarnManual(int count);

  /// No description provided for @missingAltTextBodyRequire.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 media attachment is missing an alt-text description for blind and low-vision readers. Your Accessibility Rules policy requires alt-text on all attached media before posting.} other{{count} media attachments are missing an alt-text description for blind and low-vision readers. Your Accessibility Rules policy requires alt-text on all attached media before posting.}}'**
  String missingAltTextBodyRequire(int count);

  /// No description provided for @missingAltTextAutoGenerateButton.
  ///
  /// In en, this message translates to:
  /// **'Auto-Generate Missing Alt-Text with AI'**
  String get missingAltTextAutoGenerateButton;

  /// No description provided for @missingAltTextEditButton.
  ///
  /// In en, this message translates to:
  /// **'Edit in Composer'**
  String get missingAltTextEditButton;

  /// No description provided for @missingAltTextPostAnywayButton.
  ///
  /// In en, this message translates to:
  /// **'Post Anyway'**
  String get missingAltTextPostAnywayButton;

  /// No description provided for @biasReviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Pre-Post Racial & Gender Bias Review'**
  String get biasReviewTitle;

  /// No description provided for @biasReviewCloseTooltip.
  ///
  /// In en, this message translates to:
  /// **'Close and return to composer'**
  String get biasReviewCloseTooltip;

  /// No description provided for @biasReviewSummaryTitle.
  ///
  /// In en, this message translates to:
  /// **'Summary'**
  String get biasReviewSummaryTitle;

  /// No description provided for @biasReviewCheckedComponents.
  ///
  /// In en, this message translates to:
  /// **'Checked: {components}'**
  String biasReviewCheckedComponents(String components);

  /// No description provided for @biasReviewLocalFallbackNote.
  ///
  /// In en, this message translates to:
  /// **'Note: Analyzed using offline local bias heuristics.'**
  String get biasReviewLocalFallbackNote;

  /// No description provided for @biasReviewFindingsHeader.
  ///
  /// In en, this message translates to:
  /// **'Where Bias Was Found ({count})'**
  String biasReviewFindingsHeader(int count);

  /// No description provided for @biasReviewExcerpt.
  ///
  /// In en, this message translates to:
  /// **'Excerpt: \"{excerpt}\"'**
  String biasReviewExcerpt(String excerpt);

  /// No description provided for @biasReviewSuggestedWordingTitle.
  ///
  /// In en, this message translates to:
  /// **'Suggested Alternate Wording'**
  String get biasReviewSuggestedWordingTitle;

  /// No description provided for @biasReviewUseSuggestedAndPublishButton.
  ///
  /// In en, this message translates to:
  /// **'Use Suggested Wording & Publish Now'**
  String get biasReviewUseSuggestedAndPublishButton;

  /// No description provided for @biasReviewUseSuggestedButton.
  ///
  /// In en, this message translates to:
  /// **'Use Suggested Wording in Composer'**
  String get biasReviewUseSuggestedButton;

  /// No description provided for @biasReviewReturnToComposerButton.
  ///
  /// In en, this message translates to:
  /// **'Return to Composer to Edit'**
  String get biasReviewReturnToComposerButton;

  /// No description provided for @biasReviewPublishAnywayButton.
  ///
  /// In en, this message translates to:
  /// **'Publish Anyway'**
  String get biasReviewPublishAnywayButton;

  /// No description provided for @biasReviewRequireNotice.
  ///
  /// In en, this message translates to:
  /// **'Your Bias Rules policy is set to Require: please revise the post before publishing.'**
  String get biasReviewRequireNotice;

  /// No description provided for @biasComponentPostText.
  ///
  /// In en, this message translates to:
  /// **'Post Text'**
  String get biasComponentPostText;

  /// No description provided for @biasComponentContentWarning.
  ///
  /// In en, this message translates to:
  /// **'Content Warning'**
  String get biasComponentContentWarning;

  /// No description provided for @biasComponentAttachment.
  ///
  /// In en, this message translates to:
  /// **'Attachment {index}'**
  String biasComponentAttachment(int index);

  /// No description provided for @biasComponentLink.
  ///
  /// In en, this message translates to:
  /// **'Link ({url})'**
  String biasComponentLink(String url);

  /// No description provided for @biasComponentReferencedMessage.
  ///
  /// In en, this message translates to:
  /// **'Referenced Message (@{handle})'**
  String biasComponentReferencedMessage(String handle);

  /// No description provided for @biasSummaryClean.
  ///
  /// In en, this message translates to:
  /// **'No racial or gender bias detected.'**
  String get biasSummaryClean;

  /// No description provided for @biasSummaryLocalClean.
  ///
  /// In en, this message translates to:
  /// **'No racial or gender bias detected via local check.'**
  String get biasSummaryLocalClean;

  /// No description provided for @biasSummaryLocalFindings.
  ///
  /// In en, this message translates to:
  /// **'Checked {checkedLabel} (offline heuristic check) and found {count, plural, =1{1 potential racial or gender bias issue} other{{count} potential racial or gender bias issues}}.'**
  String biasSummaryLocalFindings(String checkedLabel, int count);

  /// No description provided for @biasSummaryAiFallbackBias.
  ///
  /// In en, this message translates to:
  /// **'Checked {checkedLabel} and detected potential racial or gender bias.'**
  String biasSummaryAiFallbackBias(String checkedLabel);

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsSectionAi.
  ///
  /// In en, this message translates to:
  /// **'AI Provider & API Keys'**
  String get settingsSectionAi;

  /// No description provided for @settingsSectionCaptioning.
  ///
  /// In en, this message translates to:
  /// **'AI Alt-Text Captioning'**
  String get settingsSectionCaptioning;

  /// No description provided for @settingsDefaultDetailLevel.
  ///
  /// In en, this message translates to:
  /// **'Default Detail Level'**
  String get settingsDefaultDetailLevel;

  /// No description provided for @settingsDetailLevelItem.
  ///
  /// In en, this message translates to:
  /// **'{label} — {guidance}'**
  String settingsDetailLevelItem(String label, String guidance);

  /// No description provided for @settingsVideoKeyframesLabel.
  ///
  /// In en, this message translates to:
  /// **'Video Keyframes to Extract'**
  String get settingsVideoKeyframesLabel;

  /// No description provided for @settingsVideoKeyframesHelper.
  ///
  /// In en, this message translates to:
  /// **'Used for frame-based models or videos exceeding Gemini inline limits.'**
  String get settingsVideoKeyframesHelper;

  /// No description provided for @settingsVideoKeyframesOption.
  ///
  /// In en, this message translates to:
  /// **'{count} keyframes'**
  String settingsVideoKeyframesOption(int count);

  /// No description provided for @settingsVideoKeyframesDefaultOption.
  ///
  /// In en, this message translates to:
  /// **'{count} keyframes (Default)'**
  String settingsVideoKeyframesDefaultOption(int count);

  /// No description provided for @settingsAutoGenerateTitle.
  ///
  /// In en, this message translates to:
  /// **'Auto-Generate Alt-Text on Attach'**
  String get settingsAutoGenerateTitle;

  /// No description provided for @settingsAutoGenerateSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Automatically scan images and videos as soon as they are attached.'**
  String get settingsAutoGenerateSubtitle;

  /// No description provided for @settingsIncludePostContextTitle.
  ///
  /// In en, this message translates to:
  /// **'Include Draft Post Text as Context'**
  String get settingsIncludePostContextTitle;

  /// No description provided for @settingsIncludePostContextSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Helps the AI identify names, events, or subjects mentioned in your draft.'**
  String get settingsIncludePostContextSubtitle;

  /// No description provided for @settingsCaptionLanguageLabel.
  ///
  /// In en, this message translates to:
  /// **'Caption Output Language'**
  String get settingsCaptionLanguageLabel;

  /// No description provided for @settingsCaptionLanguageHint.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get settingsCaptionLanguageHint;

  /// No description provided for @settingsCustomInstructionsLabel.
  ///
  /// In en, this message translates to:
  /// **'Custom Instructions (Optional)'**
  String get settingsCustomInstructionsLabel;

  /// No description provided for @settingsCustomInstructionsHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Our orange tabby cat is named Marmalade; prefer plain objective tone.'**
  String get settingsCustomInstructionsHint;

  /// No description provided for @settingsSectionAccessibility.
  ///
  /// In en, this message translates to:
  /// **'Accessibility Rules'**
  String get settingsSectionAccessibility;

  /// No description provided for @settingsTtsSpeedTitle.
  ///
  /// In en, this message translates to:
  /// **'Built-in On-Device Read Aloud Speed ({speed}x)'**
  String settingsTtsSpeedTitle(String speed);

  /// No description provided for @settingsTtsSpeedSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Uses your device\'s built-in TTS engine (AVSpeechSynthesizer on Apple platforms, Google/Samsung TTS on Android, SAPI on Windows, Speech Dispatcher / eSpeak on Linux).'**
  String get settingsTtsSpeedSubtitle;

  /// No description provided for @settingsTtsSpeedLabel.
  ///
  /// In en, this message translates to:
  /// **'{speed}x'**
  String settingsTtsSpeedLabel(String speed);

  /// No description provided for @settingsAltPolicyLabel.
  ///
  /// In en, this message translates to:
  /// **'Pre-Post Alt-Text Policy'**
  String get settingsAltPolicyLabel;

  /// No description provided for @settingsSectionBias.
  ///
  /// In en, this message translates to:
  /// **'Bias Rules'**
  String get settingsSectionBias;

  /// No description provided for @settingsBiasPolicyLabel.
  ///
  /// In en, this message translates to:
  /// **'Pre-Post Racial & Gender Bias Policy'**
  String get settingsBiasPolicyLabel;

  /// No description provided for @settingsSectionAppearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance & Theme'**
  String get settingsSectionAppearance;

  /// No description provided for @settingsDetectedOsMode.
  ///
  /// In en, this message translates to:
  /// **'Detected OS mode: {mode}'**
  String settingsDetectedOsMode(String mode);

  /// No description provided for @settingsOsModeHighContrast.
  ///
  /// In en, this message translates to:
  /// **'High Contrast'**
  String get settingsOsModeHighContrast;

  /// No description provided for @settingsOsModeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get settingsOsModeDark;

  /// No description provided for @settingsOsModeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get settingsOsModeLight;

  /// No description provided for @settingsAppLanguageLabel.
  ///
  /// In en, this message translates to:
  /// **'App Interface Language'**
  String get settingsAppLanguageLabel;

  /// No description provided for @settingsAppLanguageSystemDefault.
  ///
  /// In en, this message translates to:
  /// **'System Default ({localeName})'**
  String settingsAppLanguageSystemDefault(String localeName);

  /// No description provided for @settingsAppLanguageHelper.
  ///
  /// In en, this message translates to:
  /// **'Choose the language used for menus, buttons, and accessibility labels.'**
  String get settingsAppLanguageHelper;

  /// No description provided for @settingsSectionAccount.
  ///
  /// In en, this message translates to:
  /// **'Account & Server Info'**
  String get settingsSectionAccount;

  /// No description provided for @settingsAccountTitle.
  ///
  /// In en, this message translates to:
  /// **'{displayName} ({handle})'**
  String settingsAccountTitle(String displayName, String handle);

  /// No description provided for @settingsAccountSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Server: {instanceUrl}\nMax post length: {maxChars} chars · Max media: {maxMedia} · Alt-text limit: {altLimit} chars'**
  String settingsAccountSubtitle(
      String instanceUrl, int maxChars, int maxMedia, int altLimit);

  /// No description provided for @settingsSignOut.
  ///
  /// In en, this message translates to:
  /// **'Sign Out'**
  String get settingsSignOut;

  /// No description provided for @settingsAboutTitle.
  ///
  /// In en, this message translates to:
  /// **'{appName} v{appVersion}'**
  String settingsAboutTitle(String appName, String appVersion);

  /// No description provided for @settingsAboutSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Contributor: {contributorName} · Generated with Antigravity'**
  String settingsAboutSubtitle(String contributorName);

  /// No description provided for @shortcutsTitle.
  ///
  /// In en, this message translates to:
  /// **'Keyboard Shortcuts'**
  String get shortcutsTitle;

  /// No description provided for @shortcutsOrKeyCombo.
  ///
  /// In en, this message translates to:
  /// **'{primary}  or  {alternate}'**
  String shortcutsOrKeyCombo(String primary, String alternate);

  /// No description provided for @shortcutsSectionNavigation.
  ///
  /// In en, this message translates to:
  /// **'Post Navigation'**
  String get shortcutsSectionNavigation;

  /// No description provided for @shortcutsNextPost.
  ///
  /// In en, this message translates to:
  /// **'Next post'**
  String get shortcutsNextPost;

  /// No description provided for @shortcutsPreviousPost.
  ///
  /// In en, this message translates to:
  /// **'Previous post'**
  String get shortcutsPreviousPost;

  /// No description provided for @shortcutsOpenPost.
  ///
  /// In en, this message translates to:
  /// **'Open selected post / thread'**
  String get shortcutsOpenPost;

  /// No description provided for @shortcutsEscape.
  ///
  /// In en, this message translates to:
  /// **'Go back or close viewer'**
  String get shortcutsEscape;

  /// No description provided for @shortcutsSectionActions.
  ///
  /// In en, this message translates to:
  /// **'Selected Post Actions'**
  String get shortcutsSectionActions;

  /// No description provided for @shortcutsReply.
  ///
  /// In en, this message translates to:
  /// **'Reply to selected post'**
  String get shortcutsReply;

  /// No description provided for @shortcutsFavorite.
  ///
  /// In en, this message translates to:
  /// **'Favorite / unfavorite'**
  String get shortcutsFavorite;

  /// No description provided for @shortcutsBoost.
  ///
  /// In en, this message translates to:
  /// **'Boost / unboost'**
  String get shortcutsBoost;

  /// No description provided for @shortcutsBookmark.
  ///
  /// In en, this message translates to:
  /// **'Bookmark / unbookmark'**
  String get shortcutsBookmark;

  /// No description provided for @shortcutsToggleCw.
  ///
  /// In en, this message translates to:
  /// **'Expand / collapse Content Warning'**
  String get shortcutsToggleCw;

  /// No description provided for @shortcutsOpenProfile.
  ///
  /// In en, this message translates to:
  /// **'Open author profile'**
  String get shortcutsOpenProfile;

  /// No description provided for @shortcutsSectionTimelines.
  ///
  /// In en, this message translates to:
  /// **'Switch Timelines'**
  String get shortcutsSectionTimelines;

  /// No description provided for @shortcutsHomeTimeline.
  ///
  /// In en, this message translates to:
  /// **'Home timeline'**
  String get shortcutsHomeTimeline;

  /// No description provided for @shortcutsLocalTimeline.
  ///
  /// In en, this message translates to:
  /// **'Local timeline'**
  String get shortcutsLocalTimeline;

  /// No description provided for @shortcutsFederatedTimeline.
  ///
  /// In en, this message translates to:
  /// **'Federated timeline'**
  String get shortcutsFederatedTimeline;

  /// No description provided for @shortcutsNotificationsTimeline.
  ///
  /// In en, this message translates to:
  /// **'Notifications / Alerts'**
  String get shortcutsNotificationsTimeline;

  /// No description provided for @shortcutsBookmarksTimeline.
  ///
  /// In en, this message translates to:
  /// **'Bookmarks'**
  String get shortcutsBookmarksTimeline;

  /// No description provided for @shortcutsFavoritesTimeline.
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get shortcutsFavoritesTimeline;

  /// No description provided for @shortcutsMyPostsTimeline.
  ///
  /// In en, this message translates to:
  /// **'My Published Posts'**
  String get shortcutsMyPostsTimeline;

  /// No description provided for @shortcutsSectionApp.
  ///
  /// In en, this message translates to:
  /// **'App & Composer'**
  String get shortcutsSectionApp;

  /// No description provided for @shortcutsComposeNew.
  ///
  /// In en, this message translates to:
  /// **'Compose new post'**
  String get shortcutsComposeNew;

  /// No description provided for @shortcutsPublishPost.
  ///
  /// In en, this message translates to:
  /// **'Publish post (in Composer)'**
  String get shortcutsPublishPost;

  /// No description provided for @shortcutsLocalSearch.
  ///
  /// In en, this message translates to:
  /// **'Offline local search'**
  String get shortcutsLocalSearch;

  /// No description provided for @shortcutsRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh current view'**
  String get shortcutsRefresh;

  /// No description provided for @shortcutsOpenSettings.
  ///
  /// In en, this message translates to:
  /// **'Open Settings'**
  String get shortcutsOpenSettings;

  /// No description provided for @shortcutsShowHelp.
  ///
  /// In en, this message translates to:
  /// **'Show this help sheet'**
  String get shortcutsShowHelp;

  /// No description provided for @actionAnnounceBoosted.
  ///
  /// In en, this message translates to:
  /// **'Post boosted.'**
  String get actionAnnounceBoosted;

  /// No description provided for @actionAnnounceUnboosted.
  ///
  /// In en, this message translates to:
  /// **'Boost removed.'**
  String get actionAnnounceUnboosted;

  /// No description provided for @actionErrorBoost.
  ///
  /// In en, this message translates to:
  /// **'Could not update boost: {error}'**
  String actionErrorBoost(String error);

  /// No description provided for @actionAnnounceFavorited.
  ///
  /// In en, this message translates to:
  /// **'Post favorited.'**
  String get actionAnnounceFavorited;

  /// No description provided for @actionAnnounceUnfavorited.
  ///
  /// In en, this message translates to:
  /// **'Removed from favorites.'**
  String get actionAnnounceUnfavorited;

  /// No description provided for @actionErrorFavorite.
  ///
  /// In en, this message translates to:
  /// **'Could not update favorite: {error}'**
  String actionErrorFavorite(String error);

  /// No description provided for @actionAnnounceBookmarked.
  ///
  /// In en, this message translates to:
  /// **'Post bookmarked.'**
  String get actionAnnounceBookmarked;

  /// No description provided for @actionAnnounceUnbookmarked.
  ///
  /// In en, this message translates to:
  /// **'Bookmark removed.'**
  String get actionAnnounceUnbookmarked;

  /// No description provided for @actionErrorBookmark.
  ///
  /// In en, this message translates to:
  /// **'Could not update bookmark: {error}'**
  String actionErrorBookmark(String error);

  /// No description provided for @actionDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Post?'**
  String get actionDeleteTitle;

  /// No description provided for @actionDeleteConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'This will permanently delete your post from your Mastodon server.'**
  String get actionDeleteConfirmBody;

  /// No description provided for @actionAnnounceDeleted.
  ///
  /// In en, this message translates to:
  /// **'Post deleted.'**
  String get actionAnnounceDeleted;

  /// No description provided for @actionErrorDelete.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete post: {error}'**
  String actionErrorDelete(String error);

  /// No description provided for @timeCompactNow.
  ///
  /// In en, this message translates to:
  /// **'now'**
  String get timeCompactNow;

  /// No description provided for @timeCompactMinutes.
  ///
  /// In en, this message translates to:
  /// **'{count}m'**
  String timeCompactMinutes(int count);

  /// No description provided for @timeCompactHours.
  ///
  /// In en, this message translates to:
  /// **'{count}h'**
  String timeCompactHours(int count);

  /// No description provided for @timeCompactDays.
  ///
  /// In en, this message translates to:
  /// **'{count}d'**
  String timeCompactDays(int count);

  /// No description provided for @timeCompactMonths.
  ///
  /// In en, this message translates to:
  /// **'{count}mo'**
  String timeCompactMonths(int count);

  /// No description provided for @timeCompactYears.
  ///
  /// In en, this message translates to:
  /// **'{count}y'**
  String timeCompactYears(int count);

  /// No description provided for @timeAccessibleJustNow.
  ///
  /// In en, this message translates to:
  /// **'just now'**
  String get timeAccessibleJustNow;

  /// No description provided for @timeAccessibleMinutesAgo.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 minute ago} other{{count} minutes ago}}'**
  String timeAccessibleMinutesAgo(int count);

  /// No description provided for @timeAccessibleHoursAgo.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 hour ago} other{{count} hours ago}}'**
  String timeAccessibleHoursAgo(int count);

  /// No description provided for @timeAccessibleDaysAgo.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 day ago} other{{count} days ago}}'**
  String timeAccessibleDaysAgo(int count);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
