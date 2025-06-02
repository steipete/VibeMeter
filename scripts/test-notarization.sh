#!/bin/bash

set -euo pipefail

# Script to test notarization setup locally
# Usage: ./scripts/test-notarization.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo "Testing VibeMeter notarization setup..."
echo "======================================="

# Check for required tools
echo "Checking required tools..."
command -v xcodebuild >/dev/null 2>&1 || { echo "Error: xcodebuild not found"; exit 1; }
command -v codesign >/dev/null 2>&1 || { echo "Error: codesign not found"; exit 1; }
command -v xcrun >/dev/null 2>&1 || { echo "Error: xcrun not found"; exit 1; }
echo "✓ All required tools found"

# Check for signing identity
echo -e "\nChecking code signing identity..."
SIGNING_IDENTITY=$(security find-identity -v -p codesigning | grep "Developer ID Application" | head -1 | awk '{print $2}')
if [[ -z "$SIGNING_IDENTITY" ]]; then
    echo "✗ No Developer ID Application certificate found"
    echo "  Please install your Developer ID certificate in Keychain"
    exit 1
else
    echo "✓ Found signing identity: $SIGNING_IDENTITY"
fi

# Check for notarization credentials
echo -e "\nChecking notarization credentials..."
MISSING_VARS=()

if [[ -z "${APP_STORE_CONNECT_API_KEY_P8:-}" ]] && [[ -z "${APP_STORE_CONNECT_P8_FILE_PATH:-}" ]]; then
    MISSING_VARS+=("APP_STORE_CONNECT_API_KEY_P8 or APP_STORE_CONNECT_P8_FILE_PATH")
fi

if [[ -z "${APP_STORE_CONNECT_KEY_ID:-}" ]]; then
    MISSING_VARS+=("APP_STORE_CONNECT_KEY_ID")
fi

if [[ -z "${APP_STORE_CONNECT_ISSUER_ID:-}" ]]; then
    MISSING_VARS+=("APP_STORE_CONNECT_ISSUER_ID")
fi

if [[ ${#MISSING_VARS[@]} -gt 0 ]]; then
    echo "✗ Missing environment variables:"
    for var in "${MISSING_VARS[@]}"; do
        echo "  - $var"
    done
    echo -e "\nTo set up notarization credentials:"
    echo "  export APP_STORE_CONNECT_API_KEY_P8=\"\$(cat ~/path/to/AuthKey_XXXXXXXXXX.p8)\""
    echo "  export APP_STORE_CONNECT_KEY_ID=\"XXXXXXXXXX\""
    echo "  export APP_STORE_CONNECT_ISSUER_ID=\"xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx\""
    exit 1
else
    echo "✓ All notarization credentials found"
fi

# Test build
echo -e "\nTesting build process..."
if [[ -f "$PROJECT_DIR/scripts/build.sh" ]]; then
    "$PROJECT_DIR/scripts/build.sh" --configuration Release --sign
    echo "✓ Build completed successfully"
else
    echo "✗ Build script not found"
    exit 1
fi

# Check built app
APP_PATH="$PROJECT_DIR/build/Build/Products/Release/VibeMeter.app"
if [[ ! -d "$APP_PATH" ]]; then
    echo "✗ Built app not found at expected location"
    exit 1
fi

# Verify code signature
echo -e "\nVerifying code signature..."
if codesign --verify --deep --strict "$APP_PATH" 2>&1; then
    echo "✓ Code signature valid"
else
    echo "✗ Code signature invalid"
    exit 1
fi

# Check hardened runtime
echo -e "\nChecking hardened runtime..."
if codesign -d --verbose "$APP_PATH" 2>&1 | grep -q "flags=.*runtime"; then
    echo "✓ Hardened runtime enabled"
else
    echo "✗ Hardened runtime not enabled"
    exit 1
fi

# Test notarization (dry run)
echo -e "\nTesting notarization process..."
echo "This will submit the app to Apple for notarization."
read -p "Continue? (y/N) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    if [[ -f "$PROJECT_DIR/scripts/notarize-app.sh" ]]; then
        "$PROJECT_DIR/scripts/notarize-app.sh" "$APP_PATH"
        echo "✓ Notarization completed successfully"
    else
        echo "✗ Notarization script not found"
        exit 1
    fi
else
    echo "⚠ Skipping notarization test"
fi

echo -e "\n======================================="
echo "All tests completed successfully!"
echo "Your setup is ready for CI/CD."