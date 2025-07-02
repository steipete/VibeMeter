#!/bin/bash
# Push appcast files to stats-store repository
# This script is called by update-appcast.sh after generating the appcast files

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
STATS_STORE_PATH="$HOME/Projects/stats-store"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Check if stats-store exists
if [ ! -d "$STATS_STORE_PATH" ]; then
    echo -e "${RED}Error: stats-store not found at $STATS_STORE_PATH${NC}"
    echo "Please clone https://github.com/steipete/stats-store to ~/Projects/"
    exit 1
fi

# Copy appcast files to stats-store (they'll be served from GitHub, not the public folder)
echo "📋 Copying appcast files to stats-store repository root..."
cp "$PROJECT_ROOT/appcast.xml" "$STATS_STORE_PATH/" 2>/dev/null || true
cp "$PROJECT_ROOT/appcast-prerelease.xml" "$STATS_STORE_PATH/" 2>/dev/null || true

# Commit and push changes in stats-store
cd "$STATS_STORE_PATH"
if [ -n "$(git status --porcelain)" ]; then
    echo "📤 Committing and pushing appcast updates to stats-store..."
    git add appcast.xml appcast-prerelease.xml
    git commit -m "Update VibeMeter appcast files

$(git log -1 --pretty=format:'Latest VibeMeter commit: %h - %s' --cwd="$PROJECT_ROOT")"
    git push origin main
    echo -e "${GREEN}✅ Appcast files pushed to stats-store${NC}"
else
    echo "ℹ️  No changes to push to stats-store"
fi

cd "$PROJECT_ROOT"