#!/bin/bash

# Pre-flight Check Script for VibeMeter Releases
# This script validates everything is ready for a release
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Track if any checks fail
CHECKS_PASSED=true

echo "🔍 VibeMeter Release Pre-flight Check"
echo "===================================="
echo ""

# Function to print check results
check_pass() {
    echo -e "${GREEN}✅ PASS${NC}: $1"
}

check_fail() {
    echo -e "${RED}❌ FAIL${NC}: $1"
    CHECKS_PASSED=false
}

check_warn() {
    echo -e "${YELLOW}⚠️  WARN${NC}: $1"
}

# 1. Check Git status
echo "📌 Git Status:"
if git diff-index --quiet HEAD -- 2>/dev/null; then
    check_pass "Working directory is clean"
else
    check_fail "Uncommitted changes detected"
    git status --short
fi

# Check if on main branch
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
if [[ "$CURRENT_BRANCH" == "main" ]]; then
    check_pass "On main branch"
else
    check_warn "Not on main branch (current: $CURRENT_BRANCH)"
fi

# Check if up to date with remote
git fetch origin main --quiet
LOCAL=$(git rev-parse HEAD)
REMOTE=$(git rev-parse origin/main)
if [[ "$LOCAL" == "$REMOTE" ]]; then
    check_pass "Up to date with origin/main"
else
    check_fail "Not synced with origin/main"
fi

echo ""

# 2. Check version information
echo "📌 Version Information:"
MARKETING_VERSION=$(grep 'MARKETING_VERSION' "$PROJECT_ROOT/Project.swift" | sed 's/.*"MARKETING_VERSION": "\(.*\)".*/\1/')
BUILD_NUMBER=$(grep 'CURRENT_PROJECT_VERSION' "$PROJECT_ROOT/Project.swift" | sed 's/.*"CURRENT_PROJECT_VERSION": "\(.*\)".*/\1/')

echo "   Marketing Version: $MARKETING_VERSION"
echo "   Build Number: $BUILD_NUMBER"

# Check for Info.plist overrides
if grep "CFBundleShortVersionString" "$PROJECT_ROOT/Project.swift" | grep -v "MARKETING_VERSION" | grep -q .; then
    check_fail "Info.plist has version overrides - remove them"
else
    check_pass "No Info.plist version overrides"
fi

echo ""

# 3. Check build numbers
echo "📌 Build Number Validation:"
USED_BUILD_NUMBERS=""
if [[ -f "$PROJECT_ROOT/appcast.xml" ]]; then
    APPCAST_BUILDS=$(grep -E '<sparkle:version>[0-9]+</sparkle:version>' "$PROJECT_ROOT/appcast.xml" 2>/dev/null | sed 's/.*<sparkle:version>\([0-9]*\)<\/sparkle:version>.*/\1/' | tr '\n' ' ' || true)
    USED_BUILD_NUMBERS+="$APPCAST_BUILDS"
fi
if [[ -f "$PROJECT_ROOT/appcast-prerelease.xml" ]]; then
    PRERELEASE_BUILDS=$(grep -E '<sparkle:version>[0-9]+</sparkle:version>' "$PROJECT_ROOT/appcast-prerelease.xml" 2>/dev/null | sed 's/.*<sparkle:version>\([0-9]*\)<\/sparkle:version>.*/\1/' | tr '\n' ' ' || true)
    USED_BUILD_NUMBERS+="$PRERELEASE_BUILDS"
fi

# Find highest build number
HIGHEST_BUILD=0
for EXISTING_BUILD in $USED_BUILD_NUMBERS; do
    if [[ "$EXISTING_BUILD" -gt "$HIGHEST_BUILD" ]]; then
        HIGHEST_BUILD=$EXISTING_BUILD
    fi
done

if [[ -z "$USED_BUILD_NUMBERS" ]]; then
    check_pass "No existing builds found"
else
    echo "   Existing builds: $USED_BUILD_NUMBERS"
    echo "   Highest build: $HIGHEST_BUILD"
    
    # Check for duplicates
    for EXISTING_BUILD in $USED_BUILD_NUMBERS; do
        if [[ "$BUILD_NUMBER" == "$EXISTING_BUILD" ]]; then
            check_fail "Build number $BUILD_NUMBER already exists!"
        fi
    done
    
    # Check if monotonically increasing
    if [[ "$BUILD_NUMBER" -gt "$HIGHEST_BUILD" ]]; then
        check_pass "Build number $BUILD_NUMBER is valid (> $HIGHEST_BUILD)"
    else
        check_fail "Build number must be > $HIGHEST_BUILD"
    fi
fi

echo ""

# 4. Check required tools
echo "📌 Required Tools:"

# GitHub CLI
if command -v gh &> /dev/null; then
    check_pass "GitHub CLI (gh) installed"
    if gh auth status &> /dev/null; then
        check_pass "GitHub CLI authenticated"
    else
        check_fail "GitHub CLI not authenticated - run: gh auth login"
    fi
else
    check_fail "GitHub CLI not installed - run: brew install gh"
fi

# Tuist
if command -v tuist &> /dev/null; then
    check_pass "Tuist installed"
else
    check_fail "Tuist not installed - run: curl -Ls https://install.tuist.io | bash"
fi

# Sparkle tools
if [[ -f "$HOME/.local/bin/sign_update" ]]; then
    check_pass "Sparkle sign_update installed"
else
    check_fail "Sparkle tools not installed - see RELEASE.md"
fi

# xcbeautify (optional but recommended)
if command -v xcbeautify &> /dev/null; then
    check_pass "xcbeautify installed"
else
    check_warn "xcbeautify not installed (optional) - run: brew install xcbeautify"
fi

echo ""

# 5. Check signing configuration
echo "📌 Signing Configuration:"

# Check for Developer ID certificate
if security find-identity -v -p codesigning | grep -q "Developer ID Application"; then
    check_pass "Developer ID certificate found"
else
    check_fail "No Developer ID certificate found"
fi

# Check for notarization credentials
if [[ -n "${APP_STORE_CONNECT_API_KEY_P8:-}" ]]; then
    check_pass "Notarization API key configured"
else
    check_warn "Notarization API key not in environment"
fi

echo ""

# 6. Check Sparkle configuration
echo "📌 Sparkle Configuration:"

# Check public key
PUBLIC_KEY=$(grep 'SUPublicEDKey' "$PROJECT_ROOT/Project.swift" | sed 's/.*"SUPublicEDKey": "\(.*\)".*/\1/')
if [[ -n "$PUBLIC_KEY" ]]; then
    check_pass "Sparkle public key configured"
else
    check_fail "Sparkle public key not found in Project.swift"
fi

# Check private key
if [[ -f "$PROJECT_ROOT/private/sparkle_private_key" ]]; then
    check_pass "Sparkle private key found"
else
    check_fail "Sparkle private key not found at private/sparkle_private_key"
fi

echo ""

# 7. Check appcast files
echo "📌 Appcast Files:"

if [[ -f "$PROJECT_ROOT/appcast.xml" ]]; then
    if xmllint --noout "$PROJECT_ROOT/appcast.xml" 2>/dev/null; then
        check_pass "appcast.xml is valid XML"
    else
        check_fail "appcast.xml has XML errors"
    fi
else
    check_warn "appcast.xml not found (OK if no stable releases yet)"
fi

if [[ -f "$PROJECT_ROOT/appcast-prerelease.xml" ]]; then
    if xmllint --noout "$PROJECT_ROOT/appcast-prerelease.xml" 2>/dev/null; then
        check_pass "appcast-prerelease.xml is valid XML"
    else
        check_fail "appcast-prerelease.xml has XML errors"
    fi
else
    check_warn "appcast-prerelease.xml not found (OK if no pre-releases yet)"
fi

echo ""

# 8. Summary
echo "📊 Pre-flight Summary:"
echo "===================="

if [[ "$CHECKS_PASSED" == true ]]; then
    echo -e "${GREEN}✅ All critical checks passed!${NC}"
    echo ""
    echo "Ready to release:"
    echo "  Version: $MARKETING_VERSION"
    echo "  Build: $BUILD_NUMBER"
    echo ""
    echo "Next steps:"
    echo "  - For beta: ./scripts/release-auto.sh beta 1"
    echo "  - For stable: ./scripts/release-auto.sh stable"
    exit 0
else
    echo -e "${RED}❌ Some checks failed. Please fix the issues above.${NC}"
    exit 1
fi