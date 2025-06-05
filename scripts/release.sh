#!/bin/bash

# Automated Release Script for VibeMeter
# This script handles the complete release process
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Parse arguments
RELEASE_TYPE="${1:-}"
PRERELEASE_NUMBER="${2:-}"

# Validate arguments
if [[ -z "$RELEASE_TYPE" ]]; then
    echo -e "${RED}❌ Error: Release type required${NC}"
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
        echo -e "${RED}❌ Error: Pre-release number required for $RELEASE_TYPE${NC}"
        echo "Example: $0 $RELEASE_TYPE 1"
        exit 1
    fi
fi

echo -e "${BLUE}🚀 VibeMeter Automated Release${NC}"
echo "=============================="
echo ""

# Step 1: Run pre-flight check
echo -e "${BLUE}📋 Step 1/7: Running pre-flight check...${NC}"
if ! "$SCRIPT_DIR/preflight-check.sh"; then
    echo ""
    echo -e "${RED}❌ Pre-flight check failed. Please fix the issues above.${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}✅ Pre-flight check passed!${NC}"
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
echo -e "${BLUE}📋 Step 2/7: Generating Xcode project...${NC}"
rm -rf "$PROJECT_ROOT/build"
"$SCRIPT_DIR/generate-xcproj.sh"

# Check if Xcode project was modified and commit if needed
if ! git diff --quiet "$PROJECT_ROOT/VibeMeter.xcodeproj/project.pbxproj"; then
    echo "📝 Committing Xcode project changes..."
    git add "$PROJECT_ROOT/VibeMeter.xcodeproj/project.pbxproj"
    git commit -m "Update Xcode project for build $BUILD_NUMBER"
    echo -e "${GREEN}✅ Xcode project changes committed${NC}"
fi

# Step 3: Build the app
echo ""
echo -e "${BLUE}📋 Step 3/7: Building application...${NC}"
"$SCRIPT_DIR/build.sh" --configuration Release

# Verify build
APP_PATH="$PROJECT_ROOT/build/Build/Products/Release/VibeMeter.app"
if [[ ! -d "$APP_PATH" ]]; then
    echo -e "${RED}❌ Build failed - app not found${NC}"
    exit 1
fi

# Verify build number
BUILT_VERSION=$(defaults read "$APP_PATH/Contents/Info.plist" CFBundleVersion)
if [[ "$BUILT_VERSION" != "$BUILD_NUMBER" ]]; then
    echo -e "${RED}❌ Build number mismatch! Expected $BUILD_NUMBER but got $BUILT_VERSION${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Build complete${NC}"

# Step 4: Sign and notarize
echo ""
echo -e "${BLUE}📋 Step 4/7: Signing and notarizing...${NC}"
"$SCRIPT_DIR/sign-and-notarize.sh" --sign-and-notarize

# Step 5: Create DMG
echo ""
echo -e "${BLUE}📋 Step 5/7: Creating DMG...${NC}"
DMG_NAME="VibeMeter-$RELEASE_VERSION.dmg"
DMG_PATH="$PROJECT_ROOT/build/$DMG_NAME"
"$SCRIPT_DIR/create-dmg.sh" "$APP_PATH" "$DMG_PATH"

if [[ ! -f "$DMG_PATH" ]]; then
    echo -e "${RED}❌ DMG creation failed${NC}"
    exit 1
fi

echo -e "${GREEN}✅ DMG created: $DMG_NAME${NC}"

# Step 6: Create GitHub release
echo ""
echo -e "${BLUE}📋 Step 6/7: Creating GitHub release...${NC}"

# Check if tag already exists
if git rev-parse "$TAG_NAME" >/dev/null 2>&1; then
    echo -e "${YELLOW}⚠️  Tag $TAG_NAME already exists!${NC}"
    
    # Check if a release exists for this tag
    if gh release view "$TAG_NAME" >/dev/null 2>&1; then
        echo ""
        echo "A GitHub release already exists for this tag."
        echo "What would you like to do?"
        echo "  1) Delete the existing release and tag, then create new ones"
        echo "  2) Cancel the release"
        echo ""
        read -p "Enter your choice (1 or 2): " choice
        
        case $choice in
            1)
                echo "🗑️  Deleting existing release and tag..."
                gh release delete "$TAG_NAME" --yes 2>/dev/null || true
                git tag -d "$TAG_NAME"
                git push origin :refs/tags/"$TAG_NAME" 2>/dev/null || true
                echo -e "${GREEN}✅ Existing release and tag deleted${NC}"
                ;;
            2)
                echo -e "${RED}❌ Release cancelled${NC}"
                exit 1
                ;;
            *)
                echo -e "${RED}❌ Invalid choice. Release cancelled${NC}"
                exit 1
                ;;
        esac
    else
        # Tag exists but no release - just delete the tag
        echo "🗑️  Deleting existing tag..."
        git tag -d "$TAG_NAME"
        git push origin :refs/tags/"$TAG_NAME" 2>/dev/null || true
        echo -e "${GREEN}✅ Existing tag deleted${NC}"
    fi
fi

# Create and push tag
echo "🏷️  Creating tag $TAG_NAME..."
git tag -a "$TAG_NAME" -m "Release $RELEASE_VERSION (build $BUILD_NUMBER)"
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

echo -e "${GREEN}✅ GitHub release created${NC}"

# Step 7: Update appcast
echo ""
echo -e "${BLUE}📋 Step 7/7: Updating appcast...${NC}"

# Generate appcast
echo "🔐 Generating appcast with EdDSA signatures..."
"$SCRIPT_DIR/generate-appcast.sh"

# Verify the appcast was updated
if [[ "$RELEASE_TYPE" == "stable" ]]; then
    if ! grep -q "<sparkle:version>$BUILD_NUMBER</sparkle:version>" "$PROJECT_ROOT/appcast.xml"; then
        echo -e "${YELLOW}⚠️  Appcast may not have been updated. Please check manually.${NC}"
    fi
else
    if ! grep -q "<sparkle:version>$BUILD_NUMBER</sparkle:version>" "$PROJECT_ROOT/appcast-prerelease.xml"; then
        echo -e "${YELLOW}⚠️  Pre-release appcast may not have been updated. Please check manually.${NC}"
    fi
fi

echo -e "${GREEN}✅ Appcast updated${NC}"

# Commit and push appcast files
echo ""
echo "📤 Committing and pushing appcast..."
git add "$PROJECT_ROOT/appcast.xml" "$PROJECT_ROOT/appcast-prerelease.xml" 2>/dev/null || true
if ! git diff --cached --quiet; then
    git commit -m "Update appcast for $RELEASE_VERSION"
    git push origin main
    echo -e "${GREEN}✅ Appcast changes pushed${NC}"
else
    echo "ℹ️  No appcast changes to commit"
fi

# Optional: Verify appcast
echo ""
echo "🔍 Verifying appcast files..."
if "$SCRIPT_DIR/verify-appcast.sh" | grep -q "All appcast checks passed"; then
    echo -e "${GREEN}✅ Appcast verification passed${NC}"
else
    echo -e "${YELLOW}⚠️  Some appcast issues detected. Please review the output above.${NC}"
fi

echo ""
echo -e "${GREEN}🎉 Release Complete!${NC}"
echo "=================="
echo ""
echo -e "${GREEN}✅ Successfully released VibeMeter $RELEASE_VERSION${NC}"
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

echo ""
echo "💡 Next steps:"
echo "  - Test the update from an older version"
echo "  - Monitor Console.app for any update errors"
echo "  - Update release notes on GitHub if needed"