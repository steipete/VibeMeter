#!/bin/bash

set -euo pipefail

# Script to create a DMG for VibeMeter
# Usage: ./scripts/create-dmg.sh <app_path> [output_path]

if [[ $# -lt 1 ]] || [[ $# -gt 2 ]]; then
    echo "Usage: $0 <app_path> [output_path]"
    exit 1
fi

APP_PATH="$1"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$PROJECT_DIR/build"

if [[ ! -d "$APP_PATH" ]]; then
    echo "Error: App not found at $APP_PATH"
    exit 1
fi

# Get version info
VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$APP_PATH/Contents/Info.plist")
DMG_NAME="VibeMeter-${VERSION}.dmg"

# Use provided output path or default
if [[ $# -eq 2 ]]; then
    DMG_PATH="$2"
else
    DMG_PATH="$BUILD_DIR/$DMG_NAME"
fi

echo "Creating DMG: $DMG_NAME"

# Create temporary directory for DMG contents
DMG_TEMP="$BUILD_DIR/dmg-temp"
rm -rf "$DMG_TEMP"
mkdir -p "$DMG_TEMP"

# Copy app to temporary directory
cp -R "$APP_PATH" "$DMG_TEMP/"

# Create symbolic link to Applications folder
ln -s /Applications "$DMG_TEMP/Applications"

# Create DMG
hdiutil create \
    -volname "VibeMeter" \
    -srcfolder "$DMG_TEMP" \
    -ov \
    -format UDZO \
    "$DMG_PATH"

# Clean up
rm -rf "$DMG_TEMP"

# Sign the DMG
echo "Signing DMG..."
codesign --force --sign "Developer ID Application" "$DMG_PATH"

# Verify DMG
echo "Verifying DMG..."
hdiutil verify "$DMG_PATH"

echo "DMG created successfully: $DMG_PATH"