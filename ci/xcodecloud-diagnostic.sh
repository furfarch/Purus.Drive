#!/usr/bin/env bash
set -euo pipefail

# Simple diagnostic script for Xcode Cloud / local use.
# It searches for the most recent .xcarchive and prints:
# - archive path and basic listing
# - Info.plist from the app
# - embedded.mobileprovision (decoded)
# - codesign -dvvv output
# - last 200 lines of any xcodebuild-export-archive.log found nearby

echo "== xcodecloud-diagnostic.sh =="
echo "Working dir: $(pwd)"
echo "User: $(whoami)"

# Search likely locations for .xcarchive
echo "Searching for .xcarchive (this may take a moment)..."
ARCHIVE=$(find . /Volumes/workspace "$HOME/Downloads" /Users -maxdepth 6 -type d -name "*.xcarchive" 2>/dev/null | head -n 1 || true)

if [ -z "$ARCHIVE" ]; then
  echo "No .xcarchive found under current paths. Try passing the path as first arg."
  if [ $# -ge 1 ]; then
    ARCHIVE="$1"
  else
    exit 0
  fi
fi

echo "Found archive: $ARCHIVE"
ls -la "$ARCHIVE"

APP_PATH="$(find "$ARCHIVE" -maxdepth 3 -type d -name "*.app" | head -n 1 || true)"
if [ -z "$APP_PATH" ]; then
  echo "No .app found inside archive"
  exit 0
fi

echo "App inside archive: $APP_PATH"

echo "\n--- Info.plist ---"
defaults read "$APP_PATH/Info.plist" || echo "(failed to read Info.plist)"

# embedded provisioning
if [ -f "$APP_PATH/embedded.mobileprovision" ]; then
  echo "\n--- embedded.mobileprovision (decoded) ---"
  security cms -D -i "$APP_PATH/embedded.mobileprovision" | xmllint --format - 2>/dev/null || security cms -D -i "$APP_PATH/embedded.mobileprovision" || true
else
  echo "\nNo embedded.mobileprovision found in the .app"
fi

# codesign
echo "\n--- codesign -dvvv (first 200 lines) ---"
set +e
codesign -dvvv "$APP_PATH" 2>&1 | sed -n '1,200p'
set -e

# Show nearby export logs
echo "\n--- Searching for xcodebuild-export-archive.log near archive ---"
find "$(dirname "$ARCHIVE")" -maxdepth 3 -type f -name "xcodebuild-export-archive.log" -print -exec bash -c 'echo "\n== {} (last 200 lines) =="; tail -n 200 "{}"' \; 2>/dev/null || true

# Also search for any xcodebuild-export-archive.log globally under /Volumes/workspace and ~/Downloads
find /Volumes/workspace "$HOME/Downloads" -maxdepth 5 -type f -name "xcodebuild-export-archive.log" -print -exec bash -c 'echo "\n== {} (last 200 lines) =="; tail -n 200 "{}"' \; 2>/dev/null || true

# Print environment variables relevant to xcodebuild/Xcode Cloud
echo "\n--- Relevant environment variables (XCODE_/CI_/XC_) ---"
env | egrep -i "(XCODE|CI|XC|ARCHIVE)" || true

echo "\nFinished diagnostic script. Paste the output in your support ticket or here for analysis."
