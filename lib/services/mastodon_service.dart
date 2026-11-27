// Copyright (c) 2026 brokengoose <brokengoose@users.noreply.github.com>
// SPDX-License-Identifier: MIT

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../core/constants.dart';
import '../models/mastodon_models.dart';
import 'media_cache_service.dart';

/// Exception thrown when a Mastodon REST API request returns a non-2xx status
/// or an invalid payload.
class MastodonApiException implements Exception {
  const MastodonApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

/// Client credentials issued when registering FediCaption via `POST /api/v1/apps`.
class OAuthAppCredentials {
  const OAuthAppCredentials({
    required this.clientId,
    required this.clientSecret,
  });

  final String clientId;
  final String clientSecret;
}

/// Complete Mastodon REST API client supporting OAuth 2.0, dynamic instance limits,
/// timelines, profiles, relationships, media uploads, and editing own posts with alt-text.
class MastodonService {
  MastodonService({http.Client? client})
      : _client = client ?? http.Client(),
        _ownsClient = client == null;

  final http.Client _client;
  final bool _ownsClient;

  static const Duration _profileCacheTtl = Duration(minutes: 3);
  final Map<String, ({MastodonAccount account, DateTime fetchedAt})>
      _accountCache = {};
  final Map<String, ({MastodonRelationship? relationship, DateTime fetchedAt})>
      _relationshipCache = {};

  /// Clears short-lived in-memory profile/relationship caches (e.g. on logout).
  void clearSessionCaches() {
    _accountCache.clear();
    _relationshipCache.clear();
  }

  /// Closes the internally owned HTTP client (no-op if an external client was injected).
  void dispose() {
    clearSessionCaches();
    if (_ownsClient) {
      _client.close();
    }
  }

  /// Normalizes user input such as `mastodon.social` into `https://mastodon.social`.
  static String normalizeInstanceUrl(String raw) {
    var trimmed = raw.trim();
    if (trimmed.isEmpty) return '';
    if (!trimmed.startsWith('http://') && !trimmed.startsWith('https://')) {
      trimmed = 'https://$trimmed';
    }
    while (trimmed.endsWith('/')) {
      trimmed = trimmed.substring(0, trimmed.length - 1);
    }
    return trimmed;
  }

  /// Registers the OAuth 2.0 application with the Mastodon instance (`POST /api/v1/apps`),
  /// setting `website` to FediCaption Mobile's GitHub repository URL.
  Future<OAuthAppCredentials> registerOAuthApp(
    String instanceUrl, {
    String redirectUri = AppConstants.oauthRedirectUri,
  }) async {
    final decoded = await _postJsonObject(
      instanceUrl: instanceUrl,
      path: '/api/v1/apps',
      body: {
        'client_name': AppConstants.oauthClientName,
        'redirect_uris': redirectUri,
        'scopes': AppConstants.oauthScopes,
        'website': AppConstants.oauthWebsite,
      },
      errorContext: 'Failed to register OAuth app',
      timeout: const Duration(seconds: 20),
    );
    return OAuthAppCredentials(
      clientId: (decoded['client_id'] as String?) ?? '',
      clientSecret: (decoded['client_secret'] as String?) ?? '',
    );
  }

  /// Builds the `/oauth/authorize` URI for `ASWebAuthenticationSession`,
  /// Android Custom Tabs, or desktop default-browser loopback OAuth.
  Uri buildAuthorizeUrl({
    required String instanceUrl,
    required String clientId,
    String redirectUri = AppConstants.oauthRedirectUri,
  }) {
    return _buildUri(
      instanceUrl,
      '/oauth/authorize',
      queryParameters: {
        'client_id': clientId,
        'scope': AppConstants.oauthScopes,
        'redirect_uri': redirectUri,
        'response_type': 'code',
      },
    );
  }

  /// Exchanges an OAuth authorization code for a bearer access token (`POST /oauth/token`).
  Future<String> exchangeOAuthCode({
    required String instanceUrl,
    required String clientId,
    required String clientSecret,
    required String code,
    String redirectUri = AppConstants.oauthRedirectUri,
  }) async {
    final decoded = await _postJsonObject(
      instanceUrl: instanceUrl,
      path: '/oauth/token',
      body: {
        'client_id': clientId,
        'client_secret': clientSecret,
        'redirect_uri': redirectUri,
        'grant_type': 'authorization_code',
        'code': code,
        'scope': AppConstants.oauthScopes,
      },
      errorContext: 'Failed to exchange OAuth token',
      timeout: const Duration(seconds: 20),
    );
    final token = (decoded['access_token'] as String?) ?? '';
    if (token.isEmpty) {
      throw const MastodonApiException(
        'Server did not return an access token.',
      );
    }
    return token;
  }

  /// Verifies the access token and returns the logged-in user's account profile.
  Future<MastodonAccount> verifyCredentials({
    required String instanceUrl,
    required String accessToken,
  }) async {
    final decoded = await _getJsonObject(
      instanceUrl: instanceUrl,
      path: '/api/v1/accounts/verify_credentials',
      accessToken: accessToken,
      errorContext: 'Failed to verify Mastodon credentials',
    );
    return MastodonAccount.fromJson(decoded);
  }

  /// Queries dynamic server limits from `GET /api/v2/instance` with fallback to `GET /api/v1/instance`.
  ///
  /// Returns `null` when neither endpoint could be read, so callers can fall
  /// back to defaults without mistaking them for the server's real limits.
  Future<InstanceLimits?> fetchInstanceLimits({
    required String instanceUrl,
    String? accessToken,
  }) async {
    final headers = accessToken != null && accessToken.isNotEmpty
        ? _authHeaders(accessToken)
        : const {'Accept': 'application/json'};

    for (final endpoint in ['/api/v2/instance', '/api/v1/instance']) {
      try {
        final res = await _client
            .get(_buildUri(instanceUrl, endpoint), headers: headers)
            .timeout(const Duration(seconds: 12));
        if (res.statusCode >= 200 && res.statusCode < 300) {
          final decoded = jsonDecode(res.body) as Map<String, dynamic>;
          return InstanceLimits.fromInstanceJson(decoded);
        }
      } catch (_) {
        // Try fallback endpoint.
      }
    }
    return null;
  }

  /// Fetches statuses for any supported [TimelineType] with optional `maxId`
  /// pagination or `sinceId` incremental delta polling.
  Future<List<MastodonStatus>> fetchTimeline({
    required String instanceUrl,
    required String accessToken,
    required TimelineType type,
    required String currentUserId,
    String? maxId,
    String? sinceId,
    int limit = 25,
  }) async {
    final query = <String, String>{
      'limit': '$limit',
      if (maxId != null && maxId.isNotEmpty) 'max_id': maxId,
      if (sinceId != null && sinceId.isNotEmpty) 'since_id': sinceId,
    };

    String path;
    switch (type) {
      case TimelineType.home:
        path = '/api/v1/timelines/home';
      case TimelineType.local:
        path = '/api/v1/timelines/public';
        query['local'] = 'true';
      case TimelineType.federated:
        path = '/api/v1/timelines/public';
      case TimelineType.bookmarks:
        path = '/api/v1/bookmarks';
      case TimelineType.favorites:
        path = '/api/v1/favourites';
      case TimelineType.myPosts:
        path = '/api/v1/accounts/$currentUserId/statuses';
      case TimelineType.notifications:
        return const [];
    }

    final list = await _getJsonList(
      instanceUrl: instanceUrl,
      path: path,
      accessToken: accessToken,
      queryParameters: query,
      errorContext: 'Failed to load ${type.fullTitle}',
      timeout: const Duration(seconds: 20),
    );
    return _parseStatusList(list);
  }

  /// Fetches account notifications (`GET /api/v1/notifications`) with optional
  /// `maxId` pagination or `sinceId` incremental delta polling.
  Future<List<MastodonNotification>> fetchNotifications({
    required String instanceUrl,
    required String accessToken,
    String? maxId,
    String? sinceId,
    int limit = 30,
  }) async {
    final list = await _getJsonList(
      instanceUrl: instanceUrl,
      path: '/api/v1/notifications',
      accessToken: accessToken,
      queryParameters: {
        'limit': '$limit',
        if (maxId != null && maxId.isNotEmpty) 'max_id': maxId,
        if (sinceId != null && sinceId.isNotEmpty) 'since_id': sinceId,
      },
      errorContext: 'Failed to load notifications',
      timeout: const Duration(seconds: 20),
    );
    return list
        .whereType<Map<String, dynamic>>()
        .map(MastodonNotification.fromJson)
        .toList();
  }

  /// Fetches full profile metadata for a Mastodon account (`GET /api/v1/accounts/{id}`),
  /// serving a short-TTL in-memory cache hit unless [forceRefresh] is true.
  Future<MastodonAccount> fetchAccount({
    required String instanceUrl,
    required String accessToken,
    required String accountId,
    bool forceRefresh = false,
  }) async {
    final cacheKey = '${normalizeInstanceUrl(instanceUrl)}|$accountId';
    if (!forceRefresh) {
      final cached = _accountCache[cacheKey];
      if (cached != null &&
          DateTime.now().difference(cached.fetchedAt) < _profileCacheTtl) {
        return cached.account;
      }
    }
    final decoded = await _getJsonObject(
      instanceUrl: instanceUrl,
      path: '/api/v1/accounts/$accountId',
      accessToken: accessToken,
      errorContext: 'Failed to load user profile',
    );
    final account = MastodonAccount.fromJson(decoded);
    _accountCache[cacheKey] = (account: account, fetchedAt: DateTime.now());
    return account;
  }

  /// Fetches statuses published by [accountId] with optional `maxId` pagination.
  Future<List<MastodonStatus>> fetchAccountStatuses({
    required String instanceUrl,
    required String accessToken,
    required String accountId,
    String? maxId,
    int limit = 25,
  }) async {
    final list = await _getJsonList(
      instanceUrl: instanceUrl,
      path: '/api/v1/accounts/$accountId/statuses',
      accessToken: accessToken,
      queryParameters: {
        'limit': '$limit',
        if (maxId != null && maxId.isNotEmpty) 'max_id': maxId,
      },
      errorContext: 'Failed to load user posts',
      timeout: const Duration(seconds: 20),
    );
    return _parseStatusList(list);
  }

  /// Fetches the current user's follow/notification relationship with [accountId],
  /// serving a short-TTL cache hit unless [forceRefresh] is true.
  Future<MastodonRelationship?> fetchRelationship({
    required String instanceUrl,
    required String accessToken,
    required String accountId,
    bool forceRefresh = false,
  }) async {
    final base = normalizeInstanceUrl(instanceUrl);
    final cacheKey = '$base|$accountId';
    if (!forceRefresh) {
      final cached = _relationshipCache[cacheKey];
      if (cached != null &&
          DateTime.now().difference(cached.fetchedAt) < _profileCacheTtl) {
        return cached.relationship;
      }
    }
    final uri = Uri.parse(
      '$base/api/v1/accounts/relationships?id[]=${Uri.encodeQueryComponent(accountId)}',
    );
    final res = await _client
        .get(uri, headers: _authHeaders(accessToken))
        .timeout(const Duration(seconds: 15));
    _ensureSuccess(res, 'Failed to load relationship');
    final list = jsonDecode(res.body) as List<dynamic>;
    final rel = (list.isEmpty || list.first is! Map<String, dynamic>)
        ? null
        : MastodonRelationship.fromJson(list.first as Map<String, dynamic>);
    _relationshipCache[cacheKey] =
        (relationship: rel, fetchedAt: DateTime.now());
    return rel;
  }

  /// Subscribes (`follow`) or updates notification preference (`notify: true/false`).
  Future<MastodonRelationship> followAccount({
    required String instanceUrl,
    required String accessToken,
    required String accountId,
    bool? notify,
  }) async {
    final decoded = await _postJsonObject(
      instanceUrl: instanceUrl,
      path: '/api/v1/accounts/$accountId/follow',
      accessToken: accessToken,
      body: {'notify': ?notify},
      errorContext: 'Failed to follow user',
    );
    final rel = MastodonRelationship.fromJson(decoded);
    final cacheKey = '${normalizeInstanceUrl(instanceUrl)}|$accountId';
    _relationshipCache[cacheKey] =
        (relationship: rel, fetchedAt: DateTime.now());
    return rel;
  }

  /// Unsubscribes (`unfollow`) from [accountId].
  Future<MastodonRelationship> unfollowAccount({
    required String instanceUrl,
    required String accessToken,
    required String accountId,
  }) async {
    final decoded = await _postJsonObject(
      instanceUrl: instanceUrl,
      path: '/api/v1/accounts/$accountId/unfollow',
      accessToken: accessToken,
      errorContext: 'Failed to unfollow user',
    );
    final rel = MastodonRelationship.fromJson(decoded);
    final cacheKey = '${normalizeInstanceUrl(instanceUrl)}|$accountId';
    _relationshipCache[cacheKey] =
        (relationship: rel, fetchedAt: DateTime.now());
    return rel;
  }

  /// Fetches ancestor and descendant posts for a conversation thread (`GET /api/v1/statuses/{id}/context`).
  Future<MastodonContext> fetchStatusContext({
    required String instanceUrl,
    required String accessToken,
    required String statusId,
  }) async {
    final decoded = await _getJsonObject(
      instanceUrl: instanceUrl,
      path: '/api/v1/statuses/$statusId/context',
      accessToken: accessToken,
      errorContext: 'Failed to load conversation thread',
    );
    return MastodonContext.fromJson(decoded);
  }

  /// Fetches raw source text and content warning for editing an existing status.
  Future<MastodonStatusSource> fetchStatusSource({
    required String instanceUrl,
    required String accessToken,
    required String statusId,
  }) async {
    final decoded = await _getJsonObject(
      instanceUrl: instanceUrl,
      path: '/api/v1/statuses/$statusId/source',
      accessToken: accessToken,
      errorContext: 'Failed to fetch status source for editing',
    );
    return MastodonStatusSource.fromJson(decoded);
  }

  /// Extracts a local numeric Mastodon status ID if [statusUrl] is hosted on
  /// the exact same [instanceUrl] (e.g. `https://mastodon.social/@user/12345`),
  /// allowing a cheap `GET /api/v1/statuses/{id}` instead of an expensive
  /// federated `/api/v2/search?resolve=true` query.
  static String? extractSameInstanceStatusId({
    required String instanceUrl,
    required String statusUrl,
  }) {
    final baseUri = Uri.tryParse(normalizeInstanceUrl(instanceUrl));
    final targetUri = Uri.tryParse(statusUrl.trim());
    if (baseUri == null || targetUri == null) return null;
    if (baseUri.host.isEmpty ||
        baseUri.host.toLowerCase() != targetUri.host.toLowerCase()) {
      return null;
    }
    final segments =
        targetUri.pathSegments.where((s) => s.trim().isNotEmpty).toList();
    if (segments.length < 2) return null;
    final last = segments.last;
    if (!RegExp(r'^\d{6,}$').hasMatch(last)) return null;
    final prev = segments[segments.length - 2];
    if (prev.startsWith('@') || prev == 'statuses') {
      return last;
    }
    return null;
  }

  /// Resolves a referenced Mastodon status URL. Uses cheap primary-key lookup
  /// `GET /api/v1/statuses/{id}` for same-instance URLs and falls back to
  /// `/api/v2/search?resolve=true` only for remote federated posts.
  Future<MastodonStatus?> resolveStatusByUrl({
    required String instanceUrl,
    required String accessToken,
    required String statusUrl,
  }) async {
    final localId = extractSameInstanceStatusId(
      instanceUrl: instanceUrl,
      statusUrl: statusUrl,
    );
    if (localId != null) {
      try {
        final decoded = await _getJsonObject(
          instanceUrl: instanceUrl,
          path: '/api/v1/statuses/$localId',
          accessToken: accessToken,
          errorContext: 'Failed to load local status',
          timeout: const Duration(seconds: 10),
        );
        return MastodonStatus.fromJson(decoded);
      } catch (_) {
        // Fall through to search resolver if status ID scheme differs.
      }
    }

    final uri = _buildUri(
      instanceUrl,
      '/api/v2/search',
      queryParameters: {
        'q': statusUrl,
        'type': 'statuses',
        'resolve': 'true',
        'limit': '1',
      },
    );
    try {
      final res = await _client
          .get(uri, headers: _authHeaders(accessToken))
          .timeout(const Duration(seconds: 10));
      if (res.statusCode < 200 || res.statusCode >= 300) return null;
      final decoded = jsonDecode(res.body) as Map<String, dynamic>;
      final statuses = (decoded['statuses'] as List<dynamic>?) ?? const [];
      if (statuses.isEmpty || statuses.first is! Map<String, dynamic>) {
        return null;
      }
      return MastodonStatus.fromJson(statuses.first as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  /// Uploads a media file with optional alt-text description (`POST /api/v2/media`).
  Future<MastodonMediaAttachment> uploadMedia({
    required String instanceUrl,
    required String accessToken,
    required String filePath,
    String? description,
  }) async {
    final base = normalizeInstanceUrl(instanceUrl);
    final file = File(filePath);
    if (!await file.exists()) {
      throw const MastodonApiException('Attachment file not found on device.');
    }

    final req = http.MultipartRequest('POST', Uri.parse('$base/api/v2/media'));
    req.headers.addAll(_authHeaders(accessToken));
    req.files.add(await http.MultipartFile.fromPath('file', filePath));
    if (description != null && description.trim().isNotEmpty) {
      req.fields['description'] = description.trim();
    }

    final streamed = await _client.send(req).timeout(const Duration(seconds: 90));
    final res = await http.Response.fromStream(streamed);
    _ensureSuccess(res, 'Failed to upload media');

    final decoded = jsonDecode(res.body) as Map<String, dynamic>;
    final attachment = MastodonMediaAttachment.fromJson(decoded);

    // HTTP 202 indicates asynchronous media processing (commonly videos).
    if (res.statusCode == 202 && attachment.id.isNotEmpty) {
      return _waitForMediaProcessing(
        base: base,
        accessToken: accessToken,
        mediaId: attachment.id,
        fallback: attachment,
      );
    }

    return attachment;
  }

  Future<MastodonMediaAttachment> _waitForMediaProcessing({
    required String base,
    required String accessToken,
    required String mediaId,
    required MastodonMediaAttachment fallback,
  }) async {
    // Progressive backoff reduces polling pressure on Sidekiq video workers.
    const delaysMs = [1500, 2000, 2500, 3000, 4000, 5000];
    for (var attempt = 0; attempt < 15; attempt++) {
      final delayMs =
          delaysMs[attempt < delaysMs.length ? attempt : delaysMs.length - 1];
      await Future<void>.delayed(Duration(milliseconds: delayMs));
      final res = await _client
          .get(
            Uri.parse('$base/api/v1/media/$mediaId'),
            headers: _authHeaders(accessToken),
          )
          .timeout(const Duration(seconds: 15));
      if (res.statusCode == 200) {
        return MastodonMediaAttachment.fromJson(
          jsonDecode(res.body) as Map<String, dynamic>,
        );
      }
      if (res.statusCode != 206) {
        break;
      }
    }
    return fallback;
  }

  /// Publishes a new status (`POST /api/v1/statuses`).
  Future<MastodonStatus> createStatus({
    required String instanceUrl,
    required String accessToken,
    required String statusText,
    String? spoilerText,
    PostVisibility visibility = PostVisibility.public,
    String? inReplyToId,
    String? language,
    List<String> mediaIds = const [],
  }) async {
    final decoded = await _postJsonObject(
      instanceUrl: instanceUrl,
      path: '/api/v1/statuses',
      accessToken: accessToken,
      body: {
        'status': statusText,
        'visibility': visibility.apiValue,
        if (spoilerText != null && spoilerText.trim().isNotEmpty)
          'spoiler_text': spoilerText.trim(),
        if (inReplyToId != null && inReplyToId.isNotEmpty)
          'in_reply_to_id': inReplyToId,
        if (language != null && language.trim().isNotEmpty)
          'language': language.trim(),
        if (mediaIds.isNotEmpty) 'media_ids': mediaIds,
      },
      errorContext: 'Failed to publish post',
      timeout: const Duration(seconds: 25),
    );
    return MastodonStatus.fromJson(decoded);
  }

  /// Updates an existing status (`PUT /api/v1/statuses/{id}`) including updated
  /// `media_attributes` (`{ id, description }`) so edited alt-text persists on Mastodon.
  Future<MastodonStatus> editStatus({
    required String instanceUrl,
    required String accessToken,
    required String statusId,
    required String statusText,
    String? spoilerText,
    String? language,
    List<String> mediaIds = const [],
    List<Map<String, String>> mediaAttributes = const [],
  }) async {
    final payload = <String, dynamic>{
      'status': statusText,
      'spoiler_text': (spoilerText ?? '').trim(),
      if (language != null && language.trim().isNotEmpty)
        'language': language.trim(),
      if (mediaIds.isNotEmpty) 'media_ids': mediaIds,
      if (mediaAttributes.isNotEmpty) 'media_attributes': mediaAttributes,
    };

    final res = await _client
        .put(
          _buildUri(instanceUrl, '/api/v1/statuses/$statusId'),
          headers: {
            ..._authHeaders(accessToken),
            'Content-Type': 'application/json',
          },
          body: jsonEncode(payload),
        )
        .timeout(const Duration(seconds: 25));
    _ensureSuccess(res, 'Failed to save edited post');
    return MastodonStatus.fromJson(
      jsonDecode(res.body) as Map<String, dynamic>,
    );
  }

  /// Permanently deletes a status owned by the logged-in user (`DELETE /api/v1/statuses/{id}`).
  Future<void> deleteStatus({
    required String instanceUrl,
    required String accessToken,
    required String statusId,
  }) async {
    final res = await _client
        .delete(
          _buildUri(instanceUrl, '/api/v1/statuses/$statusId'),
          headers: _authHeaders(accessToken),
        )
        .timeout(const Duration(seconds: 15));
    _ensureSuccess(res, 'Failed to delete post');
  }

  /// Favorites or unfavorites [statusId] depending on [currentlyFavourited].
  Future<MastodonStatus> toggleFavourite({
    required String instanceUrl,
    required String accessToken,
    required String statusId,
    required bool currentlyFavourited,
  }) =>
      _postStatusAction(
        instanceUrl: instanceUrl,
        accessToken: accessToken,
        statusId: statusId,
        action: currentlyFavourited ? 'unfavourite' : 'favourite',
        errorContext: 'Failed to update favorite',
      );

  /// Boosts (`reblog`) or unboosts [statusId] depending on [currentlyReblogged].
  Future<MastodonStatus> toggleReblog({
    required String instanceUrl,
    required String accessToken,
    required String statusId,
    required bool currentlyReblogged,
  }) =>
      _postStatusAction(
        instanceUrl: instanceUrl,
        accessToken: accessToken,
        statusId: statusId,
        action: currentlyReblogged ? 'unreblog' : 'reblog',
        errorContext: 'Failed to update boost',
      );

  /// Bookmarks or unbookmarks [statusId] depending on [currentlyBookmarked].
  Future<MastodonStatus> toggleBookmark({
    required String instanceUrl,
    required String accessToken,
    required String statusId,
    required bool currentlyBookmarked,
  }) =>
      _postStatusAction(
        instanceUrl: instanceUrl,
        accessToken: accessToken,
        statusId: statusId,
        action: currentlyBookmarked ? 'unbookmark' : 'bookmark',
        errorContext: 'Failed to update bookmark',
      );

  /// Translates a status via the connected Mastodon instance's built-in
  /// translation API (`POST /api/v1/statuses/:id/translate`).
  Future<MastodonStatusTranslation> translateStatus({
    required String instanceUrl,
    required String accessToken,
    required String statusId,
    required String targetLanguage,
  }) async {
    final decoded = await _postJsonObject(
      instanceUrl: instanceUrl,
      path: '/api/v1/statuses/$statusId/translate',
      accessToken: accessToken,
      body: {'lang': targetLanguage},
      errorContext: 'Failed to translate post via Mastodon server',
      timeout: const Duration(seconds: 20),
    );
    return MastodonStatusTranslation.fromJson(decoded);
  }

  /// Downloads remote image/preview bytes for on-demand timeline AI descriptions
  /// or re-scanning existing media while editing a post, reusing the local disk
  /// cache whenever possible.
  Future<({Uint8List bytes, String mimeType})> downloadMediaBytes(
    String mediaUrl,
  ) async {
    if (_ownsClient) {
      final cached = await MediaCacheService.instance.getOrFetch(mediaUrl);
      return (bytes: cached.bytes, mimeType: cached.mimeType);
    }
    final res = await _client
        .get(Uri.parse(mediaUrl), headers: _baseHeaders)
        .timeout(const Duration(seconds: 25));
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw MastodonApiException(
        'Failed to download media (${res.statusCode})',
        statusCode: res.statusCode,
      );
    }
    final contentType =
        (res.headers['content-type'] ?? 'image/jpeg').split(';').first.trim();
    return (bytes: res.bodyBytes, mimeType: contentType);
  }

  Uri _buildUri(
    String instanceUrl,
    String path, {
    Map<String, String>? queryParameters,
  }) {
    final base = normalizeInstanceUrl(instanceUrl);
    final uri = Uri.parse('$base$path');
    return queryParameters == null
        ? uri
        : uri.replace(queryParameters: queryParameters);
  }

  Future<Map<String, dynamic>> _getJsonObject({
    required String instanceUrl,
    required String path,
    required String accessToken,
    required String errorContext,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final res = await _client
        .get(
          _buildUri(instanceUrl, path),
          headers: _authHeaders(accessToken),
        )
        .timeout(timeout);
    _ensureSuccess(res, errorContext);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<List<dynamic>> _getJsonList({
    required String instanceUrl,
    required String path,
    required String accessToken,
    required String errorContext,
    Map<String, String>? queryParameters,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final res = await _client
        .get(
          _buildUri(instanceUrl, path, queryParameters: queryParameters),
          headers: _authHeaders(accessToken),
        )
        .timeout(timeout);
    _ensureSuccess(res, errorContext);
    return jsonDecode(res.body) as List<dynamic>;
  }

  Future<Map<String, dynamic>> _postJsonObject({
    required String instanceUrl,
    required String path,
    required String errorContext,
    String? accessToken,
    Map<String, dynamic>? body,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final headers = <String, String>{
      ..._baseHeaders,
      if (accessToken != null) ..._authHeaders(accessToken),
      if (body != null) 'Content-Type': 'application/json',
    };
    final res = await _client
        .post(
          _buildUri(instanceUrl, path),
          headers: headers,
          body: body != null ? jsonEncode(body) : null,
        )
        .timeout(timeout);
    _ensureSuccess(res, errorContext);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<MastodonStatus> _postStatusAction({
    required String instanceUrl,
    required String accessToken,
    required String statusId,
    required String action,
    required String errorContext,
  }) async {
    final decoded = await _postJsonObject(
      instanceUrl: instanceUrl,
      path: '/api/v1/statuses/$statusId/$action',
      accessToken: accessToken,
      errorContext: errorContext,
    );
    return MastodonStatus.fromJson(decoded);
  }

  List<MastodonStatus> _parseStatusList(List<dynamic> list) => list
      .whereType<Map<String, dynamic>>()
      .map(MastodonStatus.fromJson)
      .toList();

  static const Map<String, String> _baseHeaders = {
    'Accept': 'application/json',
    'User-Agent':
        'FediCaption/${AppConstants.appVersion} (+${AppConstants.repositoryUrl})',
  };

  Map<String, String> _authHeaders(String accessToken) => {
        ..._baseHeaders,
        'Authorization': 'Bearer $accessToken',
      };

  void _ensureSuccess(http.Response res, String fallbackMessage) {
    if (res.statusCode >= 200 && res.statusCode < 300) return;
    if (res.statusCode == 429) {
      final retryAfter = res.headers['retry-after'];
      final waitHint = (retryAfter != null && retryAfter.trim().isNotEmpty)
          ? ' Please retry after ${retryAfter.trim()}s.'
          : ' Please wait a moment before trying again.';
      throw MastodonApiException(
        'Mastodon server rate limit reached (429).$waitHint',
        statusCode: 429,
      );
    }
    String detail = fallbackMessage;
    try {
      final decoded = jsonDecode(res.body);
      if (decoded is Map<String, dynamic> && decoded['error'] is String) {
        detail = '$fallbackMessage: ${decoded['error']}';
      }
    } catch (_) {
      // Keep fallback message.
    }
    throw MastodonApiException(detail, statusCode: res.statusCode);
  }
}
