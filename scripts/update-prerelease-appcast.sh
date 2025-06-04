#!/bin/bash

# Pre-release Appcast.xml Update Script
set -euo pipefail

VERSION="$1"
BUILD_NUMBER="$2"
DMG_PATH="$3"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "📡 Updating appcast-prerelease.xml for version $VERSION"

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

# Determine if this is a pre-release version
IS_PRERELEASE="false"
if [[ "$VERSION" =~ -(alpha|beta|rc) ]]; then
    IS_PRERELEASE="true"
fi

# Read current appcast-prerelease.xml and extract existing entries
APPCAST_PATH="$PROJECT_ROOT/appcast-prerelease.xml"
NEW_ITEM_XML=""

# Create the new item XML
if [ "$IS_PRERELEASE" = "true" ]; then
    # Pre-release version
    NEW_ITEM_XML="        <item>
            <title>VibeMeter $VERSION</title>
            <link>$DOWNLOAD_URL</link>
            <sparkle:version>$BUILD_NUMBER</sparkle:version>
            <sparkle:shortVersionString>$VERSION</sparkle:shortVersionString>
            <description><![CDATA[
                <h2>VibeMeter $VERSION</h2>
                <p><strong>Pre-release version</strong> with new features and improvements.</p>
                <ul>
                    <li>Latest experimental features</li>
                    <li>Bug fixes and performance enhancements</li>
                    <li>Enhanced update channel selection</li>
                </ul>
                <p><strong>Note:</strong> This is a pre-release version and may contain bugs.</p>
            ]]></description>
            <pubDate>$RELEASE_DATE</pubDate>
            <enclosure 
                url=\"$DOWNLOAD_URL\"
                length=\"$DMG_SIZE\"
                type=\"application/octet-stream\"
                sparkle:edSignature=\"$SPARKLE_SIG\"
            />
            <sparkle:minimumSystemVersion>15.0</sparkle:minimumSystemVersion>
        </item>"
else
    # Stable version - also add to pre-release feed
    NEW_ITEM_XML="        <item>
            <title>VibeMeter $VERSION</title>
            <link>$DOWNLOAD_URL</link>
            <sparkle:version>$BUILD_NUMBER</sparkle:version>
            <sparkle:shortVersionString>$VERSION</sparkle:shortVersionString>
            <description><![CDATA[
                <h2>VibeMeter $VERSION</h2>
                <p>Latest stable version of VibeMeter with new features and improvements.</p>
                <ul>
                    <li>Enhanced spending tracking</li>
                    <li>Improved UI and performance</li>
                    <li>Bug fixes and stability improvements</li>
                </ul>
            ]]></description>
            <pubDate>$RELEASE_DATE</pubDate>
            <enclosure 
                url=\"$DOWNLOAD_URL\"
                length=\"$DMG_SIZE\"
                type=\"application/octet-stream\"
                sparkle:edSignature=\"$SPARKLE_SIG\"
            />
            <sparkle:minimumSystemVersion>14.0</sparkle:minimumSystemVersion>
        </item>"
fi

# Create a temporary file with the new appcast content
cat > "$PROJECT_ROOT/appcast-prerelease.xml" << APPCAST_EOF
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle" xmlns:dc="http://purl.org/dc/elements/1.1/">
    <channel>
        <title>VibeMeter Pre-release Updates</title>
        <link>https://github.com/$GITHUB_USERNAME/VibeMeter</link>
        <description>VibeMeter pre-release and beta updates feed</description>
        <language>en</language>
        
$NEW_ITEM_XML
        
        <!-- Existing stable releases for pre-release users -->
        <item>
            <title>VibeMeter 0.9.1</title>
            <link>https://github.com/steipete/VibeMeter/releases/download/v0.9.1/VibeMeter-0.9.1.dmg</link>
            <sparkle:version>2</sparkle:version>
            <sparkle:shortVersionString>0.9.1</sparkle:shortVersionString>
            <description><![CDATA[
                <h2>VibeMeter 0.9.1</h2>
                <p>Bug fixes and improvements for Sparkle auto-update functionality.</p>
                <ul>
                    <li>Fixed EdDSA signature generation in update scripts</li>
                    <li>Improved release automation workflow</li>
                    <li>Enhanced build script reliability</li>
                </ul>
            ]]></description>
            <pubDate>Wed, 04 Jun 2025 06:26:58 +0100</pubDate>
            <enclosure 
                url="https://github.com/steipete/VibeMeter/releases/download/v0.9.1/VibeMeter-0.9.1.dmg"
                length="5465087"
                type="application/octet-stream"
                sparkle:edSignature="P49hpPy77LD8RA6kgi5G87NUUvuC1tLN7oq70yTIQXHamWmPodpLFkxY0zXXDpuRUHfMwOwheGv7GHj/kD+2Dg=="
            />
            <sparkle:minimumSystemVersion>14.0</sparkle:minimumSystemVersion>
        </item>
        
        <item>
            <title>VibeMeter 0.9.0</title>
            <link>https://github.com/steipete/VibeMeter/releases/download/v0.9.0/VibeMeter-0.9.0.dmg</link>
            <sparkle:version>1</sparkle:version>
            <sparkle:shortVersionString>0.9.0</sparkle:shortVersionString>
            <description><![CDATA[
                <h2>VibeMeter 0.9.0</h2>
                <p>First beta release with Sparkle auto-update support.</p>
                <ul>
                    <li>Enhanced spending tracking</li>
                    <li>Improved UI and performance</li>
                    <li>Fixed Sparkle EdDSA public key format</li>
                </ul>
            ]]></description>
            <pubDate>Wed, 04 Jun 2025 06:23:20 +0100</pubDate>
            <enclosure 
                url="https://github.com/steipete/VibeMeter/releases/download/v0.9.0/VibeMeter-0.9.0.dmg"
                length="5464649"
                type="application/octet-stream"
                sparkle:edSignature="dAoJFOZiiFXUbK8IjlK+GRgTeto15J4Cvp1/j/jn05TxH9U/VE+5DORgxL1qEvU3JIa46E136p9bI8N93SvFAQ=="
            />
            <sparkle:minimumSystemVersion>14.0</sparkle:minimumSystemVersion>
        </item>
    </channel>
</rss>
APPCAST_EOF

echo "✅ Appcast-prerelease.xml updated with signature: $SPARKLE_SIG"