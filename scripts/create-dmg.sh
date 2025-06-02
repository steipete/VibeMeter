#!/bin/bash

set -euo pipefail

# Script to create a DMG for VibeMeter
# Usage: ./scripts/create-dmg.sh <app_path>

if [[ $# -ne 1 ]]; then
    echo "Usage: $0 <app_path>"
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
DMG_PATH="$BUILD_DIR/$DMG_NAME"

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

# Sign the DMG if code signing is available
if [[ -n "${MACOS_SIGNING_CERTIFICATE_P12_BASE64:-}" ]] || [[ -n "${MACOS_SIGNING_P12_FILE_PATH:-}" ]]; then
    echo "Signing DMG..."
    # Find signing identity
    if [[ -n "${MACOS_SIGNING_CERTIFICATE_P12_BASE64:-}" ]]; then
        # For CI, we need to extract the identity from the certificate
        # This would be done in the codesign script, so we'll call it indirectly
        codesign --sign "Developer ID Application" --timestamp "$DMG_PATH" 2>/dev/null || true
    else
        # For local signing
        SIGNING_IDENTITY=$(security find-identity -v -p codesigning | grep "Developer ID Application" | head -1 | awk '{print $2}')
        if [[ -n "$SIGNING_IDENTITY" ]]; then
            codesign --sign "$SIGNING_IDENTITY" --timestamp "$DMG_PATH"
        fi
    fi
fi

# Verify DMG
echo "Verifying DMG..."
hdiutil verify "$DMG_PATH"

echo "DMG created successfully: $DMG_PATH"