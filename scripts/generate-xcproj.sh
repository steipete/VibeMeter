#!/bin/bash

set -e

# Change to the project directory
cd "$(dirname "$0")/.."

if [[ "${CI:-}" != "true" ]]; then
    echo "Quitting Xcode..."
    osascript -e 'tell application "Xcode" to quit' 2>/dev/null || true
fi

echo "Generating Xcode project with Tuist..."
tuist generate --no-open

echo "Patching generated files for Swift 6 Sendable compliance..."

# Function to patch Info.plist accessor files
patch_info_plist_accessors() {
    local file=$1
    
    if [ -f "$file" ]; then
        echo "Patching $file..."
        
        # Replace [String: Any] with [String: Bool] for NSAppTransportSecurity
        sed -i '' 's/\[String: Any\]/[String: Bool]/g' "$file"
        
        # Replace [[String: Any]] with [[String: Sendable]] for arrays
        sed -i '' 's/\[\[String: Any\]\]/[[String: Sendable]]/g' "$file"
        
        # Update the ResourceLoader struct to handle typed dictionaries
        # Replace dictionary<String, Any> with dictionary<String, Bool>
        sed -i '' 's/dictionary<String, Any>/dictionary<String, Bool>/g' "$file"
        
        # Replace arrayOfDictionaries<String, Any> with arrayOfDictionaries<String, Sendable>
        sed -i '' 's/arrayOfDictionaries<String, Any>/arrayOfDictionaries<String, Sendable>/g' "$file"
    fi
}

# Find and patch all Info.plist accessor files
find . -path "*/Derived/InfoPlists+*" -name "*.swift" | while read -r file; do
    patch_info_plist_accessors "$file"
done

if [[ "${CI:-}" != "true" ]]; then
    echo "Opening Xcode workspace..."
    open VibeMeter.xcworkspace
fi

echo "✅ Xcode project generated and patched successfully!"