#!/usr/bin/env bash
set -euo pipefail

# Export an .xcarchive using the repo exportOptions plist (App Store automatic signing)
# Intended to run inside Xcode Cloud as a post-archive Script step.
# Usage: ./ci/exportArchive-with-plist.sh [archive_path] [export_options_plist]

echo "== exportArchive-with-plist.sh starting =="

# Accept optional args for archive and plist
ARCHIVE_ARG=${1-}
PLIST_ARG=${2-}

ARCHIVE=""
if [ -n "$ARCHIVE_ARG" ]; then
  ARCHIVE="$ARCHIVE_ARG"
else
  # Try common Xcode Cloud archive locations first
  ARCHIVE=$(find /Volumes/workspace -maxdepth 3 -type d -name "*.xcarchive" 2>/dev/null | head -n 1 || true)
  if [ -z "$ARCHIVE" ]; then
    ARCHIVE=$(find . "$HOME/Downloads" -maxdepth 4 -type d -name "*.xcarchive" 2>/dev/null | head -n 1 || true)
  fi
fi

if [ -z "$ARCHIVE" ]; then
  echo "No .xcarchive found in standard locations and no archive path provided. Listing /Volumes/workspace for debugging..."
  ls -la /Volumes/workspace || true
  echo "Exiting with error."
  exit 2
fi

echo "Found archive: $ARCHIVE"

EXPORT_DIR="/tmp/export-output-$(date +%s)"
mkdir -p "$EXPORT_DIR"

PLIST_PATH=""
if [ -n "$PLIST_ARG" ]; then
  PLIST_PATH="$PLIST_ARG"
else
  PLIST_PATH="$(pwd)/ci/exportOptions.app-store.plist"
fi

if [ ! -f "$PLIST_PATH" ]; then
  echo "Export options plist not found at $PLIST_PATH"
  echo "You can pass a custom plist as the second argument to this script."
  exit 2
fi

echo "Using export options plist: $PLIST_PATH"

set -x
xcodebuild -exportArchive \
  -archivePath "$ARCHIVE" \
  -exportPath "$EXPORT_DIR" \
  -exportOptionsPlist "$PLIST_PATH" \
  -allowProvisioningUpdates \
  -verbose
set +x

echo "\nExport completed. Contents of $EXPORT_DIR:"
ls -la "$EXPORT_DIR" || true

echo "== exportArchive-with-plist.sh finished =="
