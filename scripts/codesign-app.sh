#!/bin/bash

set -euo pipefail

# Script to code sign VibeMeter app
# Usage: ./scripts/codesign-app.sh <app_path>

if [[ $# -ne 1 ]]; then
    echo "Usage: $0 <app_path>"
    exit 1
fi

APP_PATH="$1"

if [[ ! -d "$APP_PATH" ]]; then
    echo "Error: App not found at $APP_PATH"
    exit 1
fi

echo "Code signing app at: $APP_PATH"

# Function to sign a single item
sign_item() {
    local item="$1"
    echo "Signing: $item"
    codesign \
        --force \
        --deep \
        --sign "$SIGNING_IDENTITY" \
        --options runtime \
        --timestamp \
        "$item"
}

# Setup signing identity
if [[ -n "${MACOS_SIGNING_CERTIFICATE_P12_BASE64:-}" ]]; then
    echo "Setting up CI signing environment..."
    
    # Decode certificate
    P12_FILE="/tmp/signing_certificate.p12"
    echo "$MACOS_SIGNING_CERTIFICATE_P12_BASE64" | base64 -d > "$P12_FILE"
    
    # Create temporary keychain
    KEYCHAIN_NAME="signing-temp.keychain-db"
    KEYCHAIN_PASSWORD="$(openssl rand -base64 32)"
    
    security create-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN_NAME"
    security set-keychain-settings -lut 21600 "$KEYCHAIN_NAME"
    security unlock-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN_NAME"
    
    # Import certificate
    security import "$P12_FILE" \
        -P "$MACOS_SIGNING_CERTIFICATE_PASSWORD" \
        -A \
        -t cert \
        -f pkcs12 \
        -k "$KEYCHAIN_NAME"
    
    # Set keychain access
    security list-keychain -d user -s "$KEYCHAIN_NAME" $(security list-keychains -d user | sed 's/"//g')
    security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "$KEYCHAIN_PASSWORD" "$KEYCHAIN_NAME"
    
    # Find signing identity
    SIGNING_IDENTITY=$(security find-identity -v -p codesigning "$KEYCHAIN_NAME" | grep "Developer ID Application" | head -1 | awk '{print $2}')
    
    # Cleanup
    rm -f "$P12_FILE"
    
    # Cleanup function
    cleanup() {
        if [[ -n "${KEYCHAIN_NAME:-}" ]]; then
            security delete-keychain "$KEYCHAIN_NAME" 2>/dev/null || true
        fi
    }
    trap cleanup EXIT
    
elif [[ -n "${MACOS_SIGNING_P12_FILE_PATH:-}" ]]; then
    echo "Using local P12 file for signing..."
    
    # Create temporary keychain for local signing
    KEYCHAIN_NAME="signing-temp.keychain-db"
    KEYCHAIN_PASSWORD="$(openssl rand -base64 32)"
    
    security create-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN_NAME"
    security set-keychain-settings -lut 21600 "$KEYCHAIN_NAME"
    security unlock-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN_NAME"
    
    # Import certificate
    security import "$MACOS_SIGNING_P12_FILE_PATH" \
        -P "$MACOS_SIGNING_CERTIFICATE_PASSWORD" \
        -A \
        -t cert \
        -f pkcs12 \
        -k "$KEYCHAIN_NAME"
    
    # Set keychain access
    security list-keychain -d user -s "$KEYCHAIN_NAME" $(security list-keychains -d user | sed 's/"//g')
    security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "$KEYCHAIN_PASSWORD" "$KEYCHAIN_NAME"
    
    # Find signing identity
    SIGNING_IDENTITY=$(security find-identity -v -p codesigning "$KEYCHAIN_NAME" | grep "Developer ID Application" | head -1 | awk '{print $2}')
    
    # Cleanup function
    cleanup() {
        if [[ -n "${KEYCHAIN_NAME:-}" ]]; then
            security delete-keychain "$KEYCHAIN_NAME" 2>/dev/null || true
        fi
    }
    trap cleanup EXIT
    
else
    echo "Using system keychain for signing..."
    # Find signing identity in system keychain
    SIGNING_IDENTITY=$(security find-identity -v -p codesigning | grep "Developer ID Application" | head -1 | awk '{print $2}')
fi

if [[ -z "$SIGNING_IDENTITY" ]]; then
    echo "Error: No signing identity found"
    exit 1
fi

echo "Using signing identity: $SIGNING_IDENTITY"

# Remove existing signatures
echo "Removing existing signatures..."
find "$APP_PATH" -type f -name "*.dylib" -o -name "*.framework" | while read -r item; do
    codesign --remove-signature "$item" 2>/dev/null || true
done

# Sign embedded frameworks and dylibs first
echo "Signing embedded frameworks and libraries..."
find "$APP_PATH/Contents/Frameworks" -name "*.framework" -o -name "*.dylib" 2>/dev/null | while read -r item; do
    sign_item "$item"
done

# Sign helpers and tools
echo "Signing embedded helpers..."
find "$APP_PATH/Contents/MacOS" -type f ! -name "VibeMeter" 2>/dev/null | while read -r item; do
    if [[ -x "$item" ]]; then
        sign_item "$item"
    fi
done

# Sign the main app
echo "Signing main application..."
codesign \
    --force \
    --deep \
    --sign "$SIGNING_IDENTITY" \
    --options runtime \
    --timestamp \
    --entitlements "$APP_PATH/Contents/Info.plist" \
    "$APP_PATH"

# Verify signature
echo "Verifying signature..."
codesign --verify --deep --strict "$APP_PATH"
spctl -a -t exec -vv "$APP_PATH"

echo "Code signing complete!"