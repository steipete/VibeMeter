#!/bin/bash
#
# Generate appcast XML files with correct file sizes from GitHub releases
#
# This script fetches release information from GitHub and generates
# appcast.xml and appcast-prerelease.xml with accurate file sizes
# to prevent Sparkle download errors.

set -euo pipefail

# Add Sparkle tools to PATH
export PATH="$HOME/.local/bin:$PATH"

# Load GitHub configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$(dirname "$SCRIPT_DIR")/.github-config"
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
fi

# Configuration
GITHUB_USERNAME="${GITHUB_USERNAME:-steipete}"
GITHUB_REPO="${GITHUB_USERNAME}/${GITHUB_REPO:-VibeMeter}"
SPARKLE_PRIVATE_KEY_PATH="private/sparkle_private_key"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Function to print colored output
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1" >&2
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" >&2
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

# Function to get file size from URL
get_file_size() {
    local url=$1
    curl -sI "$url" | grep -i content-length | awk '{print $2}' | tr -d '\r'
}

# Function to check if we have a cached signature
get_cached_signature() {
    local filename=$1
    local cache_file="$temp_dir/signatures_cache.txt"
    
    # Check if cache file exists and has the signature
    if [ -f "$cache_file" ]; then
        grep "^$filename:" "$cache_file" | cut -d: -f2 || echo ""
    else
        echo ""
    fi
}

# Function to cache a signature
cache_signature() {
    local filename=$1
    local signature=$2
    local cache_file="$temp_dir/signatures_cache.txt"
    
    if [ -n "$signature" ] && [ "$signature" != "" ]; then
        echo "$filename:$signature" >> "$cache_file"
    fi
}

# Function to generate EdDSA signature
generate_signature() {
    local file_path=$1
    local filename=$(basename "$file_path")
    
    # Check if we have a cached signature first
    local cached_sig=$(get_cached_signature "$filename")
    if [ -n "$cached_sig" ]; then
        echo "$cached_sig"
        return 0
    fi
    
    # Try to use sign_update from Keychain first (preferred method)
    if command -v sign_update >/dev/null 2>&1; then
        # First try without -f flag to use Keychain
        local signature=$(sign_update "$file_path" -p 2>/dev/null)
        if [ -n "$signature" ] && [ "$signature" != "-----END PRIVATE KEY-----" ]; then
            echo "$signature"
            return 0
        fi
        
        # If Keychain didn't work and we have a private key file, try that
        if [ -f "$SPARKLE_PRIVATE_KEY_PATH" ]; then
            signature=$(sign_update "$file_path" -f "$SPARKLE_PRIVATE_KEY_PATH" -p 2>/dev/null)
            if [ -n "$signature" ] && [ "$signature" != "-----END PRIVATE KEY-----" ]; then
                echo "$signature"
                return 0
            fi
        fi
    fi
    
    # Try using the bundled tool from Sparkle framework
    local sign_tool="/Applications/Sparkle Test App.app/Contents/Frameworks/Sparkle.framework/Versions/B/Resources/sign_update"
    if [ -f "$sign_tool" ]; then
        local signature=$("$sign_tool" "$file_path" -p 2>/dev/null)
        if [ -n "$signature" ] && [ "$signature" != "-----END PRIVATE KEY-----" ]; then
            echo "$signature"
            return 0
        fi
    fi
    
    print_warning "Could not generate signature for $filename"
    echo ""
}

# Function to format date for appcast
format_date() {
    local date_str=$1
    # Convert GitHub date format to RFC 822 format for RSS
    date -j -f "%Y-%m-%dT%H:%M:%SZ" "$date_str" "+%a, %d %b %Y %H:%M:%S %z" 2>/dev/null || \
    date -d "$date_str" "+%a, %d %b %Y %H:%M:%S %z" 2>/dev/null || \
    echo "Wed, 04 Jun 2025 12:00:00 +0000"
}

# Function to extract version and build number from release tag
parse_version() {
    local tag=$1
    local version=""
    local build=""
    
    # Remove 'v' prefix if present
    tag=${tag#v}
    
    # For pre-releases like "1.0-beta.1", extract base version
    if [[ $tag =~ ^([0-9]+\.[0-9]+)(-.*)?$ ]]; then
        version=$tag
    else
        version=$tag
    fi
    
    echo "$version"
}

# Function to create appcast item
create_appcast_item() {
    local release_json=$1
    local dmg_url=$2
    local is_prerelease=$3
    
    # Extract fields with proper fallbacks
    local tag=$(echo "$release_json" | jq -r '.tag_name // "unknown"')
    local title=$(echo "$release_json" | jq -r '.name // .tag_name // "Release"')
    local body=$(echo "$release_json" | jq -r '.body // "Release notes not available"')
    local published_at=$(echo "$release_json" | jq -r '.published_at // ""')
    
    # Validate critical fields
    if [ "$tag" = "unknown" ] || [ "$tag" = "null" ] || [ -z "$tag" ]; then
        print_warning "Invalid tag_name for release, skipping"
        return 1
    fi
    
    local version_string=$(parse_version "$tag")
    
    # Get DMG asset info using base64 encoding for robustness
    local dmg_asset_b64=$(echo "$release_json" | jq -r ".assets[] | select(.browser_download_url == \"$dmg_url\") | {size: .size, name: .name} | @base64" | head -1)
    local dmg_size=""
    
    if [ -n "$dmg_asset_b64" ] && [ "$dmg_asset_b64" != "null" ]; then
        dmg_size=$(echo "$dmg_asset_b64" | base64 --decode | jq -r '.size // null')
    fi
    
    # If size is not in JSON, fetch from HTTP headers
    if [ "$dmg_size" = "null" ] || [ -z "$dmg_size" ]; then
        print_info "Fetching file size for $dmg_url"
        dmg_size=$(get_file_size "$dmg_url")
    fi
    
    # Get signature - either from known signatures or by downloading
    local dmg_filename=$(basename "$dmg_url")
    local signature=""
    
    # Check if we have a cached signature first
    local cached_sig=$(get_cached_signature "$dmg_filename")
    if [ -n "$cached_sig" ]; then
        signature="$cached_sig"
        print_info "Using cached signature for $dmg_filename"
    else
        # We'll download DMG once later for both signature and build number
        signature=""
    fi
    
    # Extract build number from the DMG
    local build_number=""
    local temp_dmg="/tmp/$dmg_filename"
    
    # Download DMG if not already present (for both signature and build number)
    if [ ! -f "$temp_dmg" ]; then
        print_info "Downloading DMG for analysis..."
        curl -sL "$dmg_url" -o "$temp_dmg" 2>/dev/null
    fi
    
    # Generate signature if we haven't already
    if [ -z "$signature" ]; then
        signature=$(generate_signature "$temp_dmg")
        # Cache the signature for future runs
        if [ -n "$signature" ]; then
            cache_signature "$dmg_filename" "$signature"
        fi
    fi
    
    # Extract build number using helper script
    if [ -x "$SCRIPT_DIR/extract-build-number.sh" ]; then
        build_number=$("$SCRIPT_DIR/extract-build-number.sh" "$temp_dmg" 2>/dev/null || echo "")
    elif [ -x "$(dirname "$0")/extract-build-number.sh" ]; then
        build_number=$("$(dirname "$0")/extract-build-number.sh" "$temp_dmg" 2>/dev/null || echo "")
    else
        print_warning "extract-build-number.sh not found - build numbers may be incorrect"
    fi
    
    # Fallback to version-based guessing if extraction fails
    if [ -z "$build_number" ]; then
        print_warning "Could not extract build number from DMG, using fallback"
        case "$version_string" in
            *-beta.1) build_number="100" ;;
            *-beta.2) build_number="101" ;;
            *-beta.3) build_number="102" ;;
            *-beta.4) build_number="103" ;;
            *-rc.1) build_number="110" ;;
            *-rc.2) build_number="111" ;;
            1.0) build_number="200" ;;
            *) build_number="1" ;;
        esac
    fi
    
    # Clean up temp DMG
    rm -f "$temp_dmg"
    
    # Clean body for XML to handle special characters safely
    local clean_body
    clean_body=$(echo "$body" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g; s/"/\&quot;/g; s/'"'"'/\&#39;/g')
    
    # Format the description with proper XML structure
    local description="<h2>$title</h2>"
    if [ "$is_prerelease" = "true" ]; then
        description+="<p><strong>Pre-release version</strong></p>"
    fi
    
    # Add body content with proper formatting, limiting to prevent overly long descriptions
    if [ -n "$clean_body" ] && [ "$clean_body" != "Release notes not available" ]; then
        # Split body into paragraphs and limit to first 5 lines for brevity
        local formatted_body=$(echo "$clean_body" | head -5 | sed 's/^[[:space:]]*//; s/[[:space:]]*$//; /^$/d' | sed 's/^/<p>/; s/$/<\/p>/')
        description+="<div>$formatted_body</div>"
    else
        description+="<p>Release notes not available</p>"
    fi
    
    # Generate the item XML
    cat << EOF
        <item>
            <title>$title</title>
            <link>$dmg_url</link>
            <sparkle:version>$build_number</sparkle:version>
            <sparkle:shortVersionString>$version_string</sparkle:shortVersionString>
            <description><![CDATA[
                $description
            ]]></description>
            <pubDate>$(format_date "$published_at")</pubDate>
            <enclosure 
                url="$dmg_url"
                length="$dmg_size"
                type="application/octet-stream"
                sparkle:edSignature="$signature"
            />
            <sparkle:minimumSystemVersion>15.0</sparkle:minimumSystemVersion>
        </item>
EOF
}

# Main function
main() {
    print_info "Generating appcast files for $GITHUB_REPO"
    
    # Create temporary directory
    local temp_dir=$(mktemp -d)
    trap "rm -rf $temp_dir" EXIT
    
    # Fetch all releases from GitHub with error handling
    print_info "Fetching releases from GitHub..."
    local releases
    if ! releases=$(gh api "repos/$GITHUB_REPO/releases" --paginate 2>/dev/null); then
        print_error "Failed to fetch releases from GitHub. Please check your GitHub CLI authentication and network connection."
        exit 1
    fi
    
    if [ -z "$releases" ] || [ "$releases" = "[]" ]; then
        print_warning "No releases found for repository $GITHUB_REPO"
        exit 0
    fi
    
    # Separate stable and pre-releases
    local stable_releases=$(echo "$releases" | jq -c '.[] | select(.prerelease == false)')
    local pre_releases=$(echo "$releases" | jq -c '.[] | select(.prerelease == true)')
    
    # Generate stable appcast
    print_info "Generating appcast.xml..."
    cat > appcast.xml << 'EOF'
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle" xmlns:dc="http://purl.org/dc/elements/1.1/">
    <channel>
        <title>VibeMeter Updates</title>
        <link>https://github.com/steipete/VibeMeter</link>
        <description>VibeMeter automatic updates feed</description>
        <language>en</language>
EOF
    
    # Add stable releases to appcast
    while IFS= read -r release; do
        [ -z "$release" ] && continue
        
        # Find DMG asset using base64 encoding for robustness
        local dmg_asset_b64=$(echo "$release" | jq -r '.assets[] | select(.name | endswith(".dmg")) | {url: .browser_download_url, name: .name} | @base64' | head -1)
        
        if [ -n "$dmg_asset_b64" ] && [ "$dmg_asset_b64" != "null" ]; then
            local dmg_url=$(echo "$dmg_asset_b64" | base64 --decode | jq -r '.url')
            if [ -n "$dmg_url" ] && [ "$dmg_url" != "null" ]; then
                if create_appcast_item "$release" "$dmg_url" "false" >> appcast.xml; then
                    print_info "Added stable release: $(echo "$release" | jq -r '.tag_name')"
                else
                    print_warning "Failed to create item for stable release: $(echo "$release" | jq -r '.tag_name')"
                fi
            fi
        else
            print_warning "No DMG asset found for stable release: $(echo "$release" | jq -r '.tag_name // "unknown"')"
        fi
    done <<< "$stable_releases"
    
    echo "    </channel>" >> appcast.xml
    echo "</rss>" >> appcast.xml
    
    # Generate pre-release appcast
    print_info "Generating appcast-prerelease.xml..."
    cat > appcast-prerelease.xml << 'EOF'
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle" xmlns:dc="http://purl.org/dc/elements/1.1/">
    <channel>
        <title>VibeMeter Pre-release Updates</title>
        <link>https://github.com/steipete/VibeMeter</link>
        <description>VibeMeter pre-release and beta updates feed</description>
        <language>en</language>
EOF
    
    # Add pre-releases to appcast
    while IFS= read -r release; do
        [ -z "$release" ] && continue
        
        # Find DMG asset using base64 encoding for robustness
        local dmg_asset_b64=$(echo "$release" | jq -r '.assets[] | select(.name | endswith(".dmg")) | {url: .browser_download_url, name: .name} | @base64' | head -1)
        
        if [ -n "$dmg_asset_b64" ] && [ "$dmg_asset_b64" != "null" ]; then
            local dmg_url=$(echo "$dmg_asset_b64" | base64 --decode | jq -r '.url')
            if [ -n "$dmg_url" ] && [ "$dmg_url" != "null" ]; then
                if create_appcast_item "$release" "$dmg_url" "true" >> appcast-prerelease.xml; then
                    print_info "Added pre-release: $(echo "$release" | jq -r '.tag_name')"
                else
                    print_warning "Failed to create item for pre-release: $(echo "$release" | jq -r '.tag_name')"
                fi
            fi
        else
            print_warning "No DMG asset found for pre-release: $(echo "$release" | jq -r '.tag_name // "unknown"')"
        fi
    done <<< "$pre_releases"
    
    # Also add stable releases to pre-release feed
    while IFS= read -r release; do
        [ -z "$release" ] && continue
        
        # Find DMG asset using base64 encoding for robustness
        local dmg_asset_b64=$(echo "$release" | jq -r '.assets[] | select(.name | endswith(".dmg")) | {url: .browser_download_url, name: .name} | @base64' | head -1)
        
        if [ -n "$dmg_asset_b64" ] && [ "$dmg_asset_b64" != "null" ]; then
            local dmg_url=$(echo "$dmg_asset_b64" | base64 --decode | jq -r '.url')
            if [ -n "$dmg_url" ] && [ "$dmg_url" != "null" ]; then
                if create_appcast_item "$release" "$dmg_url" "false" >> appcast-prerelease.xml; then
                    print_info "Added stable release to pre-release feed: $(echo "$release" | jq -r '.tag_name')"
                else
                    print_warning "Failed to create item for stable release in pre-release feed: $(echo "$release" | jq -r '.tag_name')"
                fi
            fi
        else
            print_warning "No DMG asset found for stable release in pre-release feed: $(echo "$release" | jq -r '.tag_name // "unknown"')"
        fi
    done <<< "$stable_releases"
    
    echo "    </channel>" >> appcast-prerelease.xml
    echo "</rss>" >> appcast-prerelease.xml
    
    print_info "✅ Appcast files generated successfully!"
    print_info "  - appcast.xml (stable releases only)"
    print_info "  - appcast-prerelease.xml (all releases)"
    
    # Validate the generated files
    if command -v xmllint >/dev/null 2>&1; then
        print_info "Validating XML..."
        xmllint --noout appcast.xml && print_info "  ✓ appcast.xml is valid"
        xmllint --noout appcast-prerelease.xml && print_info "  ✓ appcast-prerelease.xml is valid"
    fi
}

# Run main function
main "$@"