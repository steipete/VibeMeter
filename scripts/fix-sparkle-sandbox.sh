#!/bin/bash
set -euo pipefail

# Fix Sparkle XPC Services for Sandboxed App
# This script copies and configures Sparkle's XPC services for proper sandboxed operation

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

if [[ $# -lt 1 ]]; then
    echo "Usage: $0 <app-path>"
    echo "Example: $0 build/Build/Products/Release/VibeMeter.app"
    exit 1
fi

APP_PATH="$1"
APP_BUNDLE_ID="com.steipete.vibemeter"

echo "🔧 Fixing Sparkle XPC services for sandboxed operation..."

# Create XPCServices directory if it doesn't exist
XPCSERVICES_DIR="$APP_PATH/Contents/XPCServices"
mkdir -p "$XPCSERVICES_DIR"

# Copy Sparkle XPC services from framework to app bundle
SPARKLE_FRAMEWORK="$APP_PATH/Contents/Frameworks/Sparkle.framework"
SPARKLE_XPCSERVICES="$SPARKLE_FRAMEWORK/Versions/B/XPCServices"

if [ ! -d "$SPARKLE_XPCSERVICES" ]; then
    echo "❌ Sparkle XPC services not found in framework"
    exit 1
fi

# Copy Downloader service
if [ -d "$SPARKLE_XPCSERVICES/Downloader.xpc" ]; then
    echo "📋 Copying Downloader.xpc..."
    cp -R "$SPARKLE_XPCSERVICES/Downloader.xpc" "$XPCSERVICES_DIR/com.steipete.vibemeter-spks.xpc"
    
    # Update Info.plist bundle identifier
    /usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier com.steipete.vibemeter-spks" \
        "$XPCSERVICES_DIR/com.steipete.vibemeter-spks.xpc/Contents/Info.plist"
fi

# Copy Installer service
if [ -d "$SPARKLE_XPCSERVICES/Installer.xpc" ]; then
    echo "📋 Copying Installer.xpc..."
    cp -R "$SPARKLE_XPCSERVICES/Installer.xpc" "$XPCSERVICES_DIR/com.steipete.vibemeter-spki.xpc"
    
    # Update Info.plist bundle identifier
    /usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier com.steipete.vibemeter-spki" \
        "$XPCSERVICES_DIR/com.steipete.vibemeter-spki.xpc/Contents/Info.plist"
fi

echo "✅ XPC services copied and configured"

# Create XPC service entitlements
XPC_ENTITLEMENTS=$(mktemp)
cat > "$XPC_ENTITLEMENTS" << 'EOF'
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
    <key>com.apple.security.temporary-exception.mach-register.global-name</key>
    <array>
        <string>com.steipete.vibemeter-spks</string>
        <string>com.steipete.vibemeter-spki</string>
    </array>
</dict>
</plist>
EOF

# Sign the XPC services
echo "🔐 Signing XPC services..."

# Get signing identity
SIGN_IDENTITY="Developer ID Application"

# Sign downloader service
if [ -d "$XPCSERVICES_DIR/com.steipete.vibemeter-spks.xpc" ]; then
    codesign --force --sign "$SIGN_IDENTITY" --options runtime \
        --entitlements "$XPC_ENTITLEMENTS" \
        "$XPCSERVICES_DIR/com.steipete.vibemeter-spks.xpc"
    echo "✅ Signed com.steipete.vibemeter-spks.xpc"
fi

# Sign installer service
if [ -d "$XPCSERVICES_DIR/com.steipete.vibemeter-spki.xpc" ]; then
    codesign --force --sign "$SIGN_IDENTITY" --options runtime \
        --entitlements "$XPC_ENTITLEMENTS" \
        "$XPCSERVICES_DIR/com.steipete.vibemeter-spki.xpc"
    echo "✅ Signed com.steipete.vibemeter-spki.xpc"
fi

# Clean up
rm -f "$XPC_ENTITLEMENTS"

echo ""
echo "🎉 Sparkle XPC services fixed for sandboxed operation!"
echo ""
echo "The XPC services have been:"
echo "  - Copied to the app bundle's XPCServices directory"
echo "  - Renamed with proper bundle identifiers"
echo "  - Signed with sandbox entitlements"
echo ""
echo "⚠️  You'll need to re-sign the entire app bundle after this fix"