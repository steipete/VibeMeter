#!/bin/bash

# =============================================================================
# VibeMeter Code Linting Script
# =============================================================================
#
# Runs SwiftLint analysis on the entire project to identify potential issues,
# style violations, and code quality problems.
#
# USAGE: ./scripts/lint.sh
# DEPENDENCIES: SwiftLint (brew install swiftlint)
# =============================================================================

set -e

# Navigate to project root
cd "$(dirname "$0")/.."

# Check if swiftlint is installed
if ! command -v swiftlint &> /dev/null; then
    echo "SwiftLint is not installed. Please install it using:"
    echo "  brew install swiftlint"
    exit 1
fi

echo "Running SwiftLint..."
swiftlint

echo "✅ SwiftLint complete!"