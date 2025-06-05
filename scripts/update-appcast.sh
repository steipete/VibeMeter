#!/bin/bash

# Appcast.xml Update Script
set -euo pipefail

if [[ $# -lt 3 ]]; then
    echo "Usage: $0 <version> <build_number> <dmg_path>"
    exit 1
fi

VERSION="$1"
BUILD_NUMBER="$2"
DMG_PATH="$3"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Determine if this is a pre-release
if [[ "$VERSION" =~ -(alpha|beta|rc)\. ]]; then
    IS_PRERELEASE=true
    APPCAST_FILE="$PROJECT_ROOT/appcast-prerelease.xml"
    echo "📡 Updating appcast-prerelease.xml for version $VERSION"
else
    IS_PRERELEASE=false
    APPCAST_FILE="$PROJECT_ROOT/appcast.xml"
    echo "📡 Updating appcast.xml for version $VERSION"
fi

# Calculate file size and SHA256
DMG_SIZE=$(stat -f%z "$DMG_PATH")
DMG_SHA256=$(shasum -a 256 "$DMG_PATH" | cut -d' ' -f1)
DMG_FILENAME=$(basename "$DMG_PATH")

# Get current date in RFC 2822 format
RELEASE_DATE=$(date -R)

# GitHub release URL
GITHUB_USERNAME="${GITHUB_USERNAME:-steipete}"
DOWNLOAD_URL="https://github.com/$GITHUB_USERNAME/VibeMeter/releases/download/v$VERSION/$DMG_FILENAME"

# Generate HTML description from changelog
echo "📝 Generating HTML description from changelog..."
DESCRIPTION_HTML=$("$SCRIPT_DIR/changelog-to-html.sh" "$VERSION" 2>/dev/null | tail -n +2 || echo "<p>Release $VERSION</p>")

# Generate EdDSA signature
echo "🔐 Generating EdDSA signature..."
export PATH="$HOME/.local/bin:$PATH"
if command -v sign_update >/dev/null 2>&1; then
    SIGNATURE_OUTPUT=$(sign_update "$DMG_PATH" -p 2>/dev/null || echo "")
    ED_SIGNATURE=$(echo "$SIGNATURE_OUTPUT" | grep -o 'sparkle:edSignature="[^"]*"' | sed 's/sparkle:edSignature="//;s/"$//' || echo "SIGNATURE_PLACEHOLDER")
else
    echo "⚠️  sign_update not found, using placeholder signature"
    ED_SIGNATURE="SIGNATURE_PLACEHOLDER"
fi

# Create or update appcast
cat > "$APPCAST_FILE" << APPCAST_EOF
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
                sparkle:edSignature="$ED_SIGNATURE"
            />
            <sparkle:minimumSystemVersion>14.0</sparkle:minimumSystemVersion>
        </item>
    </channel>
</rss>
APPCAST_EOF

echo "✅ $(basename "$APPCAST_FILE") updated"
if [[ "$ED_SIGNATURE" == "SIGNATURE_PLACEHOLDER" ]]; then
    echo "⚠️  Remember to sign the DMG with your Sparkle private key and update the signature"
    echo "⚠️  Command: sign_update '$DMG_PATH'"
fi
