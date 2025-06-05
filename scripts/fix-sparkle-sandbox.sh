#!/bin/bash
set -euo pipefail

# Fix Sparkle for Sandboxed App
# This script is now simplified - we use Sparkle's default XPC services as-is

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

if [[ $# -lt 1 ]]; then
    echo "Usage: $0 <app-path>"
    echo "Example: $0 build/Build/Products/Release/VibeMeter.app"
    exit 1
fi

APP_PATH="$1"

echo "🔧 Verifying Sparkle configuration for sandboxed operation..."

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

echo ""
echo "📋 Sparkle XPC Services Status:"
echo "================================"

# Check Installer service
if [ -d "$SPARKLE_XPCSERVICES/Installer.xpc" ]; then
    echo "✅ Installer.xpc found"
    # Check bundle ID
    INSTALLER_BUNDLE_ID=$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "$SPARKLE_XPCSERVICES/Installer.xpc/Contents/Info.plist" 2>/dev/null || echo "Not found")
    echo "   Bundle ID: $INSTALLER_BUNDLE_ID"
    if [[ "$INSTALLER_BUNDLE_ID" == "org.sparkle-project.InstallerLauncher" ]]; then
        echo "   ✅ Using Sparkle default bundle ID (correct)"
    else
        echo "   ⚠️  Custom bundle ID detected"
    fi
else
    echo "❌ Installer.xpc not found (required for sandboxed apps)"
fi

# Check Downloader service
if [ -d "$SPARKLE_XPCSERVICES/Downloader.xpc" ]; then
    echo "✅ Downloader.xpc found (not used when app has network access)"
fi

echo ""
echo "📝 Required App Configuration:"
echo "=============================="
echo ""
echo "1. Info.plist must have:"
echo "   SUEnableInstallerLauncherService = YES"
echo "   SUEnableDownloaderService = NO"
echo ""
echo "2. Entitlements must include:"
echo "   <key>com.apple.security.temporary-exception.mach-lookup.global-name</key>"
echo "   <array>"
echo "       <string>com.steipete.vibemeter-spki</string>"
echo "   </array>"
echo ""
echo "3. XPC services should NOT be modified or re-signed"
echo "   (Sparkle handles this automatically)"
echo ""
echo "✅ Sparkle sandbox check complete!"