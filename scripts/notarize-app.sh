#!/bin/bash
# notarize-app.sh - Complete notarization script for VibeMeter with Sparkle
# Handles hardened runtime, proper signing of all components, and notarization

set -eo pipefail

# ============================================================================
# Configuration
# ============================================================================

log() {
    echo "[$(date "+%Y-%m-%d %H:%M:%S")] $1"
}

error() {
    echo "[$(date "+%Y-%m-%d %H:%M:%S")] ❌ ERROR: $1" >&2
    exit 1
}

success() {
    echo "[$(date "+%Y-%m-%d %H:%M:%S")] ✅ $1"
}

APP_BUNDLE="${1:-build/Build/Products/Release/VibeMeter.app}"
SIGN_IDENTITY="Developer ID Application: Peter Steinberger (Y5PE65HELJ)"
TIMEOUT_MINUTES=30

# Check if app bundle exists
if [ ! -d "$APP_BUNDLE" ]; then
    error "App bundle not found at $APP_BUNDLE"
fi

log "Starting complete notarization process for $APP_BUNDLE"

# Check required environment variables for notarization
if [ -z "$APP_STORE_CONNECT_API_KEY_P8" ] || [ -z "$APP_STORE_CONNECT_KEY_ID" ] || [ -z "$APP_STORE_CONNECT_ISSUER_ID" ]; then
    error "Required environment variables not set. Need APP_STORE_CONNECT_API_KEY_P8, APP_STORE_CONNECT_KEY_ID, APP_STORE_CONNECT_ISSUER_ID"
fi

# Create temporary API key file
API_KEY_FILE=$(mktemp)
echo "$APP_STORE_CONNECT_API_KEY_P8" > "$API_KEY_FILE"

cleanup() {
    rm -f "$API_KEY_FILE" "/tmp/VibeMeter_notarize.zip"
}
trap cleanup EXIT

# ============================================================================
# Create Entitlements Files
# ============================================================================

create_entitlements() {
    local entitlements_file="$1"
    local is_xpc_service="$2"
    
    cat > "$entitlements_file" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.cs.allow-jit</key>
    <false/>
    <key>com.apple.security.cs.allow-unsigned-executable-memory</key>
    <false/>
    <key>com.apple.security.cs.disable-executable-page-protection</key>
    <false/>
    <key>com.apple.security.cs.disable-library-validation</key>
    <false/>
    <key>com.apple.security.hardened-runtime</key>
    <true/>
EOF

    if [ "$is_xpc_service" = "true" ]; then
        cat >> "$entitlements_file" << 'EOF'
    <key>com.apple.security.app-sandbox</key>
    <true/>
    <key>com.apple.security.files.user-selected.read-write</key>
    <true/>
EOF
    fi

    cat >> "$entitlements_file" << 'EOF'
</dict>
</plist>
EOF
}

# Create entitlements files
MAIN_ENTITLEMENTS="/tmp/main_entitlements.plist"
XPC_ENTITLEMENTS="/tmp/xpc_entitlements.plist"

create_entitlements "$MAIN_ENTITLEMENTS" "false"
create_entitlements "$XPC_ENTITLEMENTS" "true"

# ============================================================================
# Signing Functions
# ============================================================================

sign_binary() {
    local binary="$1"
    local entitlements="$2"
    local description="$3"
    
    log "Signing $description: $(basename "$binary")"
    
    # Add keychain option if available
    keychain_opts=""
    if [ -n "${KEYCHAIN_NAME:-}" ]; then
        keychain_opts="--keychain $KEYCHAIN_NAME"
    fi
    
    codesign \
        --force \
        --sign "$SIGN_IDENTITY" \
        --entitlements "$entitlements" \
        --options runtime \
        --timestamp \
        $keychain_opts \
        "$binary"
}

sign_app_bundle() {
    local bundle="$1"
    local entitlements="$2"
    local description="$3"
    
    log "Signing $description: $(basename "$bundle")"
    
    # Add keychain option if available
    keychain_opts=""
    if [ -n "${KEYCHAIN_NAME:-}" ]; then
        keychain_opts="--keychain $KEYCHAIN_NAME"
    fi
    
    codesign \
        --force \
        --sign "$SIGN_IDENTITY" \
        --entitlements "$entitlements" \
        --options runtime \
        --timestamp \
        $keychain_opts \
        "$bundle"
}

# ============================================================================
# Deep Signing Process
# ============================================================================

log "Performing deep signing with proper Sparkle framework handling..."

# 1. Sign XPC services first (they need special entitlements)
log "Signing XPC services..."
find "$APP_BUNDLE/Contents" -name "*.xpc" -type d | while read xpc; do
    if [ -f "$xpc/Contents/MacOS/"* ]; then
        executable=$(find "$xpc/Contents/MacOS" -type f -perm +111 | head -1)
        if [ -n "$executable" ]; then
            sign_binary "$executable" "$XPC_ENTITLEMENTS" "XPC service executable"
        fi
    fi
    sign_app_bundle "$xpc" "$XPC_ENTITLEMENTS" "XPC service bundle"
done

# 2. Handle Sparkle framework with comprehensive signing
SPARKLE_FRAMEWORK="$APP_BUNDLE/Contents/Frameworks/Sparkle.framework"
if [ -d "$SPARKLE_FRAMEWORK" ]; then
    log "Found Sparkle framework, performing comprehensive signing..."
    
    # Sign XPC services in Sparkle
    find "$SPARKLE_FRAMEWORK" -name "*.xpc" -type d | while read xpc; do
        if [ -f "$xpc/Contents/MacOS/"* ]; then
            executable=$(find "$xpc/Contents/MacOS" -type f -perm +111 | head -1)
            if [ -n "$executable" ]; then
                sign_binary "$executable" "$XPC_ENTITLEMENTS" "Sparkle XPC executable"
            fi
        fi
        sign_app_bundle "$xpc" "$XPC_ENTITLEMENTS" "Sparkle XPC service"
    done
    
    # Sign standalone executables in Sparkle
    find "$SPARKLE_FRAMEWORK" -type f -perm +111 -not -path "*/MacOS/*" -not -path "*/XPCServices/*" | while read executable; do
        sign_binary "$executable" "$MAIN_ENTITLEMENTS" "Sparkle executable"
    done
    
    # Sign nested app bundles in Sparkle
    find "$SPARKLE_FRAMEWORK" -name "*.app" -type d | while read app; do
        if [ -f "$app/Contents/MacOS/"* ]; then
            executable=$(find "$app/Contents/MacOS" -type f -perm +111 | head -1)
            if [ -n "$executable" ]; then
                sign_binary "$executable" "$MAIN_ENTITLEMENTS" "Sparkle app executable"
            fi
        fi
        sign_app_bundle "$app" "$MAIN_ENTITLEMENTS" "Sparkle app bundle"
    done
    
    # Sign the main Sparkle framework binary
    if [ -f "$SPARKLE_FRAMEWORK/Sparkle" ]; then
        sign_binary "$SPARKLE_FRAMEWORK/Sparkle" "$MAIN_ENTITLEMENTS" "Sparkle framework binary"
    fi
    
    # Sign the framework bundle
    log "Signing Sparkle framework bundle..."
    keychain_opts=""
    if [ -n "${KEYCHAIN_NAME:-}" ]; then
        keychain_opts="--keychain $KEYCHAIN_NAME"
    fi
    
    codesign \
        --force \
        --sign "$SIGN_IDENTITY" \
        --options runtime \
        --timestamp \
        $keychain_opts \
        "$SPARKLE_FRAMEWORK"
fi

# 3. Sign other frameworks
log "Signing other frameworks..."
find "$APP_BUNDLE/Contents/Frameworks" -name "*.framework" -not -path "*Sparkle*" -type d | while read framework; do
    framework_binary="$framework/$(basename "$framework" .framework)"
    if [ -f "$framework_binary" ]; then
        sign_binary "$framework_binary" "$MAIN_ENTITLEMENTS" "Framework binary"
    fi
    
    keychain_opts=""
    if [ -n "${KEYCHAIN_NAME:-}" ]; then
        keychain_opts="--keychain $KEYCHAIN_NAME"
    fi
    
    codesign \
        --force \
        --sign "$SIGN_IDENTITY" \
        --options runtime \
        --timestamp \
        $keychain_opts \
        "$framework"
done

# 4. Sign helper tools and executables
log "Signing helper tools..."
find "$APP_BUNDLE/Contents" -type f -perm +111 -not -path "*/MacOS/*" -not -path "*/Frameworks/*" | while read executable; do
    sign_binary "$executable" "$MAIN_ENTITLEMENTS" "Helper executable"
done

# 5. Finally, sign the main app bundle
log "Signing main app bundle..."
keychain_opts=""
if [ -n "${KEYCHAIN_NAME:-}" ]; then
    keychain_opts="--keychain $KEYCHAIN_NAME"
fi

codesign \
    --force \
    --sign "$SIGN_IDENTITY" \
    --entitlements "$MAIN_ENTITLEMENTS" \
    --options runtime \
    --timestamp \
    $keychain_opts \
    "$APP_BUNDLE"

# ============================================================================
# Notarization
# ============================================================================

# Check if notarytool is available
if ! xcrun --find notarytool &> /dev/null; then
    error "notarytool not found. Please ensure Xcode 13+ is installed"
fi

log "Using modern notarytool for notarization"

# Create ZIP for notarization
ZIP_PATH="/tmp/VibeMeter_notarize.zip"
log "Creating ZIP archive for notarization..."
if ! ditto -c -k --keepParent "$APP_BUNDLE" "$ZIP_PATH"; then
    error "Failed to create ZIP archive"
fi

# Submit for notarization using notarytool
log "Submitting app for notarization..."
SUBMIT_CMD="xcrun notarytool submit \"$ZIP_PATH\" --key \"$API_KEY_FILE\" --key-id \"$APP_STORE_CONNECT_KEY_ID\" --issuer \"$APP_STORE_CONNECT_ISSUER_ID\" --wait --timeout ${TIMEOUT_MINUTES}m"

# Run submission with timeout
if ! eval "$SUBMIT_CMD"; then
    error "Notarization submission failed"
fi

success "Notarization completed successfully"

# Staple the notarization ticket
log "Stapling notarization ticket to app bundle..."
if ! xcrun stapler staple "$APP_BUNDLE"; then
    error "Failed to staple notarization ticket"
fi

# Verify the stapling
log "Verifying stapled notarization ticket..."
if ! xcrun stapler validate "$APP_BUNDLE"; then
    error "Failed to verify stapled ticket"
fi

# Test with spctl to ensure it passes Gatekeeper
log "Testing with spctl (Gatekeeper)..."
if spctl -a -t exec -vv "$APP_BUNDLE" 2>&1; then
    success "spctl verification passed - app will run without warnings"
else
    log "⚠️ spctl verification failed - app may show security warnings"
fi

success "Notarization and stapling completed successfully"

# Clean up temporary files
rm -f "$MAIN_ENTITLEMENTS" "$XPC_ENTITLEMENTS"