#!/usr/bin/env bash
#
# run-device.sh — build + install + launch the app on the connected iPhone.
#
# Why this exists:
#   `flutter run --release` currently fails on this machine with
#   "Build succeeded but the expected app at build/ios/iphoneos/Runner.app
#   not found" — a Flutter 3.44 / Xcode 26 path bug (Xcode writes the bundle
#   to build/ios/Release-iphoneos/Runner.app, Flutter looks in the wrong
#   folder). And plain `flutter run` (debug) can't attach a debugger on the
#   iOS 27 beta device. This script sidesteps both: it builds a release
#   bundle and installs/launches it directly with `devicectl`.
#
# Usage:
#   ./run-device.sh            # production backend (default)
#   ./run-device.sh staging    # staging backend
#
set -euo pipefail

BUNDLE_ID="com.techkushx.fixitfelixpro"

# Default changed to staging for the Supabase migration.
#
# `staging` points the app at the fif-pro-development project, which holds the
# migrated data and has Google/Apple sign-in configured. `production` points at
# fif-pro-production, which is intentionally still EMPTY — the data import is
# held until cutover — and has Email sign-in only. Testing against it would
# look like a broken app.
ENV="${1:-staging}"

# Auto-detect the connected device rather than hardcoding an id: the previous
# hardcoded UDID no longer matches what devicectl reports.
# Match the UUID by shape, not by column: device names contain spaces, so
# positional awk picks the wrong field.
DEVICE_ID="${DEVICE_ID:-$(xcrun devicectl list devices 2>/dev/null \
  | grep -E '\bconnected\b' \
  | grep -oE '[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}' \
  | head -1)}"
if [ -z "$DEVICE_ID" ]; then
  echo "✗ No connected device found. Unlock the iPhone and trust this Mac." >&2
  exit 1
fi
echo "▶ Device: $DEVICE_ID"

echo "▶ Building release bundle (ENV=$ENV)…"
flutter build ios --release --dart-define=ENV="$ENV"

# Find the freshly built .app wherever Xcode placed it.
APP_PATH=$(find build/ios -maxdepth 2 -name "Runner.app" -path "*Release-iphoneos*" -print -quit)
if [ -z "$APP_PATH" ]; then
  APP_PATH=$(find build/ios -maxdepth 2 -name "Runner.app" -path "*iphoneos*" -print -quit)
fi
if [ -z "$APP_PATH" ]; then
  echo "✗ Could not locate a built Runner.app under build/ios." >&2
  exit 1
fi
echo "▶ Installing $APP_PATH …"
xcrun devicectl device install app --device "$DEVICE_ID" "$APP_PATH"

echo "▶ Launching…"
xcrun devicectl device process launch --device "$DEVICE_ID" "$BUNDLE_ID"

echo "✓ Done — the app is running on your iPhone. Tap its icon anytime to reopen."
