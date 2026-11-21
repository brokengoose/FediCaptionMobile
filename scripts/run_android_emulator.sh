#!/usr/bin/env bash
# Copyright (c) 2026 brokengoose <brokengoose@users.noreply.github.com>
# SPDX-License-Identifier: MIT
#
# Rebuilds FediCaption Mobile, starts the Android emulator (if not already
# running) with macOS CoreAudio support for TTS, installs the freshly built APK
# onto the emulator, and launches the app.
#
# Usage:
#   ./scripts/run_android_emulator.sh [--release | --debug] [--avd <name>] [--quick-boot] [--no-launch]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

APP_ID="io.github.brokengoose.fedicaption_mobile"
MAIN_ACTIVITY="${APP_ID}/.MainActivity"
BUILD_MODE="release"
AVD_NAME="${AVD_NAME:-Medium_Phone_API_37.0}"
QUICK_BOOT="false"
LAUNCH_APP="true"
BOOT_TIMEOUT_SECONDS=180

# Parse optional CLI arguments.
while [[ $# -gt 0 ]]; do
  case "$1" in
    --release)
      BUILD_MODE="release"
      shift
      ;;
    --debug)
      BUILD_MODE="debug"
      shift
      ;;
    --avd)
      if [[ $# -lt 2 ]]; then
        echo "Error: --avd requires an AVD name." >&2
        exit 1
      fi
      AVD_NAME="$2"
      shift 2
      ;;
    --quick-boot)
      QUICK_BOOT="true"
      shift
      ;;
    --no-launch)
      LAUNCH_APP="false"
      shift
      ;;
    -h|--help)
      sed -n '2,12p' "${BASH_SOURCE[0]}"
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      exit 1
      ;;
  esac
done

# Locate Flutter binary.
if [[ -n "${FLUTTER_BIN:-}" ]]; then
  FLUTTER="$FLUTTER_BIN"
elif command -v flutter >/dev/null 2>&1; then
  FLUTTER="$(command -v flutter)"
elif [[ -x "$HOME/develop/flutter/bin/flutter" ]]; then
  FLUTTER="$HOME/develop/flutter/bin/flutter"
else
  echo "Error: Could not find 'flutter'. Set FLUTTER_BIN or add Flutter to PATH." >&2
  exit 1
fi

# Locate Android SDK tools.
ANDROID_SDK="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-$HOME/Library/Android/sdk}}"
ADB="$ANDROID_SDK/platform-tools/adb"
EMULATOR="$ANDROID_SDK/emulator/emulator"

if [[ ! -x "$ADB" ]]; then
  echo "Error: Could not find adb at $ADB. Set ANDROID_SDK_ROOT or ANDROID_HOME." >&2
  exit 1
fi
if [[ ! -x "$EMULATOR" ]]; then
  echo "Error: Could not find emulator at $EMULATOR. Set ANDROID_SDK_ROOT or ANDROID_HOME." >&2
  exit 1
fi

cd "$PROJECT_ROOT"

# 1. Build the APK.
echo "==> Building Android APK ($BUILD_MODE)..."
"$FLUTTER" build apk "--$BUILD_MODE"

APK_PATH="$PROJECT_ROOT/build/app/outputs/flutter-apk/app-${BUILD_MODE}.apk"
if [[ ! -f "$APK_PATH" ]]; then
  echo "Error: Expected APK not found at $APK_PATH" >&2
  exit 1
fi
echo "==> Built APK: $APK_PATH"

# 2. Ensure adb server is running, then reuse an existing emulator or start one.
"$ADB" start-server >/dev/null 2>&1 || true

find_running_emulator() {
  "$ADB" devices | awk '$1 ~ /^emulator-/ && $2 == "device" { print $1; exit }'
}

EMULATOR_SERIAL="$(find_running_emulator || true)"

if [[ -z "$EMULATOR_SERIAL" ]]; then
  # Verify requested AVD exists; otherwise fall back to the first available AVD.
  AVAILABLE_AVDS="$("$EMULATOR" -list-avds || true)"
  if [[ -z "$AVAILABLE_AVDS" ]]; then
    echo "Error: No Android Virtual Devices (AVDs) found. Create one in Android Studio." >&2
    exit 1
  fi
  if ! printf '%s\n' "$AVAILABLE_AVDS" | grep -Fxq "$AVD_NAME"; then
    FALLBACK_AVD="$(printf '%s\n' "$AVAILABLE_AVDS" | head -n 1)"
    echo "==> AVD '$AVD_NAME' not found; using '$FALLBACK_AVD' instead."
    AVD_NAME="$FALLBACK_AVD"
  fi

  EMU_ARGS=(-avd "$AVD_NAME" -no-boot-anim)
  if [[ "$QUICK_BOOT" != "true" ]]; then
    # Cold boot avoids hanging on stale/corrupted default_boot snapshots.
    EMU_ARGS+=(-no-snapshot-load)
  fi
  if [[ "$(uname -s)" == "Darwin" ]]; then
    # CoreAudio ensures TTS playback routes properly to macOS speakers.
    EMU_ARGS+=(-audio coreaudio)
  fi

  EMULATOR_LOG="/tmp/fedicaption-emulator.log"
  echo "==> Starting Android emulator '$AVD_NAME' (log: $EMULATOR_LOG)..."
  if command -v python3 >/dev/null 2>&1; then
    # Detach into a new session so the emulator stays open after this script exits.
    python3 -c '
import subprocess, sys
log_path = sys.argv[1]
cmd = sys.argv[2:]
with open(log_path, "wb") as log_file:
    subprocess.Popen(
        cmd,
        stdin=subprocess.DEVNULL,
        stdout=log_file,
        stderr=subprocess.STDOUT,
        start_new_session=True,
        close_fds=True,
    )
' "$EMULATOR_LOG" "$EMULATOR" "${EMU_ARGS[@]}"
  else
    nohup "$EMULATOR" "${EMU_ARGS[@]}" >"$EMULATOR_LOG" 2>&1 </dev/null &
    disown || true
  fi

  echo "==> Waiting for emulator to boot..."
  ELAPSED=0
  while [[ $ELAPSED -lt $BOOT_TIMEOUT_SECONDS ]]; do
    # If the emulator booted but a stale adb daemon missed it, restart adb server.
    if [[ -z "${EMULATOR_SERIAL:-}" && ( $ELAPSED -eq 20 || $ELAPSED -eq 60 ) ]]; then
      echo "==> Refreshing adb server to detect emulator..."
      "$ADB" kill-server >/dev/null 2>&1 || true
      "$ADB" start-server >/dev/null 2>&1 || true
    fi
    EMULATOR_SERIAL="$(find_running_emulator || true)"
    if [[ -n "$EMULATOR_SERIAL" ]]; then
      BOOT_COMPLETED="$("$ADB" -s "$EMULATOR_SERIAL" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r' || true)"
      if [[ "$BOOT_COMPLETED" == "1" ]]; then
        break
      fi
    fi
    sleep 2
    ELAPSED=$((ELAPSED + 2))
  done

  if [[ -z "$EMULATOR_SERIAL" ]]; then
    echo "Error: Timed out waiting for emulator '$AVD_NAME' to appear in adb." >&2
    exit 1
  fi
  if [[ "${BOOT_COMPLETED:-0}" != "1" ]]; then
    echo "Error: Timed out waiting for emulator '$EMULATOR_SERIAL' to finish booting." >&2
    exit 1
  fi
  # Give PackageManager a brief moment to settle after boot_completed=1.
  sleep 2
  echo "==> Emulator '$EMULATOR_SERIAL' is ready."
else
  echo "==> Using already running emulator: $EMULATOR_SERIAL"
fi

# 3. Install the APK onto the emulator (explicitly targeting emulator serial).
echo "==> Installing $APK_PATH onto $EMULATOR_SERIAL..."
"$ADB" -s "$EMULATOR_SERIAL" install -r "$APK_PATH"

# 4. Launch the app.
if [[ "$LAUNCH_APP" == "true" ]]; then
  echo "==> Launching $APP_ID..."
  "$ADB" -s "$EMULATOR_SERIAL" shell am start -n "$MAIN_ACTIVITY" >/dev/null
fi

echo "==> Done! FediCaption Mobile ($BUILD_MODE) is installed on $EMULATOR_SERIAL."
