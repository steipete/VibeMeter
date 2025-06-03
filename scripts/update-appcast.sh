#!/bin/bash

# Appcast.xml Update Script
set -euo pipefail

VERSION="$1"
BUILD_NUMBER="$2"
DMG_PATH="$3"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "📡 Updating appcast.xml for version $VERSION"

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
DESCRIPTION_HTML=$("$SCRIPT_DIR/changelog-to-html.sh" "$VERSION" 2>/dev/null | tail -n +2)

# Fallback if no changelog entry found
if [ -z "$DESCRIPTION_HTML" ]; then
    DESCRIPTION_HTML="<h2>VibeMeter $VERSION</h2><p>Bug fixes and improvements.</p>"
fi

# Create or update appcast.xml
cat > "$PROJECT_ROOT/appcast.xml" << APPCAST_EOF
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
                sparkle:edSignature="SIGNATURE_PLACEHOLDER"
            />
            <sparkle:minimumSystemVersion>14.0</sparkle:minimumSystemVersion>
        </item>
    </channel>
</rss>
APPCAST_EOF

echo "✅ Appcast.xml updated"

# Sign the DMG if private key exists
PRIVATE_KEY_PATH="$PROJECT_ROOT/private/sparkle_private_key"
if [ -f "$PRIVATE_KEY_PATH" ]; then
    echo "🔐 Signing DMG with Sparkle EdDSA key..."
    
    # Create signature
    TEMP_SIG="/tmp/vibe_sig_$$.bin"
    openssl pkeyutl -sign -inkey "$PRIVATE_KEY_PATH" -in "$DMG_PATH" -out "$TEMP_SIG" 2>/dev/null
    
    if [ -f "$TEMP_SIG" ]; then
        # Convert to base64
        SPARKLE_SIG=$(base64 < "$TEMP_SIG")
        rm "$TEMP_SIG"
        
        # Update the appcast with the actual signature
        sed -i '' "s/sparkle:edSignature=\"SIGNATURE_PLACEHOLDER\"/sparkle:edSignature=\"$SPARKLE_SIG\"/" "$PROJECT_ROOT/appcast.xml"
        echo "✅ DMG signed and appcast.xml updated with signature"
    else
        echo "⚠️  Failed to create EdDSA signature"
    fi
else
    echo "⚠️  Sparkle private key not found at: $PRIVATE_KEY_PATH"
    echo "⚠️  Run ./scripts/setup-sparkle-release.sh to generate keys"
    echo "⚠️  Or manually sign: openssl pkeyutl -sign -inkey /path/to/key -in '$DMG_PATH'"
fi
