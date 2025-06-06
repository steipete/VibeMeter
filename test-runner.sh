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

# Detect CI environment and increase verbosity
if [ "${CI:-}" = "true" ] || [ -n "${GITHUB_ACTIONS:-}" ]; then
    echo "CI environment detected - enabling verbose output"
    VERBOSE="YES"
fi

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

if [ "$VERBOSE" = "YES" ]; then
    # In verbose mode (CI), show raw build output with timeout protection
    # Use gtimeout on macOS (from coreutils) or fallback without timeout
    TIMEOUT_CMD=""
    if command -v gtimeout &> /dev/null; then
        TIMEOUT_CMD="gtimeout 600"
    elif command -v timeout &> /dev/null; then
        TIMEOUT_CMD="timeout 600"
    fi
    
    if [ -n "$TIMEOUT_CMD" ]; then
        if ! $TIMEOUT_CMD eval "$BUILD_CMD"; then
            BUILD_STATUS=$?
            if [ $BUILD_STATUS -eq 124 ]; then
                echo -e "${RED}❌ Build timed out after 10 minutes${NC}"
            else
                echo -e "${RED}❌ Build failed${NC}"
            fi
            exit 1
        fi
    else
        # No timeout available, run without it
        if ! eval "$BUILD_CMD"; then
            echo -e "${RED}❌ Build failed${NC}"
            exit 1
        fi
    fi
else
    # Local development, use xcbeautify for clean output
    if ! eval "$BUILD_CMD" | xcbeautify; then
        echo -e "${RED}❌ Build failed${NC}"
        exit 1
    fi
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
else
    echo "Verbose mode enabled - showing full xcodebuild output"
fi

# Run tests and capture output
set +e
if [ -n "$JUNIT_OUTPUT" ]; then
    # For Swift Testing, run tests and capture results
    if [ "$VERBOSE" = "YES" ]; then
        # In verbose mode (CI), show raw output without xcbeautify filtering
        # Use timeout to prevent hanging in CI
        if [ -n "$TIMEOUT_CMD" ]; then
            $TIMEOUT_CMD eval "$TEST_CMD" 2>&1 | tee test-output.log
            TEST_STATUS=${PIPESTATUS[0]}
            # If timeout occurred, mark as failure
            if [ $TEST_STATUS -eq 124 ]; then
                echo "Tests timed out after 10 minutes"
                TEST_STATUS=1
            fi
        else
            # No timeout available, run without it
            eval "$TEST_CMD" 2>&1 | tee test-output.log
            TEST_STATUS=${PIPESTATUS[0]}
        fi
    else
        # Local development, use xcbeautify for clean output
        eval "$TEST_CMD" 2>&1 | tee test-output.log | xcbeautify
        TEST_STATUS=${PIPESTATUS[0]}
    fi
    
    # Create a simple JUnit report based on test output
    echo -e "\n${YELLOW}Creating test results...${NC}"
    
    # Extract test summary from output
    if grep -q "Test run with" test-output.log; then
        # Parse Swift Testing output format: "✔ Test run with 603 tests passed after 117.662 seconds."
        SUMMARY_LINE=$(grep "Test run with" test-output.log | tail -1)
        echo "Found summary: $SUMMARY_LINE"
        
        if echo "$SUMMARY_LINE" | grep -q "passed"; then
            TOTAL=$(echo "$SUMMARY_LINE" | sed -E 's/.*with ([0-9]+) tests passed.*/\1/' 2>/dev/null || echo "1")
            FAILURES="0"
        else
            TOTAL=$(echo "$SUMMARY_LINE" | sed -E 's/.*with ([0-9]+) tests.*/\1/' 2>/dev/null || echo "1") 
            FAILURES="1"
        fi
    else
        # Check for any failed tests in the output
        FAILED_COUNT=$(grep -c "✗.*failed" test-output.log 2>/dev/null || echo "0")
        PASSED_COUNT=$(grep -c "✔.*passed" test-output.log 2>/dev/null || echo "0")
        
        if [ "$FAILED_COUNT" -gt 0 ]; then
            TOTAL=$((PASSED_COUNT + FAILED_COUNT))
            FAILURES="$FAILED_COUNT"
        else
            # Fallback values - assume failure if no clear success
            TOTAL="1"
            FAILURES="1"
        fi
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
    if [ "$VERBOSE" = "YES" ]; then
        # In verbose mode (CI), show raw output without xcbeautify filtering
        # Use timeout to prevent hanging in CI
        if [ -n "$TIMEOUT_CMD" ]; then
            $TIMEOUT_CMD eval "$TEST_CMD"
            TEST_STATUS=$?
            # If timeout occurred, mark as failure
            if [ $TEST_STATUS -eq 124 ]; then
                echo "Tests timed out after 10 minutes"
                TEST_STATUS=1
            fi
        else
            # No timeout available, run without it
            eval "$TEST_CMD"
            TEST_STATUS=$?
        fi
    else
        # Local development, use xcbeautify for clean output
        eval "$TEST_CMD" | xcbeautify
        TEST_STATUS=${PIPESTATUS[0]}
    fi
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