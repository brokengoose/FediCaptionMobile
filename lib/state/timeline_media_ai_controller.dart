// Copyright (c) 2026 brokengoose <brokengoose@users.noreply.github.com>
// SPDX-License-Identifier: MIT

import 'dart:collection';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/accessibility_announcer.dart';
import '../l10n/l10n.dart';
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
    required this._mastodon,
    required this._aiProvider,
    AppLocalizations Function()? l10nProvider,
    this.maxEntries = 200,
  }) : _l10nProvider = l10nProvider ?? (() => resolveAppLocalizations());

  final MastodonService _mastodon;
  final AiProviderService _aiProvider;
  final AppLocalizations Function() _l10nProvider;
  final int maxEntries;

  final LinkedHashMap<String, String> _descriptions =
      LinkedHashMap<String, String>();
  final Set<String> _describingIds = {};
  final Map<String, String> _errors = {};
  bool _disposed = false;

  static const String _prefsCacheKey = 'fedicaption_media_ai_captions_v1';

  String? descriptionFor(String mediaId) => _descriptions[mediaId];
  bool isDescribing(String mediaId) => _describingIds.contains(mediaId);
  String? errorFor(String mediaId) => _errors[mediaId];

  /// Loads previously generated timeline AI descriptions from local storage so
  /// restarting the app does not re-download media or re-call the AI model.
  Future<void> loadPersistedCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsCacheKey);
      if (raw == null || raw.isEmpty) return;
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return;
      for (final entry in decoded.entries) {
        if (entry.value is String && (entry.value as String).isNotEmpty) {
          _descriptions[entry.key] = entry.value as String;
        }
      }
      while (_descriptions.length > maxEntries) {
        _descriptions.remove(_descriptions.keys.first);
      }
      _safeNotify();
    } catch (_) {
      // Best-effort cache restore.
    }
  }

  Future<void> _persistCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsCacheKey, jsonEncode(_descriptions));
    } catch (_) {
      // Best-effort cache persistence.
    }
  }

  /// Downloads [attachment] media bytes (preferring pre-sized `preview_url`
  /// and reusing the local disk cache) and generates an accessible AI alt-text
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

    final l10n = _l10nProvider();
    AccessibilityAnnouncer.announce(l10n.mediaAiAnnounceGenerating);

    try {
      // Prefer Mastodon's pre-sized preview_url (typically 20-50x smaller than
      // full-resolution url and already in our disk cache from timeline display).
      final targetUrl = attachment.bestPreviewUrl;

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
      _persistCache();
      AccessibilityAnnouncer.announce(l10n.mediaAiAnnounceReady(caption));
    } catch (e) {
      _errors[attachment.id] = e.toString();
      AccessibilityAnnouncer.announce(l10n.mediaAiAnnounceFailed);
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
