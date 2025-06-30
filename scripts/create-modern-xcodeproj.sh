#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo "Creating modern Xcode project with folder references..."

# Backup existing project
if [ -d "$PROJECT_DIR/VibeMeter.xcodeproj" ]; then
    echo "Backing up existing project..."
    mv "$PROJECT_DIR/VibeMeter.xcodeproj" "$PROJECT_DIR/VibeMeter.xcodeproj.old"
fi

# Create new project using xcodegen or manually
# Since we don't have xcodegen, we'll need to create it manually in Xcode

echo "Please follow these steps to create a modern Xcode project:"
echo ""
echo "1. Open Xcode"
echo "2. Create a new project (File > New > Project)"
echo "3. Choose macOS > App"
echo "4. Configure:"
echo "   - Product Name: VibeMeter"
echo "   - Team: Peter Steinberger"
echo "   - Organization Identifier: com.steipete"
echo "   - Bundle Identifier: com.steipete.vibemeter"
echo "   - Language: Swift"
echo "   - User Interface: SwiftUI"
echo "   - IMPORTANT: Check 'Use Core Data' and 'Include Tests' (we'll remove Core Data later)"
echo ""
echo "5. Save the project in: $PROJECT_DIR (replace the existing one)"
echo ""
echo "6. In the new project:"
echo "   - Delete the auto-generated files (ContentView.swift, etc.)"
echo "   - Delete the .xcdatamodeld file"
echo "   - Remove Core Data code from the app delegate"
echo ""
echo "7. Add folder references:"
echo "   - Right-click on the project in navigator"
echo "   - Choose 'Add Files to VibeMeter...'"
echo "   - Select the VibeMeter folder"
echo "   - IMPORTANT: Choose 'Create folder references' (not groups)"
echo "   - Check 'VibeMeter' target"
echo ""
echo "8. Configure build settings:"
echo "   - Set deployment target to macOS 15.0"
echo "   - Set Swift Language Version to 6.0"
echo "   - Add xcconfig files to project settings"
echo ""
echo "9. Add Swift Package Dependencies:"
echo "   - File > Add Package Dependencies"
echo "   - Add the packages from Package.swift"
echo ""
echo "Press Enter when you've completed these steps..."
read

echo "Project setup complete!"