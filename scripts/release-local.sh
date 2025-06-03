#!/bin/bash

# Local Release Script for VibeMeter
# This script creates a local release without uploading to GitHub
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Get version from Project.swift
VERSION=$(grep 'MARKETING_VERSION' "$PROJECT_ROOT/Project.swift" | sed 's/.*"MARKETING_VERSION": "\(.*\)".*/\1/')
BUILD_NUMBER=$(grep 'CURRENT_PROJECT_VERSION' "$PROJECT_ROOT/Project.swift" | sed 's/.*"CURRENT_PROJECT_VERSION": "\(.*\)".*/\1/')

echo "📦 Creating local release for VibeMeter v$VERSION (build $BUILD_NUMBER)"

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

# Sign the app (skip notarization for local builds)
echo "🔐 Signing app for local testing..."
./scripts/sign-and-notarize.sh --app-path "$APP_PATH" --sign-only

# Create DMG
echo "📀 Creating DMG..."
DMG_PATH="$PROJECT_ROOT/build/VibeMeter-$VERSION.dmg"
./scripts/create-dmg.sh "$APP_PATH"

# Create releases directory if it doesn't exist
mkdir -p "$PROJECT_ROOT/releases"

# Copy DMG to releases directory
RELEASE_DMG="$PROJECT_ROOT/releases/VibeMeter-$VERSION-local.dmg"
cp "$DMG_PATH" "$RELEASE_DMG"

echo "✅ Local release created successfully!"
echo "📀 DMG available at: $RELEASE_DMG"
echo "🚀 You can test this locally before creating a GitHub release"
