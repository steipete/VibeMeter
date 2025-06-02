#!/bin/bash
# codesign-app.sh - Code signing script for VibeMeter

set -euo pipefail

log() {
    echo "[$(date "+%Y-%m-%d %H:%M:%S")] $1"
}

# Default parameters
APP_BUNDLE="${1:-build/Build/Products/Release/VibeMeter.app}"
SIGN_IDENTITY="${2:-Developer ID Application}"

# Validate input
if [ ! -d "$APP_BUNDLE" ]; then
    log "Error: App bundle not found at $APP_BUNDLE"
    log "Usage: $0 <app_path> [signing_identity]"
    exit 1
fi

log "Code signing $APP_BUNDLE with identity: $SIGN_IDENTITY"

# Create entitlements with hardened runtime
ENTITLEMENTS_FILE="VibeMeter/VibeMeter.entitlements"
TMP_ENTITLEMENTS="/tmp/VibeMeter_entitlements.plist"

if [ -f "$ENTITLEMENTS_FILE" ]; then
    log "Using entitlements from $ENTITLEMENTS_FILE"
    cp "$ENTITLEMENTS_FILE" "$TMP_ENTITLEMENTS"
    
    # Ensure hardened runtime is enabled
    if ! grep -q "com.apple.security.hardened-runtime" "$TMP_ENTITLEMENTS"; then
        awk '/<\/dict>/ { print "    <key>com.apple.security.hardened-runtime</key>\n    <true/>"; } { print; }' "$TMP_ENTITLEMENTS" > "${TMP_ENTITLEMENTS}.new"
        mv "${TMP_ENTITLEMENTS}.new" "$TMP_ENTITLEMENTS"
    fi
else
    log "Creating entitlements file with hardened runtime..."
    cat > "$TMP_ENTITLEMENTS" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.app-sandbox</key>
    <true/>
    <key>com.apple.security.hardened-runtime</key>
    <true/>
    <key>com.apple.security.network.client</key>
    <true/>
    <key>com.apple.security.files.user-selected.read-only</key>
    <true/>
</dict>
</plist>
EOF
fi

# Clean up any existing signatures and quarantine attributes
log "Preparing app bundle for signing..."
xattr -cr "$APP_BUNDLE" 2>/dev/null || true

# Sign frameworks first (if any)
if [ -d "$APP_BUNDLE/Contents/Frameworks" ]; then
    log "Signing embedded frameworks..."
    find "$APP_BUNDLE/Contents/Frameworks" \( -type d -name "*.framework" -o -type f -name "*.dylib" \) 2>/dev/null | while read -r framework; do
        log "Signing framework: $framework"
        codesign --force --options runtime --sign "$SIGN_IDENTITY" "$framework" || log "Warning: Failed to sign $framework"
    done
fi

# Sign the main executable
log "Signing main executable..."
codesign --force --options runtime --entitlements "$TMP_ENTITLEMENTS" --sign "$SIGN_IDENTITY" "$APP_BUNDLE/Contents/MacOS/VibeMeter" || true

# Sign the app bundle with deep signing and hardened runtime
log "Signing complete app bundle..."
codesign --force --deep --options runtime --entitlements "$TMP_ENTITLEMENTS" --sign "$SIGN_IDENTITY" "$APP_BUNDLE"

# Verify the signature
log "Verifying code signature..."
if codesign --verify --verbose=2 "$APP_BUNDLE" 2>&1; then
    log "✅ Code signature verification passed"
else
    log "⚠️ Code signature verification had warnings (may be expected in CI)"
fi

# Test with spctl (may fail without proper certificates)
if spctl -a -t exec -vv "$APP_BUNDLE" 2>&1; then
    log "✅ spctl verification passed"
else
    log "⚠️ spctl verification failed (expected without proper Developer ID certificate)"
fi

# Clean up
rm -f "$TMP_ENTITLEMENTS"

log "✅ Code signing completed successfully"