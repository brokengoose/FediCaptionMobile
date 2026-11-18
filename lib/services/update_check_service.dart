// Copyright (c) 2026 brokengoose <brokengoose@users.noreply.github.com>
// SPDX-License-Identifier: MIT

import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/constants.dart';
import '../models/update_info.dart';

/// Checks GitHub for newer releases (and falls back to the `VERSION` file on `main`).
class UpdateCheckService {
  UpdateCheckService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  /// Compares two semantic version strings (e.g. `v1.2.0` vs `1.0.0`).
  /// Returns `true` strictly when [latest] > [current].
  static bool isNewerVersion(String latest, String current) {
    final latestParts = _parseSemver(latest);
    final currentParts = _parseSemver(current);
    if (latestParts == null || currentParts == null) return false;

    for (var i = 0; i < 3; i++) {
      if (latestParts[i] > currentParts[i]) return true;
      if (latestParts[i] < currentParts[i]) return false;
    }
    return false;
  }

  static List<int>? _parseSemver(String raw) {
    var cleaned = raw.trim();
    if (cleaned.startsWith('v') || cleaned.startsWith('V')) {
      cleaned = cleaned.substring(1);
    }
    // Strip pre-release or build metadata suffix for core comparison.
    cleaned = cleaned.split('-').first.split('+').first.trim();
    final segments = cleaned.split('.');
    if (segments.isEmpty) return null;

    final nums = <int>[];
    for (var i = 0; i < 3; i++) {
      if (i < segments.length) {
        final parsed = int.tryParse(segments[i]);
        if (parsed == null) return null;
        nums.add(parsed);
      } else {
        nums.add(0);
      }
    }
    return nums;
  }

  /// Checks GitHub for a newer version than [currentVersion].
  /// Returns [UpdateInfo] if a newer version exists, otherwise `null`.
  Future<UpdateInfo?> checkForUpdate({
    String currentVersion = AppConstants.appVersion,
  }) async {
    // 1. Check GitHub Releases API first.
    try {
      final res = await _client
          .get(
            Uri.parse(AppConstants.githubLatestReleaseApi),
            headers: const {
              'Accept': 'application/vnd.github+json',
              'User-Agent': 'FediCaptionMobile/${AppConstants.appVersion}',
            },
          )
          .timeout(const Duration(seconds: 8));

      if (res.statusCode >= 200 && res.statusCode < 300) {
        final decoded = jsonDecode(res.body) as Map<String, dynamic>;
        final tagName = (decoded['tag_name'] as String?)?.trim() ?? '';
        final htmlUrl = (decoded['html_url'] as String?)?.trim() ??
            '${AppConstants.repositoryUrl}/releases';
        final notes = (decoded['body'] as String?)?.trim();
        if (tagName.isNotEmpty && isNewerVersion(tagName, currentVersion)) {
          return UpdateInfo(
            currentVersion: currentVersion,
            latestVersion: tagName.replaceFirst(RegExp(r'^[vV]'), ''),
            releaseUrl: htmlUrl,
            releaseNotes: notes,
          );
        }
        if (tagName.isNotEmpty) {
          return null;
        }
      }
    } catch (_) {
      // Fall through to VERSION file on main branch.
    }

    // 2. Fallback: Check VERSION file on main branch.
    try {
      final res = await _client
          .get(Uri.parse(AppConstants.githubMainVersionFileUrl))
          .timeout(const Duration(seconds: 8));
      if (res.statusCode >= 200 && res.statusCode < 300) {
        final remoteVersion = res.body.trim();
        if (remoteVersion.isNotEmpty &&
            isNewerVersion(remoteVersion, currentVersion)) {
          return UpdateInfo(
            currentVersion: currentVersion,
            latestVersion: remoteVersion.replaceFirst(RegExp(r'^[vV]'), ''),
            releaseUrl: '${AppConstants.repositoryUrl}/releases',
          );
        }
      }
    } catch (_) {
      // Network unavailable; ignore update check silently.
    }

    return null;
  }
}
