// Copyright (c) 2026 brokengoose <brokengoose@users.noreply.github.com>
// SPDX-License-Identifier: MIT

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../core/constants.dart';
import '../models/mastodon_models.dart';

class MastodonApiException implements Exception {
  const MastodonApiException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

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
  MastodonService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

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

  /// Registers the OAuth 2.0 application with the Mastodon instance (`POST /api/v1/apps`).
  /// Per Section 1, `website` explicitly points to the GitHub repository URL.
  Future<OAuthAppCredentials> registerOAuthApp(String instanceUrl) async {
    final base = normalizeInstanceUrl(instanceUrl);
    final res = await _client
        .post(
          Uri.parse('$base/api/v1/apps'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'client_name': AppConstants.oauthClientName,
            'redirect_uris': AppConstants.oauthRedirectUri,
            'scopes': AppConstants.oauthScopes,
            'website': AppConstants.oauthWebsite,
          }),
        )
        .timeout(const Duration(seconds: 20));

    _ensureSuccess(res, 'Failed to register OAuth app');
    final decoded = jsonDecode(res.body) as Map<String, dynamic>;
    return OAuthAppCredentials(
      clientId: (decoded['client_id'] as String?) ?? '',
      clientSecret: (decoded['client_secret'] as String?) ?? '',
    );
  }

  /// Builds the `/oauth/authorize` URI for `ASWebAuthenticationSession` / Custom Tabs.
  Uri buildAuthorizeUrl({
    required String instanceUrl,
    required String clientId,
  }) {
    final base = normalizeInstanceUrl(instanceUrl);
    return Uri.parse('$base/oauth/authorize').replace(
      queryParameters: {
        'client_id': clientId,
        'scope': AppConstants.oauthScopes,
        'redirect_uri': AppConstants.oauthRedirectUri,
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
  }) async {
    final base = normalizeInstanceUrl(instanceUrl);
    final res = await _client
        .post(
          Uri.parse('$base/oauth/token'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'client_id': clientId,
            'client_secret': clientSecret,
            'redirect_uri': AppConstants.oauthRedirectUri,
            'grant_type': 'authorization_code',
            'code': code,
            'scope': AppConstants.oauthScopes,
          }),
        )
        .timeout(const Duration(seconds: 20));

    _ensureSuccess(res, 'Failed to exchange OAuth token');
    final decoded = jsonDecode(res.body) as Map<String, dynamic>;
    final token = (decoded['access_token'] as String?) ?? '';
    if (token.isEmpty) {
      throw const MastodonApiException('Server did not return an access token.');
    }
    return token;
  }

  /// Verifies the access token and returns the logged-in user's account profile.
  Future<MastodonAccount> verifyCredentials({
    required String instanceUrl,
    required String accessToken,
  }) async {
    final base = normalizeInstanceUrl(instanceUrl);
    final res = await _client
        .get(
          Uri.parse('$base/api/v1/accounts/verify_credentials'),
          headers: _authHeaders(accessToken),
        )
        .timeout(const Duration(seconds: 15));
    _ensureSuccess(res, 'Failed to verify Mastodon credentials');
    return MastodonAccount.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  /// Queries dynamic server limits from `GET /api/v2/instance` with fallback to `GET /api/v1/instance`.
  Future<InstanceLimits> fetchInstanceLimits({
    required String instanceUrl,
    String? accessToken,
  }) async {
    final base = normalizeInstanceUrl(instanceUrl);
    final headers = accessToken != null && accessToken.isNotEmpty
        ? _authHeaders(accessToken)
        : const {'Accept': 'application/json'};

    for (final endpoint in ['/api/v2/instance', '/api/v1/instance']) {
      try {
        final res = await _client
            .get(Uri.parse('$base$endpoint'), headers: headers)
            .timeout(const Duration(seconds: 12));
        if (res.statusCode >= 200 && res.statusCode < 300) {
          final decoded = jsonDecode(res.body) as Map<String, dynamic>;
          return InstanceLimits.fromInstanceJson(decoded);
        }
      } catch (_) {
        // Try fallback endpoint.
      }
    }
    return const InstanceLimits();
  }

  /// Fetches statuses for any supported [TimelineType].
  Future<List<MastodonStatus>> fetchTimeline({
    required String instanceUrl,
    required String accessToken,
    required TimelineType type,
    required String currentUserId,
    String? maxId,
    int limit = 25,
  }) async {
    final base = normalizeInstanceUrl(instanceUrl);
    final query = <String, String>{
      'limit': '$limit',
      if (maxId != null && maxId.isNotEmpty) 'max_id': maxId,
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

    final uri = Uri.parse('$base$path').replace(queryParameters: query);
    final res = await _client
        .get(uri, headers: _authHeaders(accessToken))
        .timeout(const Duration(seconds: 20));
    _ensureSuccess(res, 'Failed to load ${type.fullTitle}');
    final list = jsonDecode(res.body) as List<dynamic>;
    return list
        .whereType<Map<String, dynamic>>()
        .map(MastodonStatus.fromJson)
        .toList();
  }

  Future<List<MastodonNotification>> fetchNotifications({
    required String instanceUrl,
    required String accessToken,
    String? maxId,
    int limit = 30,
  }) async {
    final base = normalizeInstanceUrl(instanceUrl);
    final uri = Uri.parse('$base/api/v1/notifications').replace(
      queryParameters: {
        'limit': '$limit',
        if (maxId != null && maxId.isNotEmpty) 'max_id': maxId,
      },
    );
    final res = await _client
        .get(uri, headers: _authHeaders(accessToken))
        .timeout(const Duration(seconds: 20));
    _ensureSuccess(res, 'Failed to load notifications');
    final list = jsonDecode(res.body) as List<dynamic>;
    return list
        .whereType<Map<String, dynamic>>()
        .map(MastodonNotification.fromJson)
        .toList();
  }

  Future<MastodonAccount> fetchAccount({
    required String instanceUrl,
    required String accessToken,
    required String accountId,
  }) async {
    final base = normalizeInstanceUrl(instanceUrl);
    final res = await _client
        .get(
          Uri.parse('$base/api/v1/accounts/$accountId'),
          headers: _authHeaders(accessToken),
        )
        .timeout(const Duration(seconds: 15));
    _ensureSuccess(res, 'Failed to load user profile');
    return MastodonAccount.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<List<MastodonStatus>> fetchAccountStatuses({
    required String instanceUrl,
    required String accessToken,
    required String accountId,
    String? maxId,
    int limit = 25,
  }) async {
    final base = normalizeInstanceUrl(instanceUrl);
    final uri = Uri.parse('$base/api/v1/accounts/$accountId/statuses').replace(
      queryParameters: {
        'limit': '$limit',
        if (maxId != null && maxId.isNotEmpty) 'max_id': maxId,
      },
    );
    final res = await _client
        .get(uri, headers: _authHeaders(accessToken))
        .timeout(const Duration(seconds: 20));
    _ensureSuccess(res, 'Failed to load user posts');
    final list = jsonDecode(res.body) as List<dynamic>;
    return list
        .whereType<Map<String, dynamic>>()
        .map(MastodonStatus.fromJson)
        .toList();
  }

  Future<MastodonRelationship?> fetchRelationship({
    required String instanceUrl,
    required String accessToken,
    required String accountId,
  }) async {
    final base = normalizeInstanceUrl(instanceUrl);
    final uri = Uri.parse(
      '$base/api/v1/accounts/relationships?id[]=${Uri.encodeQueryComponent(accountId)}',
    );
    final res = await _client
        .get(uri, headers: _authHeaders(accessToken))
        .timeout(const Duration(seconds: 15));
    _ensureSuccess(res, 'Failed to load relationship');
    final list = jsonDecode(res.body) as List<dynamic>;
    if (list.isEmpty || list.first is! Map<String, dynamic>) return null;
    return MastodonRelationship.fromJson(list.first as Map<String, dynamic>);
  }

  /// Subscribes (`follow`) or updates notification preference (`notify: true/false`).
  Future<MastodonRelationship> followAccount({
    required String instanceUrl,
    required String accessToken,
    required String accountId,
    bool? notify,
  }) async {
    final base = normalizeInstanceUrl(instanceUrl);
    final res = await _client
        .post(
          Uri.parse('$base/api/v1/accounts/$accountId/follow'),
          headers: {
            ..._authHeaders(accessToken),
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            if (notify != null) 'notify': notify,
          }),
        )
        .timeout(const Duration(seconds: 15));
    _ensureSuccess(res, 'Failed to follow user');
    return MastodonRelationship.fromJson(
      jsonDecode(res.body) as Map<String, dynamic>,
    );
  }

  Future<MastodonRelationship> unfollowAccount({
    required String instanceUrl,
    required String accessToken,
    required String accountId,
  }) async {
    final base = normalizeInstanceUrl(instanceUrl);
    final res = await _client
        .post(
          Uri.parse('$base/api/v1/accounts/$accountId/unfollow'),
          headers: _authHeaders(accessToken),
        )
        .timeout(const Duration(seconds: 15));
    _ensureSuccess(res, 'Failed to unfollow user');
    return MastodonRelationship.fromJson(
      jsonDecode(res.body) as Map<String, dynamic>,
    );
  }

  Future<MastodonContext> fetchStatusContext({
    required String instanceUrl,
    required String accessToken,
    required String statusId,
  }) async {
    final base = normalizeInstanceUrl(instanceUrl);
    final res = await _client
        .get(
          Uri.parse('$base/api/v1/statuses/$statusId/context'),
          headers: _authHeaders(accessToken),
        )
        .timeout(const Duration(seconds: 15));
    _ensureSuccess(res, 'Failed to load conversation thread');
    return MastodonContext.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  /// Fetches raw source text and content warning for editing an existing status.
  Future<MastodonStatusSource> fetchStatusSource({
    required String instanceUrl,
    required String accessToken,
    required String statusId,
  }) async {
    final base = normalizeInstanceUrl(instanceUrl);
    final res = await _client
        .get(
          Uri.parse('$base/api/v1/statuses/$statusId/source'),
          headers: _authHeaders(accessToken),
        )
        .timeout(const Duration(seconds: 15));
    _ensureSuccess(res, 'Failed to fetch status source for editing');
    return MastodonStatusSource.fromJson(
      jsonDecode(res.body) as Map<String, dynamic>,
    );
  }

  /// Resolves a referenced Mastodon status URL via `/api/v2/search?resolve=true`.
  Future<MastodonStatus?> resolveStatusByUrl({
    required String instanceUrl,
    required String accessToken,
    required String statusUrl,
  }) async {
    final base = normalizeInstanceUrl(instanceUrl);
    final uri = Uri.parse('$base/api/v2/search').replace(
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
    for (var attempt = 0; attempt < 20; attempt++) {
      await Future<void>.delayed(const Duration(seconds: 2));
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
    final base = normalizeInstanceUrl(instanceUrl);
    final payload = <String, dynamic>{
      'status': statusText,
      'visibility': visibility.apiValue,
      if (spoilerText != null && spoilerText.trim().isNotEmpty)
        'spoiler_text': spoilerText.trim(),
      if (inReplyToId != null && inReplyToId.isNotEmpty)
        'in_reply_to_id': inReplyToId,
      if (language != null && language.trim().isNotEmpty)
        'language': language.trim(),
      if (mediaIds.isNotEmpty) 'media_ids': mediaIds,
    };

    final res = await _client
        .post(
          Uri.parse('$base/api/v1/statuses'),
          headers: {
            ..._authHeaders(accessToken),
            'Content-Type': 'application/json',
          },
          body: jsonEncode(payload),
        )
        .timeout(const Duration(seconds: 25));
    _ensureSuccess(res, 'Failed to publish post');
    return MastodonStatus.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
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
    final base = normalizeInstanceUrl(instanceUrl);
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
          Uri.parse('$base/api/v1/statuses/$statusId'),
          headers: {
            ..._authHeaders(accessToken),
            'Content-Type': 'application/json',
          },
          body: jsonEncode(payload),
        )
        .timeout(const Duration(seconds: 25));
    _ensureSuccess(res, 'Failed to save edited post');
    return MastodonStatus.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<void> deleteStatus({
    required String instanceUrl,
    required String accessToken,
    required String statusId,
  }) async {
    final base = normalizeInstanceUrl(instanceUrl);
    final res = await _client
        .delete(
          Uri.parse('$base/api/v1/statuses/$statusId'),
          headers: _authHeaders(accessToken),
        )
        .timeout(const Duration(seconds: 15));
    _ensureSuccess(res, 'Failed to delete post');
  }

  Future<MastodonStatus> toggleFavourite({
    required String instanceUrl,
    required String accessToken,
    required String statusId,
    required bool currentlyFavourited,
  }) async {
    final base = normalizeInstanceUrl(instanceUrl);
    final action = currentlyFavourited ? 'unfavourite' : 'favourite';
    final res = await _client
        .post(
          Uri.parse('$base/api/v1/statuses/$statusId/$action'),
          headers: _authHeaders(accessToken),
        )
        .timeout(const Duration(seconds: 15));
    _ensureSuccess(res, 'Failed to update favorite');
    return MastodonStatus.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<MastodonStatus> toggleReblog({
    required String instanceUrl,
    required String accessToken,
    required String statusId,
    required bool currentlyReblogged,
  }) async {
    final base = normalizeInstanceUrl(instanceUrl);
    final action = currentlyReblogged ? 'unreblog' : 'reblog';
    final res = await _client
        .post(
          Uri.parse('$base/api/v1/statuses/$statusId/$action'),
          headers: _authHeaders(accessToken),
        )
        .timeout(const Duration(seconds: 15));
    _ensureSuccess(res, 'Failed to update boost');
    return MastodonStatus.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<MastodonStatus> toggleBookmark({
    required String instanceUrl,
    required String accessToken,
    required String statusId,
    required bool currentlyBookmarked,
  }) async {
    final base = normalizeInstanceUrl(instanceUrl);
    final action = currentlyBookmarked ? 'unbookmark' : 'bookmark';
    final res = await _client
        .post(
          Uri.parse('$base/api/v1/statuses/$statusId/$action'),
          headers: _authHeaders(accessToken),
        )
        .timeout(const Duration(seconds: 15));
    _ensureSuccess(res, 'Failed to update bookmark');
    return MastodonStatus.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  /// Downloads remote image/preview bytes for on-demand timeline AI descriptions
  /// or re-scanning existing media while editing a post.
  Future<({Uint8List bytes, String mimeType})> downloadMediaBytes(
    String mediaUrl,
  ) async {
    final res = await _client
        .get(Uri.parse(mediaUrl))
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

  Map<String, String> _authHeaders(String accessToken) => {
        'Authorization': 'Bearer $accessToken',
        'Accept': 'application/json',
      };

  void _ensureSuccess(http.Response res, String fallbackMessage) {
    if (res.statusCode >= 200 && res.statusCode < 300) return;
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
