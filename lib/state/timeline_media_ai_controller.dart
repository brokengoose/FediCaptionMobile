// Copyright (c) 2026 brokengoose <brokengoose@users.noreply.github.com>
// SPDX-License-Identifier: MIT

import 'dart:collection';

import 'package:flutter/foundation.dart';

import '../core/accessibility_announcer.dart';
import '../models/ai_models.dart';
import '../models/app_settings.dart';
import '../models/mastodon_models.dart';
import '../services/ai_provider_service.dart';
import '../services/mastodon_service.dart';

/// Scoped [ChangeNotifier] for on-demand AI alt-text descriptions of timeline
/// media attachments, keeping caption generation updates isolated from global
/// app listeners and bounded in memory.
class TimelineMediaAiController extends ChangeNotifier {
  TimelineMediaAiController({
    required MastodonService mastodon,
    required AiProviderService aiProvider,
    this.maxEntries = 200,
  })  : _mastodon = mastodon,
        _aiProvider = aiProvider;

  final MastodonService _mastodon;
  final AiProviderService _aiProvider;
  final int maxEntries;

  final LinkedHashMap<String, String> _descriptions =
      LinkedHashMap<String, String>();
  final Set<String> _describingIds = {};
  final Map<String, String> _errors = {};
  bool _disposed = false;

  String? descriptionFor(String mediaId) => _descriptions[mediaId];
  bool isDescribing(String mediaId) => _describingIds.contains(mediaId);
  String? errorFor(String mediaId) => _errors[mediaId];

  /// Downloads [attachment] media bytes and generates an accessible AI alt-text
  /// caption on demand.
  Future<void> describeMedia({
    required MastodonMediaAttachment attachment,
    required AppSettings settings,
    required AiCredentials credentials,
    required int maxAltTextLength,
    String? postContext,
  }) async {
    if (_describingIds.contains(attachment.id)) return;

    _describingIds.add(attachment.id);
    _errors.remove(attachment.id);
    _safeNotify();

    AccessibilityAnnouncer.announce('Generating AI description for media.');

    try {
      final targetUrl = attachment.isVideo
          ? attachment.bestPreviewUrl
          : (attachment.url.isNotEmpty ? attachment.url : attachment.previewUrl);

      final downloaded = await _mastodon.downloadMediaBytes(targetUrl);
      final caption = await _aiProvider.generateAltText(
        settings: settings,
        credentials: credentials,
        isVideo: attachment.isVideo,
        detailLevel: settings.defaultDetailLevel,
        maxAltTextLength: maxAltTextLength,
        preExtractedMedia: [
          MediaBinaryPayload(
            bytes: downloaded.bytes,
            mimeType: downloaded.mimeType,
            isVideo: false,
          ),
        ],
        draftPostContext: postContext,
      );

      _descriptions.remove(attachment.id);
      _descriptions[attachment.id] = caption;
      while (_descriptions.length > maxEntries) {
        _descriptions.remove(_descriptions.keys.first);
      }
      AccessibilityAnnouncer.announce('AI description ready. $caption');
    } catch (e) {
      _errors[attachment.id] = e.toString();
      AccessibilityAnnouncer.announce('Failed to generate AI description.');
    } finally {
      _describingIds.remove(attachment.id);
      _safeNotify();
    }
  }

  void clear() {
    _descriptions.clear();
    _describingIds.clear();
    _errors.clear();
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
    super.dispose();
  }
}
