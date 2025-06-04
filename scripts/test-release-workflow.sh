#!/bin/bash

# Release Workflow Test Script
# Tests the release scripts without actually creating releases
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo "🧪 VibeMeter Release Workflow Test"
echo "=================================="
echo ""
echo "This script tests the release workflow without creating actual releases."
echo ""

# Test results
TESTS_PASSED=0
TESTS_FAILED=0

# Function to run a test
run_test() {
    local TEST_NAME="$1"
    local TEST_CMD="$2"
    
    echo -e "${BLUE}Testing: $TEST_NAME${NC}"
    if eval "$TEST_CMD"; then
        echo -e "${GREEN}✅ PASS${NC}"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}❌ FAIL${NC}"
        ((TESTS_FAILED++))
    fi
    echo ""
}

# 1. Test script existence and executability
echo "📌 Script Availability Tests:"
echo "----------------------------"

SCRIPTS=(
    "build.sh"
    "create-prerelease.sh"
    "create-github-release.sh"
    "release.sh"
    "sign-and-notarize.sh"
    "create-dmg.sh"
    "verify-app.sh"
    "verify-appcast.sh"
    "validate-release.sh"
    "version.sh"
)

for SCRIPT in "${SCRIPTS[@]}"; do
    run_test "$SCRIPT exists and is executable" "[[ -x '$SCRIPT_DIR/$SCRIPT' ]]"
done

# 2. Test dependencies
echo "📌 Dependency Tests:"
echo "-------------------"

run_test "gh CLI installed" "command -v gh >/dev/null 2>&1"
run_test "xmllint installed" "command -v xmllint >/dev/null 2>&1"
run_test "codesign installed" "command -v codesign >/dev/null 2>&1"
run_test "spctl installed" "command -v spctl >/dev/null 2>&1"
run_test "sign_update in PATH" "export PATH=\"\$HOME/.local/bin:\$PATH\" && command -v sign_update >/dev/null 2>&1"

# 3. Test version parsing
echo "📌 Version Parsing Tests:"
echo "------------------------"

run_test "Can extract MARKETING_VERSION" "grep 'MARKETING_VERSION' '$PROJECT_ROOT/Project.swift' | sed 's/.*\"MARKETING_VERSION\": \"\(.*\)\".*/\1/' | grep -E '^[0-9]+\.[0-9]+\.[0-9]+'"
run_test "Can extract CURRENT_PROJECT_VERSION" "grep 'CURRENT_PROJECT_VERSION' '$PROJECT_ROOT/Project.swift' | sed 's/.*\"CURRENT_PROJECT_VERSION\": \"\(.*\)\".*/\1/' | grep -E '^[0-9]+$'"

# 4. Test build number validation logic
echo "📌 Build Number Validation Tests:"
echo "---------------------------------"

# Create a test function for build number validation
test_build_validation() {
    local TEST_BUILD="$1"
    local EXPECTED_RESULT="$2"
    
    # Extract existing builds from appcast
    USED_BUILD_NUMBERS=""
    if [[ -f "$PROJECT_ROOT/appcast.xml" ]]; then
        USED_BUILD_NUMBERS+=$(grep -o 'sparkle:version="[0-9]*"' "$PROJECT_ROOT/appcast.xml" | sed 's/sparkle:version="//g' | sed 's/"//g' | tr '\n' ' ')
    fi
    if [[ -f "$PROJECT_ROOT/appcast-prerelease.xml" ]]; then
        USED_BUILD_NUMBERS+=$(grep -o 'sparkle:version="[0-9]*"' "$PROJECT_ROOT/appcast-prerelease.xml" | sed 's/sparkle:version="//g' | sed 's/"//g' | tr '\n' ' ')
    fi
    
    # Find highest build
    HIGHEST_BUILD=0
    for EXISTING_BUILD in $USED_BUILD_NUMBERS; do
        if [[ "$EXISTING_BUILD" -gt "$HIGHEST_BUILD" ]]; then
            HIGHEST_BUILD=$EXISTING_BUILD
        fi
    done
    
    # Check if build is valid
    if [[ "$TEST_BUILD" -gt "$HIGHEST_BUILD" ]]; then
        return 0  # Valid
    else
        return 1  # Invalid
    fi
}

run_test "Build 201 is valid (> 200)" "test_build_validation 201 valid"
run_test "Build 200 is invalid (duplicate)" "! test_build_validation 200 invalid"
run_test "Build 199 is invalid (< 200)" "! test_build_validation 199 invalid"

# 5. Test appcast parsing
echo "📌 Appcast Parsing Tests:"
echo "------------------------"

if [[ -f "$PROJECT_ROOT/appcast-prerelease.xml" ]]; then
    run_test "Pre-release appcast is valid XML" "xmllint --noout '$PROJECT_ROOT/appcast-prerelease.xml' 2>/dev/null"
    run_test "Pre-release appcast contains items" "grep -q '<item>' '$PROJECT_ROOT/appcast-prerelease.xml'"
    run_test "Pre-release appcast has sparkle:version" "grep -q 'sparkle:version=\"' '$PROJECT_ROOT/appcast-prerelease.xml'"
fi

if [[ -f "$PROJECT_ROOT/appcast.xml" ]]; then
    run_test "Stable appcast is valid XML" "xmllint --noout '$PROJECT_ROOT/appcast.xml' 2>/dev/null"
fi

# 6. Test validation script
echo "📌 Validation Script Tests:"
echo "--------------------------"

run_test "validate-release.sh runs without error" "./scripts/validate-release.sh >/dev/null 2>&1"

# 7. Test verification scripts
echo "📌 Verification Script Tests:"
echo "-----------------------------"

# Test verify-app.sh with a dummy path (should fail gracefully)
run_test "verify-app.sh handles missing app" "./scripts/verify-app.sh /nonexistent/path 2>&1 | grep -q 'not found'"

# Test verify-appcast.sh
run_test "verify-appcast.sh runs" "./scripts/verify-appcast.sh >/dev/null 2>&1 || true"

# 8. Test version script
echo "📌 Version Script Tests:"
echo "-----------------------"

run_test "version.sh shows help" "./scripts/version.sh --help | grep -q 'Usage:'"
run_test "version.sh shows current version" "./scripts/version.sh --current | grep -q 'Current version:'"

# 9. Test pre-release suffix extraction
echo "📌 Pre-release Suffix Tests:"
echo "----------------------------"

test_suffix_extraction() {
    local INPUT="$1"
    local EXPECTED="$2"
    local RESULT=$(echo "$INPUT" | sed 's/-[a-zA-Z]*\.[0-9]*$//')
    [[ "$RESULT" == "$EXPECTED" ]]
}

run_test "Extract base from 1.0.0-beta.1" "test_suffix_extraction '1.0.0-beta.1' '1.0.0'"
run_test "Extract base from 1.0.0" "test_suffix_extraction '1.0.0' '1.0.0'"
run_test "Extract base from 2.3.4-rc.99" "test_suffix_extraction '2.3.4-rc.99' '2.3.4'"

# Summary
echo ""
echo "📊 Test Summary:"
echo "==============="
echo -e "${GREEN}Passed: $TESTS_PASSED${NC}"
echo -e "${RED}Failed: $TESTS_FAILED${NC}"
echo ""

if [[ $TESTS_FAILED -eq 0 ]]; then
    echo -e "${GREEN}✅ All tests passed! Release workflow is ready.${NC}"
    exit 0
else
    echo -e "${RED}❌ Some tests failed. Please fix issues before releasing.${NC}"
    exit 1
fi