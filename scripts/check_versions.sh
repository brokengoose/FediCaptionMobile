#!/usr/bin/env bash
# Copyright (c) 2026 brokengoose <brokengoose@users.noreply.github.com>
# SPDX-License-Identifier: MIT
#
# Fails if the app version is not identical in every place it is declared:
#   - VERSION                         (CI artifact names)
#   - pubspec.yaml `version:`         (store/build metadata; "+build" ignored)
#   - lib/core/constants.dart         (AppConstants.appVersion, update check)
#   - the pushed tag, when given      (e.g. v1.2.3 or v1.2.3-beta.1 -> 1.2.3)
#
# Usage: scripts/check_versions.sh [tag]
set -euo pipefail

cd "$(dirname "$0")/.."

file_version="$(tr -d '[:space:]' < VERSION)"
pubspec_version="$(sed -n -E 's/^version:[[:space:]]*([^+[:space:]]+).*/\1/p' pubspec.yaml)"
const_version="$(sed -n -E "s/.*static const String appVersion = '([^']+)'.*/\1/p" lib/core/constants.dart)"

status=0
report() { printf '  %-32s %s\n' "$1" "${2:-<missing>}"; }

echo "Declared app versions:"
report "VERSION" "$file_version"
report "pubspec.yaml version" "$pubspec_version"
report "AppConstants.appVersion" "$const_version"

for v in "$pubspec_version" "$const_version"; do
  if [[ "$v" != "$file_version" ]]; then status=1; fi
done

if [[ $# -ge 1 && -n "$1" ]]; then
  tag_version="${1#v}"
  tag_core="${tag_version%%-*}"
  report "git tag" "$tag_version"
  # Pre-release tags (e.g. v1.0.0-beta.4) share the base VERSION (1.0.0).
  if [[ "$tag_version" != "$file_version" && "$tag_core" != "$file_version" ]]; then
    status=1
  fi
fi

if [[ $status -ne 0 ]]; then
  echo "error: app version mismatch; update all of the above to the same value." >&2
else
  echo "OK: all versions match ($file_version)."
fi
exit $status
