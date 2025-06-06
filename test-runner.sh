#!/bin/bash
set -euo pipefail

echo "Running VibeMeter test suite..."

# Run tests with a reasonable timeout and capture output
if xcodebuild test \
    -workspace VibeMeter.xcworkspace \
    -scheme VibeMeter \
    -configuration Debug \
    -quiet \
    -parallel-testing-enabled NO \
    -test-timeouts-enabled YES \
    -maximum-test-execution-time-allowance 300 \
    2>&1 | tee test-output.log; then
    echo "✅ All tests passed!"
    exit 0
else
    echo "❌ Some tests failed. Checking failures..."
    grep -E "(failed:|error:|FAILED|Test Case.*failed)" test-output.log | tail -30
    exit 1
fi