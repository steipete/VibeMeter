#!/bin/bash
set -e

PROJECT_FILE="/Users/steipete/Projects/VibeMeter/VibeMeter.xcodeproj/project.pbxproj"

echo "Removing Tuist references from Xcode project..."

# Remove lines containing TuistAssets or TuistBundle
sed -i '' '/TuistAssets+VibeMeter.swift/d' "$PROJECT_FILE"
sed -i '' '/TuistBundle+VibeMeter.swift/d' "$PROJECT_FILE"

echo "Tuist references removed successfully!"