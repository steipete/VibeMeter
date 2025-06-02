#!/bin/bash

set -euo pipefail

# Script to notarize VibeMeter app
# Usage: ./scripts/notarize-app.sh <app_path>

if [[ $# -ne 1 ]]; then
    echo "Usage: $0 <app_path>"
    exit 1
fi

APP_PATH="$1"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ ! -d "$APP_PATH" ]]; then
    echo "Error: App not found at $APP_PATH"
    exit 1
fi

echo "Notarizing app at: $APP_PATH"

# Check for required environment variables
if [[ -z "${APP_STORE_CONNECT_API_KEY_P8:-}" ]]; then
    echo "Error: APP_STORE_CONNECT_API_KEY_P8 not set"
    exit 1
fi

if [[ -z "${APP_STORE_CONNECT_KEY_ID:-}" ]]; then
    echo "Error: APP_STORE_CONNECT_KEY_ID not set"
    exit 1
fi

if [[ -z "${APP_STORE_CONNECT_ISSUER_ID:-}" ]]; then
    echo "Error: APP_STORE_CONNECT_ISSUER_ID not set"
    exit 1
fi

# Download rcodesign if not present
RCODESIGN_VERSION="0.22.0"
RCODESIGN_PATH="/tmp/rcodesign"

if [[ ! -f "$RCODESIGN_PATH" ]]; then
    echo "Downloading rcodesign..."
    if [[ "$(uname -m)" == "arm64" ]]; then
        RCODESIGN_URL="https://github.com/indygreg/apple-platform-rs/releases/download/apple-codesign%2F${RCODESIGN_VERSION}/apple-codesign-${RCODESIGN_VERSION}-aarch64-apple-darwin.tar.gz"
    else
        RCODESIGN_URL="https://github.com/indygreg/apple-platform-rs/releases/download/apple-codesign%2F${RCODESIGN_VERSION}/apple-codesign-${RCODESIGN_VERSION}-x86_64-apple-darwin.tar.gz"
    fi
    
    curl -L "$RCODESIGN_URL" | tar xz -C /tmp rcodesign
    chmod +x "$RCODESIGN_PATH"
fi

# Create API key file
API_KEY_FILE="/tmp/api_key.json"
cat > "$API_KEY_FILE" <<EOF
{
  "key": "${APP_STORE_CONNECT_API_KEY_P8}",
  "key_id": "${APP_STORE_CONNECT_KEY_ID}",
  "issuer_id": "${APP_STORE_CONNECT_ISSUER_ID}"
}
EOF

# Create ZIP for notarization
ZIP_PATH="/tmp/VibeMeter.zip"
echo "Creating ZIP archive..."
ditto -c -k --keepParent "$APP_PATH" "$ZIP_PATH"

# Submit for notarization
echo "Submitting app for notarization..."
SUBMISSION_OUTPUT=$("$RCODESIGN_PATH" notary-submit \
    --api-key-file "$API_KEY_FILE" \
    --wait \
    "$ZIP_PATH" 2>&1)

echo "$SUBMISSION_OUTPUT"

# Check if notarization was successful
if echo "$SUBMISSION_OUTPUT" | grep -q "status: accepted"; then
    echo "Notarization successful!"
    
    # Staple the notarization ticket
    echo "Stapling notarization ticket..."
    xcrun stapler staple "$APP_PATH"
    
    # Verify stapling
    echo "Verifying notarization..."
    xcrun stapler validate "$APP_PATH"
    spctl -a -t open --context context:primary-signature -v "$APP_PATH"
    
else
    echo "Error: Notarization failed"
    echo "$SUBMISSION_OUTPUT"
    exit 1
fi

# Cleanup
rm -f "$API_KEY_FILE" "$ZIP_PATH"

echo "Notarization complete!"