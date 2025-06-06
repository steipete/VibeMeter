#!/bin/bash

# test-by-tag.sh - Run tests filtered by tags
# Usage: ./scripts/test-by-tag.sh [options]

set -euo pipefail

# Default values
TAGS=""
SKIP_TAGS=""
CONFIGURATION="Debug"
VERBOSE=false

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

function usage() {
    cat << EOF
Usage: $(basename "$0") [options]

Run VibeMeter tests filtered by tags.

Options:
    -t, --tag TAG         Run tests with specific tag (can be specified multiple times)
    -s, --skip TAG        Skip tests with specific tag (can be specified multiple times)
    -c, --configuration   Build configuration (Debug/Release) [default: Debug]
    -v, --verbose         Show verbose output
    -h, --help           Show this help message

Available tags:
    Test Speed:
        fast              Tests that execute quickly (< 100ms)
        slow              Tests that take longer (> 100ms)
    
    Test Types:
        unit              Pure unit tests with mocked dependencies
        integration       Tests that integrate multiple components
        network           Tests that make actual network calls
    
    Feature Areas:
        currency          Currency conversion and formatting tests
        provider          Provider-specific tests (Cursor, etc.)
        authentication    Auth and token management tests
        ui                UI component tests
        settings          Settings and preferences tests
        notifications     Notification system tests
        background        Background processing tests
    
    Environment:
        requiresNetwork   Tests that require internet connectivity
        requiresKeychain  Tests that interact with Keychain
        requiresOS        Tests that require specific OS features
    
    Priority:
        critical          Critical tests that must always pass
        edgeCase          Tests for edge cases and error conditions
        performance       Performance-related tests

Examples:
    # Run only fast unit tests
    $(basename "$0") --tag fast --tag unit
    
    # Run all tests except slow ones
    $(basename "$0") --skip slow
    
    # Run critical currency tests
    $(basename "$0") --tag critical --tag currency
    
    # Run integration tests but skip network-dependent ones
    $(basename "$0") --tag integration --skip network

EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -t|--tag)
            TAGS="$TAGS --filter .$2"
            shift 2
            ;;
        -s|--skip)
            SKIP_TAGS="$SKIP_TAGS --skip .$2"
            shift 2
            ;;
        -c|--configuration)
            CONFIGURATION="$2"
            shift 2
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            usage
            exit 1
            ;;
    esac
done

# Check if we're in the project root
if [[ ! -f "Project.swift" ]]; then
    echo -e "${RED}Error: Must be run from the project root directory${NC}"
    exit 1
fi

# Generate Xcode project if needed
if [[ ! -d "VibeMeter.xcworkspace" ]]; then
    echo -e "${YELLOW}Generating Xcode project...${NC}"
    ./scripts/generate-xcproj.sh
fi

# Build the test command
TEST_CMD="xcodebuild -workspace VibeMeter.xcworkspace -scheme VibeMeter -configuration $CONFIGURATION"

# Add test action
TEST_CMD="$TEST_CMD test"

# Add tag filters
if [[ -n "$TAGS" ]] || [[ -n "$SKIP_TAGS" ]]; then
    TEST_CMD="$TEST_CMD TEST_TAGS=\"$TAGS $SKIP_TAGS\""
fi

# Add quiet flag unless verbose
if [[ "$VERBOSE" != true ]]; then
    TEST_CMD="$TEST_CMD -quiet"
fi

# Display what we're running
echo -e "${GREEN}Running tests with configuration: $CONFIGURATION${NC}"
if [[ -n "$TAGS" ]]; then
    echo -e "${GREEN}Including tags:${NC}$TAGS"
fi
if [[ -n "$SKIP_TAGS" ]]; then
    echo -e "${YELLOW}Skipping tags:${NC}$SKIP_TAGS"
fi
echo ""

# Run the tests
if [[ "$VERBOSE" == true ]]; then
    echo -e "${YELLOW}Command: $TEST_CMD${NC}"
    echo ""
fi

eval $TEST_CMD

# Check the result
if [[ $? -eq 0 ]]; then
    echo -e "\n${GREEN}✅ Tests passed!${NC}"
else
    echo -e "\n${RED}❌ Tests failed!${NC}"
    exit 1
fi