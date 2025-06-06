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
    # For Swift Testing, we need to use resultBundlePath and process it afterwards
    eval "$TEST_CMD" 2>&1 | tee test-output.log | xcbeautify
    TEST_STATUS=${PIPESTATUS[0]}
    
    # Convert xcresult to JUnit format if tests ran
    if [ -f "test-results.xcresult" ]; then
        echo -e "\n${YELLOW}Converting test results to JUnit format...${NC}"
        # Use xcresulttool or xcodebuild to export test results
        xcodebuild -resultBundlePath test-results.xcresult -resultBundleVersion 3 -exportResultBundlePath test-results.xcresult || true
        
        # For now, create a simple JUnit report based on test output
        if grep -q "Test run started" test-output.log; then
            # Extract test counts
            TOTAL=$(grep -E "Executed [0-9]+ test" test-output.log | tail -1 | sed -E 's/.*Executed ([0-9]+) test.*/\1/' || echo "0")
            FAILURES=$(grep -E "with [0-9]+ failure" test-output.log | tail -1 | sed -E 's/.*with ([0-9]+) failure.*/\1/' || echo "0")
            
            # Create JUnit XML
            cat > "$JUNIT_OUTPUT" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<testsuites name="VibeMeterTests" tests="${TOTAL}" failures="${FAILURES}">
  <testsuite name="VibeMeterTests" tests="${TOTAL}" failures="${FAILURES}">
    $(grep -E "✔|✗" test-output.log | while read -r line; do
        if [[ "$line" =~ ✔ ]]; then
            TEST_NAME=$(echo "$line" | sed -E 's/.*"(.*)".*/\1/')
            TIME=$(echo "$line" | sed -E 's/.*\(([0-9.]+) seconds\).*/\1/' || echo "0.0")
            echo "    <testcase name=\"$TEST_NAME\" time=\"$TIME\" />"
        elif [[ "$line" =~ ✗ ]]; then
            TEST_NAME=$(echo "$line" | sed -E 's/.*"(.*)".*/\1/')
            echo "    <testcase name=\"$TEST_NAME\"><failure message=\"Test failed\" /></testcase>"
        fi
    done)
  </testsuite>
</testsuites>
EOF
        else
            # No Swift Testing output, create empty report
            echo '<?xml version="1.0" encoding="UTF-8"?><testsuites name="VibeMeterTests" tests="0" failures="0" />' > "$JUNIT_OUTPUT"
        fi
    fi
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