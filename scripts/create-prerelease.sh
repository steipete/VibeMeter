#!/bin/bash

# Pre-release Creation Script for VibeMeter
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Usage function
usage() {
    echo "Usage: $0 [TYPE] [NUMBER]"
    echo ""
    echo "Create VibeMeter pre-release versions"
    echo ""
    echo "ARGUMENTS:"
    echo "  TYPE       Pre-release type (alpha, beta, rc)"
    echo "  NUMBER     Pre-release number (1, 2, 3...)"
    echo ""
    echo "EXAMPLES:"
    echo "  $0 beta 1         # Create 0.9.2-beta.1"
    echo "  $0 alpha 2        # Create 0.9.2-alpha.2"
    echo "  $0 rc 1           # Create 0.9.2-rc.1"
    echo ""
}

# Check for help flag
if [[ "$1" == "--help" || "$1" == "-h" ]]; then
    usage
    exit 0
fi

# Parse arguments
PRERELEASE_TYPE="${1:-beta}"  # beta, alpha, rc
PRERELEASE_NUMBER="${2:-1}"   # 1, 2, 3, etc.

# Get base version from Project.swift
MARKETING_VERSION=$(grep 'MARKETING_VERSION' "$PROJECT_ROOT/Project.swift" | sed 's/.*"MARKETING_VERSION": "\(.*\)".*/\1/')
BUILD_NUMBER=$(grep 'CURRENT_PROJECT_VERSION' "$PROJECT_ROOT/Project.swift" | sed 's/.*"CURRENT_PROJECT_VERSION": "\(.*\)".*/\1/')

# Extract base version without pre-release suffix if present
# This handles cases where MARKETING_VERSION might already be "1.0.0-beta.1"
BASE_VERSION=$(echo "$MARKETING_VERSION" | sed 's/-[a-zA-Z]*\.[0-9]*$//')

# Create pre-release version
PRERELEASE_VERSION="$BASE_VERSION-$PRERELEASE_TYPE.$PRERELEASE_NUMBER"
PRERELEASE_BUILD_NUMBER="$BUILD_NUMBER"

# Validate that we're not creating a double suffix
if [[ "$MARKETING_VERSION" == *"-"* && "$MARKETING_VERSION" != "$PRERELEASE_VERSION" ]]; then
    echo "⚠️  Warning: Marketing version ($MARKETING_VERSION) already contains a pre-release suffix"
    echo "   Creating version: $PRERELEASE_VERSION"
    echo "   Consider updating Project.swift to base version: $BASE_VERSION"
fi

echo "📦 Creating pre-release for VibeMeter v$PRERELEASE_VERSION (build $PRERELEASE_BUILD_NUMBER)"

# Validate pre-release type
case "$PRERELEASE_TYPE" in
    beta|alpha|rc)
        ;;
    *)
        echo "❌ Invalid pre-release type: $PRERELEASE_TYPE"
        echo "Valid types: beta, alpha, rc"
        exit 1
        ;;
esac

# Build the app
echo "🔨 Building application..."
cd "$PROJECT_ROOT"
./scripts/build.sh --configuration Release

# Check if built app exists
APP_PATH="$PROJECT_ROOT/build/Build/Products/Release/VibeMeter.app"
if [[ ! -d "$APP_PATH" ]]; then
    echo "❌ Built app not found at $APP_PATH"
    exit 1
fi

# Verify the built app has the correct build number
BUILT_BUILD_NUMBER=$(defaults read "$APP_PATH/Contents/Info.plist" CFBundleVersion 2>/dev/null || echo "unknown")
if [[ "$BUILT_BUILD_NUMBER" != "$BUILD_NUMBER" ]]; then
    echo "❌ Build number mismatch!"
    echo "   Expected: $BUILD_NUMBER"
    echo "   Found: $BUILT_BUILD_NUMBER"
    echo "   The app may not have been rebuilt after updating Project.swift"
    exit 1
fi

# Update Info.plist with pre-release version
echo "📝 Updating app version to $PRERELEASE_VERSION..."
PLIST_PATH="$APP_PATH/Contents/Info.plist"
plutil -replace CFBundleShortVersionString -string "$PRERELEASE_VERSION" "$PLIST_PATH"

# Sign and notarize the app
echo "🔐 Signing and notarizing..."
./scripts/sign-and-notarize.sh --app-path "$APP_PATH" --sign-and-notarize

# Create DMG
echo "📀 Creating DMG..."
DMG_PATH="$PROJECT_ROOT/build/VibeMeter-$PRERELEASE_VERSION.dmg"
./scripts/create-dmg.sh "$APP_PATH" "$DMG_PATH"

# Generate pre-release notes
RELEASE_NOTES="Pre-release version of VibeMeter v$PRERELEASE_VERSION

⚠️ **This is a pre-release version** and may contain bugs or incomplete features.

This pre-release includes:
- Latest experimental features
- Bug fixes and improvements
- Performance enhancements

## Installation
1. Download the DMG file
2. Open it and drag VibeMeter to Applications
3. Grant necessary permissions when prompted

## Feedback
Please report any issues or feedback on GitHub:
https://github.com/steipete/VibeMeter/issues

## Auto-Updates
This version supports automatic updates via Sparkle and will receive both stable and pre-release updates."

# Create GitHub pre-release (requires gh CLI)
echo "🚀 Creating GitHub pre-release..."
gh release create "v$PRERELEASE_VERSION" "$DMG_PATH" \
    --title "VibeMeter v$PRERELEASE_VERSION" \
    --notes "$RELEASE_NOTES" \
    --prerelease

# Update pre-release appcast.xml
echo "📡 Updating appcast-prerelease.xml..."
./scripts/generate-appcast.sh

echo "✅ Pre-release created successfully!"
echo "📡 Don't forget to commit and push the updated appcast-prerelease.xml"
echo ""
echo "🔗 Release URL: https://github.com/steipete/VibeMeter/releases/tag/v$PRERELEASE_VERSION"