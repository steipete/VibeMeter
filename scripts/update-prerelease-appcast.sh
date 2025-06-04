#!/bin/bash

# Pre-release Appcast.xml Update Script - DEPRECATED
# This script is being replaced by generate-appcast.sh
set -euo pipefail

VERSION="$1"
BUILD_NUMBER="$2"
DMG_PATH="$3"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "⚠️  WARNING: This script is deprecated. Use generate-appcast.sh instead."
echo "📡 Running generate-appcast.sh to update appcast files..."

# Run the new generate-appcast.sh script
"$SCRIPT_DIR/generate-appcast.sh"

echo "✅ Appcast files updated successfully"