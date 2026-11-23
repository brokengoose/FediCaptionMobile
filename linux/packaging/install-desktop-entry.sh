#!/usr/bin/env bash
# Copyright (c) 2026 brokengoose <brokengoose@users.noreply.github.com>
# SPDX-License-Identifier: MIT
#
# Installs a desktop menu entry and app icon for a portable FediCaption
# Linux bundle extracted anywhere on disk.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_BIN="$SCRIPT_DIR/fedicaption"
ICON_SRC="$SCRIPT_DIR/data/flutter_assets/assets/icon/app_icon.png"

if [[ ! -x "$APP_BIN" ]]; then
  echo "Error: FediCaption executable not found at $APP_BIN" >&2
  exit 1
fi

ICON_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/icons/hicolor/512x512/apps"
APPS_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/applications"

mkdir -p "$ICON_DIR" "$APPS_DIR"

if [[ -f "$ICON_SRC" ]]; then
  cp -f "$ICON_SRC" "$ICON_DIR/fedicaption.png"
fi

cat > "$APPS_DIR/fedicaption.desktop" <<EOF
[Desktop Entry]
Name=FediCaption
Comment=Accessible Mastodon client with AI alt-text and bias checking
Exec="$APP_BIN" %u
Icon=fedicaption
Terminal=false
Type=Application
Categories=Network;InstantMessaging;Accessibility;
StartupWMClass=io.github.brokengoose.fedicaption
EOF

chmod 644 "$APPS_DIR/fedicaption.desktop"

if command -v update-desktop-database >/dev/null 2>&1; then
  update-desktop-database "$APPS_DIR" 2>/dev/null || true
fi

if command -v gtk-update-icon-cache >/dev/null 2>&1; then
  gtk-update-icon-cache -f -t "${XDG_DATA_HOME:-$HOME/.local/share}/icons/hicolor" 2>/dev/null || true
fi

echo "Installed FediCaption desktop entry to $APPS_DIR/fedicaption.desktop"
