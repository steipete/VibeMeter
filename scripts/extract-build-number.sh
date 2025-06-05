#!/bin/bash
# Extract build number from DMG by mounting and reading Info.plist

set -euo pipefail

if [[ $# -lt 1 ]]; then
    echo "Usage: $0 <dmg-path>"
    exit 1
fi

DMG_PATH="$1"
MOUNT_POINT="/tmp/vibemeter_mount_$$"

# Create mount point
mkdir -p "$MOUNT_POINT"

# Mount DMG quietly
if hdiutil attach "$DMG_PATH" -mountpoint "$MOUNT_POINT" -quiet -nobrowse; then
    # Find the app bundle
    APP_PATH=$(find "$MOUNT_POINT" -name "VibeMeter.app" -maxdepth 1 | head -1)
    
    if [ -n "$APP_PATH" ]; then
        # Extract build number
        BUILD_NUMBER=$(/usr/libexec/PlistBuddy -c "Print CFBundleVersion" "$APP_PATH/Contents/Info.plist" 2>/dev/null || echo "")
        echo "$BUILD_NUMBER"
    fi
    
    # Unmount
    hdiutil detach "$MOUNT_POINT" -quiet || true
else
    echo "" >&2
fi

# Cleanup
rmdir "$MOUNT_POINT" 2>/dev/null || true