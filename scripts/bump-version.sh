#!/bin/bash

# =============================================================================
# VibeMeter Version Bump Script
# =============================================================================
#
# This script helps manage version numbers and build numbers for VibeMeter
# releases. It ensures proper formatting and automatic build number increments.
#
# USAGE:
#   ./scripts/bump-version.sh <version> [build]
#
# ARGUMENTS:
#   version  The new version (e.g., "2.0.0", "2.0.0-beta.4", "2.1.0-rc.1")
#   build    Optional build number (auto-increments if not provided)
#
# EXAMPLES:
#   ./scripts/bump-version.sh 2.0.0           # Bump to stable 2.0.0
#   ./scripts/bump-version.sh 2.0.0-beta.4    # Bump to beta.4
#   ./scripts/bump-version.sh 2.1.0-rc.1      # Bump to rc.1
#   ./scripts/bump-version.sh 2.0.0 210       # Set specific build number
#
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
VERSION_FILE="$PROJECT_ROOT/VibeMeter/version.xcconfig"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Parse arguments
NEW_VERSION="${1:-}"
NEW_BUILD="${2:-}"

# Show usage if no arguments
if [[ -z "$NEW_VERSION" ]]; then
    echo -e "${RED}❌ Error: Version required${NC}"
    echo ""
    echo "Usage: $0 <version> [build]"
    echo ""
    echo "Examples:"
    echo "  $0 2.0.0              # Stable release"
    echo "  $0 2.0.0-beta.4       # Beta release"
    echo "  $0 2.1.0-rc.1         # Release candidate"
    echo "  $0 2.0.0 210          # With specific build"
    exit 1
fi

echo -e "${BLUE}📦 VibeMeter Version Bump${NC}"
echo "========================"
echo ""

# Validate version format
if ! [[ "$NEW_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[a-z]+\.[0-9]+)?$ ]]; then
    echo -e "${RED}❌ Error: Invalid version format${NC}"
    echo "Expected format: X.Y.Z or X.Y.Z-type.N"
    echo "Examples: 2.0.0, 2.0.0-beta.4, 2.1.0-rc.1"
    exit 1
fi

# Extract current values
CURRENT_VERSION=$(grep 'MARKETING_VERSION' "$VERSION_FILE" | sed 's/.*MARKETING_VERSION = \(.*\)/\1/')
CURRENT_BUILD=$(grep 'CURRENT_PROJECT_VERSION' "$VERSION_FILE" | sed 's/.*CURRENT_PROJECT_VERSION = \(.*\)/\1/')

echo "Current version: $CURRENT_VERSION (build $CURRENT_BUILD)"
echo "New version:     $NEW_VERSION"

# Auto-increment build number if not provided
if [[ -z "$NEW_BUILD" ]]; then
    # Get highest build number from appcast files
    HIGHEST_BUILD=0
    
    # Check appcast.xml
    if [[ -f "$PROJECT_ROOT/appcast.xml" ]]; then
        APPCAST_BUILDS=$(xmllint --xpath "//sparkle:version/text()" "$PROJECT_ROOT/appcast.xml" 2>/dev/null | tr '\n' ' ' || echo "")
        for build in $APPCAST_BUILDS; do
            if [[ $build -gt $HIGHEST_BUILD ]]; then
                HIGHEST_BUILD=$build
            fi
        done
    fi
    
    # Check appcast-prerelease.xml
    if [[ -f "$PROJECT_ROOT/appcast-prerelease.xml" ]]; then
        PRERELEASE_BUILDS=$(xmllint --xpath "//sparkle:version/text()" "$PROJECT_ROOT/appcast-prerelease.xml" 2>/dev/null | tr '\n' ' ' || echo "")
        for build in $PRERELEASE_BUILDS; do
            if [[ $build -gt $HIGHEST_BUILD ]]; then
                HIGHEST_BUILD=$build
            fi
        done
    fi
    
    # Use current build if higher
    if [[ $CURRENT_BUILD -gt $HIGHEST_BUILD ]]; then
        HIGHEST_BUILD=$CURRENT_BUILD
    fi
    
    NEW_BUILD=$((HIGHEST_BUILD + 1))
    echo -e "${YELLOW}📈 Auto-incrementing build: $CURRENT_BUILD → $NEW_BUILD${NC}"
else
    echo "New build:       $NEW_BUILD"
    
    # Validate build number
    if ! [[ "$NEW_BUILD" =~ ^[0-9]+$ ]]; then
        echo -e "${RED}❌ Error: Build number must be numeric${NC}"
        exit 1
    fi
    
    # Check if build number is going backwards
    if [[ $NEW_BUILD -le $CURRENT_BUILD ]]; then
        echo -e "${YELLOW}⚠️  Warning: New build ($NEW_BUILD) is not higher than current ($CURRENT_BUILD)${NC}"
        read -p "Continue anyway? (y/n): " confirm
        if [[ "$confirm" != "y" ]]; then
            echo -e "${RED}❌ Cancelled${NC}"
            exit 1
        fi
    fi
fi

# Determine if this is a pre-release
IS_PRERELEASE="NO"
if [[ "$NEW_VERSION" =~ -[a-z]+\.[0-9]+$ ]]; then
    IS_PRERELEASE="YES"
fi

echo ""
echo "📝 Updating version.xcconfig..."

# Create backup
cp "$VERSION_FILE" "$VERSION_FILE.bak"

# Update the file
cat > "$VERSION_FILE" << EOF
// VibeMeter Version Configuration
// This file contains the version and build number for the app

MARKETING_VERSION = $NEW_VERSION
CURRENT_PROJECT_VERSION = $NEW_BUILD

// Bundle identifier
PRODUCT_BUNDLE_IDENTIFIER = com.steipete.vibemeter

// Pre-release build flag (set by release script)
IS_PRERELEASE_BUILD = $IS_PRERELEASE
EOF

echo -e "${GREEN}✅ Updated version.xcconfig${NC}"

# Show the changes
echo ""
echo "Changes made:"
echo "  MARKETING_VERSION:       $CURRENT_VERSION → $NEW_VERSION"
echo "  CURRENT_PROJECT_VERSION: $CURRENT_BUILD → $NEW_BUILD"
echo "  IS_PRERELEASE_BUILD:     $IS_PRERELEASE"

# Clean up backup
rm -f "$VERSION_FILE.bak"

echo ""
echo -e "${GREEN}✅ Version bump complete!${NC}"
echo ""
echo "Next steps:"
echo "  1. Review the changes: git diff"
echo "  2. Commit the changes: git add -A && git commit -m \"chore: bump version to $NEW_VERSION (build $NEW_BUILD)\""
echo "  3. Run the release: ./scripts/release.sh"
echo ""

# Remind about release type
if [[ "$IS_PRERELEASE" == "YES" ]]; then
    # Extract pre-release type and number
    if [[ "$NEW_VERSION" =~ -([a-z]+)\.([0-9]+)$ ]]; then
        PRERELEASE_TYPE="${BASH_REMATCH[1]}"
        PRERELEASE_NUM="${BASH_REMATCH[2]}"
        echo -e "${BLUE}ℹ️  This is a pre-release. Run:${NC}"
        echo "   ./scripts/release.sh $PRERELEASE_TYPE $PRERELEASE_NUM"
    fi
else
    echo -e "${BLUE}ℹ️  This is a stable release. Run:${NC}"
    echo "   ./scripts/release.sh stable"
fi