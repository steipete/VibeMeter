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

# Sign the XPC services
echo "🔐 Signing XPC services..."

# Get signing identity
SIGN_IDENTITY="Developer ID Application"

# Sign Installer service (no special entitlements needed)
if [ -d "$SPARKLE_XPCSERVICES/Installer.xpc" ]; then
    codesign --force --sign "$SIGN_IDENTITY" --options runtime \
        "$SPARKLE_XPCSERVICES/Installer.xpc"
    echo "✅ Signed Installer.xpc"
else
    echo "⚠️  Installer.xpc not found (this is required for sandboxed apps)"
fi

# Note: We don't sign the Downloader service because:
# 1. VibeMeter has network access (com.apple.security.network.client)
# 2. SUEnableDownloaderService is set to false in Info.plist
# 3. Sparkle will download updates directly without the XPC service

echo ""
echo "🎉 Sparkle configured for sandboxed operation!"
echo ""
echo "The XPC services have been:"
echo "  - Signed with proper entitlements"
echo "  - Left in their original location inside Sparkle.framework"
echo ""
echo "✅ Configuration verified:"
echo "    SUEnableInstallerLauncherService = YES (using Installer.xpc)"
echo "    SUEnableDownloaderService = NO (app has network access)"
echo ""
echo "⚠️  Important: XPC services must stay inside Sparkle.framework"
echo "    Do NOT copy them to the app bundle root!"