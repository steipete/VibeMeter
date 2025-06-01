#!/bin/bash

# Script to fix trailing newline violations in Swift files

set -e

# Navigate to project root
cd "$(dirname "$0")/.."

echo "Fixing trailing newline violations..."

# Find all Swift files and ensure they have exactly one trailing newline
find . -name "*.swift" -type f ! -path "./Pods/*" ! -path "./Derived/*" ! -path "./.build/*" | while read -r file; do
    # Check if file ends with a newline
    if [ -n "$(tail -c1 "$file")" ]; then
        # File doesn't end with newline, add one
        echo "" >> "$file"
        echo "Added newline to: $file"
    fi
    
    # Remove multiple trailing newlines (keep only one)
    # This uses sed to remove blank lines at the end of file
    sed -i '' -e :a -e '/^\s*$/d;N;ba' "$file"
    echo "" >> "$file"  # Ensure exactly one newline
done

echo "✅ Trailing newline fixes complete!"