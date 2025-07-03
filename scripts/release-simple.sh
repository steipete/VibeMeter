#!/bin/bash

# =============================================================================
# VibeMeter Simplified Release Script
# =============================================================================
#
# This script provides a streamlined release process that works with the
# version bump script. It reads the version from version.xcconfig and
# automatically determines the release type.
#
# USAGE:
#   ./scripts/release-simple.sh
#
# WORKFLOW:
#   1. Run bump-version.sh to set the version
#   2. Commit the version changes
#   3. Run this script to create the release
#
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🚀 VibeMeter Simplified Release${NC}"
echo "================================"
echo ""

# Read version info from xcconfig
MARKETING_VERSION=$(grep 'MARKETING_VERSION' "$PROJECT_ROOT/VibeMeter/version.xcconfig" | sed 's/.*MARKETING_VERSION = \(.*\)/\1/')
BUILD_NUMBER=$(grep 'CURRENT_PROJECT_VERSION' "$PROJECT_ROOT/VibeMeter/version.xcconfig" | sed 's/.*CURRENT_PROJECT_VERSION = \(.*\)/\1/')

# Determine release type from version
if [[ "$MARKETING_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    RELEASE_TYPE="stable"
    PRERELEASE_NUMBER=""
elif [[ "$MARKETING_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+-([a-z]+)\.([0-9]+)$ ]]; then
    RELEASE_TYPE="${BASH_REMATCH[1]}"
    PRERELEASE_NUMBER="${BASH_REMATCH[2]}"
else
    echo -e "${RED}❌ Error: Invalid version format in version.xcconfig: $MARKETING_VERSION${NC}"
    echo "Please run bump-version.sh first"
    exit 1
fi

echo "📦 Release Information:"
echo "   Version: $MARKETING_VERSION"
echo "   Build: $BUILD_NUMBER"
echo "   Type: $RELEASE_TYPE"
if [[ -n "$PRERELEASE_NUMBER" ]]; then
    echo "   Pre-release: $RELEASE_TYPE.$PRERELEASE_NUMBER"
fi
echo ""

# Ask for confirmation
read -p "Continue with release? (y/n): " confirm
if [[ "$confirm" != "y" ]]; then
    echo -e "${RED}❌ Release cancelled${NC}"
    exit 1
fi

# Check for uncommitted changes
if ! git diff --quiet || ! git diff --cached --quiet; then
    echo -e "${YELLOW}⚠️  Uncommitted changes detected${NC}"
    echo ""
    git status --short
    echo ""
    read -p "Commit these changes before release? (y/n): " commit_changes
    if [[ "$commit_changes" == "y" ]]; then
        git add -A
        git commit -m "chore: prepare release $MARKETING_VERSION (build $BUILD_NUMBER)"
        echo -e "${GREEN}✅ Changes committed${NC}"
    else
        echo -e "${RED}❌ Please commit changes before releasing${NC}"
        exit 1
    fi
fi

# Run the main release script with the correct arguments
echo ""
echo "🚀 Starting release process..."
echo ""

if [[ "$RELEASE_TYPE" == "stable" ]]; then
    exec "$SCRIPT_DIR/release.sh" stable
else
    exec "$SCRIPT_DIR/release.sh" "$RELEASE_TYPE" "$PRERELEASE_NUMBER"
fi