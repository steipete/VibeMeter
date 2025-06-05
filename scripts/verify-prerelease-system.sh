#!/bin/bash

# =============================================================================
# VibeMeter IS_PRERELEASE_BUILD System Verification Script
# =============================================================================
#
# This script comprehensively verifies that the automatic update channel 
# detection system is properly configured and functioning. It ensures that
# beta builds automatically default to the pre-release update channel.
#
# USAGE:
#   ./scripts/verify-prerelease-system.sh
#
# VERIFICATION CHECKS:
#   - Project.swift IS_PRERELEASE_BUILD configuration
#   - UpdateChannel.swift flag detection logic
#   - Release script environment variable setup
#   - AppBehaviorSettingsManager integration
#   - Build system environment variable handling
#   - Runtime Info.plist flag verification
#   - Documentation completeness
#
# FEATURES:
#   - Configuration validation across all components
#   - Build system integration testing
#   - Runtime verification of existing builds
#   - Documentation completeness checking
#   - Clear pass/fail reporting with fix suggestions
#
# EXIT CODES:
#   0  All checks passed - system properly configured
#   1  Some checks failed - configuration issues detected
#
# DEPENDENCIES:
#   - Xcode and xcodebuild (for build system testing)
#   - Generated Xcode workspace (optional, for full testing)
#   - Existing built apps (optional, for runtime testing)
#
# EXAMPLES:
#   ./scripts/verify-prerelease-system.sh
#
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Track if any checks fail
CHECKS_PASSED=true

echo -e "${BLUE}🔍 VibeMeter IS_PRERELEASE_BUILD System Verification${NC}"
echo "=================================================="
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

echo "📌 Configuration Verification:"

# 1. Check Project.swift configuration
if grep -q '"IS_PRERELEASE_BUILD".*"\$(IS_PRERELEASE_BUILD)"' "$PROJECT_ROOT/Project.swift"; then
    check_pass "IS_PRERELEASE_BUILD flag configured in Project.swift Info.plist"
else
    check_fail "IS_PRERELEASE_BUILD flag missing from Project.swift"
    echo "  Add this to the infoPlist section in Project.swift:"
    echo '  "IS_PRERELEASE_BUILD": "$(IS_PRERELEASE_BUILD)",'
fi

# 2. Check UpdateChannel.swift detection logic
if grep -q "Bundle.main.object.*IS_PRERELEASE_BUILD" "$PROJECT_ROOT/VibeMeter/Core/Models/UpdateChannel.swift"; then
    check_pass "UpdateChannel has IS_PRERELEASE_BUILD detection logic"
    
    # Verify the logic structure
    if grep -A5 "Bundle.main.object.*IS_PRERELEASE_BUILD" "$PROJECT_ROOT/VibeMeter/Core/Models/UpdateChannel.swift" | grep -q "return .prerelease"; then
        check_pass "UpdateChannel correctly returns .prerelease for beta builds"
    else
        check_fail "UpdateChannel detection logic incomplete"
    fi
else
    check_fail "UpdateChannel.swift missing IS_PRERELEASE_BUILD flag detection"
    echo "  Add this to defaultChannel() method:"
    echo "  if let isPrereleaseValue = Bundle.main.object(forInfoDictionaryKey: \"IS_PRERELEASE_BUILD\"),"
    echo "     let isPrerelease = isPrereleaseValue as? Bool,"
    echo "     isPrerelease {"
    echo "      return .prerelease"
    echo "  }"
fi

# 3. Check release script configuration
if grep -q "export IS_PRERELEASE_BUILD=" "$PROJECT_ROOT/scripts/release.sh"; then
    check_pass "Release script sets IS_PRERELEASE_BUILD environment variable"
    
    # Check both YES and NO cases
    if grep -q 'IS_PRERELEASE_BUILD=YES' "$PROJECT_ROOT/scripts/release.sh" && \
       grep -q 'IS_PRERELEASE_BUILD=NO' "$PROJECT_ROOT/scripts/release.sh"; then
        check_pass "Release script handles both beta and stable builds"
    else
        check_fail "Release script missing YES/NO handling for IS_PRERELEASE_BUILD"
    fi
else
    check_fail "Release script missing IS_PRERELEASE_BUILD setup"
    echo "  Add this to release.sh before building:"
    echo "  if [[ \"\$RELEASE_TYPE\" != \"stable\" ]]; then"
    echo "      export IS_PRERELEASE_BUILD=YES"
    echo "  else"
    echo "      export IS_PRERELEASE_BUILD=NO"
    echo "  fi"
fi

# 4. Check AppBehaviorSettingsManager integration
if grep -q "UpdateChannel.defaultChannel" "$PROJECT_ROOT/VibeMeter/Core/Services/Settings/AppBehaviorSettingsManager.swift"; then
    check_pass "AppBehaviorSettingsManager uses UpdateChannel.defaultChannel()"
else
    check_fail "AppBehaviorSettingsManager not using auto-detection"
    echo "  Update initialization to use:"
    echo "  let defaultChannel = UpdateChannel.defaultChannel(for: currentVersion)"
fi

echo ""

# 5. Build and runtime verification
echo "📌 Build System Verification:"

# Test environment variable handling
echo "Testing environment variable handling..."

# Simulate beta build
export IS_PRERELEASE_BUILD=YES
if xcodebuild -workspace "$PROJECT_ROOT/VibeMeter.xcworkspace" -scheme VibeMeter -configuration Debug -showBuildSettings | grep -q "IS_PRERELEASE_BUILD = YES"; then
    check_pass "Xcode build system recognizes IS_PRERELEASE_BUILD=YES"
else
    check_warn "Could not verify Xcode build system integration (workspace not generated?)"
fi

# Reset
unset IS_PRERELEASE_BUILD

echo ""

# 6. Test with actual builds if available
echo "📌 Runtime Verification:"

# Check if we have any built apps to test
if [[ -d "$PROJECT_ROOT/build/Build/Products/Release/VibeMeter.app" ]]; then
    echo "Testing with existing Release build..."
    
    PLIST_PATH="$PROJECT_ROOT/build/Build/Products/Release/VibeMeter.app/Contents/Info.plist"
    if [[ -f "$PLIST_PATH" ]]; then
        if plutil -p "$PLIST_PATH" | grep -q "IS_PRERELEASE_BUILD"; then
            FLAG_VALUE=$(defaults read "$PLIST_PATH" IS_PRERELEASE_BUILD 2>/dev/null || echo "not found")
            if [[ "$FLAG_VALUE" == "YES" ]]; then
                check_pass "Recent build has IS_PRERELEASE_BUILD=YES (beta build)"
            elif [[ "$FLAG_VALUE" == "NO" ]]; then
                check_pass "Recent build has IS_PRERELEASE_BUILD=NO (stable build)"
            elif [[ "$FLAG_VALUE" == "" ]]; then
                check_warn "Recent build has empty IS_PRERELEASE_BUILD (env var not set during build)"
            else
                check_warn "Recent build has IS_PRERELEASE_BUILD=$FLAG_VALUE"
            fi
        else
            check_fail "Recent build missing IS_PRERELEASE_BUILD in Info.plist"
        fi
    fi
else
    check_warn "No existing builds found - run a build to test runtime behavior"
fi

echo ""

# 7. Documentation verification
echo "📌 Documentation Verification:"

if grep -q "IS_PRERELEASE_BUILD" "$PROJECT_ROOT/README.md"; then
    check_pass "README.md documents IS_PRERELEASE_BUILD system"
else
    check_fail "README.md missing IS_PRERELEASE_BUILD documentation"
fi

if grep -q "Automatic Channel Detection" "$PROJECT_ROOT/README.md"; then
    check_pass "README.md documents automatic channel detection"
else
    check_warn "README.md could include more details about automatic channel detection"
fi

echo ""

# 8. Summary
echo "📊 Verification Summary:"
echo "======================"

if [[ "$CHECKS_PASSED" == true ]]; then
    echo -e "${GREEN}✅ IS_PRERELEASE_BUILD system is properly configured!${NC}"
    echo ""
    echo "System features:"
    echo "  ✓ Beta builds automatically default to pre-release update channel"
    echo "  ✓ Stable builds automatically default to stable update channel"
    echo "  ✓ Users can still manually override the channel in settings"
    echo "  ✓ Fallback to version string parsing if flag is missing"
    echo ""
    echo "Test the system:"
    echo "  1. Create a beta build: ./scripts/release.sh beta 1"
    echo "  2. Download and install the beta"
    echo "  3. Verify update channel defaults to 'Include Pre-releases'"
    exit 0
else
    echo -e "${RED}❌ IS_PRERELEASE_BUILD system has configuration issues!${NC}"
    echo ""
    echo "Please fix the issues above to ensure proper automatic update channel detection."
    exit 1
fi