#!/bin/bash

set -euo pipefail

# Script to create a DMG for VibeMeter
# Usage: ./scripts/create-dmg.sh <app_path> [output_path]

if [[ $# -lt 1 ]] || [[ $# -gt 2 ]]; then
    echo "Usage: $0 <app_path> [output_path]"
    exit 1
fi

APP_PATH="$1"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$PROJECT_DIR/build"

if [[ ! -d "$APP_PATH" ]]; then
    echo "Error: App not found at $APP_PATH"
    exit 1
fi

# Get version info
VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$APP_PATH/Contents/Info.plist")
DMG_NAME="VibeMeter-${VERSION}.dmg"

# Use provided output path or default
if [[ $# -eq 2 ]]; then
    DMG_PATH="$2"
else
    DMG_PATH="$BUILD_DIR/$DMG_NAME"
fi

echo "Creating DMG: $DMG_NAME"

# Create temporary directory for DMG contents
DMG_TEMP="$BUILD_DIR/dmg-temp"
rm -rf "$DMG_TEMP"
mkdir -p "$DMG_TEMP"

# Copy app to temporary directory
cp -R "$APP_PATH" "$DMG_TEMP/"

# Create symbolic link to Applications folder
ln -s /Applications "$DMG_TEMP/Applications"

# Create DMG
hdiutil create \
    -volname "VibeMeter" \
    -srcfolder "$DMG_TEMP" \
    -ov \
    -format UDZO \
    "$DMG_PATH"

# Clean up
rm -rf "$DMG_TEMP"

# === EXTENSIVE ENVIRONMENT DEBUGGING ===
echo "=== Environment Debug Information ==="
echo "Current working directory: $(pwd)"
echo "User: $(whoami)"
echo "Date: $(date)"
echo "Environment variables related to signing:"
echo "  KEYCHAIN_NAME=${KEYCHAIN_NAME:-<not set>}"
echo "  SIGN_IDENTITY=${SIGN_IDENTITY:-<not set>}"
echo "  RUNNER_TEMP=${RUNNER_TEMP:-<not set>}"
echo "  GITHUB_ACTIONS=${GITHUB_ACTIONS:-<not set>}"
echo "  CI=${CI:-<not set>}"

# Check if secrets are available (without exposing their values)
echo "GitHub Secrets Status:"
echo "  APP_STORE_CONNECT_API_KEY_P8: ${APP_STORE_CONNECT_API_KEY_P8:+SET}" 
echo "  APP_STORE_CONNECT_ISSUER_ID: ${APP_STORE_CONNECT_ISSUER_ID:+SET}"
echo "  APP_STORE_CONNECT_KEY_ID: ${APP_STORE_CONNECT_KEY_ID:+SET}"
echo "  MACOS_SIGNING_CERTIFICATE_P12_BASE64: ${MACOS_SIGNING_CERTIFICATE_P12_BASE64:+SET}"
echo "  MACOS_SIGNING_CERTIFICATE_PASSWORD: ${MACOS_SIGNING_CERTIFICATE_PASSWORD:+SET}"

# List all keychains
echo "=== Keychain Information ==="
echo "Available keychains:"
security list-keychains -d user || echo "Failed to list user keychains"
security list-keychains -d system || echo "Failed to list system keychains"

echo ""
echo "Default keychain:"
security default-keychain -d user || echo "Failed to get default user keychain"

# Check if specific keychain exists
if [ -n "${KEYCHAIN_NAME:-}" ]; then
    echo ""
    echo "Checking for specified keychain: $KEYCHAIN_NAME"
    if security list-keychains -d user | grep -q "$KEYCHAIN_NAME"; then
        echo "✅ Keychain $KEYCHAIN_NAME found in user domain"
    else
        echo "❌ Keychain $KEYCHAIN_NAME NOT found in user domain"
    fi
    
    # Try to unlock the keychain if it exists
    if [ -f "$KEYCHAIN_NAME" ]; then
        echo "Keychain file exists at: $KEYCHAIN_NAME"
        echo "Checking keychain lock status..."
        security show-keychain-info "$KEYCHAIN_NAME" 2>&1 || echo "Cannot get keychain info"
    else
        echo "Keychain file does not exist at: $KEYCHAIN_NAME"
    fi
fi

# === SIGNING IDENTITY ANALYSIS ===
echo ""
echo "=== Signing Identity Analysis ==="

# Sign the DMG if signing credentials are available
if command -v codesign &> /dev/null; then
    echo "✅ codesign command is available"
    
    # Use the same signing identity as the app signing process
    SIGN_IDENTITY="${SIGN_IDENTITY:-Developer ID Application}"
    echo "Target signing identity: '$SIGN_IDENTITY'"
    
    # Check if we're in CI and have a specific keychain
    KEYCHAIN_OPTS=""
    if [ -n "${KEYCHAIN_NAME:-}" ]; then
        echo "Using keychain: $KEYCHAIN_NAME"
        KEYCHAIN_OPTS="--keychain $KEYCHAIN_NAME"
    else
        echo "No specific keychain specified, using default"
    fi
    
    # Try to find a valid signing identity
    IDENTITY_CHECK_CMD="security find-identity -v -p codesigning"
    if [ -n "${KEYCHAIN_NAME:-}" ]; then
        IDENTITY_CHECK_CMD="$IDENTITY_CHECK_CMD $KEYCHAIN_NAME"
        echo "Full identity check command: $IDENTITY_CHECK_CMD"
    fi
    
    echo ""
    echo "=== Full Identity Check Output ==="
    echo "Running: $IDENTITY_CHECK_CMD"
    IDENTITY_OUTPUT=$($IDENTITY_CHECK_CMD 2>&1) || true
    echo "Raw output:"
    echo "$IDENTITY_OUTPUT"
    echo "=== End Identity Check Output ==="
    
    # Count valid identities
    VALID_COUNT=$(echo "$IDENTITY_OUTPUT" | grep -c "valid identities found" || echo "0")
    echo "Valid identities found: $VALID_COUNT"
    
    # Check if any signing identity is available
    if echo "$IDENTITY_OUTPUT" | grep -q "valid identities found" && ! echo "$IDENTITY_OUTPUT" | grep -q "0 valid identities found"; then
        echo "✅ At least one valid signing identity found"
        
        # Show all identities
        echo "All available identities:"
        echo "$IDENTITY_OUTPUT" | grep -E "^\s*[0-9]+\)"
        
        # Check if our specific identity exists
        if echo "$IDENTITY_OUTPUT" | grep -q "$SIGN_IDENTITY"; then
            echo "✅ Found specific identity: $SIGN_IDENTITY"
            echo "Attempting to sign DMG with identity: $SIGN_IDENTITY"
            echo "Command: codesign --force --sign \"$SIGN_IDENTITY\" $KEYCHAIN_OPTS \"$DMG_PATH\""
            if codesign --force --sign "$SIGN_IDENTITY" $KEYCHAIN_OPTS "$DMG_PATH"; then
                echo "✅ DMG signing successful"
            else
                echo "❌ DMG signing failed"
                exit 1
            fi
        else
            echo "❌ Specific identity '$SIGN_IDENTITY' not found"
            
            # Try to use the first available Developer ID Application identity
            echo "Searching for any Developer ID Application identity..."
            AVAILABLE_IDENTITY=$(echo "$IDENTITY_OUTPUT" | grep "Developer ID Application" | head -1 | sed -E 's/.*"([^"]+)".*/\1/' || echo "")
            if [ -n "$AVAILABLE_IDENTITY" ]; then
                echo "✅ Found alternative identity: $AVAILABLE_IDENTITY"
                echo "Command: codesign --force --sign \"$AVAILABLE_IDENTITY\" $KEYCHAIN_OPTS \"$DMG_PATH\""
                if codesign --force --sign "$AVAILABLE_IDENTITY" $KEYCHAIN_OPTS "$DMG_PATH"; then
                    echo "✅ DMG signing successful with alternative identity"
                else
                    echo "❌ DMG signing failed with alternative identity"
                    exit 1
                fi
            else
                echo "❌ No Developer ID Application identity found"
                echo "⚠️ DMG will not be signed"
            fi
        fi
    else
        echo "❌ No valid signing identities available"
        echo "⚠️ DMG will not be signed"
        echo "This is expected for PR builds where certificates are not imported"
    fi
else
    echo "❌ codesign command not available"
    echo "⚠️ DMG will not be signed"
fi

echo "=== End Environment Debug Information ==="

# Verify DMG
echo "Verifying DMG..."
hdiutil verify "$DMG_PATH"

echo "DMG created successfully: $DMG_PATH"