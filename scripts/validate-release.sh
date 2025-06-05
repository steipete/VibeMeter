#!/bin/bash

# Release Validation Script for VibeMeter
# Checks if the project is ready for release
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "🔍 VibeMeter Release Validation"
echo "==============================="

# Check git status
echo ""
echo "📌 Git Status:"
if git diff-index --quiet HEAD --; then
    echo "   ✅ Working directory is clean"
else
    echo "   ⚠️  Uncommitted changes detected"
    git status --short
fi

# Check version info
echo ""
echo "📌 Version Information:"
MARKETING_VERSION=$(grep 'MARKETING_VERSION' "$PROJECT_ROOT/Project.swift" | sed 's/.*"MARKETING_VERSION": "\(.*\)".*/\1/')
BUILD_NUMBER=$(grep 'CURRENT_PROJECT_VERSION' "$PROJECT_ROOT/Project.swift" | sed 's/.*"CURRENT_PROJECT_VERSION": "\(.*\)".*/\1/')
BASE_VERSION=$(echo "$MARKETING_VERSION" | sed 's/-[a-zA-Z]*\.[0-9]*$//')

echo "   Marketing Version: $MARKETING_VERSION"
echo "   Base Version: $BASE_VERSION"
echo "   Build Number: $BUILD_NUMBER"

if [[ "$MARKETING_VERSION" != "$BASE_VERSION" ]]; then
    echo "   ⚠️  Marketing version contains pre-release suffix"
    echo "   Consider resetting to: $BASE_VERSION"
fi

# Check build numbers in appcasts
echo ""
echo "📌 Existing Build Numbers:"
USED_BUILD_NUMBERS=""
if [[ -f "$PROJECT_ROOT/appcast.xml" ]]; then
    STABLE_BUILDS=$(grep -E '<sparkle:version>[0-9]+</sparkle:version>' "$PROJECT_ROOT/appcast.xml" | sed 's/.*<sparkle:version>\([0-9]*\)<\/sparkle:version>.*/\1/' | sort -n)
    if [[ -n "$STABLE_BUILDS" ]]; then
        echo "   Stable releases:"
        echo "$STABLE_BUILDS" | while read -r build; do
            echo "      - Build $build"
        done
        USED_BUILD_NUMBERS+="$STABLE_BUILDS "
    fi
fi

if [[ -f "$PROJECT_ROOT/appcast-prerelease.xml" ]]; then
    PRERELEASE_BUILDS=$(grep -E '<sparkle:version>[0-9]+</sparkle:version>' "$PROJECT_ROOT/appcast-prerelease.xml" | sed 's/.*<sparkle:version>\([0-9]*\)<\/sparkle:version>.*/\1/' | sort -n)
    if [[ -n "$PRERELEASE_BUILDS" ]]; then
        echo "   Pre-release versions:"
        echo "$PRERELEASE_BUILDS" | while read -r build; do
            echo "      - Build $build"
        done
        USED_BUILD_NUMBERS+="$PRERELEASE_BUILDS"
    fi
fi

# Find highest build
HIGHEST_BUILD=0
for EXISTING_BUILD in $USED_BUILD_NUMBERS; do
    if [[ "$EXISTING_BUILD" -gt "$HIGHEST_BUILD" ]]; then
        HIGHEST_BUILD=$EXISTING_BUILD
    fi
done

echo ""
echo "   Highest existing build: $HIGHEST_BUILD"
echo "   Current build: $BUILD_NUMBER"

if [[ "$BUILD_NUMBER" -le "$HIGHEST_BUILD" ]]; then
    echo "   ❌ Build number must be > $HIGHEST_BUILD"
    echo "   Suggested next build: $((HIGHEST_BUILD + 1))"
else
    echo "   ✅ Build number is valid"
fi

# Check for duplicate builds
for EXISTING_BUILD in $USED_BUILD_NUMBERS; do
    if [[ "$BUILD_NUMBER" == "$EXISTING_BUILD" ]]; then
        echo "   ❌ Build number $BUILD_NUMBER already exists!"
        break
    fi
done

# Check GitHub releases
echo ""
echo "📌 GitHub Releases:"
RELEASE_COUNT=$(gh release list --limit 10 2>/dev/null | wc -l | tr -d ' ')
echo "   Recent releases: $RELEASE_COUNT"
gh release list --limit 5 2>/dev/null || echo "   Unable to fetch releases"

# Check build directory
echo ""
echo "📌 Build Directory:"
if [[ -d "$PROJECT_ROOT/build" ]]; then
    echo "   ⚠️  Build directory exists (will be cleaned automatically)"
    # Count files in build directory
    FILE_COUNT=$(find "$PROJECT_ROOT/build" -type f 2>/dev/null | wc -l | tr -d ' ')
    echo "   Files in build: $FILE_COUNT"
else
    echo "   ✅ Build directory is clean"
fi

# Summary
echo ""
echo "📌 Release Readiness Summary:"
echo "==============================="

READY=true

if [[ "$BUILD_NUMBER" -le "$HIGHEST_BUILD" ]]; then
    echo "❌ Build number needs to be incremented"
    READY=false
else
    echo "✅ Build number is valid"
fi

if [[ "$MARKETING_VERSION" != "$BASE_VERSION" ]]; then
    echo "⚠️  Marketing version has pre-release suffix (scripts will handle this)"
else
    echo "✅ Marketing version is clean"
fi

if ! git diff-index --quiet HEAD --; then
    echo "⚠️  Uncommitted changes exist"
else
    echo "✅ Git working directory is clean"
fi

echo ""
if [[ "$READY" == "true" ]]; then
    echo "✅ Ready for release!"
else
    echo "❌ Issues need to be resolved before release"
fi

echo ""
echo "Next steps:"
echo "1. Fix any issues identified above"
echo "2. For stable release: ./scripts/release.sh --stable"
echo "3. For pre-release: ./scripts/release.sh --prerelease beta 2"