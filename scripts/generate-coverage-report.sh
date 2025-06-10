#!/bin/bash

# Script to generate code coverage report for VibeMeter
# This script runs tests with coverage enabled and generates reports

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🧪 VibeMeter Code Coverage Report Generator${NC}"
echo "========================================="

# Configuration
SCHEME="VibeMeter"
WORKSPACE="VibeMeter.xcworkspace"
DERIVED_DATA_PATH="build/DerivedData"
COVERAGE_OUTPUT_DIR="build/coverage"
XCRESULT_PATH=""

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --html)
            GENERATE_HTML=true
            shift
            ;;
        --json)
            GENERATE_JSON=true
            shift
            ;;
        --open)
            OPEN_REPORT=true
            shift
            ;;
        --min-coverage)
            MIN_COVERAGE=$2
            shift 2
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            exit 1
            ;;
    esac
done

# Set defaults if not specified
GENERATE_HTML=${GENERATE_HTML:-true}
GENERATE_JSON=${GENERATE_JSON:-false}
OPEN_REPORT=${OPEN_REPORT:-false}
MIN_COVERAGE=${MIN_COVERAGE:-0}

# Clean previous coverage data
echo -e "${YELLOW}Cleaning previous coverage data...${NC}"
rm -rf "$COVERAGE_OUTPUT_DIR"
mkdir -p "$COVERAGE_OUTPUT_DIR"

# Run tests with coverage enabled
echo -e "${YELLOW}Running tests with code coverage...${NC}"
xcodebuild test \
    -workspace "$WORKSPACE" \
    -scheme "$SCHEME" \
    -configuration Debug \
    -derivedDataPath "$DERIVED_DATA_PATH" \
    -enableCodeCoverage YES \
    -resultBundlePath "$COVERAGE_OUTPUT_DIR/TestResults.xcresult" \
    -quiet || {
    echo -e "${RED}Tests failed!${NC}"
    exit 1
}

XCRESULT_PATH="$COVERAGE_OUTPUT_DIR/TestResults.xcresult"

# Extract coverage data
echo -e "${YELLOW}Extracting coverage data...${NC}"
xcrun xccov view --report --only-targets "$XCRESULT_PATH" > "$COVERAGE_OUTPUT_DIR/coverage.txt"

# Generate JSON report if requested
if [ "$GENERATE_JSON" = true ]; then
    echo -e "${YELLOW}Generating JSON coverage report...${NC}"
    xcrun xccov view --report --json "$XCRESULT_PATH" > "$COVERAGE_OUTPUT_DIR/coverage.json"
fi

# Generate HTML report if requested
if [ "$GENERATE_HTML" = true ]; then
    echo -e "${YELLOW}Generating HTML coverage report...${NC}"
    
    # Check if xcov is installed
    if ! command -v xcov &> /dev/null; then
        echo -e "${YELLOW}xcov not found. Installing via gem...${NC}"
        sudo gem install xcov
    fi
    
    # Create xcov configuration
    cat > "$COVERAGE_OUTPUT_DIR/.xcov.yml" <<EOF
workspace: "$WORKSPACE"
scheme: "$SCHEME"
output_directory: "$COVERAGE_OUTPUT_DIR/html"
derived_data_path: "$DERIVED_DATA_PATH"
minimum_coverage_percentage: $MIN_COVERAGE
ignore_file_path:
  - "VibeMeterTests/*"
  - "*/PreviewHelpers/*"
  - "*/TestUtilities/*"
  - "*/Mocks/*"
EOF
    
    # Generate HTML report
    cd "$COVERAGE_OUTPUT_DIR"
    xcov || true
    cd - > /dev/null
fi

# Parse coverage percentage
COVERAGE_PERCENT=$(grep "VibeMeter.app" "$COVERAGE_OUTPUT_DIR/coverage.txt" | awk '{print $3}' | sed 's/%//')

# Display summary
echo ""
echo -e "${GREEN}✅ Code Coverage Report Generated${NC}"
echo "================================="
echo -e "Overall Coverage: ${BLUE}${COVERAGE_PERCENT}%${NC}"
echo ""

# Show file-level coverage
echo "File Coverage Summary:"
echo "---------------------"
grep -E "\.swift" "$COVERAGE_OUTPUT_DIR/coverage.txt" | grep -v "Test" | sort -k3 -nr | head -20

# Check minimum coverage
if [ -n "$MIN_COVERAGE" ] && [ "$MIN_COVERAGE" -gt 0 ]; then
    if (( $(echo "$COVERAGE_PERCENT < $MIN_COVERAGE" | bc -l) )); then
        echo ""
        echo -e "${RED}❌ Coverage ${COVERAGE_PERCENT}% is below minimum required ${MIN_COVERAGE}%${NC}"
        exit 1
    else
        echo ""
        echo -e "${GREEN}✅ Coverage ${COVERAGE_PERCENT}% meets minimum required ${MIN_COVERAGE}%${NC}"
    fi
fi

# Output locations
echo ""
echo "Reports saved to:"
echo -e "  Text:  ${BLUE}$COVERAGE_OUTPUT_DIR/coverage.txt${NC}"
if [ "$GENERATE_JSON" = true ]; then
    echo -e "  JSON:  ${BLUE}$COVERAGE_OUTPUT_DIR/coverage.json${NC}"
fi
if [ "$GENERATE_HTML" = true ] && [ -d "$COVERAGE_OUTPUT_DIR/html" ]; then
    echo -e "  HTML:  ${BLUE}$COVERAGE_OUTPUT_DIR/html/index.html${NC}"
    
    if [ "$OPEN_REPORT" = true ]; then
        echo ""
        echo -e "${YELLOW}Opening HTML report...${NC}"
        open "$COVERAGE_OUTPUT_DIR/html/index.html"
    fi
fi

echo ""
echo -e "${GREEN}✨ Done!${NC}"