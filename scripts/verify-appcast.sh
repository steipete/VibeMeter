#!/bin/bash

# Appcast Verification Script for VibeMeter
# Validates appcast XML files for common issues
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "🔍 VibeMeter Appcast Verification"
echo "================================="
echo ""

ISSUES=0

# Function to validate an appcast file
validate_appcast() {
    local APPCAST_FILE="$1"
    local APPCAST_NAME="$2"
    
    if [[ ! -f "$APPCAST_FILE" ]]; then
        echo -e "${YELLOW}⚠️  $APPCAST_NAME not found${NC}"
        return
    fi
    
    echo "📌 Checking $APPCAST_NAME:"
    
    # Check if valid XML
    if xmllint --noout "$APPCAST_FILE" 2>/dev/null; then
        echo -e "${GREEN}   ✅ Valid XML syntax${NC}"
    else
        echo -e "${RED}   ❌ Invalid XML syntax${NC}"
        xmllint --noout "$APPCAST_FILE" 2>&1 | sed 's/^/      /'
        ((ISSUES++))
        return
    fi
    
    # Extract all items
    ITEMS=$(xmllint --xpath "//item" "$APPCAST_FILE" 2>/dev/null || echo "")
    ITEM_COUNT=$(echo "$ITEMS" | grep -c "<item>" || echo "0")
    echo "   Found $ITEM_COUNT release(s)"
    
    if [[ $ITEM_COUNT -eq 0 ]]; then
        echo -e "${YELLOW}   ⚠️  No releases found in appcast${NC}"
        return
    fi
    
    # Parse each item
    BUILDS=()
    VERSIONS=()
    
    for i in $(seq 1 $ITEM_COUNT); do
        # Extract version info
        VERSION=$(xmllint --xpath "string(//item[$i]/enclosure/@sparkle:shortVersionString)" "$APPCAST_FILE" 2>/dev/null || echo "")
        BUILD=$(xmllint --xpath "string(//item[$i]/enclosure/@sparkle:version)" "$APPCAST_FILE" 2>/dev/null || echo "")
        URL=$(xmllint --xpath "string(//item[$i]/enclosure/@url)" "$APPCAST_FILE" 2>/dev/null || echo "")
        LENGTH=$(xmllint --xpath "string(//item[$i]/enclosure/@length)" "$APPCAST_FILE" 2>/dev/null || echo "")
        SIGNATURE=$(xmllint --xpath "string(//item[$i]/enclosure/@sparkle:edSignature)" "$APPCAST_FILE" 2>/dev/null || echo "")
        
        echo ""
        echo "   Release #$i:"
        echo "      Version: $VERSION"
        echo "      Build: $BUILD"
        
        # Validate build number
        if [[ -z "$BUILD" ]]; then
            echo -e "${RED}      ❌ Missing build number${NC}"
            ((ISSUES++))
        elif ! [[ "$BUILD" =~ ^[0-9]+$ ]]; then
            echo -e "${RED}      ❌ Invalid build number: $BUILD${NC}"
            ((ISSUES++))
        else
            echo -e "${GREEN}      ✅ Valid build number${NC}"
            BUILDS+=("$BUILD")
        fi
        
        # Validate URL
        if [[ -z "$URL" ]]; then
            echo -e "${RED}      ❌ Missing download URL${NC}"
            ((ISSUES++))
        elif [[ "$URL" =~ ^https://github.com/steipete/VibeMeter/releases/download/ ]]; then
            echo -e "${GREEN}      ✅ Valid GitHub release URL${NC}"
            
            # Check if release exists on GitHub
            RELEASE_TAG=$(echo "$URL" | sed -n 's|.*/download/\([^/]*\)/.*|\1|p')
            if gh release view "$RELEASE_TAG" &>/dev/null; then
                echo -e "${GREEN}      ✅ GitHub release exists${NC}"
            else
                echo -e "${RED}      ❌ GitHub release not found: $RELEASE_TAG${NC}"
                ((ISSUES++))
            fi
        else
            echo -e "${YELLOW}      ⚠️  Non-GitHub URL: $URL${NC}"
        fi
        
        # Validate signature
        if [[ -z "$SIGNATURE" ]]; then
            echo -e "${RED}      ❌ Missing EdDSA signature${NC}"
            ((ISSUES++))
        else
            echo -e "${GREEN}      ✅ EdDSA signature present${NC}"
        fi
        
        # Validate file size
        if [[ -z "$LENGTH" ]]; then
            echo -e "${RED}      ❌ Missing file size${NC}"
            ((ISSUES++))
        elif ! [[ "$LENGTH" =~ ^[0-9]+$ ]]; then
            echo -e "${RED}      ❌ Invalid file size: $LENGTH${NC}"
            ((ISSUES++))
        else
            echo -e "${GREEN}      ✅ File size: $(($LENGTH / 1024 / 1024)) MB${NC}"
        fi
        
        VERSIONS+=("$VERSION")
    done
    
    # Check for duplicate build numbers
    echo ""
    echo "   Build Number Analysis:"
    UNIQUE_BUILDS=$(printf '%s\n' "${BUILDS[@]}" | sort -u | wc -l)
    TOTAL_BUILDS=${#BUILDS[@]}
    
    if [[ $UNIQUE_BUILDS -ne $TOTAL_BUILDS ]]; then
        echo -e "${RED}   ❌ Duplicate build numbers found!${NC}"
        printf '%s\n' "${BUILDS[@]}" | sort | uniq -d | while read -r DUP; do
            echo "      Duplicate: $DUP"
        done
        ((ISSUES++))
    else
        echo -e "${GREEN}   ✅ All build numbers are unique${NC}"
    fi
    
    # Check build number ordering
    SORTED_BUILDS=$(printf '%s\n' "${BUILDS[@]}" | sort -nr)
    CURRENT_BUILDS=$(printf '%s\n' "${BUILDS[@]}")
    
    if [[ "$SORTED_BUILDS" == "$CURRENT_BUILDS" ]]; then
        echo -e "${GREEN}   ✅ Build numbers are in descending order (newest first)${NC}"
    else
        echo -e "${YELLOW}   ⚠️  Build numbers are not in descending order${NC}"
        echo "      Expected order: $(echo $SORTED_BUILDS | tr '\n' ' ')"
        echo "      Current order: $(echo $CURRENT_BUILDS | tr '\n' ' ')"
    fi
    
    echo ""
}

# Validate both appcast files
validate_appcast "$PROJECT_ROOT/appcast.xml" "Stable appcast"
echo ""
validate_appcast "$PROJECT_ROOT/appcast-prerelease.xml" "Pre-release appcast"

# Cross-validation between appcasts
echo ""
echo "📌 Cross-Validation:"

if [[ -f "$PROJECT_ROOT/appcast.xml" ]] && [[ -f "$PROJECT_ROOT/appcast-prerelease.xml" ]]; then
    # Get all build numbers from both files
    ALL_BUILDS=""
    if [[ -f "$PROJECT_ROOT/appcast.xml" ]]; then
        ALL_BUILDS+=$(grep -o 'sparkle:version="[0-9]*"' "$PROJECT_ROOT/appcast.xml" | sed 's/sparkle:version="//g' | sed 's/"//g' | tr '\n' ' ')
    fi
    if [[ -f "$PROJECT_ROOT/appcast-prerelease.xml" ]]; then
        ALL_BUILDS+=" "
        ALL_BUILDS+=$(grep -o 'sparkle:version="[0-9]*"' "$PROJECT_ROOT/appcast-prerelease.xml" | sed 's/sparkle:version="//g' | sed 's/"//g' | tr '\n' ' ')
    fi
    
    # Check for duplicates across files
    UNIQUE_ALL=$(echo $ALL_BUILDS | tr ' ' '\n' | sort -u | wc -l)
    TOTAL_ALL=$(echo $ALL_BUILDS | tr ' ' '\n' | wc -l)
    
    if [[ $UNIQUE_ALL -ne $TOTAL_ALL ]]; then
        echo -e "${RED}   ❌ Build numbers are duplicated between appcast files!${NC}"
        echo $ALL_BUILDS | tr ' ' '\n' | sort | uniq -d | while read -r DUP; do
            echo "      Duplicate build: $DUP"
        done
        ((ISSUES++))
    else
        echo -e "${GREEN}   ✅ No build number conflicts between appcast files${NC}"
    fi
fi

# Summary
echo ""
echo "📊 Appcast Verification Summary:"
echo "================================"

if [[ $ISSUES -eq 0 ]]; then
    echo -e "${GREEN}✅ All appcast checks passed!${NC}"
    echo ""
    echo "Your appcast files are properly formatted."
else
    echo -e "${RED}❌ Found $ISSUES issue(s)${NC}"
    echo ""
    echo "Please fix these issues to ensure proper updates."
fi

# Suggestions
echo ""
echo "💡 Tips:"
echo "   - Build numbers must be unique across ALL releases"
echo "   - Build numbers should increase monotonically"
echo "   - Newest releases should appear first in appcast"
echo "   - All releases need EdDSA signatures"
echo "   - GitHub releases must exist before appcast update"