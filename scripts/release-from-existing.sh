#!/bin/bash

# Quick Release Script for VibeMeter
# This script creates a release from an existing signed and notarized app
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_step() {
    echo -e "\n${BLUE}📋 $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Check if existing app path is provided
if [ $# -eq 0 ]; then
    # Try to find the most recent build
    APP_PATH="$PROJECT_ROOT/build/Build/Products/Release/VibeMeter.app"
    if [ ! -d "$APP_PATH" ]; then
        print_error "No app path provided and no build found at default location"
        echo "Usage: $0 [path/to/VibeMeter.app]"
        echo "Or build first with: ./scripts/build.sh --configuration Release"
        exit 1
    fi
    print_warning "Using app at: $APP_PATH"
else
    APP_PATH="$1"
fi

# Verify app exists
if [ ! -d "$APP_PATH" ]; then
    print_error "App not found at: $APP_PATH"
    exit 1
fi

print_step "Starting quick release from existing app"

# Get version from app
VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$APP_PATH/Contents/Info.plist")
BUILD_NUMBER=$(/usr/libexec/PlistBuddy -c "Print CFBundleVersion" "$APP_PATH/Contents/Info.plist")

print_success "Found VibeMeter v$VERSION (build $BUILD_NUMBER)"

# Verify app is signed
print_step "Verifying app signature"
if codesign -v "$APP_PATH" 2>&1; then
    print_success "App signature is valid"
else
    print_error "App is not properly signed"
    exit 1
fi

# Check if notarized
print_step "Checking notarization status"
if xcrun stapler validate "$APP_PATH" 2>&1 | grep -q "The validate action worked"; then
    print_success "App is notarized"
else
    print_warning "App may not be notarized - continuing anyway"
fi

# Create DMG
print_step "Creating DMG"
DMG_PATH="$PROJECT_ROOT/build/VibeMeter-$VERSION.dmg"
if [ -f "$DMG_PATH" ]; then
    print_warning "DMG already exists, removing old version"
    rm "$DMG_PATH"
fi

"$SCRIPT_DIR/create-dmg.sh" "$APP_PATH"

if [ ! -f "$DMG_PATH" ]; then
    print_error "DMG creation failed"
    exit 1
fi

print_success "DMG created at: $DMG_PATH"

# Sign DMG with Sparkle
print_step "Signing DMG with Sparkle EdDSA key"

# Check if private key exists
PRIVATE_KEY_PATH="$PROJECT_ROOT/private/sparkle_private_key"
if [ ! -f "$PRIVATE_KEY_PATH" ]; then
    print_error "Sparkle private key not found at: $PRIVATE_KEY_PATH"
    print_error "Run ./scripts/setup-sparkle-release.sh to generate keys"
    exit 1
fi

# Create signature
TEMP_SIG="/tmp/vibe_sig_$$.bin"
openssl pkeyutl -sign -inkey "$PRIVATE_KEY_PATH" -in "$DMG_PATH" -out "$TEMP_SIG" 2>/dev/null

if [ ! -f "$TEMP_SIG" ]; then
    print_error "Failed to create EdDSA signature"
    exit 1
fi

# Convert to base64
SPARKLE_SIG=$(base64 < "$TEMP_SIG")
rm "$TEMP_SIG"

print_success "Created EdDSA signature"

# Get file size
DMG_SIZE=$(stat -f%z "$DMG_PATH")

# Update appcast.xml
print_step "Updating appcast.xml"

# Generate release date
RELEASE_DATE=$(date -R)

# GitHub release URL
GITHUB_USERNAME="${GITHUB_USERNAME:-steipete}"
DMG_FILENAME=$(basename "$DMG_PATH")
DOWNLOAD_URL="https://github.com/$GITHUB_USERNAME/VibeMeter/releases/download/v$VERSION/$DMG_FILENAME"

# Generate HTML description from changelog
print_step "Generating release notes from changelog"
DESCRIPTION_HTML=$("$SCRIPT_DIR/changelog-to-html.sh" "$VERSION" 2>/dev/null | tail -n +2)

if [ -z "$DESCRIPTION_HTML" ]; then
    print_warning "No changelog entry found for version $VERSION"
    DESCRIPTION_HTML="<h2>VibeMeter $VERSION</h2><p>Bug fixes and improvements.</p>"
fi

# Create appcast.xml
cat > "$PROJECT_ROOT/appcast.xml" << EOF
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle" xmlns:dc="http://purl.org/dc/elements/1.1/">
    <channel>
        <title>VibeMeter Updates</title>
        <link>https://github.com/$GITHUB_USERNAME/VibeMeter</link>
        <description>VibeMeter automatic updates feed</description>
        <language>en</language>
        
        <item>
            <title>VibeMeter $VERSION</title>
            <link>$DOWNLOAD_URL</link>
            <sparkle:version>$BUILD_NUMBER</sparkle:version>
            <sparkle:shortVersionString>$VERSION</sparkle:shortVersionString>
            <description><![CDATA[
                $DESCRIPTION_HTML
            ]]></description>
            <pubDate>$RELEASE_DATE</pubDate>
            <enclosure 
                url="$DOWNLOAD_URL"
                length="$DMG_SIZE"
                type="application/octet-stream"
                sparkle:edSignature="$SPARKLE_SIG"
            />
            <sparkle:minimumSystemVersion>14.0</sparkle:minimumSystemVersion>
        </item>
    </channel>
</rss>
EOF

print_success "Updated appcast.xml"

# Commit changes
print_step "Committing changes"
git add appcast.xml
if git diff --staged --quiet; then
    print_warning "No changes to commit"
else
    git commit -m "Release version $VERSION

- Updated appcast.xml for Sparkle auto-updates
- Version: $VERSION (build $BUILD_NUMBER)
- DMG size: $DMG_SIZE bytes"
    print_success "Changes committed"
fi

# Push changes
print_step "Pushing to GitHub"
git push origin main

# Create tag
TAG="v$VERSION"
if git rev-parse "$TAG" >/dev/null 2>&1; then
    print_warning "Tag $TAG already exists"
else
    git tag -a "$TAG" -m "Release $VERSION"
    git push origin "$TAG"
    print_success "Created and pushed tag: $TAG"
fi

# Create GitHub release
print_step "Creating GitHub release"

# Check if gh is installed
if ! command -v gh &> /dev/null; then
    print_error "GitHub CLI (gh) not found"
    print_error "Install with: brew install gh"
    print_error "Then run: gh auth login"
    exit 1
fi

# Check if authenticated
if ! gh auth status &> /dev/null; then
    print_error "Not authenticated with GitHub"
    print_error "Run: gh auth login"
    exit 1
fi

# Create release
RELEASE_NOTES="## VibeMeter $VERSION

### Installation
1. Download the DMG file
2. Open it and drag VibeMeter to Applications
3. Launch VibeMeter from Applications

### Auto-Updates
This version supports automatic updates via Sparkle.

$(<"$PROJECT_ROOT/CHANGELOG.md" sed -n "/## \[$VERSION\]/,/## \[/p" | sed '$ d' | tail -n +2)"

if [ -z "$RELEASE_NOTES" ]; then
    RELEASE_NOTES="Release $VERSION - Bug fixes and improvements"
fi

gh release create "$TAG" "$DMG_PATH" \
    --title "VibeMeter $VERSION" \
    --notes "$RELEASE_NOTES" \
    --latest

print_success "GitHub release created!"
print_success "Release URL: https://github.com/$GITHUB_USERNAME/VibeMeter/releases/tag/$TAG"

# Final summary
echo
print_success "🎉 Release $VERSION completed successfully!"
echo
echo "Next steps:"
echo "1. Test the auto-update from a previous version"
echo "2. Announce the release"
echo "3. Monitor for any issues"