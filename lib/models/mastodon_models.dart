// Copyright (c) 2026 brokengoose <brokengoose@users.noreply.github.com>
// SPDX-License-Identifier: MIT

import '../core/constants.dart';
import '../core/html_utils.dart';

/// Supported timelines and feeds.
enum TimelineType {
  home('Home', 'Home Timeline'),
  local('Local', 'Local Timeline'),
  federated('Federated', 'Federated Timeline'),
  notifications('Notifications', 'Notifications'),
  bookmarks('Bookmarks', 'Bookmarks'),
  favorites('Favorites', 'Favorites'),
  myPosts('My Posts', 'My Published Posts');

  const TimelineType(this.shortLabel, this.fullTitle);

  final String shortLabel;
  final String fullTitle;
}

/// Mastodon post visibility options.
enum PostVisibility {
  public('public', 'Public', 'Visible to everyone and shown in public timelines'),
  unlisted('unlisted', 'Unlisted', 'Visible to everyone, but omitted from public timelines'),
  private('private', 'Followers Only', 'Visible only to your followers'),
  direct('direct', 'Mentioned Only', 'Visible only to mentioned users');

  const PostVisibility(this.apiValue, this.label, this.description);

  final String apiValue;
  final String label;
  final String description;

  static PostVisibility fromApi(String? value) {
    return PostVisibility.values.firstWhere(
      (v) => v.apiValue == value,
      orElse: () => PostVisibility.public,
    );
  }
}

/// Dynamic character and media limits queried from the connected Mastodon server.
class InstanceLimits {
  const InstanceLimits({
    this.maxCharacters = AppConstants.defaultMaxCharacters,
    this.maxMediaAttachments = AppConstants.defaultMaxMediaAttachments,
    this.altTextLimit = AppConstants.defaultAltTextLimit,
    this.instanceTitle = '',
    this.translationEnabled = false,
  });

  final int maxCharacters;
  final int maxMediaAttachments;
  final int altTextLimit;
  final String instanceTitle;
  final bool translationEnabled;

  /// Parses limits from `/api/v2/instance` or `/api/v1/instance` (including Glitch-soc,
  /// Hometown, Pleroma, and Akkoma extensions).
  factory InstanceLimits.fromInstanceJson(Map<String, dynamic> json) {
    final config = json['configuration'] as Map<String, dynamic>?;
    final statuses = config?['statuses'] as Map<String, dynamic>?;
    final media = config?['media_attachments'] as Map<String, dynamic>?;
    final translation = config?['translation'] as Map<String, dynamic>?;

    final maxChars = _parsePositiveInt(statuses?['max_characters']) ??
        _parsePositiveInt(json['max_toot_chars']) ??
        _parsePositiveInt(json['max_characters']) ??
        AppConstants.defaultMaxCharacters;

    final maxMedia = _parsePositiveInt(statuses?['max_media_attachments']) ??
        AppConstants.defaultMaxMediaAttachments;

    final altLimit = _parsePositiveInt(media?['description_limit']) ??
        AppConstants.defaultAltTextLimit;

    final translationEnabled = translation?['enabled'] == true;

    return InstanceLimits(
      maxCharacters: maxChars,
      maxMediaAttachments: maxMedia,
      altTextLimit: altLimit,
      instanceTitle: (json['title'] as String?) ?? '',
      translationEnabled: translationEnabled,
    );
  }

  static int? _parsePositiveInt(dynamic value) {
    if (value is int && value > 0) return value;
    if (value is num && value.toInt() > 0) return value.toInt();
    if (value is String) {
      final parsed = int.tryParse(value);
      if (parsed != null && parsed > 0) return parsed;
    }
    return null;
  }
}

/// Represents a Mastodon/Fediverse user account profile.
class MastodonAccount {
  const MastodonAccount({
    required this.id,
    required this.username,
    required this.acct,
    required this.displayName,
    required this.avatar,
    this.header = '',
    this.note = '',
    this.url = '',
    this.followersCount = 0,
    this.followingCount = 0,
    this.statusesCount = 0,
  });

  final String id;
  final String username;
  final String acct;
  final String displayName;
  final String avatar;
  final String header;
  final String note;
  final String url;
  final int followersCount;
  final int followingCount;
  final int statusesCount;

  String get effectiveDisplayName =>
      displayName.trim().isNotEmpty ? displayName.trim() : username;

  String get handle => acct.startsWith('@') ? acct : '@$acct';

  String get plainBio => HtmlUtils.htmlToPlainText(note);

  factory MastodonAccount.fromJson(Map<String, dynamic> json) {
    return MastodonAccount(
      id: (json['id'] ?? '').toString(),
      username: (json['username'] as String?) ?? '',
      acct: (json['acct'] as String?) ?? (json['username'] as String?) ?? '',
      displayName: (json['display_name'] as String?) ?? '',
      avatar: (json['avatar_static'] as String?) ??
          (json['avatar'] as String?) ??
          '',
      header: (json['header_static'] as String?) ??
          (json['header'] as String?) ??
          '',
      note: (json['note'] as String?) ?? '',
      url: (json['url'] as String?) ?? '',
      followersCount: (json['followers_count'] as num?)?.toInt() ?? 0,
      followingCount: (json['following_count'] as num?)?.toInt() ?? 0,
      statusesCount: (json['statuses_count'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Represents an image, video, GIFV, or audio attachment on a Mastodon status.
class MastodonMediaAttachment {
  const MastodonMediaAttachment({
    required this.id,
    required this.type,
    required this.url,
    this.previewUrl = '',
    this.description,
    this.remoteUrl,
    this.aspectRatio,
  });

  final String id;
  final String type; // image, video, gifv, audio, unknown
  final String url;
  final String previewUrl;
  final String? description;
  final String? remoteUrl;
  final double? aspectRatio;

  bool get isVideo => type == 'video' || type == 'gifv';
  bool get isImage => type == 'image';
  bool get hasAltText => (description ?? '').trim().isNotEmpty;
  String get bestPreviewUrl => previewUrl.isNotEmpty ? previewUrl : url;

  factory MastodonMediaAttachment.fromJson(Map<String, dynamic> json) {
    final meta = json['meta'] as Map<String, dynamic>?;
    final small = meta?['small'] as Map<String, dynamic>?;
    final original = meta?['original'] as Map<String, dynamic>?;
    final rawAspect = (small?['aspect'] ?? original?['aspect']) as num?;
    final aspect =
        rawAspect != null && rawAspect.isFinite && rawAspect > 0
            ? rawAspect.toDouble()
            : null;
    return MastodonMediaAttachment(
      id: (json['id'] ?? '').toString(),
      type: (json['type'] as String?) ?? 'unknown',
      url: (json['url'] as String?) ?? '',
      previewUrl: (json['preview_url'] as String?) ?? '',
      description: json['description'] as String?,
      remoteUrl: json['remote_url'] as String?,
      aspectRatio: aspect,
    );
  }
}

/// Represents an `@mention` entity referenced inside a Mastodon status.
class MastodonMention {
  const MastodonMention({
    required this.id,
    required this.username,
    required this.acct,
    required this.url,
  });

  final String id;
  final String username;
  final String acct;
  final String url;

  /// Creates a lightweight [MastodonAccount] stub for immediately navigating to
  /// `ProfileScreen` before full profile metadata finishes loading.
  MastodonAccount toStubAccount() => MastodonAccount(
        id: id,
        username: username,
        acct: acct,
        displayName: username,
        avatar: '',
        url: url,
      );

  factory MastodonMention.fromJson(Map<String, dynamic> json) {
    return MastodonMention(
      id: (json['id'] ?? '').toString(),
      username: (json['username'] as String?) ?? '',
      acct: (json['acct'] as String?) ?? '',
      url: (json['url'] as String?) ?? '',
    );
  }
}

/// Represents a Mastodon status (post), including optional boost (`reblog`) and
/// native quote (`quotedStatus`) payloads.
class MastodonStatus {
  const MastodonStatus({
    required this.id,
    required this.createdAt,
    required this.account,
    required this.contentHtml,
    this.spoilerText = '',
    this.url,
    this.uri = '',
    this.visibility = PostVisibility.public,
    this.language,
    this.inReplyToId,
    this.inReplyToAccountId,
    this.repliesCount = 0,
    this.reblogsCount = 0,
    this.favouritesCount = 0,
    this.reblogged = false,
    this.favourited = false,
    this.bookmarked = false,
    this.sensitive = false,
    this.mediaAttachments = const [],
    this.mentions = const [],
    this.reblog,
    this.quotedStatus,
    this.editedAt,
  });

  final String id;
  final DateTime createdAt;
  final MastodonAccount account;
  final String contentHtml;
  final String spoilerText;
  final String? url;
  final String uri;
  final PostVisibility visibility;
  final String? language;
  final String? inReplyToId;
  final String? inReplyToAccountId;
  final int repliesCount;
  final int reblogsCount;
  final int favouritesCount;
  final bool reblogged;
  final bool favourited;
  final bool bookmarked;
  final bool sensitive;
  final List<MastodonMediaAttachment> mediaAttachments;
  final List<MastodonMention> mentions;
  final MastodonStatus? reblog;
  final MastodonStatus? quotedStatus;
  final DateTime? editedAt;

  /// The actual displayed status (unwraps boost wrapper if present).
  MastodonStatus get displayStatus => reblog ?? this;

  bool get isBoost => reblog != null;

  /// Original permalink URL to open in external browser.
  String get permalinkUrl {
    final target = displayStatus;
    if (target.url != null && target.url!.trim().isNotEmpty) {
      return target.url!.trim();
    }
    return target.uri;
  }

  String get plainText => HtmlUtils.htmlToPlainText(contentHtml);

  MastodonStatus copyWith({
    bool? reblogged,
    bool? favourited,
    bool? bookmarked,
    int? reblogsCount,
    int? favouritesCount,
    int? repliesCount,
    MastodonStatus? reblog,
    MastodonStatus? quotedStatus,
    String? contentHtml,
    String? spoilerText,
    List<MastodonMediaAttachment>? mediaAttachments,
    List<MastodonMention>? mentions,
    DateTime? editedAt,
  }) {
    return MastodonStatus(
      id: id,
      createdAt: createdAt,
      account: account,
      contentHtml: contentHtml ?? this.contentHtml,
      spoilerText: spoilerText ?? this.spoilerText,
      url: url,
      uri: uri,
      visibility: visibility,
      language: language,
      inReplyToId: inReplyToId,
      inReplyToAccountId: inReplyToAccountId,
      repliesCount: repliesCount ?? this.repliesCount,
      reblogsCount: reblogsCount ?? this.reblogsCount,
      favouritesCount: favouritesCount ?? this.favouritesCount,
      reblogged: reblogged ?? this.reblogged,
      favourited: favourited ?? this.favourited,
      bookmarked: bookmarked ?? this.bookmarked,
      sensitive: sensitive,
      mediaAttachments: mediaAttachments ?? this.mediaAttachments,
      mentions: mentions ?? this.mentions,
      reblog: reblog ?? this.reblog,
      quotedStatus: quotedStatus ?? this.quotedStatus,
      editedAt: editedAt ?? this.editedAt,
    );
  }

  factory MastodonStatus.fromJson(Map<String, dynamic> json) {
    final rawMedia = (json['media_attachments'] as List<dynamic>?) ?? const [];
    final rawMentions = (json['mentions'] as List<dynamic>?) ?? const [];
    final rawReblog = json['reblog'] as Map<String, dynamic>?;
    final rawQuote = json['quote'] as Map<String, dynamic>?;
    Map<String, dynamic>? quotedStatusJson;
    if (rawQuote != null) {
      if (rawQuote['quoted_status'] is Map<String, dynamic>) {
        quotedStatusJson = rawQuote['quoted_status'] as Map<String, dynamic>;
      } else if (rawQuote['id'] != null && rawQuote['account'] is Map<String, dynamic>) {
        quotedStatusJson = rawQuote;
      }
    }
    final rawEditedAt = json['edited_at'] as String?;

    return MastodonStatus(
      id: (json['id'] ?? '').toString(),
      createdAt: DateTime.tryParse((json['created_at'] as String?) ?? '') ??
          DateTime.now().toUtc(),
      account: MastodonAccount.fromJson(
        (json['account'] as Map<String, dynamic>?) ?? const {},
      ),
      contentHtml: (json['content'] as String?) ?? '',
      spoilerText: (json['spoiler_text'] as String?) ?? '',
      url: json['url'] as String?,
      uri: (json['uri'] as String?) ?? '',
      visibility: PostVisibility.fromApi(json['visibility'] as String?),
      language: json['language'] as String?,
      inReplyToId: json['in_reply_to_id']?.toString(),
      inReplyToAccountId: json['in_reply_to_account_id']?.toString(),
      repliesCount: (json['replies_count'] as num?)?.toInt() ?? 0,
      reblogsCount: (json['reblogs_count'] as num?)?.toInt() ?? 0,
      favouritesCount: (json['favourites_count'] as num?)?.toInt() ?? 0,
      reblogged: json['reblogged'] as bool? ?? false,
      favourited: json['favourited'] as bool? ?? false,
      bookmarked: json['bookmarked'] as bool? ?? false,
      sensitive: json['sensitive'] as bool? ?? false,
      mediaAttachments: rawMedia
          .whereType<Map<String, dynamic>>()
          .map(MastodonMediaAttachment.fromJson)
          .toList(),
      mentions: rawMentions
          .whereType<Map<String, dynamic>>()
          .map(MastodonMention.fromJson)
          .toList(),
      reblog: rawReblog != null ? MastodonStatus.fromJson(rawReblog) : null,
      quotedStatus: quotedStatusJson != null
          ? MastodonStatus.fromJson(quotedStatusJson)
          : null,
      editedAt: rawEditedAt != null ? DateTime.tryParse(rawEditedAt) : null,
    );
  }
}

/// Unformatted source text and content warning returned by `GET /api/v1/statuses/{id}/source`.
class MastodonStatusSource {
  const MastodonStatusSource({
    required this.id,
    required this.text,
    required this.spoilerText,
  });

  final String id;
  final String text;
  final String spoilerText;

  factory MastodonStatusSource.fromJson(Map<String, dynamic> json) {
    return MastodonStatusSource(
      id: (json['id'] ?? '').toString(),
      text: (json['text'] as String?) ?? '',
      spoilerText: (json['spoiler_text'] as String?) ?? '',
    );
  }
}

/// Follow, notification, mute, and block relationship state for a Mastodon account.
class MastodonRelationship {
  const MastodonRelationship({
    required this.id,
    this.following = false,
    this.followedBy = false,
    this.requested = false,
    this.notifying = false,
    this.muting = false,
    this.blocking = false,
  });

  final String id;
  final bool following;
  final bool followedBy;
  final bool requested;
  final bool notifying;
  final bool muting;
  final bool blocking;

  factory MastodonRelationship.fromJson(Map<String, dynamic> json) {
    return MastodonRelationship(
      id: (json['id'] ?? '').toString(),
      following: json['following'] as bool? ?? false,
      followedBy: json['followed_by'] as bool? ?? false,
      requested: json['requested'] as bool? ?? false,
      notifying: json['notifying'] as bool? ?? false,
      muting: json['muting'] as bool? ?? false,
      blocking: json['blocking'] as bool? ?? false,
    );
  }
}

/// Represents a Mastodon notification event (mention, boost, favorite, follow, quote, etc.).
class MastodonNotification {
  const MastodonNotification({
    required this.id,
    required this.type,
    required this.createdAt,
    required this.account,
    this.status,
  });

  final String id;
  final String type; // mention, status, reblog, follow, follow_request, favourite, poll, update, quote, quoted_update
  final DateTime createdAt;
  final MastodonAccount account;
  final MastodonStatus? status;

  String get actionDescription {
    switch (type) {
      case 'mention':
        return 'mentioned you';
      case 'reblog':
        return 'boosted your post';
      case 'favourite':
        return 'favorited your post';
      case 'follow':
        return 'followed you';
      case 'follow_request':
        return 'requested to follow you';
      case 'status':
        return 'published a new post';
      case 'update':
        return 'edited a post';
      case 'poll':
        return 'a poll you participated in has ended';
      case 'quote':
        return 'quoted your post';
      case 'quoted_update':
        return 'edited a post you quoted';
      default:
        return type;
    }
  }

  factory MastodonNotification.fromJson(Map<String, dynamic> json) {
    final rawStatus = json['status'] as Map<String, dynamic>?;
    return MastodonNotification(
      id: (json['id'] ?? '').toString(),
      type: (json['type'] as String?) ?? 'unknown',
      createdAt: DateTime.tryParse((json['created_at'] as String?) ?? '') ??
          DateTime.now().toUtc(),
      account: MastodonAccount.fromJson(
        (json['account'] as Map<String, dynamic>?) ?? const {},
      ),
      status: rawStatus != null ? MastodonStatus.fromJson(rawStatus) : null,
    );
  }
}

/// Ancestor and descendant posts forming a conversation thread around a focal status.
class MastodonContext {
  const MastodonContext({
    required this.ancestors,
    required this.descendants,
  });

  final List<MastodonStatus> ancestors;
  final List<MastodonStatus> descendants;

  factory MastodonContext.fromJson(Map<String, dynamic> json) {
    final rawAncestors = (json['ancestors'] as List<dynamic>?) ?? const [];
    final rawDescendants = (json['descendants'] as List<dynamic>?) ?? const [];
    return MastodonContext(
      ancestors: rawAncestors
          .whereType<Map<String, dynamic>>()
          .map(MastodonStatus.fromJson)
          .toList(),
      descendants: rawDescendants
          .whereType<Map<String, dynamic>>()
          .map(MastodonStatus.fromJson)
          .toList(),
    );
  }
}

/// Result returned by Mastodon's `POST /api/v1/statuses/:id/translate` endpoint.
class MastodonStatusTranslation {
  const MastodonStatusTranslation({
    required this.contentHtml,
    required this.spoilerText,
    required this.detectedSourceLanguage,
    required this.provider,
    this.mediaDescriptions = const {},
  });

  final String contentHtml;
  final String spoilerText;
  final String detectedSourceLanguage;
  final String provider;
  final Map<String, String> mediaDescriptions;

  String get plainContent => HtmlUtils.htmlToPlainText(contentHtml).trim();

  factory MastodonStatusTranslation.fromJson(Map<String, dynamic> json) {
    final rawMedia = (json['media_attachments'] as List<dynamic>?) ?? const [];
    final mediaMap = <String, String>{};
    for (final item in rawMedia) {
      if (item is Map<String, dynamic>) {
        final id = (item['id'] ?? '').toString().trim();
        final desc = (item['description'] as String?)?.trim() ?? '';
        if (id.isNotEmpty && desc.isNotEmpty) {
          mediaMap[id] = desc;
        }
      }
    }
    return MastodonStatusTranslation(
      contentHtml: (json['content'] as String?) ?? '',
      spoilerText: (json['spoiler_text'] as String?) ?? '',
      detectedSourceLanguage:
          (json['detected_source_language'] as String?) ?? '',
      provider: (json['provider'] as String?) ?? '',
      mediaDescriptions: mediaMap,
    );
  }
}
