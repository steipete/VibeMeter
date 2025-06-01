#!/bin/bash

# Script to run SwiftLint on the project

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