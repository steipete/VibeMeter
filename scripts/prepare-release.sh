#!/bin/bash

# =============================================================================
# VibeMeter Release Preparation Script
# =============================================================================
#
# This script helps prepare a new release by guiding through all the steps:
# - Checking git status
# - Updating CHANGELOG.md
# - Bumping version
# - Running pre-flight checks
# - Creating the release
#
# USAGE:
#   ./scripts/prepare-release.sh <version>
#
# ARGUMENTS:
#   version  The new version (e.g., "2.0.0", "2.0.0-beta.4", "2.1.0-rc.1")
#
# EXAMPLES:
#   ./scripts/prepare-release.sh 2.0.0        # Prepare stable release
#   ./scripts/prepare-release.sh 2.0.0-beta.4 # Prepare beta release
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
CYAN='\033[0;36m'
NC='\033[0m'

# Parse arguments
NEW_VERSION="${1:-}"

if [[ -z "$NEW_VERSION" ]]; then
    echo -e "${RED}❌ Error: Version required${NC}"
    echo ""
    echo "Usage: $0 <version>"
    echo ""
    echo "Examples:"
    echo "  $0 2.0.0              # Stable release"
    echo "  $0 2.0.0-beta.4       # Beta release"
    echo "  $0 2.1.0-rc.1         # Release candidate"
    exit 1
fi

echo -e "${BLUE}🎯 VibeMeter Release Preparation${NC}"
echo "================================"
echo ""
echo "Preparing release: $NEW_VERSION"
echo ""

# Step 1: Check git status
echo -e "${CYAN}📋 Step 1: Checking git status...${NC}"

# Check branch
CURRENT_BRANCH=$(git branch --show-current)
if [[ "$CURRENT_BRANCH" != "main" ]]; then
    echo -e "${YELLOW}⚠️  Not on main branch (current: $CURRENT_BRANCH)${NC}"
    read -p "Switch to main branch? (y/n): " switch_branch
    if [[ "$switch_branch" == "y" ]]; then
        git checkout main
        git pull --rebase origin main
    else
        echo -e "${RED}❌ Must be on main branch to release${NC}"
        exit 1
    fi
fi

# Check for uncommitted changes
if ! git diff --quiet || ! git diff --cached --quiet; then
    echo -e "${YELLOW}⚠️  Uncommitted changes detected:${NC}"
    git status --short
    echo ""
    read -p "Stash changes and continue? (y/n): " stash_changes
    if [[ "$stash_changes" == "y" ]]; then
        git stash push -m "prepare-release: stashing changes for $NEW_VERSION"
        echo -e "${GREEN}✅ Changes stashed${NC}"
    else
        echo -e "${RED}❌ Please handle uncommitted changes first${NC}"
        exit 1
    fi
fi

# Pull latest
echo "📥 Pulling latest changes..."
git pull --rebase origin main

echo -e "${GREEN}✅ Git status OK${NC}"
echo ""

# Step 2: Check CHANGELOG
echo -e "${CYAN}📋 Step 2: Checking CHANGELOG.md...${NC}"

# Extract version without pre-release suffix for changelog lookup
CHANGELOG_VERSION="$NEW_VERSION"
if [[ "$CHANGELOG_VERSION" =~ ^([0-9]+\.[0-9]+\.[0-9]+)- ]]; then
    CHANGELOG_BASE="${BASH_REMATCH[1]}"
else
    CHANGELOG_BASE="$CHANGELOG_VERSION"
fi

# Check if version exists in changelog
if grep -q "## \[$CHANGELOG_BASE\]" "$PROJECT_ROOT/CHANGELOG.md" || \
   grep -q "## \[$CHANGELOG_VERSION\]" "$PROJECT_ROOT/CHANGELOG.md"; then
    echo -e "${GREEN}✅ CHANGELOG.md contains entry for version${NC}"
else
    echo -e "${YELLOW}⚠️  No CHANGELOG entry found for $NEW_VERSION${NC}"
    echo ""
    echo "Please add a changelog entry in CHANGELOG.md:"
    echo ""
    echo "## [$CHANGELOG_BASE] - $(date +%Y-%m-%d)"
    echo ""
    echo "### 🎯 Major Features"
    echo "- **Feature Name** - Description"
    echo ""
    echo "### 🎨 UI Improvements"
    echo "- **Improvement** - Description"
    echo ""
    echo "### 🐛 Bug Fixes"
    echo "- **Fixed issue** - Description"
    echo ""
    read -p "Open CHANGELOG.md in editor? (y/n): " open_editor
    if [[ "$open_editor" == "y" ]]; then
        ${EDITOR:-nano} "$PROJECT_ROOT/CHANGELOG.md"
    else
        echo -e "${RED}❌ Please update CHANGELOG.md before continuing${NC}"
        exit 1
    fi
fi

echo ""

# Step 3: Bump version
echo -e "${CYAN}📋 Step 3: Bumping version...${NC}"
"$SCRIPT_DIR/bump-version.sh" "$NEW_VERSION"

# Get the new build number
BUILD_NUMBER=$(grep 'CURRENT_PROJECT_VERSION' "$PROJECT_ROOT/VibeMeter/version.xcconfig" | sed 's/.*CURRENT_PROJECT_VERSION = \(.*\)/\1/')

echo ""

# Step 4: Run pre-flight check
echo -e "${CYAN}📋 Step 4: Running pre-flight check...${NC}"
echo ""
if ! "$SCRIPT_DIR/preflight-check.sh"; then
    echo ""
    echo -e "${RED}❌ Pre-flight check failed${NC}"
    echo "Please fix the issues and run this script again"
    exit 1
fi

echo ""

# Step 5: Commit changes
echo -e "${CYAN}📋 Step 5: Committing changes...${NC}"

# Check what needs to be committed
if ! git diff --quiet || ! git diff --cached --quiet; then
    echo "Changes to commit:"
    git status --short
    echo ""
    
    git add VibeMeter/version.xcconfig CHANGELOG.md
    git commit -m "chore: prepare release $NEW_VERSION (build $BUILD_NUMBER)

- Updated version.xcconfig
- Updated CHANGELOG.md"
    
    echo -e "${GREEN}✅ Changes committed${NC}"
else
    echo "ℹ️  No changes to commit"
fi

echo ""

# Step 6: Create release
echo -e "${CYAN}📋 Step 6: Ready to create release${NC}"
echo ""
echo "Summary:"
echo "  - Version: $NEW_VERSION"
echo "  - Build: $BUILD_NUMBER"
echo "  - Branch: $(git branch --show-current)"
echo "  - Changelog: ✓"
echo "  - Pre-flight: ✓"
echo ""

read -p "Create release now? (y/n): " create_release
if [[ "$create_release" == "y" ]]; then
    echo ""
    echo "🚀 Starting release..."
    exec "$SCRIPT_DIR/release-simple.sh"
else
    echo ""
    echo -e "${YELLOW}📝 Release preparation complete!${NC}"
    echo ""
    echo "To create the release later, run:"
    echo "  ./scripts/release-simple.sh"
    echo ""
    echo "Or use the original release script:"
    if [[ "$NEW_VERSION" =~ -([a-z]+)\.([0-9]+)$ ]]; then
        echo "  ./scripts/release.sh ${BASH_REMATCH[1]} ${BASH_REMATCH[2]}"
    else
        echo "  ./scripts/release.sh stable"
    fi
fi