// Copyright (c) 2026 brokengoose <brokengoose@users.noreply.github.com>
// SPDX-License-Identifier: MIT

/// Application-wide constants, repository metadata, and protocol defaults.
class AppConstants {
  AppConstants._();

  static const String appName = 'FediCaption';
  static const String appVersion = '1.0.0';
  static const String contributorName = 'brokengoose';
  static const String contributorEmail = 'brokengoose@users.noreply.github.com';

  static const String githubOwner = 'brokengoose';
  static const String githubRepo = 'FediCaptionMobile';
  static const String repositoryUrl =
      'https://github.com/$githubOwner/$githubRepo';
  static const String githubLatestReleaseApi =
      'https://api.github.com/repos/$githubOwner/$githubRepo/releases/latest';
  static const String githubMainVersionFileUrl =
      'https://raw.githubusercontent.com/$githubOwner/$githubRepo/main/VERSION';

  // OAuth 2.0 configuration
  static const String oauthClientName = 'FediCaption Mobile';
  static const String oauthCallbackScheme = 'fedicaption';
  static const String oauthRedirectUri = '$oauthCallbackScheme://oauth-callback';
  static const String oauthScopes = 'read write follow push';
  static const String oauthWebsite = repositoryUrl;

  // Mandatory AI alt-text caption prefix
  static const String aiCaptionPrefix = 'AI generated description: ';

  // Mastodon default fallback limits (overridden dynamically by /api/v2/instance)
  static const int defaultMaxCharacters = 500;
  static const int defaultMaxMediaAttachments = 4;
  static const int defaultAltTextLimit = 1500;

  // Inline video size threshold for Google Gemini (18 MB raw bytes)
  static const int geminiInlineVideoMaxBytes = 18 * 1024 * 1024;

  // AI provider default base URLs
  static const String geminiBaseUrl =
      'https://generativelanguage.googleapis.com/v1beta';
  static const String openAiDefaultBaseUrl = 'https://api.openai.com/v1';
  static const String anthropicBaseUrl = 'https://api.anthropic.com/v1';
  static const String anthropicVersion = '2023-06-01';
  static const String localDefaultBaseUrl = 'http://localhost:11434/v1';

  // Accessible minimum touch target size (>= 44pt iOS / 48dp Android)
  static const double minTouchTargetSize = 48.0;
}
