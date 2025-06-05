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
    
    # Count items
    ITEM_COUNT=$(grep -c "<item>" "$APPCAST_FILE" 2>/dev/null || true)
    ITEM_COUNT=${ITEM_COUNT:-0}
    echo "   Found $ITEM_COUNT release(s)"
    
    if [[ $ITEM_COUNT -eq 0 ]]; then
        echo -e "${YELLOW}   ⚠️  No releases found in appcast${NC}"
        return
    fi
    
    # Extract build numbers and versions
    BUILDS=($(grep -o '<sparkle:version>[0-9]*</sparkle:version>' "$APPCAST_FILE" | sed 's/<[^>]*>//g'))
    VERSIONS=($(grep -o '<sparkle:shortVersionString>[^<]*</sparkle:shortVersionString>' "$APPCAST_FILE" | sed 's/<[^>]*>//g'))
    URLS=($(grep -o 'url="[^"]*"' "$APPCAST_FILE" | sed 's/url="//;s/"//'))
    SIGNATURES=($(grep -o 'sparkle:edSignature="[^"]*"' "$APPCAST_FILE" | sed 's/sparkle:edSignature="//;s/"//'))
    
    echo ""
    for i in "${!BUILDS[@]}"; do
        echo "   Release #$((i+1)):"
        echo "      Version: ${VERSIONS[$i]:-<missing>}"
        echo "      Build: ${BUILDS[$i]:-<missing>}"
        
        # Validate build number
        if [[ -z "${BUILDS[$i]:-}" ]]; then
            echo -e "${RED}      ❌ Missing build number${NC}"
            ((ISSUES++))
        elif ! [[ "${BUILDS[$i]}" =~ ^[0-9]+$ ]]; then
            echo -e "${RED}      ❌ Invalid build number: ${BUILDS[$i]}${NC}"
            ((ISSUES++))
        else
            echo -e "${GREEN}      ✅ Valid build number${NC}"
        fi
        
        # Validate URL
        if [[ -z "${URLS[$i]:-}" ]]; then
            echo -e "${RED}      ❌ Missing download URL${NC}"
            ((ISSUES++))
        elif [[ "${URLS[$i]}" =~ ^https://github.com/steipete/VibeMeter/releases/download/ ]]; then
            echo -e "${GREEN}      ✅ Valid GitHub release URL${NC}"
            
            # Check if release exists on GitHub
            RELEASE_TAG=$(echo "${URLS[$i]}" | sed -n 's|.*/download/\([^/]*\)/.*|\1|p')
            if gh release view "$RELEASE_TAG" &>/dev/null; then
                echo -e "${GREEN}      ✅ GitHub release exists${NC}"
            else
                echo -e "${RED}      ❌ GitHub release not found: $RELEASE_TAG${NC}"
                ((ISSUES++))
            fi
        else
            echo -e "${YELLOW}      ⚠️  Non-GitHub URL: ${URLS[$i]}${NC}"
        fi
        
        # Validate signature
        if [[ -z "${SIGNATURES[$i]:-}" ]]; then
            echo -e "${RED}      ❌ Missing EdDSA signature${NC}"
            ((ISSUES++))
        else
            echo -e "${GREEN}      ✅ EdDSA signature present${NC}"
        fi
        echo ""
    done
    
    # Check for duplicate build numbers
    if [[ ${#BUILDS[@]} -gt 0 ]]; then
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
        SORTED_BUILDS=($(printf '%s\n' "${BUILDS[@]}" | sort -nr))
        if [[ "${SORTED_BUILDS[*]}" == "${BUILDS[*]}" ]]; then
            echo -e "${GREEN}   ✅ Build numbers are in descending order (newest first)${NC}"
        else
            echo -e "${YELLOW}   ⚠️  Build numbers are not in descending order${NC}"
            echo "      Expected order: ${SORTED_BUILDS[*]}"
            echo "      Current order: ${BUILDS[*]}"
        fi
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
    ALL_BUILDS=()
    if [[ -f "$PROJECT_ROOT/appcast.xml" ]]; then
        while IFS= read -r build; do
            ALL_BUILDS+=("$build")
        done < <(grep -o '<sparkle:version>[0-9]*</sparkle:version>' "$PROJECT_ROOT/appcast.xml" | sed 's/<[^>]*>//g')
    fi
    if [[ -f "$PROJECT_ROOT/appcast-prerelease.xml" ]]; then
        while IFS= read -r build; do
            ALL_BUILDS+=("$build")
        done < <(grep -o '<sparkle:version>[0-9]*</sparkle:version>' "$PROJECT_ROOT/appcast-prerelease.xml" | sed 's/<[^>]*>//g')
    fi
    
    # Check for duplicates across files
    if [[ ${#ALL_BUILDS[@]} -gt 0 ]]; then
        UNIQUE_ALL=$(printf '%s\n' "${ALL_BUILDS[@]}" | sort -u | wc -l)
        TOTAL_ALL=${#ALL_BUILDS[@]}
        
        if [[ $UNIQUE_ALL -ne $TOTAL_ALL ]]; then
            echo -e "${RED}   ❌ Build numbers are duplicated between appcast files!${NC}"
            printf '%s\n' "${ALL_BUILDS[@]}" | sort | uniq -d | while read -r DUP; do
                echo "      Duplicate build: $DUP"
            done
            ((ISSUES++))
        else
            echo -e "${GREEN}   ✅ No build number conflicts between appcast files${NC}"
        fi
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