#!/bin/bash

# =============================================================================
# VibeMeter Build Script
# =============================================================================
# 
# This script builds the VibeMeter application using xcodebuild with optional
# code signing support. It includes comprehensive error checking and reports
# build details including the IS_PRERELEASE_BUILD flag status.
#
# USAGE:
#   ./scripts/build.sh [--configuration Debug|Release] [--sign]
#
# ARGUMENTS:
#   --configuration <Debug|Release>  Build configuration (default: Release)
#   --sign                          Sign the app after building (requires cert)
#
# ENVIRONMENT VARIABLES:
#   IS_PRERELEASE_BUILD=YES|NO      Sets pre-release flag in Info.plist
#   MACOS_SIGNING_CERTIFICATE_P12_BASE64  CI certificate for signing
#
# OUTPUTS:
#   - Built app at: build/Build/Products/<Configuration>/VibeMeter.app
#   - Version and build number information
#   - IS_PRERELEASE_BUILD flag status verification
#
# DEPENDENCIES:
#   - Xcode and command line tools
#   - xcbeautify (optional, for prettier output)
#   - Generated Xcode project (run generate-xcproj.sh first)
#
# EXAMPLES:
#   ./scripts/build.sh                           # Release build
#   ./scripts/build.sh --configuration Debug     # Debug build
#   ./scripts/build.sh --sign                    # Release build with signing
#   IS_PRERELEASE_BUILD=YES ./scripts/build.sh   # Beta build
#
# =============================================================================

set -euo pipefail

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

# Use CI-specific configuration if in CI environment
XCCONFIG_ARG=""
if [[ "${CI:-false}" == "true" ]] && [[ -f "$PROJECT_DIR/.xcode-ci-config.xcconfig" ]]; then
    echo "Using CI-specific build configuration"
    XCCONFIG_ARG="-xcconfig $PROJECT_DIR/.xcode-ci-config.xcconfig"
fi

# Check if xcbeautify is available
if command -v xcbeautify &> /dev/null; then
    echo "🔨 Building with xcbeautify..."
    xcodebuild \
        -workspace VibeMeter.xcworkspace \
        -scheme VibeMeter \
        -configuration "$CONFIGURATION" \
        -derivedDataPath "$BUILD_DIR" \
        -destination "platform=macOS" \
        $XCCONFIG_ARG \
        build | xcbeautify
else
    echo "🔨 Building (install xcbeautify for cleaner output)..."
    xcodebuild \
        -workspace VibeMeter.xcworkspace \
        -scheme VibeMeter \
        -configuration "$CONFIGURATION" \
        -derivedDataPath "$BUILD_DIR" \
        -destination "platform=macOS" \
        $XCCONFIG_ARG \
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