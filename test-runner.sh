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
        # For Swift Testing, we can't use -only-testing with the old syntax
        # Run all tests for now until we figure out the proper syntax
        TEST_FILTER=""
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
    -destination 'platform=macOS' \
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
    -destination 'platform=macOS' \
    -configuration Debug \
    -derivedDataPath build/DerivedData \
    -parallel-testing-enabled NO \
    -test-timeouts-enabled YES \
    -default-test-execution-time-allowance 60 \
    -maximum-test-execution-time-allowance 300 \
    $TEST_FILTER"

if [ -n "$JUNIT_OUTPUT" ]; then
    # Clean up any existing result bundle
    rm -rf test-results.xcresult
    TEST_CMD="$TEST_CMD -resultBundlePath test-results.xcresult"
fi

if [ "$VERBOSE" = "NO" ]; then
    TEST_CMD="$TEST_CMD -quiet"
fi

# Run tests and capture output
set +e
if [ -n "$JUNIT_OUTPUT" ]; then
    # For Swift Testing, run tests and capture results
    eval "$TEST_CMD" 2>&1 | tee test-output.log | xcbeautify
    TEST_STATUS=${PIPESTATUS[0]}
    
    # Create a simple JUnit report based on test output
    echo -e "\n${YELLOW}Creating test results...${NC}"
    
    # Extract test summary from output
    if grep -q "Test run with" test-output.log; then
        # Parse Swift Testing output format
        SUMMARY_LINE=$(grep "Test run with" test-output.log | tail -1)
        echo "Found summary: $SUMMARY_LINE"
        
        if echo "$SUMMARY_LINE" | grep -q "passed"; then
            TOTAL=$(echo "$SUMMARY_LINE" | sed -E 's/.*with ([0-9]+) tests.*/\1/' 2>/dev/null || echo "1")
            FAILURES="0"
        else
            TOTAL=$(echo "$SUMMARY_LINE" | sed -E 's/.*with ([0-9]+) tests.*/\1/' 2>/dev/null || echo "1") 
            FAILURES="1"
        fi
    else
        # Fallback values
        TOTAL="1"
        FAILURES="1"
    fi
    
    # Create simple JUnit XML
    cat > "$JUNIT_OUTPUT" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<testsuites name="VibeMeterTests" tests="${TOTAL}" failures="${FAILURES}">
  <testsuite name="VibeMeterTests" tests="${TOTAL}" failures="${FAILURES}">
    <testcase name="SwiftTestingSuite" classname="VibeMeterTests">
    </testcase>
  </testsuite>
</testsuites>
EOF
else
    eval "$TEST_CMD" | xcbeautify
    TEST_STATUS=${PIPESTATUS[0]}
fi
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