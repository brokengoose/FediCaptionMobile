// Copyright (c) 2026 brokengoose <brokengoose@users.noreply.github.com>
// SPDX-License-Identifier: MIT

import 'package:flutter/foundation.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';

import '../core/accessibility_announcer.dart';
import '../core/constants.dart';
import '../core/theme/theme_controller.dart';
import '../models/ai_models.dart';
import '../models/app_settings.dart';
import '../models/mastodon_models.dart';
import '../models/update_info.dart';
import '../services/ai_provider_service.dart';
import '../services/bias_check_service.dart';
import '../services/link_preview_fetcher.dart';
import '../services/mastodon_service.dart';
import '../services/on_device_ai_service.dart';
import '../services/storage_service.dart';
import '../services/translation_service.dart';
import '../services/tts_service.dart';
import '../services/update_check_service.dart';
import 'quote_cache_controller.dart';
import 'timeline_media_ai_controller.dart';

/// Top-level application state coordinator for authentication, settings,
/// AI model discovery, on-device AI status, and GitHub update checks.
///
/// High-frequency per-card updates (quoted-post resolution and on-demand
/// timeline media descriptions) live on dedicated scoped sub-notifiers
/// ([quoteCache] and [mediaAi]) so timeline scrolling does not rebuild the
/// entire widget tree.
class AppController extends ChangeNotifier {
  AppController({
    StorageService? storageService,
    MastodonService? mastodonService,
    AiProviderService? aiProviderService,
    OnDeviceAiService? onDeviceAiService,
    TranslationService? translationService,
    LinkPreviewFetcher? linkPreviewFetcher,
    UpdateCheckService? updateCheckService,
    TtsService? ttsService,
    ThemeController? themeController,
  })  : storage = storageService ?? StorageService(),
        mastodon = mastodonService ?? MastodonService(),
        _ownsMastodon = mastodonService == null,
        onDeviceAi = onDeviceAiService ?? OnDeviceAiService(),
        _linkPreviewFetcher = linkPreviewFetcher ?? LinkPreviewFetcher(),
        _ownsLinkPreviewFetcher = linkPreviewFetcher == null,
        updateChecker = updateCheckService ?? UpdateCheckService(),
        _ownsUpdateChecker = updateCheckService == null,
        tts = ttsService ?? TtsService(),
        themeController = themeController ?? ThemeController() {
    _ownsAiProvider = aiProviderService == null;
    aiProvider = aiProviderService ??
        AiProviderService(onDeviceAiService: onDeviceAi);
    translation =
        translationService ?? TranslationService(onDeviceAi: onDeviceAi);
    biasChecker = BiasCheckService(
      aiProviderService: aiProvider,
      linkPreviewFetcher: _linkPreviewFetcher,
      mastodonService: mastodon,
    );
    quoteCache = QuoteCacheController(mastodon: mastodon);
    mediaAi = TimelineMediaAiController(
      mastodon: mastodon,
      aiProvider: aiProvider,
    );
    for (final provider in AiProviderType.values) {
      _modelsByProvider[provider] = AiProviderService.defaultModelsFor(provider);
    }
  }

  final StorageService storage;
  final MastodonService mastodon;
  final bool _ownsMastodon;
  final OnDeviceAiService onDeviceAi;
  late final TranslationService translation;
  final LinkPreviewFetcher _linkPreviewFetcher;
  final bool _ownsLinkPreviewFetcher;
  late final AiProviderService aiProvider;
  late final bool _ownsAiProvider;
  late final BiasCheckService biasChecker;
  final UpdateCheckService updateChecker;
  final bool _ownsUpdateChecker;
  final TtsService tts;
  final ThemeController themeController;
  late final QuoteCacheController quoteCache;
  late final TimelineMediaAiController mediaAi;

  bool _disposed = false;

  OnDeviceAiStatus _onDeviceAiStatus =
      OnDeviceAiStatus.unavailableForCurrentPlatform();
  bool _isCheckingOnDeviceAi = false;
  bool _isDownloadingOnDeviceModel = false;
  String? _onDeviceAiError;

  bool _isInitializing = true;
  bool _isAuthenticating = false;
  String? _authError;

  MastodonSession? _session;
  MastodonAccount? _currentAccount;
  InstanceLimits _instanceLimits = const InstanceLimits();

  AppSettings _settings = const AppSettings();
  AiCredentials _credentials = const AiCredentials();

  UpdateInfo? _availableUpdate;
  bool _updateBannerDismissed = false;

  // Dynamic model lists for each AI provider
  final Map<AiProviderType, List<AiModelOption>> _modelsByProvider = {};
  final Set<AiProviderType> _loadingModels = {};

  // Incrementing counter used to signal timelines to refresh after posting/editing/deleting.
  int _timelineRefreshNonce = 0;

  bool get isInitializing => _isInitializing;
  bool get isAuthenticating => _isAuthenticating;
  String? get authError => _authError;
  bool get isAuthenticated => _session != null && _currentAccount != null;
  bool get needsAiSetup => isAuthenticated && !_settings.aiSetupCompleted;

  MastodonSession? get session => _session;
  MastodonAccount? get currentAccount => _currentAccount;
  InstanceLimits get instanceLimits => _instanceLimits;

  AppSettings get settings => _settings;
  AiCredentials get credentials => _credentials;

  OnDeviceAiStatus get onDeviceAiStatus => _onDeviceAiStatus;
  bool get isCheckingOnDeviceAi => _isCheckingOnDeviceAi;
  bool get isDownloadingOnDeviceModel => _isDownloadingOnDeviceModel;
  String? get onDeviceAiError => _onDeviceAiError;

  UpdateInfo? get visibleUpdate =>
      _updateBannerDismissed ? null : _availableUpdate;

  int get timelineRefreshNonce => _timelineRefreshNonce;

  List<AiModelOption> modelsFor(AiProviderType provider) =>
      _modelsByProvider[provider] ?? AiProviderService.defaultModelsFor(provider);

  bool isLoadingModels(AiProviderType provider) =>
      _loadingModels.contains(provider);

  // Scoped pass-through helpers for on-demand timeline media AI captions
  String? aiDescriptionForMedia(String mediaId) =>
      mediaAi.descriptionFor(mediaId);
  bool isDescribingMedia(String mediaId) => mediaAi.isDescribing(mediaId);
  String? mediaDescribeError(String mediaId) => mediaAi.errorFor(mediaId);

  // Scoped pass-through helpers for quoted status resolution
  MastodonStatus? cachedQuotedStatus(String url) =>
      quoteCache.cachedStatus(url);
  bool hasResolvedQuote(String url) => quoteCache.hasResolved(url);
  bool isResolvingQuote(String url) => quoteCache.isResolving(url);

  /// Resolves a quoted Mastodon post URL via `/api/v2/search?resolve=true` and
  /// caches the result on [quoteCache].
  Future<MastodonStatus?> resolveQuotedStatus(
    String url, {
    bool forceRetry = false,
  }) =>
      quoteCache.resolve(url, session: _session, forceRetry: forceRetry);

  /// Loads persisted settings, secure credentials, Mastodon session, instance limits,
  /// and runs the startup GitHub version check.
  Future<void> initialize() async {
    _isInitializing = true;
    _safeNotify();

    try {
      _settings = await storage.loadSettings();
      _credentials = await storage.loadAiCredentials();
      themeController.setPreference(_settings.themePreference);

      final savedSession = await storage.loadSession();
      if (savedSession != null) {
        try {
          final account = await mastodon.verifyCredentials(
            instanceUrl: savedSession.instanceUrl,
            accessToken: savedSession.accessToken,
          );
          _session = savedSession;
          _currentAccount = account;
          _instanceLimits = await mastodon.fetchInstanceLimits(
            instanceUrl: savedSession.instanceUrl,
            accessToken: savedSession.accessToken,
          );
        } catch (e) {
          _authError = 'Saved session expired or server unreachable: $e';
        }
      }
    } finally {
      _isInitializing = false;
      _safeNotify();
    }

    if (_disposed) return;

    // Fire-and-forget startup tasks: on-device AI check, GitHub update check & models refresh.
    refreshOnDeviceAiStatus();
    _runUpdateCheck();
    refreshModelsFor(_settings.activeProvider);
  }

  /// Checks whether the phone's built-in OS AI (Apple Foundation Models on iOS /
  /// Google Gemini Nano via ML Kit GenAI & AICore on Android) is available.
  Future<OnDeviceAiStatus> refreshOnDeviceAiStatus() async {
    _isCheckingOnDeviceAi = true;
    _onDeviceAiError = null;
    _safeNotify();
    try {
      _onDeviceAiStatus = await onDeviceAi.checkStatus();
    } catch (e) {
      _onDeviceAiStatus = OnDeviceAiStatus.unavailableForCurrentPlatform();
      _onDeviceAiError = e.toString();
    } finally {
      _isCheckingOnDeviceAi = false;
      _safeNotify();
    }
    return _onDeviceAiStatus;
  }

  /// Triggers OS-managed on-device model provisioning (e.g. Android AICore Gemini Nano).
  Future<void> downloadOnDeviceModel() async {
    if (_isDownloadingOnDeviceModel) return;
    _isDownloadingOnDeviceModel = true;
    _onDeviceAiError = null;
    _safeNotify();

    AccessibilityAnnouncer.announce('Downloading on-device AI model.');
    try {
      _onDeviceAiStatus = await onDeviceAi.downloadModelsIfNeeded();
      AccessibilityAnnouncer.announce(_onDeviceAiStatus.summaryMessage);
    } catch (e) {
      _onDeviceAiError = e.toString();
      AccessibilityAnnouncer.announce('Failed to download on-device AI model.');
    } finally {
      _isDownloadingOnDeviceModel = false;
      _safeNotify();
    }
  }

  Future<void> _runUpdateCheck() async {
    final update = await updateChecker.checkForUpdate(
      currentVersion: AppConstants.appVersion,
    );
    if (update == null || _disposed) return;

    final dismissedVersion = await storage.loadDismissedUpdateVersion();
    if (dismissedVersion == update.latestVersion || _disposed) return;

    _availableUpdate = update;
    _updateBannerDismissed = false;
    _safeNotify();

    AccessibilityAnnouncer.announce(
      'Update available: FediCaption version ${update.latestVersion} is now on GitHub.',
    );
  }

  Future<void> dismissUpdateBanner() async {
    final update = _availableUpdate;
    _updateBannerDismissed = true;
    _safeNotify();
    if (update != null) {
      await storage.saveDismissedUpdateVersion(update.latestVersion);
    }
  }

  /// Authenticates via Mastodon OAuth 2.0 (`ASWebAuthenticationSession` / Custom Tabs).
  Future<bool> loginWithOAuth(String rawInstanceUrl) async {
    final instanceUrl = MastodonService.normalizeInstanceUrl(rawInstanceUrl);
    if (instanceUrl.isEmpty) {
      _authError =
          'Please enter a valid Mastodon server domain (e.g. mastodon.social).';
      _safeNotify();
      return false;
    }

    _isAuthenticating = true;
    _authError = null;
    _safeNotify();

    try {
      final appCreds = await mastodon.registerOAuthApp(instanceUrl);
      final authUri = mastodon.buildAuthorizeUrl(
        instanceUrl: instanceUrl,
        clientId: appCreds.clientId,
      );

      final callbackResult = await FlutterWebAuth2.authenticate(
        url: authUri.toString(),
        callbackUrlScheme: AppConstants.oauthCallbackScheme,
      );

      final callbackUri = Uri.parse(callbackResult);
      final code = callbackUri.queryParameters['code'];
      if (code == null || code.isEmpty) {
        final err = callbackUri.queryParameters['error_description'] ??
            callbackUri.queryParameters['error'] ??
            'Authorization was cancelled.';
        throw MastodonApiException(err);
      }

      final accessToken = await mastodon.exchangeOAuthCode(
        instanceUrl: instanceUrl,
        clientId: appCreds.clientId,
        clientSecret: appCreds.clientSecret,
        code: code,
      );

      return await _completeSignIn(
        instanceUrl: instanceUrl,
        accessToken: accessToken,
      );
    } catch (e) {
      _authError = e.toString();
      _isAuthenticating = false;
      _safeNotify();
      return false;
    }
  }

  /// Authenticates via a user-supplied Direct Access Token (fallback for instances or power users).
  Future<bool> loginWithAccessToken({
    required String rawInstanceUrl,
    required String accessToken,
  }) async {
    final instanceUrl = MastodonService.normalizeInstanceUrl(rawInstanceUrl);
    final trimmedToken = accessToken.trim();
    if (instanceUrl.isEmpty || trimmedToken.isEmpty) {
      _authError = 'Both server URL and access token are required.';
      _safeNotify();
      return false;
    }

    _isAuthenticating = true;
    _authError = null;
    _safeNotify();

    try {
      return await _completeSignIn(
        instanceUrl: instanceUrl,
        accessToken: trimmedToken,
      );
    } catch (e) {
      _authError = e.toString();
      _isAuthenticating = false;
      _safeNotify();
      return false;
    }
  }

  Future<bool> _completeSignIn({
    required String instanceUrl,
    required String accessToken,
  }) async {
    final account = await mastodon.verifyCredentials(
      instanceUrl: instanceUrl,
      accessToken: accessToken,
    );
    final limits = await mastodon.fetchInstanceLimits(
      instanceUrl: instanceUrl,
      accessToken: accessToken,
    );

    final newSession = MastodonSession(
      instanceUrl: instanceUrl,
      accessToken: accessToken,
    );
    await storage.saveSession(newSession);

    _session = newSession;
    _currentAccount = account;
    _instanceLimits = limits;
    _isAuthenticating = false;
    _authError = null;
    _safeNotify();

    AccessibilityAnnouncer.announce(
      'Signed in as ${account.effectiveDisplayName} on $instanceUrl.',
    );
    return true;
  }

  Future<void> logout() async {
    await tts.stop();
    await storage.clearSession();
    _session = null;
    _currentAccount = null;
    _instanceLimits = const InstanceLimits();
    mediaAi.clear();
    quoteCache.clear();
    _safeNotify();
    AccessibilityAnnouncer.announce('Signed out of Mastodon.');
  }

  /// Persists updated non-secret settings and optionally refreshes models when
  /// the active provider or server base URL changed.
  Future<void> updateSettings(
    AppSettings updated, {
    bool autoRefreshModels = true,
  }) async {
    final providerChanged = updated.activeProvider != _settings.activeProvider;
    final urlChanged = updated.openAiBaseUrl != _settings.openAiBaseUrl ||
        updated.localBaseUrl != _settings.localBaseUrl;

    _settings = updated;
    themeController.setPreference(updated.themePreference);
    _safeNotify();

    await storage.saveSettings(updated);

    if (autoRefreshModels && (providerChanged || urlChanged)) {
      await refreshModelsFor(updated.activeProvider);
    }
  }

  /// Persists updated AI credentials to secure storage and optionally triggers
  /// model discovery for [refreshProvider].
  Future<void> updateCredentials(
    AiCredentials updated, {
    AiProviderType? refreshProvider,
  }) async {
    _credentials = updated;
    _safeNotify();
    await storage.saveAiCredentials(updated);

    if (refreshProvider != null) {
      await refreshModelsFor(refreshProvider);
    }
  }

  /// Marks first-time AI setup as completed and saves both settings and credentials.
  Future<void> completeAiSetup({
    required AppSettings settings,
    required AiCredentials credentials,
  }) async {
    final finalized = settings.copyWith(aiSetupCompleted: true);
    _settings = finalized;
    _credentials = credentials;
    themeController.setPreference(finalized.themePreference);
    _safeNotify();

    await storage.saveAiCredentials(credentials);
    await storage.saveSettings(finalized);

    if (finalized.isAiEnabled) {
      refreshModelsFor(finalized.activeProvider);
      AccessibilityAnnouncer.announce(
        'AI setup complete using ${finalized.activeProvider.displayName}.',
      );
    } else {
      AccessibilityAnnouncer.announce(
        'Setup complete with No AI selected. Manual alt-text and offline bias heuristics are active.',
      );
    }
  }

  /// Dynamically fetches models for [provider] and guarantees the currently
  /// selected model remains selectable in the drop-down picker.
  Future<void> refreshModelsFor(AiProviderType provider) async {
    if (provider == AiProviderType.none) {
      _modelsByProvider[provider] = const [];
      _safeNotify();
      return;
    }
    _loadingModels.add(provider);
    _safeNotify();

    try {
      final fetched = await aiProvider.fetchAvailableModels(
        provider: provider,
        settings: _settings,
        credentials: _credentials,
      );
      if (_disposed) return;
      _modelsByProvider[provider] = fetched;

      // If the currently stored model isn't in the freshly returned list, adopt top choice.
      final currentModel = _settings.modelForProvider(provider);
      final exists = fetched.any((m) => m.id == currentModel);
      if (!exists && fetched.isNotEmpty) {
        final nextSettings = _settings.withModelForProvider(
          provider,
          fetched.first.id,
        );
        _settings = nextSettings;
        await storage.saveSettings(nextSettings);
      }
    } finally {
      _loadingModels.remove(provider);
      _safeNotify();
    }
  }

  /// On-demand AI alt-text generation for media attachments on timeline posts.
  Future<void> describeTimelineMedia(
    MastodonMediaAttachment attachment, {
    String? postContext,
  }) =>
      mediaAi.describeMedia(
        attachment: attachment,
        settings: _settings,
        credentials: _credentials,
        maxAltTextLength: _instanceLimits.altTextLimit,
        postContext: postContext,
      );

  void notifyTimelinesShouldRefresh() {
    _timelineRefreshNonce++;
    _safeNotify();
  }

  void _safeNotify() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    quoteCache.dispose();
    mediaAi.dispose();
    tts.dispose();
    themeController.dispose();
    if (_ownsMastodon) mastodon.dispose();
    if (_ownsAiProvider) aiProvider.dispose();
    if (_ownsLinkPreviewFetcher) _linkPreviewFetcher.dispose();
    if (_ownsUpdateChecker) updateChecker.dispose();
    super.dispose();
  }
}
