#!/bin/bash
set -euo pipefail

# Fix Sparkle for Sandboxed App
# This script ensures Sparkle's XPC services are properly signed for sandboxed operation

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

if [[ $# -lt 1 ]]; then
    echo "Usage: $0 <app-path>"
    echo "Example: $0 build/Build/Products/Release/VibeMeter.app"
    exit 1
fi

APP_PATH="$1"

echo "🔧 Configuring Sparkle for sandboxed operation..."

# Find Sparkle framework
SPARKLE_FRAMEWORK="$APP_PATH/Contents/Frameworks/Sparkle.framework"
SPARKLE_XPCSERVICES="$SPARKLE_FRAMEWORK/Versions/B/XPCServices"

if [ ! -d "$SPARKLE_FRAMEWORK" ]; then
    echo "❌ Sparkle framework not found"
    exit 1
fi

if [ ! -d "$SPARKLE_XPCSERVICES" ]; then
    echo "❌ Sparkle XPC services not found in framework"
    exit 1
fi

# Create XPC service entitlements for Downloader
DOWNLOADER_ENTITLEMENTS=$(mktemp)
cat > "$DOWNLOADER_ENTITLEMENTS" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.app-sandbox</key>
    <true/>
    <key>com.apple.security.network.client</key>
    <true/>
    <key>com.apple.security.files.user-selected.read-write</key>
    <true/>
</dict>
</plist>
EOF

# Sign the XPC services with proper entitlements
echo "🔐 Signing XPC services..."

# Get signing identity
SIGN_IDENTITY="Developer ID Application"

# Sign Installer service (no special entitlements needed)
if [ -d "$SPARKLE_XPCSERVICES/Installer.xpc" ]; then
    codesign --force --sign "$SIGN_IDENTITY" --options runtime \
        "$SPARKLE_XPCSERVICES/Installer.xpc"
    echo "✅ Signed Installer.xpc"
fi

# Sign Downloader service with network entitlements
if [ -d "$SPARKLE_XPCSERVICES/Downloader.xpc" ]; then
    codesign --force --sign "$SIGN_IDENTITY" --options runtime \
        --entitlements "$DOWNLOADER_ENTITLEMENTS" \
        "$SPARKLE_XPCSERVICES/Downloader.xpc"
    echo "✅ Signed Downloader.xpc with network entitlements"
fi

# Clean up
rm -f "$DOWNLOADER_ENTITLEMENTS"

echo ""
echo "🎉 Sparkle configured for sandboxed operation!"
echo ""
echo "The XPC services have been:"
echo "  - Signed with proper entitlements"
echo "  - Left in their original location inside Sparkle.framework"
echo ""
echo "⚠️  Make sure your app's Info.plist has:"
echo "    SUEnableInstallerLauncherService = YES"
echo "    SUEnableDownloaderService = YES"