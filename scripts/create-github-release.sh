#!/bin/bash

# GitHub Release Creation Script for VibeMeter
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Get version from Project.swift
VERSION=$(grep 'MARKETING_VERSION' "$PROJECT_ROOT/Project.swift" | sed 's/.*"MARKETING_VERSION": "\(.*\)".*/\1/')
BUILD_NUMBER=$(grep 'CURRENT_PROJECT_VERSION' "$PROJECT_ROOT/Project.swift" | sed 's/.*"CURRENT_PROJECT_VERSION": "\(.*\)".*/\1/')

echo "📦 Creating GitHub release for VibeMeter v$VERSION (build $BUILD_NUMBER)"

# Clean build directory for fresh compile
echo "🧹 Cleaning build directory for fresh compile..."
rm -rf "$PROJECT_ROOT/build"

# Check existing releases for build number conflicts
echo "🔍 Checking for build number conflicts..."

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
echo "   Version: $VERSION"
echo "   Build Number: $BUILD_NUMBER"
echo "   Highest Existing Build: $HIGHEST_BUILD"
echo ""
echo "✅ All checks passed. Starting build..."

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

echo "✅ Built app verified with build number: $BUILT_BUILD_NUMBER"

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
DMG_PATH="$PROJECT_ROOT/build/VibeMeter-$VERSION.dmg"
./scripts/create-dmg.sh "$APP_PATH"

# Verify the DMG
echo "🔍 Verifying DMG..."
if ./scripts/verify-app.sh "$DMG_PATH"; then
    echo "✅ DMG verification passed"
else
    echo "❌ DMG verification failed!"
    exit 1
fi

# Generate release notes
RELEASE_NOTES="Release notes for VibeMeter v$VERSION

This release includes:
- Latest features and improvements
- Bug fixes and performance enhancements

## Installation
1. Download the DMG file
2. Open it and drag VibeMeter to Applications
3. Grant necessary permissions when prompted

## Auto-Updates
This version supports automatic updates via Sparkle."

# Create GitHub release (requires gh CLI)
echo "🚀 Creating GitHub release..."
gh release create "v$VERSION" "$DMG_PATH" \
    --title "VibeMeter v$VERSION" \
    --notes "$RELEASE_NOTES" \
    --generate-notes

# Update appcast.xml
echo "📡 Updating appcast.xml..."
./scripts/update-appcast.sh "$VERSION" "$BUILD_NUMBER" "$DMG_PATH"

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
echo "✅ Version verified: $VERSION"
echo "✅ App signed and notarized"
echo "✅ DMG created and verified"
echo "✅ GitHub release created"
echo ""

echo "✅ GitHub release created successfully!"
echo ""
echo "📋 Next Steps:"
echo "1. Review appcast verification results above"
echo "2. Commit and push the updated appcast.xml"
echo "3. Test update on a machine with the previous version"
