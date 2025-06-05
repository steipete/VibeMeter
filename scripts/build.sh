#!/bin/bash

set -euo pipefail

# Script to build VibeMeter
# Usage: ./scripts/build.sh [--configuration Debug|Release] [--sign]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$PROJECT_DIR/build"

# Default values
CONFIGURATION="Release"
SIGN_APP=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --configuration)
            CONFIGURATION="$2"
            shift 2
            ;;
        --sign)
            SIGN_APP=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 [--configuration Debug|Release] [--sign]"
            exit 1
            ;;
    esac
done

echo "Building VibeMeter..."
echo "Configuration: $CONFIGURATION"
echo "Code signing: $SIGN_APP"

# Clean build directory only if it doesn't exist
mkdir -p "$BUILD_DIR"

# Build the app
cd "$PROJECT_DIR"

# Check if xcbeautify is available
if command -v xcbeautify &> /dev/null; then
    echo "🔨 Building with xcbeautify..."
    xcodebuild \
        -workspace VibeMeter.xcworkspace \
        -scheme VibeMeter \
        -configuration "$CONFIGURATION" \
        -derivedDataPath "$BUILD_DIR" \
        -destination "platform=macOS" \
        build | xcbeautify
else
    echo "🔨 Building (install xcbeautify for cleaner output)..."
    xcodebuild \
        -workspace VibeMeter.xcworkspace \
        -scheme VibeMeter \
        -configuration "$CONFIGURATION" \
        -derivedDataPath "$BUILD_DIR" \
        -destination "platform=macOS" \
        build
fi

APP_PATH="$BUILD_DIR/Build/Products/$CONFIGURATION/VibeMeter.app"

if [[ ! -d "$APP_PATH" ]]; then
    echo "Error: Build failed - app not found at $APP_PATH"
    exit 1
fi

# Sparkle sandbox fix is no longer needed - we use default XPC services
# The fix-sparkle-sandbox.sh script now just verifies configuration
if [[ "$CONFIGURATION" == "Release" ]]; then
    if [ -x "$SCRIPT_DIR/fix-sparkle-sandbox.sh" ]; then
        echo "Verifying Sparkle configuration..."
        "$SCRIPT_DIR/fix-sparkle-sandbox.sh" "$APP_PATH"
    fi
fi

# Sign the app if requested
if [[ "$SIGN_APP" == true ]]; then
    if [[ -n "${MACOS_SIGNING_CERTIFICATE_P12_BASE64:-}" ]]; then
        echo "Signing app with CI certificate..."
        "$SCRIPT_DIR/codesign-app.sh" "$APP_PATH"
    else
        echo "Warning: Signing requested but no certificate configured"
    fi
fi

echo "Build complete: $APP_PATH"

# Print version info
VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$APP_PATH/Contents/Info.plist")
BUILD=$(/usr/libexec/PlistBuddy -c "Print CFBundleVersion" "$APP_PATH/Contents/Info.plist")
echo "Version: $VERSION ($BUILD)"

# Verify IS_PRERELEASE_BUILD flag
PRERELEASE_FLAG=$(/usr/libexec/PlistBuddy -c "Print IS_PRERELEASE_BUILD" "$APP_PATH/Contents/Info.plist" 2>/dev/null || echo "not found")
if [[ "$PRERELEASE_FLAG" != "not found" ]]; then
    if [[ "$PRERELEASE_FLAG" == "YES" ]]; then
        echo "✓ IS_PRERELEASE_BUILD: YES (pre-release build)"
    elif [[ "$PRERELEASE_FLAG" == "NO" ]]; then
        echo "✓ IS_PRERELEASE_BUILD: NO (stable build)"
    else
        echo "⚠ IS_PRERELEASE_BUILD: '$PRERELEASE_FLAG' (unexpected value)"
    fi
else
    echo "⚠ IS_PRERELEASE_BUILD: not set (will use version string fallback)"
fi