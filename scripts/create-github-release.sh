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
./scripts/create-dmg.sh "$APP_PATH" "$DMG_PATH"

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
./scripts/generate-appcast.sh

echo "✅ GitHub release created successfully!"
echo "📡 Don't forget to commit and push the updated appcast.xml"
