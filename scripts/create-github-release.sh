#!/bin/bash

# GitHub Release Creation Script for VibeMeter
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Get version from Project.swift
VERSION=$(grep 'MARKETING_VERSION' "$PROJECT_ROOT/Project.swift" | sed 's/.*"MARKETING_VERSION": "\(.*\)".*/\1/')
BUILD_NUMBER=$(grep 'CURRENT_PROJECT_VERSION' "$PROJECT_ROOT/Project.swift" | sed 's/.*"CURRENT_PROJECT_VERSION": "\(.*\)".*/\1/')

echo "📦 Creating GitHub release for VibeMeter v$VERSION (build $BUILD_NUMBER)"

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

# Sign and notarize the app
echo "🔐 Signing and notarizing..."
./scripts/sign-and-notarize.sh --app-path "$APP_PATH" --sign-and-notarize

# Create DMG
echo "📀 Creating DMG..."
DMG_PATH="$PROJECT_ROOT/build/VibeMeter-$VERSION.dmg"
./scripts/create-dmg.sh "$APP_PATH"

# Generate release notes from CHANGELOG.md
RELEASE_NOTES="## VibeMeter $VERSION

### Installation
1. Download the DMG file
2. Open it and drag VibeMeter to Applications
3. Launch VibeMeter from Applications

### Auto-Updates
This version supports automatic updates via Sparkle.

"

# Extract version section from CHANGELOG.md
CHANGELOG_SECTION=$(<"$PROJECT_ROOT/CHANGELOG.md" sed -n "/## \[$VERSION\]/,/## \[/p" | sed '$ d' | tail -n +2)

if [ -n "$CHANGELOG_SECTION" ]; then
    RELEASE_NOTES="$RELEASE_NOTES$CHANGELOG_SECTION"
else
    RELEASE_NOTES="${RELEASE_NOTES}Bug fixes and improvements."
fi

# Check if gh is installed
if ! command -v gh &> /dev/null; then
    echo "❌ GitHub CLI (gh) not found"
    echo "Install with: brew install gh"
    echo "Then run: gh auth login"
    exit 1
fi

# Create GitHub release (requires gh CLI)
echo "🚀 Creating GitHub release..."
gh release create "v$VERSION" "$DMG_PATH" \
    --title "VibeMeter $VERSION" \
    --notes "$RELEASE_NOTES" \
    --latest

# Update appcast.xml
echo "📡 Updating appcast.xml..."
./scripts/update-appcast.sh "$VERSION" "$BUILD_NUMBER" "$DMG_PATH"

echo "✅ GitHub release created successfully!"
echo "📡 Don't forget to commit and push the updated appcast.xml"
