#!/bin/bash

# Script to format all Swift files in the project

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