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

# Clean build directory for fresh compile
echo "🧹 Cleaning build directory for fresh compile..."
rm -rf "$PROJECT_ROOT/build"

# Check existing releases for build number conflicts
echo "🔍 Checking for build number conflicts..."
EXISTING_BUILDS=$(gh release list --limit 100 2>/dev/null | while read -r line; do
    RELEASE_TAG=$(echo "$line" | awk '{print $3}')
    if [[ -n "$RELEASE_TAG" ]]; then
        # Try to download and check the DMG
        DMG_URL="https://github.com/steipete/VibeMeter/releases/download/$RELEASE_TAG/VibeMeter-*.dmg"
        # This is just for display - we'll check appcast for actual build numbers
        echo "   Checking release: $RELEASE_TAG"
    fi
done)

# Parse appcast files for existing build numbers
USED_BUILD_NUMBERS=""
if [[ -f "$PROJECT_ROOT/appcast.xml" ]]; then
    USED_BUILD_NUMBERS+=$(grep -E '<sparkle:version>[0-9]+</sparkle:version>' "$PROJECT_ROOT/appcast.xml" | sed 's/.*<sparkle:version>\([0-9]*\)<\/sparkle:version>.*/\1/' | tr '\n' ' ')
fi
if [[ -f "$PROJECT_ROOT/appcast-prerelease.xml" ]]; then
    USED_BUILD_NUMBERS+=$(grep -E '<sparkle:version>[0-9]+</sparkle:version>' "$PROJECT_ROOT/appcast-prerelease.xml" | sed 's/.*<sparkle:version>\([0-9]*\)<\/sparkle:version>.*/\1/' | tr '\n' ' ')
fi

# Check if current build number already exists
if [[ -n "$USED_BUILD_NUMBERS" ]]; then
    for EXISTING_BUILD in $USED_BUILD_NUMBERS; do
        if [[ "$BUILD_NUMBER" == "$EXISTING_BUILD" ]]; then
            echo "❌ Build number $BUILD_NUMBER already exists in releases!"
            echo "   Used build numbers: $USED_BUILD_NUMBERS"
            echo "   Please increment CURRENT_PROJECT_VERSION in Project.swift"
            exit 1
        fi
        if [[ "$BUILD_NUMBER" -le "$EXISTING_BUILD" ]]; then
            echo "⚠️  Warning: Build number $BUILD_NUMBER is not higher than existing build $EXISTING_BUILD"
            echo "   Sparkle requires monotonically increasing build numbers"
        fi
    done
fi

# Find highest existing build number
HIGHEST_BUILD=0
for EXISTING_BUILD in $USED_BUILD_NUMBERS; do
    if [[ "$EXISTING_BUILD" -gt "$HIGHEST_BUILD" ]]; then
        HIGHEST_BUILD=$EXISTING_BUILD
    fi
done

if [[ "$BUILD_NUMBER" -le "$HIGHEST_BUILD" ]]; then
    echo "❌ Build number must be higher than $HIGHEST_BUILD"
    echo "   Current build number: $BUILD_NUMBER"
    echo "   Please update CURRENT_PROJECT_VERSION in Project.swift to at least $((HIGHEST_BUILD + 1))"
    exit 1
fi

echo "✅ Build number $BUILD_NUMBER is valid (highest existing: $HIGHEST_BUILD)"

# Pre-flight summary
echo ""
echo "📋 Pre-flight Summary:"
echo "   Base Version: $BASE_VERSION"
echo "   Pre-release Version: $PRERELEASE_VERSION"
echo "   Build Number: $BUILD_NUMBER"
echo "   Highest Existing Build: $HIGHEST_BUILD"
echo ""
read -p "Continue with build? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "❌ Aborted by user"
    exit 1
fi

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

# Verify the signed and notarized app
echo "🔍 Verifying signed app..."
if ./scripts/verify-app.sh "$APP_PATH"; then
    echo "✅ App verification passed"
else
    echo "❌ App verification failed!"
    exit 1
fi

# Create DMG
echo "📀 Creating DMG..."
DMG_PATH="$PROJECT_ROOT/build/VibeMeter-$PRERELEASE_VERSION.dmg"
./scripts/create-dmg.sh "$APP_PATH" "$DMG_PATH"

# Verify the DMG
echo "🔍 Verifying DMG..."
if ./scripts/verify-app.sh "$DMG_PATH"; then
    echo "✅ DMG verification passed"
else
    echo "❌ DMG verification failed!"
    exit 1
fi

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

# Verify appcast files
echo "🔍 Verifying appcast files..."
if ./scripts/verify-appcast.sh; then
    echo "✅ Appcast verification passed"
else
    echo "⚠️  Appcast verification found issues - please review"
fi

# Final verification summary
echo ""
echo "📊 Release Verification Summary:"
echo "================================"
echo "✅ Build verified: $BUILD_NUMBER"
echo "✅ Version verified: $PRERELEASE_VERSION"
echo "✅ App signed and notarized"
echo "✅ DMG created and verified"
echo "✅ GitHub release created"
echo ""

echo "✅ Pre-release created successfully!"
echo ""
echo "📋 Next Steps:"
echo "1. Review appcast verification results above"
echo "2. Commit and push the updated appcast-prerelease.xml"
echo "3. Test update on a machine with the previous version"
echo ""
echo "🔗 Release URL: https://github.com/steipete/VibeMeter/releases/tag/v$PRERELEASE_VERSION"