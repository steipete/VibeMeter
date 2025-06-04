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

# Generate EdDSA signature first if possible
SPARKLE_SIG="SIGNATURE_PLACEHOLDER"
PRIVATE_KEY_PATH="$PROJECT_ROOT/private/sparkle_private_key"
if [ -f "$PRIVATE_KEY_PATH" ]; then
    echo "🔐 Signing DMG with Sparkle EdDSA key..."
    
    # Create signature using sign_update tool
    SPARKLE_BIN="$PROJECT_ROOT/build/SourcePackages/artifacts/sparkle/Sparkle/bin"
    if [ -d "$SPARKLE_BIN" ] && [ -f "$SPARKLE_BIN/sign_update" ]; then
        # Extract raw private key from PEM format
        openssl pkey -in "$PRIVATE_KEY_PATH" -outform DER | tail -c 32 | base64 > /tmp/vibemeter_private_raw.key
        
        # Sign and get the signature
        SPARKLE_SIG_OUTPUT=$("$SPARKLE_BIN/sign_update" "$DMG_PATH" -f /tmp/vibemeter_private_raw.key 2>&1)
        SPARKLE_SIG=$(echo "$SPARKLE_SIG_OUTPUT" | grep -o 'sparkle:edSignature="[^"]*"' | cut -d'"' -f2)
        
        # Clean up temp key
        rm -f /tmp/vibemeter_private_raw.key
        
        if [ -n "$SPARKLE_SIG" ]; then
            echo "✅ DMG signed successfully"
        else
            echo "⚠️  Failed to create EdDSA signature"
            echo "Output: $SPARKLE_SIG_OUTPUT"
            SPARKLE_SIG="SIGNATURE_PLACEHOLDER"
        fi
    else
        echo "⚠️  Sparkle sign_update tool not found. Run a build first."
    fi
else
    echo "⚠️  Sparkle private key not found at: $PRIVATE_KEY_PATH"
    echo "⚠️  Run ./scripts/setup-sparkle-release.sh to generate keys"
fi

# Create or update appcast.xml with the signature
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
                <h2>VibeMeter $VERSION</h2>
                <p>Latest version of VibeMeter with new features and improvements.</p>
                <ul>
                    <li>Enhanced spending tracking</li>
                    <li>Improved UI and performance</li>
                    <li>Bug fixes and stability improvements</li>
                </ul>
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
APPCAST_EOF

echo "✅ Appcast.xml updated with signature: $SPARKLE_SIG"

# Also update the pre-release appcast to include this stable release
echo "📡 Also updating appcast-prerelease.xml with stable release..."
./scripts/update-prerelease-appcast.sh "$VERSION" "$BUILD_NUMBER" "$DMG_PATH"