#!/bin/bash

# =============================================================================
# VibeMeter Code Formatting Script
# =============================================================================
#
# Formats all Swift files in the project using SwiftFormat with project-specific
# configuration. This ensures consistent code style across the entire codebase.
#
# USAGE: ./scripts/format.sh
# DEPENDENCIES: SwiftFormat (brew install swiftformat)
# =============================================================================

set -e

# Navigate to project root
cd "$(dirname "$0")/.."

# Check if swiftformat is installed
if ! command -v swiftformat &> /dev/null; then
    echo "SwiftFormat is not installed. Please install it using:"
    echo "  brew install swiftformat"
    exit 1
fi

echo "Running SwiftFormat..."
swiftformat . --verbose

echo "✅ Swift formatting complete!"