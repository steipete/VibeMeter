#!/bin/bash

# Universal Release Script for VibeMeter
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Usage function
usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Create VibeMeter releases (stable or pre-release)"
    echo ""
    echo "OPTIONS:"
    echo "  --stable                Create a stable release"
    echo "  --prerelease TYPE NUM   Create a pre-release (TYPE: alpha, beta, rc; NUM: 1, 2, 3...)"
    echo "  --help                  Show this help message"
    echo ""
    echo "EXAMPLES:"
    echo "  $0 --stable                    # Create stable release"
    echo "  $0 --prerelease beta 1         # Create 0.9.1-beta.1"
    echo "  $0 --prerelease alpha 2        # Create 0.9.1-alpha.2"
    echo "  $0 --prerelease rc 1           # Create 0.9.1-rc.1"
    echo ""
}

# Parse arguments
RELEASE_TYPE=""
PRERELEASE_TYPE=""
PRERELEASE_NUMBER=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --stable)
            RELEASE_TYPE="stable"
            shift
            ;;
        --prerelease)
            RELEASE_TYPE="prerelease"
            if [[ $# -lt 3 ]]; then
                echo "❌ --prerelease requires TYPE and NUMBER arguments"
                usage
                exit 1
            fi
            PRERELEASE_TYPE="$2"
            PRERELEASE_NUMBER="$3"
            shift 3
            ;;
        --help)
            usage
            exit 0
            ;;
        *)
            echo "❌ Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

# Validate arguments
if [[ -z "$RELEASE_TYPE" ]]; then
    echo "❌ Must specify either --stable or --prerelease"
    usage
    exit 1
fi

# Get current version info
MARKETING_VERSION=$(grep 'MARKETING_VERSION' "$PROJECT_ROOT/Project.swift" | sed 's/.*"MARKETING_VERSION": "\(.*\)".*/\1/')
BUILD_NUMBER=$(grep 'CURRENT_PROJECT_VERSION' "$PROJECT_ROOT/Project.swift" | sed 's/.*"CURRENT_PROJECT_VERSION": "\(.*\)".*/\1/')

# Extract base version without pre-release suffix if present
BASE_VERSION=$(echo "$MARKETING_VERSION" | sed 's/-[a-zA-Z]*\.[0-9]*$//')

echo "🚀 VibeMeter Release Script"
echo "📦 Base version: $BASE_VERSION"
echo "🔢 Build number: $BUILD_NUMBER"
echo ""

# Check for uncommitted changes
if ! git diff-index --quiet HEAD --; then
    echo "⚠️  Warning: You have uncommitted changes"
    read -p "Continue anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "❌ Aborted"
        exit 1
    fi
fi

# Perform the appropriate release
case "$RELEASE_TYPE" in
    stable)
        echo "📦 Creating stable release v$BASE_VERSION..."
        cd "$PROJECT_ROOT"
        ./scripts/create-github-release.sh
        ;;
    prerelease)
        FULL_VERSION="$BASE_VERSION-$PRERELEASE_TYPE.$PRERELEASE_NUMBER"
        echo "📦 Creating pre-release v$FULL_VERSION..."
        cd "$PROJECT_ROOT"
        ./scripts/create-prerelease.sh "$PRERELEASE_TYPE" "$PRERELEASE_NUMBER"
        ;;
esac

echo ""
echo "✅ Release completed successfully!"
echo ""
echo "🔗 View releases: https://github.com/steipete/VibeMeter/releases"
echo "📡 Don't forget to:"
echo "   1. Commit and push updated appcast files"
echo "   2. Test the update mechanism"
echo "   3. Announce the release"