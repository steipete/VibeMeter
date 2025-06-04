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

# Sign the DMG if signing credentials are available
if command -v codesign &> /dev/null; then
    # Use the same signing identity as the app signing process
    SIGN_IDENTITY="${SIGN_IDENTITY:-Developer ID Application}"
    
    # Check if we're in CI and have a specific keychain
    KEYCHAIN_OPTS=""
    if [ -n "${KEYCHAIN_NAME:-}" ]; then
        echo "Using keychain: $KEYCHAIN_NAME"
        KEYCHAIN_OPTS="--keychain $KEYCHAIN_NAME"
    fi
    
    # Try to find a valid signing identity
    IDENTITY_CHECK_CMD="security find-identity -v -p codesigning"
    if [ -n "${KEYCHAIN_NAME:-}" ]; then
        IDENTITY_CHECK_CMD="$IDENTITY_CHECK_CMD $KEYCHAIN_NAME"
    fi
    
    # Check if any signing identity is available
    if $IDENTITY_CHECK_CMD 2>/dev/null | grep -q "valid identities found"; then
        # Check if our specific identity exists
        if $IDENTITY_CHECK_CMD 2>/dev/null | grep -q "$SIGN_IDENTITY"; then
            echo "Signing DMG with identity: $SIGN_IDENTITY"
            codesign --force --sign "$SIGN_IDENTITY" $KEYCHAIN_OPTS "$DMG_PATH"
        else
            # Try to use the first available Developer ID Application identity
            AVAILABLE_IDENTITY=$($IDENTITY_CHECK_CMD 2>/dev/null | grep "Developer ID Application" | head -1 | sed -E 's/.*"([^"]+)".*/\1/')
            if [ -n "$AVAILABLE_IDENTITY" ]; then
                echo "Using available identity: $AVAILABLE_IDENTITY"
                codesign --force --sign "$AVAILABLE_IDENTITY" $KEYCHAIN_OPTS "$DMG_PATH"
            else
                echo "⚠️ No Developer ID Application identity found - DMG will not be signed"
            fi
        fi
    else
        echo "⚠️ No signing identities available - DMG will not be signed"
        echo "This is expected for PR builds where certificates are not imported"
    fi
else
    echo "⚠️ codesign not available - DMG will not be signed"
fi

# Verify DMG
echo "Verifying DMG..."
hdiutil verify "$DMG_PATH"

echo "DMG created successfully: $DMG_PATH"