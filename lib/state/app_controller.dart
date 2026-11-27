// Copyright (c) 2026 brokengoose <brokengoose@users.noreply.github.com>
// SPDX-License-Identifier: MIT

import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';

import '../core/accessibility_announcer.dart';
import '../core/constants.dart';
import '../core/language/language_registry.dart';
import '../core/theme/theme_controller.dart';
import '../l10n/l10n.dart';
import '../l10n/model_localizations.dart';
import '../models/ai_models.dart';
import '../models/app_settings.dart';
import '../models/mastodon_models.dart';
import '../models/update_info.dart';
import '../services/ai_provider_service.dart';
import '../services/bias_check_service.dart';
import '../services/link_preview_fetcher.dart';
import '../services/mastodon_service.dart';
import '../services/media_cache_service.dart';
import '../services/on_device_ai_service.dart';
import '../services/storage_service.dart';
import '../services/translation_service.dart';
import '../services/tts_service.dart';
import '../services/update_check_service.dart';
import 'quote_cache_controller.dart';
import 'timeline_cache_controller.dart';
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
  }) : storage = storageService ?? StorageService(),
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
    aiProvider =
        aiProviderService ?? AiProviderService(onDeviceAiService: onDeviceAi);
    translation =
        translationService ??
        TranslationService(
          onDeviceAi: onDeviceAi,
          aiProvider: aiProvider,
          mastodon: mastodon,
          osLanguageProvider: () =>
              _settings.resolvedAppLocale?.languageCode ??
              (LanguageRegistry.normalizeCode(
                    PlatformDispatcher.instance.locale.languageCode,
                  ) ??
                  'en'),
        );
    quoteCache = QuoteCacheController(mastodon: mastodon);
    timelineCache = TimelineCacheController();
    biasChecker = BiasCheckService(
      aiProviderService: aiProvider,
      linkPreviewFetcher: _linkPreviewFetcher,
      mastodonService: mastodon,
      quoteCache: quoteCache,
    );
    mediaAi = TimelineMediaAiController(
      mastodon: mastodon,
      aiProvider: aiProvider,
      l10nProvider: () => l10n,
    );
    for (final provider in AiProviderType.values) {
      _modelsByProvider[provider] = AiProviderService.defaultModelsFor(
        provider,
      );
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
  late final TimelineCacheController timelineCache;
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
  List<StoredAccount> _accounts = const [];
  String? _activeAccountKey;
  bool _isSwitchingAccount = false;
  int _accountGeneration = 0;
  InstanceLimits _instanceLimits = const InstanceLimits();

  AppSettings _settings = const AppSettings();
  AiCredentials _credentials = const AiCredentials();

  UpdateInfo? _availableUpdate;
  bool _updateBannerDismissed = false;

  // Dynamic model lists for each AI provider
  final Map<AiProviderType, List<AiModelOption>> _modelsByProvider = {};
  final Set<AiProviderType> _loadingModels = {};
  final Map<AiProviderType, int> _modelRequestIds = {};

  // Incrementing counter used to signal timelines to refresh after posting/editing/deleting.
  int _timelineRefreshNonce = 0;

  bool get isInitializing => _isInitializing;
  bool get isAuthenticating => _isAuthenticating;
  bool get isSwitchingAccount => _isSwitchingAccount;
  String? get authError => _authError;
  bool get isAuthenticated => _session != null && _currentAccount != null;
  bool get needsAiSetup => !_settings.aiSetupCompleted;
  List<StoredAccount> get accounts => List.unmodifiable(_accounts);
  bool get hasMultipleAccounts => _accounts.length > 1;
  String? get activeAccountKey => _activeAccountKey;
  int get accountGeneration => _accountGeneration;

  StoredAccount? get activeStoredAccount {
    final key = _activeAccountKey;
    if (key == null) return null;
    for (final item in _accounts) {
      if (item.key == key) return item;
    }
    return null;
  }

  String get activeAccountFullHandle {
    final stored = activeStoredAccount;
    if (stored != null) return stored.fullHandle;
    if (_session != null && _currentAccount != null) {
      return StoredAccount.fromSessionAndAccount(
        session: _session!,
        account: _currentAccount!,
      ).fullHandle;
    }
    return _currentAccount?.handle ?? '';
  }

  MastodonSession? get session => _session;
  MastodonAccount? get currentAccount => _currentAccount;
  InstanceLimits get instanceLimits => _instanceLimits;

  AppSettings get settings => _settings;
  AiCredentials get credentials => _credentials;

  /// Resolved UI locale combining optional user override and OS locale.
  Locale get effectiveLocale =>
      resolveSupportedLocale(_settings.resolvedAppLocale);

  /// Localized string table matching [effectiveLocale] for non-BuildContext callers.
  AppLocalizations get l10n =>
      resolveAppLocalizations(_settings.resolvedAppLocale);

  void _syncAnnouncementDirection() {
    AccessibilityAnnouncer.defaultTextDirection = resolveTextDirection(
      effectiveLocale,
    );
  }

  OnDeviceAiStatus get onDeviceAiStatus => _onDeviceAiStatus;
  bool get isCheckingOnDeviceAi => _isCheckingOnDeviceAi;
  bool get isDownloadingOnDeviceModel => _isDownloadingOnDeviceModel;
  String? get onDeviceAiError => _onDeviceAiError;

  UpdateInfo? get visibleUpdate =>
      _updateBannerDismissed ? null : _availableUpdate;

  int get timelineRefreshNonce => _timelineRefreshNonce;

  List<AiModelOption> modelsFor(AiProviderType provider) =>
      _modelsByProvider[provider] ??
      AiProviderService.defaultModelsFor(provider);

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
  }) => quoteCache.resolve(url, session: _session, forceRetry: forceRetry);

  /// Loads persisted settings, secure credentials, Mastodon session, instance limits,
  /// and runs the startup GitHub version check.
  Future<void> initialize() async {
    _isInitializing = true;
    _safeNotify();

    try {
      _settings = await storage.loadSettings();
      _credentials = await storage.loadAiCredentials();
      themeController.setPreference(_settings.themePreference);
      _syncAnnouncementDirection();

      final savedAccounts = await storage.loadAccounts();
      final activeKey = await storage.loadActiveAccountKey();

      if (savedAccounts.isNotEmpty) {
        _accounts = savedAccounts;
        final target = savedAccounts.firstWhere(
          (a) => a.key == activeKey,
          orElse: () => savedAccounts.first,
        );
        try {
          final account = await mastodon.verifyCredentials(
            instanceUrl: target.instanceUrl,
            accessToken: target.accessToken,
          );
          final limits = await _loadOrFetchInstanceLimits(
            instanceUrl: target.instanceUrl,
            accessToken: target.accessToken,
          );
          final refreshed = StoredAccount.fromSessionAndAccount(
            session: target.session,
            account: account,
          );
          _upsertStoredAccount(refreshed);
          await storage.saveAccount(refreshed);
          _session = refreshed.session;
          _currentAccount = account;
          _activeAccountKey = refreshed.key;
          _instanceLimits = limits;
        } catch (e) {
          _activeAccountKey = target.key;
          if (_isAuthRejection(e)) {
            _authError = l10n.authErrorExpiredSession(e.toString());
          } else {
            // Network/server trouble (offline, timeout, 5xx) is not an expired
            // session: stay signed in with the stored profile so the timeline
            // can show its own error + retry instead of bouncing to login.
            _session = target.session;
            _currentAccount = _accountFromStored(target);
            _instanceLimits =
                await storage.loadCachedInstanceLimits(target.instanceUrl) ??
                const InstanceLimits();
          }
        }
      } else {
        final savedSession = await storage.loadSession();
        if (savedSession != null) {
          try {
            final account = await mastodon.verifyCredentials(
              instanceUrl: savedSession.instanceUrl,
              accessToken: savedSession.accessToken,
            );
            final limits = await _loadOrFetchInstanceLimits(
              instanceUrl: savedSession.instanceUrl,
              accessToken: savedSession.accessToken,
            );
            final migrated = StoredAccount.fromSessionAndAccount(
              session: savedSession,
              account: account,
            );
            _upsertStoredAccount(migrated);
            await storage.saveAccount(migrated);
            _session = savedSession;
            _currentAccount = account;
            _activeAccountKey = migrated.key;
            _instanceLimits = limits;
          } catch (e) {
            _authError = l10n.authErrorExpiredSession(e.toString());
          }
        }
      }
    } finally {
      _isInitializing = false;
      _safeNotify();
    }

    if (_disposed) return;

    // Fire-and-forget startup tasks: restore AI caption cache, prune media disk
    // cache, check on-device AI, GitHub update check & models refresh.
    unawaited(mediaAi.useAccount(isAuthenticated ? _activeAccountKey : null));
    unawaited(MediaCacheService.instance.pruneIfNeeded());
    unawaited(refreshOnDeviceAiStatus());
    unawaited(_runUpdateCheck());
    unawaited(refreshModelsFor(_settings.activeProvider));
  }

  /// True when the server explicitly rejected the stored token.
  static bool _isAuthRejection(Object error) =>
      error is MastodonApiException &&
      (error.statusCode == 401 || error.statusCode == 403);

  /// Minimal offline stand-in for the signed-in account, built from the
  /// profile fields persisted with each [StoredAccount].
  static MastodonAccount _accountFromStored(StoredAccount stored) =>
      MastodonAccount(
        id: stored.accountId,
        username: stored.username,
        acct: stored.acct,
        displayName: stored.displayName,
        avatar: stored.avatar,
      );

  Future<InstanceLimits> _loadOrFetchInstanceLimits({
    required String instanceUrl,
    required String accessToken,
  }) async {
    final cached = await storage.loadCachedInstanceLimits(instanceUrl);
    if (cached != null) return cached;
    final fetched = await mastodon.fetchInstanceLimits(
      instanceUrl: instanceUrl,
      accessToken: accessToken,
    );
    // Never cache the defaults used when the server couldn't be reached;
    // otherwise one failed fetch would pin the wrong limits for the whole TTL.
    if (fetched == null) return const InstanceLimits();
    await storage.saveCachedInstanceLimits(instanceUrl, fetched);
    return fetched;
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

    AccessibilityAnnouncer.announce(l10n.onDeviceAiAnnounceDownloading);
    try {
      _onDeviceAiStatus = await onDeviceAi.downloadModelsIfNeeded();
      AccessibilityAnnouncer.announce(
        _onDeviceAiStatus.localizedSummaryMessage(l10n),
      );
    } catch (e) {
      _onDeviceAiError = e.toString();
      AccessibilityAnnouncer.announce(l10n.onDeviceAiAnnounceDownloadFailed);
    } finally {
      _isDownloadingOnDeviceModel = false;
      _safeNotify();
    }
  }

  Future<void> _runUpdateCheck() async {
    final update = await updateChecker.checkForUpdate();
    if (update == null || _disposed) return;

    final dismissedVersion = await storage.loadDismissedUpdateVersion();
    if (dismissedVersion == update.latestVersion || _disposed) return;

    _availableUpdate = update;
    _updateBannerDismissed = false;
    _safeNotify();

    AccessibilityAnnouncer.announce(
      l10n.updateAnnounceAvailable(update.latestVersion),
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
      _authError = l10n.authErrorInvalidInstance;
      _safeNotify();
      return false;
    }

    _isAuthenticating = true;
    _authError = null;
    _safeNotify();

    try {
      // On Windows & Linux, launch the user's default system browser with a
      // temporary RFC 8252 loopback listener (no Edge WebView2 required).
      final useSystemBrowserLoopback =
          !kIsWeb &&
          (defaultTargetPlatform == TargetPlatform.windows ||
              defaultTargetPlatform == TargetPlatform.linux);
      final redirectUri = useSystemBrowserLoopback
          ? AppConstants.desktopLoopbackOAuthRedirectUri
          : AppConstants.oauthRedirectUri;
      final callbackScheme = useSystemBrowserLoopback
          ? AppConstants.desktopLoopbackOAuthOrigin
          : AppConstants.oauthCallbackScheme;
      final authOptions = useSystemBrowserLoopback
          ? FlutterWebAuth2Options(
              useWebview: false,
              landingPageHtml: _buildOAuthLandingHtml(),
            )
          : const FlutterWebAuth2Options();

      // Reuse cached OAuth app credentials per instance + redirect URI to avoid
      // creating orphaned duplicate rows in Mastodon's oauth_applications table.
      var appCreds = await storage.loadOAuthAppCredentials(
        instanceUrl,
        redirectUri: redirectUri,
      );
      final usedCachedApp = appCreds != null;
      if (appCreds == null) {
        appCreds = await mastodon.registerOAuthApp(
          instanceUrl,
          redirectUri: redirectUri,
        );
        await storage.saveOAuthAppCredentials(
          instanceUrl,
          appCreds,
          redirectUri: redirectUri,
        );
      }

      final authUri = mastodon.buildAuthorizeUrl(
        instanceUrl: instanceUrl,
        clientId: appCreds.clientId,
        redirectUri: redirectUri,
      );

      final callbackResult = await FlutterWebAuth2.authenticate(
        url: authUri.toString(),
        callbackUrlScheme: callbackScheme,
        options: authOptions,
      );

      final callbackUri = Uri.parse(callbackResult);
      final code = callbackUri.queryParameters['code'];
      if (code == null || code.isEmpty) {
        final err =
            callbackUri.queryParameters['error_description'] ??
            callbackUri.queryParameters['error'] ??
            l10n.authErrorCancelled;
        throw MastodonApiException(err);
      }

      String accessToken;
      try {
        accessToken = await mastodon.exchangeOAuthCode(
          instanceUrl: instanceUrl,
          clientId: appCreds.clientId,
          clientSecret: appCreds.clientSecret,
          code: code,
          redirectUri: redirectUri,
        );
      } catch (e) {
        // If a cached OAuth app was revoked server-side, clear it so the next
        // attempt registers cleanly.
        if (usedCachedApp) {
          await storage.clearOAuthAppCredentials(
            instanceUrl,
            redirectUri: redirectUri,
          );
        }
        rethrow;
      }

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
      _authError = l10n.authErrorMissingInstanceAndToken;
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
    final limits = await _loadOrFetchInstanceLimits(
      instanceUrl: instanceUrl,
      accessToken: accessToken,
    );

    final newSession = MastodonSession(
      instanceUrl: instanceUrl,
      accessToken: accessToken,
    );
    final stored = StoredAccount.fromSessionAndAccount(
      session: newSession,
      account: account,
    );
    final switchingFromOther =
        _activeAccountKey != null && _activeAccountKey != stored.key;
    if (switchingFromOther) {
      await tts.stop();
    }

    await storage.saveAccount(stored);
    _upsertStoredAccount(stored);

    // Commit point: reset account-scoped caches in the same synchronous step
    // as the session swap (see switchAccount).
    if (switchingFromOther || _activeAccountKey == null) {
      _resetAccountScopedState(stored.key);
    }
    _session = newSession;
    _currentAccount = account;
    _activeAccountKey = stored.key;
    _instanceLimits = limits;
    if (switchingFromOther) {
      _accountGeneration++;
    }
    _isAuthenticating = false;
    _authError = null;
    _safeNotify();

    AccessibilityAnnouncer.announce(
      l10n.authAnnounceSignedIn(account.effectiveDisplayName, instanceUrl),
    );
    return true;
  }

  /// Switches the active Mastodon account to a previously saved login in [_accounts].
  Future<bool> switchAccount(String accountKey) async {
    StoredAccount? target;
    for (final item in _accounts) {
      if (item.key == accountKey) {
        target = item;
        break;
      }
    }
    if (target == null) return false;
    if (accountKey == _activeAccountKey && isAuthenticated) {
      return true;
    }

    _isSwitchingAccount = true;
    _authError = null;
    _safeNotify();

    await tts.stop();

    try {
      final account = await mastodon.verifyCredentials(
        instanceUrl: target.instanceUrl,
        accessToken: target.accessToken,
      );
      final limits = await _loadOrFetchInstanceLimits(
        instanceUrl: target.instanceUrl,
        accessToken: target.accessToken,
      );
      final refreshed = StoredAccount.fromSessionAndAccount(
        session: target.session,
        account: account,
      );
      _upsertStoredAccount(refreshed);
      await storage.saveAccount(refreshed);

      // Commit point. Caches are reset here, synchronously with the session
      // swap and generation bump, not before the awaits above: screens of the
      // old account stay mounted until now, and anything they wrote while
      // the switch was pending must not be served to the new account. A
      // failed switch leaves the current account's caches intact.
      _resetAccountScopedState(refreshed.key);
      _session = refreshed.session;
      _currentAccount = account;
      _activeAccountKey = refreshed.key;
      _instanceLimits = limits;
      _accountGeneration++;
      _isSwitchingAccount = false;
      _safeNotify();

      AccessibilityAnnouncer.announce(
        l10n.authAnnounceSwitchedAccount(
          account.effectiveDisplayName,
          refreshed.fullHandle,
        ),
      );
      return true;
    } catch (e) {
      _authError = e.toString();
      _isSwitchingAccount = false;
      _safeNotify();
      return false;
    }
  }

  Future<void> logout({String? accountKey}) async {
    final targetKey = accountKey ?? _activeAccountKey;
    if (targetKey == null) {
      await tts.stop();
      await storage.clearSession();
      _session = null;
      _currentAccount = null;
      _instanceLimits = const InstanceLimits();
      _resetAccountScopedState(null);
      _accountGeneration++;
      _safeNotify();
      AccessibilityAnnouncer.announce(l10n.authAnnounceSignedOut);
      return;
    }

    _accounts = _accounts.where((a) => a.key != targetKey).toList();
    await storage.removeAccount(targetKey);

    if (targetKey != _activeAccountKey) {
      _safeNotify();
      return;
    }

    await tts.stop();
    _resetAccountScopedState(null);

    if (_accounts.isNotEmpty) {
      _activeAccountKey = null;
      _session = null;
      _currentAccount = null;
      await switchAccount(_accounts.first.key);
      return;
    }

    _session = null;
    _currentAccount = null;
    _activeAccountKey = null;
    _instanceLimits = const InstanceLimits();
    _accountGeneration++;
    await storage.clearSession();
    _safeNotify();
    AccessibilityAnnouncer.announce(l10n.authAnnounceSignedOut);
  }

  void _upsertStoredAccount(StoredAccount account) {
    final next = <StoredAccount>[];
    var replaced = false;
    for (final item in _accounts) {
      if (item.key == account.key) {
        next.add(account);
        replaced = true;
      } else {
        next.add(item);
      }
    }
    if (!replaced) {
      next.add(account);
    }
    _accounts = next;
  }

  /// Drops every account-scoped cache and scopes AI captions to
  /// [nextAccountKey] (`null` = signed out).
  void _resetAccountScopedState(String? nextAccountKey) {
    mastodon.clearSessionCaches();
    timelineCache.clear();
    quoteCache.clear();
    unawaited(mediaAi.useAccount(nextAccountKey));
  }

  /// Persists updated non-secret settings and optionally refreshes models when
  /// the active provider or server base URL changed.
  Future<void> updateSettings(
    AppSettings updated, {
    bool autoRefreshModels = true,
  }) async {
    final providerChanged = updated.activeProvider != _settings.activeProvider;
    final urlChanged =
        updated.openAiBaseUrl != _settings.openAiBaseUrl ||
        updated.localBaseUrl != _settings.localBaseUrl;

    _settings = updated;
    themeController.setPreference(updated.themePreference);
    _syncAnnouncementDirection();
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

  /// Applies the recommended default provider during first-time AI onboarding
  /// before setup is saved, without writing incomplete onboarding state to disk.
  void selectInitialSetupProvider(AiProviderType provider) {
    if (_settings.aiSetupCompleted || _settings.activeProvider == provider) {
      return;
    }
    _settings = _settings.copyWith(activeProvider: provider);
    _safeNotify();
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
    _syncAnnouncementDirection();
    _safeNotify();

    await storage.saveAiCredentials(credentials);
    await storage.saveSettings(finalized);

    if (finalized.isAiEnabled) {
      unawaited(refreshModelsFor(finalized.activeProvider));
      AccessibilityAnnouncer.announce(
        l10n.aiSetupAnnounceCompleteWithAi(
          finalized.activeProvider.localizedDisplayName(l10n),
        ),
      );
    } else {
      AccessibilityAnnouncer.announce(l10n.aiSetupAnnounceCompleteNoAi);
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
    // Per-provider request token: a slower fetch started with older settings
    // (e.g. a previous base URL or key) must not overwrite a newer result or
    // reset and persist the selected model.
    final requestId = (_modelRequestIds[provider] ?? 0) + 1;
    _modelRequestIds[provider] = requestId;
    bool isLatest() => _modelRequestIds[provider] == requestId;

    _loadingModels.add(provider);
    _safeNotify();

    try {
      final fetched = await aiProvider.fetchAvailableModels(
        provider: provider,
        settings: _settings,
        credentials: _credentials,
      );
      if (_disposed || !isLatest()) return;
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
      if (isLatest()) {
        _loadingModels.remove(provider);
        _safeNotify();
      }
    }
  }

  /// On-demand AI alt-text generation for media attachments on timeline posts.
  Future<void> describeTimelineMedia(
    MastodonMediaAttachment attachment, {
    String? postContext,
  }) => mediaAi.describeMedia(
    attachment: attachment,
    settings: _settings,
    credentials: _credentials,
    maxAltTextLength: _instanceLimits.altTextLimit,
    postContext: postContext,
  );

  void notifyTimelinesShouldRefresh() {
    timelineCache.markAllStale();
    _timelineRefreshNonce++;
    _safeNotify();
  }

  /// Propagates a newly edited status immediately across timeline,
  /// notification, and quote caches so stale pre-edit text is replaced.
  void applyEditedStatus(MastodonStatus updated) {
    final target = updated.displayStatus;
    timelineCache.updateStatusEverywhere(target);
    quoteCache.updateStatus(target);
  }

  String _buildOAuthLandingHtml() {
    final loc = l10n;
    final locale = effectiveLocale;
    final dir = resolveTextDirection(locale) == TextDirection.rtl
        ? 'rtl'
        : 'ltr';
    const esc = HtmlEscape();
    final lang = esc.convert(locale.toLanguageTag());
    final title = esc.convert(loc.oauthLandingTitle);
    final heading = esc.convert(loc.oauthLandingHeading);
    final body = esc.convert(loc.oauthLandingBody);
    return '''
<!DOCTYPE html>
<html lang="$lang" dir="$dir">
<head>
  <meta charset="utf-8" />
  <title>$title</title>
  <style>
    body { font-family: system-ui, -apple-system, sans-serif; display: grid; place-items: center; min-height: 100vh; margin: 0; background: #14171f; color: #f8f9fc; }
    main { max-width: 440px; padding: 32px; border-radius: 14px; background: #1e2330; text-align: center; }
    h1 { font-size: 1.4rem; margin: 0 0 12px; }
    p { margin: 0; color: #c7cede; line-height: 1.5; }
  </style>
</head>
<body>
  <main>
    <h1>$heading</h1>
    <p>$body</p>
  </main>
</body>
</html>
''';
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
    timelineCache.dispose();
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
