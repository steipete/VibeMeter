#!/bin/bash
# notarize-app.sh - Notarization script for VibeMeter

set -euo pipefail

log() {
    echo "[$(date "+%Y-%m-%d %H:%M:%S")] $1"
}

# Default parameters
APP_BUNDLE="${1:-build/Build/Products/Release/VibeMeter.app}"
TIMEOUT_MINUTES=30

# Validate input
if [ ! -d "$APP_BUNDLE" ]; then
    log "Error: App bundle not found at $APP_BUNDLE"
    log "Usage: $0 <app_path>"
    exit 1
fi

log "Notarizing app at: $APP_BUNDLE"

# Check for required environment variables
MISSING_VARS=()
[ -z "${APP_STORE_CONNECT_API_KEY_P8:-}" ] && MISSING_VARS+=("APP_STORE_CONNECT_API_KEY_P8")
[ -z "${APP_STORE_CONNECT_KEY_ID:-}" ] && MISSING_VARS+=("APP_STORE_CONNECT_KEY_ID")
[ -z "${APP_STORE_CONNECT_ISSUER_ID:-}" ] && MISSING_VARS+=("APP_STORE_CONNECT_ISSUER_ID")

if [ ${#MISSING_VARS[@]} -gt 0 ]; then
    log "Error: Missing required environment variables: ${MISSING_VARS[*]}"
    log "Please set these variables in your environment or CI secrets"
    exit 1
fi

# Create temporary P8 key file
API_KEY_FILE="/tmp/AuthKey_${APP_STORE_CONNECT_KEY_ID}.p8"
echo "$APP_STORE_CONNECT_API_KEY_P8" > "$API_KEY_FILE"

# Cleanup function
cleanup() {
    rm -f "$API_KEY_FILE" "/tmp/VibeMeter_notarize.zip"
}
trap cleanup EXIT

# Check if notarytool is available
if ! xcrun --find notarytool &> /dev/null; then
    log "Error: notarytool not found. Please ensure Xcode 13+ is installed"
    exit 1
fi

log "Using modern notarytool for notarization"

# Create ZIP for notarization
ZIP_PATH="/tmp/VibeMeter_notarize.zip"
log "Creating ZIP archive for notarization..."
if ! ditto -c -k --keepParent "$APP_BUNDLE" "$ZIP_PATH"; then
    log "Error: Failed to create ZIP archive"
    exit 1
fi

# Submit for notarization using notarytool
log "Submitting app for notarization..."
SUBMIT_CMD="xcrun notarytool submit \"$ZIP_PATH\" --key \"$API_KEY_FILE\" --key-id \"$APP_STORE_CONNECT_KEY_ID\" --issuer \"$APP_STORE_CONNECT_ISSUER_ID\" --wait --timeout ${TIMEOUT_MINUTES}m"

# Run submission with timeout
if ! eval "$SUBMIT_CMD"; then
    log "Error: Notarization submission failed"
    exit 1
fi

log "✅ Notarization completed successfully"

# Staple the notarization ticket
log "Stapling notarization ticket to app bundle..."
if ! xcrun stapler staple "$APP_BUNDLE"; then
    log "Error: Failed to staple notarization ticket"
    exit 1
fi

# Verify the stapling
log "Verifying stapled notarization ticket..."
if ! xcrun stapler validate "$APP_BUNDLE"; then
    log "Error: Failed to verify stapled ticket"
    exit 1
fi

# Test with spctl to ensure it passes Gatekeeper
log "Testing with spctl (Gatekeeper)..."
if spctl -a -t exec -vv "$APP_BUNDLE" 2>&1; then
    log "✅ spctl verification passed - app will run without warnings"
else
    log "⚠️ spctl verification failed - app may show security warnings"
fi

log "✅ Notarization and stapling completed successfully"