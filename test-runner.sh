#!/bin/bash
set -euo pipefail

# Test runner for VibeMeter with support for different modes
# Usage: ./test-runner.sh [mode] [options]
# Modes: all, quick, suite
# Options: --junit-output, --parallel, --verbose

MODE="${1:-all}"
JUNIT_OUTPUT=""
PARALLEL="NO"
VERBOSE="NO"
TEST_FILTER=""

# Parse arguments
shift || true
while [[ $# -gt 0 ]]; do
    case $1 in
        --junit-output)
            JUNIT_OUTPUT="$2"
            shift 2
            ;;
        --parallel)
            PARALLEL="YES"
            shift
            ;;
        --verbose)
            VERBOSE="YES"
            shift
            ;;
        --suite)
            TEST_FILTER="$TEST_FILTER -only-testing:$2"
            shift 2
            ;;
        *)
            shift
            ;;
    esac
done

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}🧪 VibeMeter Test Runner${NC}"
echo "Mode: $MODE"

# Ensure we have required tools
if ! command -v xcodebuild &> /dev/null; then
    echo -e "${RED}❌ xcodebuild not found. Please install Xcode.${NC}"
    exit 1
fi

# Install xcbeautify if not present
if ! command -v xcbeautify &> /dev/null; then
    echo "Installing xcbeautify..."
    brew install xcbeautify
fi

# Generate project if needed
if [ ! -d "VibeMeter.xcworkspace" ]; then
    echo "Generating Xcode project..."
    ./scripts/generate-xcproj.sh
fi

# Define test suites for different modes
case $MODE in
    "quick")
        echo -e "${YELLOW}Running quick core tests...${NC}"
        TEST_FILTER=""
        TEST_FILTER="$TEST_FILTER -only-testing:VibeMeterTests/CursorProviderBasicTests"
        TEST_FILTER="$TEST_FILTER -only-testing:VibeMeterTests/CursorProviderDataTests"
        TEST_FILTER="$TEST_FILTER -only-testing:VibeMeterTests/ExchangeRateManagerNetworkTests"
        TEST_FILTER="$TEST_FILTER -only-testing:VibeMeterTests/MultiProviderDataOrchestratorTests"
        TEST_FILTER="$TEST_FILTER -only-testing:VibeMeterTests/CurrencyConversionBasicTests"
        TEST_FILTER="$TEST_FILTER -only-testing:VibeMeterTests/SettingsManagerTests"
        TEST_FILTER="$TEST_FILTER -only-testing:VibeMeterTests/NotificationManagerBasicTests"
        ;;
    "all")
        echo -e "${YELLOW}Running all tests...${NC}"
        TEST_FILTER=""
        ;;
    "suite")
        echo -e "${YELLOW}Running specified test suites...${NC}"
        # TEST_FILTER already set by --suite arguments
        ;;
    *)
        echo -e "${RED}Unknown mode: $MODE${NC}"
        echo "Usage: $0 [all|quick|suite] [options]"
        exit 1
        ;;
esac

# Build for testing
echo -e "\n${YELLOW}Building for tests...${NC}"
BUILD_CMD="xcodebuild build-for-testing \
    -workspace VibeMeter.xcworkspace \
    -scheme VibeMeter \
    -destination 'platform=macOS,arch=arm64' \
    -configuration Debug \
    -derivedDataPath build/DerivedData"

if [ "$VERBOSE" = "NO" ]; then
    BUILD_CMD="$BUILD_CMD -quiet"
fi

if ! eval "$BUILD_CMD" | xcbeautify; then
    echo -e "${RED}❌ Build failed${NC}"
    exit 1
fi

# Run tests
echo -e "\n${YELLOW}Running tests...${NC}"
TEST_CMD="xcodebuild test-without-building \
    -workspace VibeMeter.xcworkspace \
    -scheme VibeMeter \
    -destination 'platform=macOS,arch=arm64' \
    -configuration Debug \
    -derivedDataPath build/DerivedData \
    -parallel-testing-enabled $PARALLEL \
    -test-timeouts-enabled YES \
    -default-test-execution-time-allowance 30 \
    -maximum-test-execution-time-allowance 120 \
    $TEST_FILTER"

if [ -n "$JUNIT_OUTPUT" ]; then
    TEST_CMD="$TEST_CMD -resultBundlePath test-results.xcresult"
fi

if [ "$VERBOSE" = "NO" ]; then
    TEST_CMD="$TEST_CMD -quiet"
fi

# Run tests and capture output
set +e
if [ -n "$JUNIT_OUTPUT" ]; then
    eval "$TEST_CMD" | xcbeautify --report junit --report-path . --junit-report-filename "$JUNIT_OUTPUT"
else
    eval "$TEST_CMD" | xcbeautify
fi
TEST_STATUS=$?
set -e

# Report results
if [ $TEST_STATUS -eq 0 ]; then
    echo -e "\n${GREEN}✅ All tests passed!${NC}"
    exit 0
else
    echo -e "\n${RED}❌ Some tests failed${NC}"
    
    # Try to extract failure details
    if [ -f "test-output.log" ]; then
        echo -e "\n${YELLOW}Failed tests:${NC}"
        grep -E "(failed:|error:|FAILED|Test Case.*failed)" test-output.log | tail -30
    fi
    
    exit $TEST_STATUS
fi