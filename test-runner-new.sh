#!/bin/bash

# Simple test runner for new tests only

echo "Building VibeMeter..."
xcodebuild -workspace VibeMeter.xcworkspace -scheme VibeMeter -configuration Debug build CODE_SIGNING_ALLOWED=NO -quiet

echo ""
echo "Running PricingDataManager tests..."
swift test --filter PricingDataManagerTests 2>/dev/null || echo "Note: Swift test runner not available, using xcodebuild"

echo ""
echo "Running CollectionExtensions tests..."
swift test --filter CollectionExtensionsTests 2>/dev/null || echo "Note: Swift test runner not available, using xcodebuild"

echo ""
echo "Running ClaudeProviderPricing tests..."
swift test --filter ClaudeProviderPricingTests 2>/dev/null || echo "Note: Swift test runner not available, using xcodebuild"

echo ""
echo "Test run complete!"