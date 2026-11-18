// Copyright (c) 2026 brokengoose <brokengoose@users.noreply.github.com>
// SPDX-License-Identifier: MIT

/// Version update information retrieved from GitHub.
class UpdateInfo {
  const UpdateInfo({
    required this.currentVersion,
    required this.latestVersion,
    required this.releaseUrl,
    this.releaseNotes,
  });

  final String currentVersion;
  final String latestVersion;
  final String releaseUrl;
  final String? releaseNotes;
}
