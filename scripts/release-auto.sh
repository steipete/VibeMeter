#!/bin/bash

# Automated Release Script for VibeMeter
# This script handles the complete release process
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Parse arguments
RELEASE_TYPE="${1:-}"
PRERELEASE_NUMBER="${2:-}"

# Validate arguments
if [[ -z "$RELEASE_TYPE" ]]; then
    echo "❌ Error: Release type required"
    echo ""
    echo "Usage:"
    echo "  $0 stable             # Create stable release"
    echo "  $0 beta <number>      # Create beta.N release"
    echo "  $0 alpha <number>     # Create alpha.N release"
    echo "  $0 rc <number>        # Create rc.N release"
    echo ""
    echo "Examples:"
    echo "  $0 stable"
    echo "  $0 beta 1"
    echo "  $0 rc 3"
    exit 1
fi

# For pre-releases, validate number
if [[ "$RELEASE_TYPE" != "stable" ]]; then
    if [[ -z "$PRERELEASE_NUMBER" ]]; then
        echo "❌ Error: Pre-release number required for $RELEASE_TYPE"
        echo "Example: $0 $RELEASE_TYPE 1"
        exit 1
    fi
fi

echo "🚀 VibeMeter Automated Release"
echo "=============================="
echo ""

# Step 1: Run pre-flight check
echo "📋 Step 1/7: Running pre-flight check..."
if ! "$SCRIPT_DIR/preflight-check.sh"; then
    echo ""
    echo "❌ Pre-flight check failed. Please fix the issues above."
    exit 1
fi

echo ""
echo "✅ Pre-flight check passed!"
echo ""

# Get version info
MARKETING_VERSION=$(grep 'MARKETING_VERSION' "$PROJECT_ROOT/Project.swift" | sed 's/.*"MARKETING_VERSION": "\(.*\)".*/\1/')
BUILD_NUMBER=$(grep 'CURRENT_PROJECT_VERSION' "$PROJECT_ROOT/Project.swift" | sed 's/.*"CURRENT_PROJECT_VERSION": "\(.*\)".*/\1/')

# Determine release version
if [[ "$RELEASE_TYPE" == "stable" ]]; then
    RELEASE_VERSION="$MARKETING_VERSION"
    TAG_NAME="v$RELEASE_VERSION"
else
    RELEASE_VERSION="$MARKETING_VERSION-$RELEASE_TYPE.$PRERELEASE_NUMBER"
    TAG_NAME="v$RELEASE_VERSION"
fi

echo "📦 Preparing release:"
echo "   Type: $RELEASE_TYPE"
echo "   Version: $RELEASE_VERSION"
echo "   Build: $BUILD_NUMBER"
echo "   Tag: $TAG_NAME"
echo ""

# Step 2: Clean and generate project
echo "📋 Step 2/7: Generating Xcode project..."
rm -rf "$PROJECT_ROOT/build"
"$SCRIPT_DIR/generate-xcproj.sh"

# Check if Xcode project was modified and commit if needed
if ! git diff --quiet "$PROJECT_ROOT/VibeMeter.xcodeproj/project.pbxproj"; then
    echo "📝 Committing Xcode project changes..."
    git add "$PROJECT_ROOT/VibeMeter.xcodeproj/project.pbxproj"
    git commit -m "Update Xcode project for release build"
    echo "✅ Xcode project changes committed"
fi

# Step 3: Build the app
echo ""
echo "📋 Step 3/7: Building application..."
"$SCRIPT_DIR/build.sh" --configuration Release

# Verify build
APP_PATH="$PROJECT_ROOT/build/Build/Products/Release/VibeMeter.app"
if [[ ! -d "$APP_PATH" ]]; then
    echo "❌ Build failed - app not found"
    exit 1
fi

# Verify build number
BUILT_VERSION=$(defaults read "$APP_PATH/Contents/Info.plist" CFBundleVersion)
if [[ "$BUILT_VERSION" != "$BUILD_NUMBER" ]]; then
    echo "❌ Build number mismatch! Expected $BUILD_NUMBER but got $BUILT_VERSION"
    exit 1
fi

echo "✅ Build complete"

# Step 4: Sign and notarize
echo ""
echo "📋 Step 4/7: Signing and notarizing..."
"$SCRIPT_DIR/sign-and-notarize.sh" --sign-and-notarize

# Step 5: Create DMG
echo ""
echo "📋 Step 5/7: Creating DMG..."
DMG_NAME="VibeMeter-$RELEASE_VERSION.dmg"
DMG_PATH="$PROJECT_ROOT/build/$DMG_NAME"
"$SCRIPT_DIR/create-dmg.sh" "$APP_PATH" "$DMG_PATH"

if [[ ! -f "$DMG_PATH" ]]; then
    echo "❌ DMG creation failed"
    exit 1
fi

echo "✅ DMG created: $DMG_NAME"

# Step 6: Create GitHub release
echo ""
echo "📋 Step 6/7: Creating GitHub release..."

# Check if tag already exists
if git rev-parse "$TAG_NAME" >/dev/null 2>&1; then
    echo "⚠️  Tag $TAG_NAME already exists!"
    echo ""
    echo "What would you like to do?"
    echo "  1) Delete the existing tag and create a new one"
    echo "  2) Cancel the release"
    echo ""
    read -p "Enter your choice (1 or 2): " choice
    
    case $choice in
        1)
            echo "🗑️  Deleting existing tag..."
            git tag -d "$TAG_NAME"
            git push origin :refs/tags/"$TAG_NAME" 2>/dev/null || true
            echo "✅ Existing tag deleted"
            ;;
        2)
            echo "❌ Release cancelled"
            exit 1
            ;;
        *)
            echo "❌ Invalid choice. Release cancelled"
            exit 1
            ;;
    esac
fi

# Create and push tag
echo "🏷️  Creating tag $TAG_NAME..."
git tag -a "$TAG_NAME" -m "Release $RELEASE_VERSION"
git push origin "$TAG_NAME"

# Create release
echo "📤 Creating GitHub release..."
RELEASE_NOTES="Release $RELEASE_VERSION (build $BUILD_NUMBER)"

if [[ "$RELEASE_TYPE" == "stable" ]]; then
    gh release create "$TAG_NAME" \
        --title "VibeMeter $RELEASE_VERSION" \
        --notes "$RELEASE_NOTES" \
        "$DMG_PATH"
else
    gh release create "$TAG_NAME" \
        --title "VibeMeter $RELEASE_VERSION" \
        --notes "$RELEASE_NOTES" \
        --prerelease \
        "$DMG_PATH"
fi

echo "✅ GitHub release created"

# Step 7: Update appcast
echo ""
echo "📋 Step 7/7: Updating appcast..."

# Generate EdDSA signature
echo "🔐 Generating EdDSA signature..."
export PATH="$HOME/.local/bin:$PATH"
SIGNATURE_OUTPUT=$(sign_update "$DMG_PATH" -p)
ED_SIGNATURE=$(echo "$SIGNATURE_OUTPUT" | grep -o 'sparkle:edSignature="[^"]*"' | sed 's/sparkle:edSignature="//;s/"$//')
FILE_SIZE=$(stat -f%z "$DMG_PATH")

# Update appropriate appcast
if [[ "$RELEASE_TYPE" == "stable" ]]; then
    APPCAST_FILE="$PROJECT_ROOT/appcast.xml"
else
    APPCAST_FILE="$PROJECT_ROOT/appcast-prerelease.xml"
fi

# Generate appcast using the more reliable generate-appcast.sh
"$SCRIPT_DIR/generate-appcast.sh"

# Verify the appcast was updated
if [[ "$RELEASE_TYPE" == "stable" ]]; then
    if ! grep -q "<sparkle:version>$BUILD_NUMBER</sparkle:version>" "$PROJECT_ROOT/appcast.xml"; then
        echo "⚠️  Appcast may not have been updated correctly. Running manual update..."
        "$SCRIPT_DIR/update-appcast.sh" "$RELEASE_VERSION" "$BUILD_NUMBER" "$DMG_PATH" || true
    fi
else
    if ! grep -q "<sparkle:version>$BUILD_NUMBER</sparkle:version>" "$PROJECT_ROOT/appcast-prerelease.xml"; then
        echo "⚠️  Pre-release appcast may not have been updated correctly. Running manual update..."
        "$SCRIPT_DIR/update-appcast.sh" "$RELEASE_VERSION" "$BUILD_NUMBER" "$DMG_PATH" || true
    fi
fi

echo "✅ Appcast updated"

# Commit and push appcast files
echo ""
echo "📤 Committing and pushing appcast..."
git add "$PROJECT_ROOT/appcast.xml" "$PROJECT_ROOT/appcast-prerelease.xml" 2>/dev/null || true
if ! git diff --cached --quiet; then
    git commit -m "Update appcast for $RELEASE_VERSION"
    git push origin main
    echo "✅ Appcast changes pushed"
else
    echo "ℹ️  No appcast changes to commit"
fi

echo ""
echo "🎉 Release Complete!"
echo "=================="
echo ""
echo "✅ Successfully released VibeMeter $RELEASE_VERSION"
echo ""
echo "Release details:"
echo "  - Version: $RELEASE_VERSION"
echo "  - Build: $BUILD_NUMBER"
echo "  - Tag: $TAG_NAME"
echo "  - DMG: $DMG_NAME"
echo "  - GitHub: https://github.com/steipete/VibeMeter/releases/tag/$TAG_NAME"
echo ""

if [[ "$RELEASE_TYPE" != "stable" ]]; then
    echo "📝 Note: This is a pre-release. Users with 'Include Pre-releases' enabled will receive this update."
else
    echo "📝 Note: This is a stable release. All users will receive this update."
fi