#!/bin/bash

# Fix trailing newlines in Swift files
# This script ensures all Swift files end with exactly one newline character

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "🔧 Fixing trailing newlines in Swift files..."

# Find all Swift files, excluding build directories and generated files
files=$(find . -name "*.swift" \
    -not -path "./build/*" \
    -not -path "./.build/*" \
    -not -path "./Derived/*" \
    -type f)

fixed_count=0
total_count=0

for file in $files; do
    total_count=$((total_count + 1))
    
    # Check if file is missing final newline or has multiple trailing newlines
    if [ ! -s "$file" ]; then
        # Empty file - add single newline
        echo "" > "$file"
        echo -e "${YELLOW}Fixed empty file: $file${NC}"
        fixed_count=$((fixed_count + 1))
    elif [ -z "$(tail -c 1 "$file")" ]; then
        # File has final newline, check for multiple trailing newlines
        # Remove all trailing newlines and add exactly one
        perl -i -pe 'chomp if eof' "$file"
        echo "" >> "$file"
        echo -e "${GREEN}Fixed multiple trailing newlines: $file${NC}"
        fixed_count=$((fixed_count + 1))
    else
        # File is missing final newline
        echo "" >> "$file"
        echo -e "${GREEN}Added missing trailing newline: $file${NC}"
        fixed_count=$((fixed_count + 1))
    fi
done

if [ $fixed_count -eq 0 ]; then
    echo -e "${GREEN}✅ All $total_count Swift files already have proper trailing newlines!${NC}"
else
    echo -e "${GREEN}✅ Fixed trailing newlines in $fixed_count out of $total_count Swift files!${NC}"
fi