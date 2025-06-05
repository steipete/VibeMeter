#!/bin/bash

# VibeMeter - GitHub Releases + Sparkle Setup Script
# This script sets up the complete workflow for GitHub releases with Sparkle auto-updates

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "🚀 Setting up VibeMeter for GitHub Releases + Sparkle Auto-Updates"
echo "Project root: $PROJECT_ROOT"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_step() {
    echo -e "\n${BLUE}📋 $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_step "Step 1: Generate Sparkle EdDSA Keys"

# Create keys directory
mkdir -p "$PROJECT_ROOT/private"
cd "$PROJECT_ROOT/private"

# Check if keys already exist
if [[ -f "sparkle_private_key" && -f "sparkle_public_key" ]]; then
    print_warning "Sparkle keys already exist in private/ directory"
    echo "Public key content:"
    cat sparkle_public_key
else
    # Generate EdDSA keys using OpenSSL (alternative to Sparkle's generate_keys)
    print_step "Generating EdDSA key pair..."
    
    # Generate private key
    openssl genpkey -algorithm Ed25519 -out sparkle_private_key
    
    # Extract public key
    openssl pkey -in sparkle_private_key -pubout -outform DER | base64 > sparkle_public_key
    
    print_success "Generated Sparkle EdDSA keys"
    echo "Public key (add this to Project.swift):"
    cat sparkle_public_key
fi

print_step "Step 2: Update Project.swift with Sparkle Configuration"

# Read the current public key
PUBLIC_KEY=$(cat sparkle_public_key)

print_step "Step 3: Verifying Release Scripts"

# Check that release scripts exist
if [[ -f "$PROJECT_ROOT/scripts/release-auto.sh" ]]; then
    print_success "Release scripts already exist"
else
    print_error "Release scripts not found! Please ensure all scripts are present."
    exit 1
fi

# Skip to end of the old script creation block
: << 'SKIP_OLD_SCRIPT_CREATION'
#!/bin/bash

# GitHub Release Creation Script for VibeMeter
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Get version from Project.swift
VERSION=$(grep 'MARKETING_VERSION' "$PROJECT_ROOT/Project.swift" | sed 's/.*"MARKETING_VERSION": "\(.*\)".*/\1/')
BUILD_NUMBER=$(grep 'CURRENT_PROJECT_VERSION' "$PROJECT_ROOT/Project.swift" | sed 's/.*"CURRENT_PROJECT_VERSION": "\(.*\)".*/\1/')

echo "📦 Creating GitHub release for VibeMeter v$VERSION (build $BUILD_NUMBER)"

# Build the app
echo "🔨 Building application..."
cd "$PROJECT_ROOT"
./scripts/build.sh --configuration Release

# Check if built app exists
APP_PATH="$PROJECT_ROOT/build/Build/Products/Release/VibeMeter.app"
if [[ ! -d "$APP_PATH" ]]; then
    echo "❌ Built app not found at $APP_PATH"
    exit 1
fi

# Sign and notarize the app
echo "🔐 Signing and notarizing..."
./scripts/sign-and-notarize.sh --app-path "$APP_PATH" --sign-and-notarize

# Create DMG
echo "📀 Creating DMG..."
DMG_PATH="$PROJECT_ROOT/build/VibeMeter-$VERSION.dmg"
./scripts/create-dmg.sh "$APP_PATH"

# Generate release notes
RELEASE_NOTES="Release notes for VibeMeter v$VERSION

This release includes:
- Latest features and improvements
- Bug fixes and performance enhancements

## Installation
1. Download the DMG file
2. Open it and drag VibeMeter to Applications
3. Grant necessary permissions when prompted

## Auto-Updates
This version supports automatic updates via Sparkle."

# Create GitHub release (requires gh CLI)
echo "🚀 Creating GitHub release..."
gh release create "v$VERSION" "$DMG_PATH" \
    --title "VibeMeter v$VERSION" \
    --notes "$RELEASE_NOTES" \
    --generate-notes

# Update appcast.xml
echo "📡 Updating appcast.xml..."
./scripts/update-appcast.sh "$VERSION" "$BUILD_NUMBER" "$DMG_PATH"

echo "✅ GitHub release created successfully!"
echo "📡 Don't forget to commit and push the updated appcast.xml"
EOF
SKIP_OLD_SCRIPT_CREATION

# Scripts are now provided in the repository

# Create appcast update script
cat > "$PROJECT_ROOT/scripts/update-appcast.sh" << 'EOF'
#!/bin/bash

# Appcast.xml Update Script
set -euo pipefail

VERSION="$1"
BUILD_NUMBER="$2"
DMG_PATH="$3"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "📡 Updating appcast.xml for version $VERSION"

# Calculate file size and SHA256
DMG_SIZE=$(stat -f%z "$DMG_PATH")
DMG_SHA256=$(shasum -a 256 "$DMG_PATH" | cut -d' ' -f1)
DMG_FILENAME=$(basename "$DMG_PATH")

# Get current date in RFC 2822 format
RELEASE_DATE=$(date -R)

# GitHub release URL
GITHUB_USERNAME="${GITHUB_USERNAME:-steipete}"
DOWNLOAD_URL="https://github.com/$GITHUB_USERNAME/VibeMeter/releases/download/v$VERSION/$DMG_FILENAME"

# Generate HTML description from changelog
echo "📝 Generating HTML description from changelog..."
DESCRIPTION_HTML=\$(./scripts/changelog-to-html.sh "\$VERSION" 2>/dev/null | tail -n +2)

# Create or update appcast.xml
cat > "$PROJECT_ROOT/appcast.xml" << APPCAST_EOF
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle" xmlns:dc="http://purl.org/dc/elements/1.1/">
    <channel>
        <title>VibeMeter Updates</title>
        <link>https://github.com/$GITHUB_USERNAME/VibeMeter</link>
        <description>VibeMeter automatic updates feed</description>
        <language>en</language>
        
        <item>
            <title>VibeMeter $VERSION</title>
            <link>$DOWNLOAD_URL</link>
            <sparkle:version>$BUILD_NUMBER</sparkle:version>
            <sparkle:shortVersionString>$VERSION</sparkle:shortVersionString>
            <description><![CDATA[
                \$DESCRIPTION_HTML
            ]]></description>
            <pubDate>$RELEASE_DATE</pubDate>
            <enclosure 
                url="$DOWNLOAD_URL"
                length="$DMG_SIZE"
                type="application/octet-stream"
                sparkle:edSignature="SIGNATURE_PLACEHOLDER"
            />
            <sparkle:minimumSystemVersion>14.0</sparkle:minimumSystemVersion>
        </item>
    </channel>
</rss>
APPCAST_EOF

echo "✅ Appcast.xml updated"
echo "⚠️  Remember to sign the DMG with your Sparkle private key and update the signature"
echo "⚠️  Command: sign_update '$DMG_PATH' /path/to/sparkle_private_key"
EOF

chmod +x "$PROJECT_ROOT/scripts/update-appcast.sh"

print_step "Step 4: Creating local release script"

# Create local release script for testing
cat > "$PROJECT_ROOT/scripts/release-local.sh" << 'EOF'
#!/bin/bash

# Local Release Script for VibeMeter
# This script creates a local release without uploading to GitHub
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Get version from Project.swift
VERSION=$(grep 'MARKETING_VERSION' "$PROJECT_ROOT/Project.swift" | sed 's/.*"MARKETING_VERSION": "\(.*\)".*/\1/')
BUILD_NUMBER=$(grep 'CURRENT_PROJECT_VERSION' "$PROJECT_ROOT/Project.swift" | sed 's/.*"CURRENT_PROJECT_VERSION": "\(.*\)".*/\1/')

echo "📦 Creating local release for VibeMeter v$VERSION (build $BUILD_NUMBER)"

# Build the app
echo "🔨 Building application..."
cd "$PROJECT_ROOT"
./scripts/build.sh --configuration Release

# Check if built app exists
APP_PATH="$PROJECT_ROOT/build/Build/Products/Release/VibeMeter.app"
if [[ ! -d "$APP_PATH" ]]; then
    echo "❌ Built app not found at $APP_PATH"
    exit 1
fi

# Sign the app (skip notarization for local builds)
echo "🔐 Signing app for local testing..."
./scripts/sign-and-notarize.sh --app-path "$APP_PATH" --sign-only

# Create DMG
echo "📀 Creating DMG..."
DMG_PATH="$PROJECT_ROOT/build/VibeMeter-$VERSION.dmg"
./scripts/create-dmg.sh "$APP_PATH"

# Create releases directory if it doesn't exist
mkdir -p "$PROJECT_ROOT/releases"

# Copy DMG to releases directory
RELEASE_DMG="$PROJECT_ROOT/releases/VibeMeter-$VERSION-local.dmg"
cp "$DMG_PATH" "$RELEASE_DMG"

echo "✅ Local release created successfully!"
echo "📀 DMG available at: $RELEASE_DMG"
echo "🚀 You can test this locally before creating a GitHub release"
EOF

chmod +x "$PROJECT_ROOT/scripts/release-local.sh"

print_step "Step 5: Setup Instructions"

cat << SETUP_EOF

🎉 Sparkle + GitHub Releases setup is complete!

📋 NEXT STEPS:

1. 🔑 Update Project.swift with your public key:
   Replace 'YOUR_SPARKLE_PUBLIC_ED_KEY_HERE' with:
   $(cat sparkle_public_key)

2. 🌐 The GitHub username is already configured for steipete
   
3. 📝 The appcast URL is already configured in Project.swift

4. 🔧 Install required tools:
   - GitHub CLI: brew install gh
   - Sign into GitHub: gh auth login

5. 🧪 Test release readiness:
   ./scripts/preflight-check.sh

6. 🚀 Create your first GitHub release:
   ./scripts/release-auto.sh stable  # For stable release
   ./scripts/release-auto.sh beta 1  # For beta release

7. 📡 Host appcast.xml:
   - Commit appcast.xml to your repository
   - Ensure it's accessible at the URL in your Project.swift

🔒 SECURITY NOTES:
- Keep 'private/sparkle_private_key' SECRET and secure
- Add 'private/' to .gitignore
- Consider using GitHub secrets for CI/CD

📁 FILES CREATED:
- private/sparkle_private_key (KEEP SECRET!)
- private/sparkle_public_key
- scripts/update-appcast.sh
- scripts/release-local.sh

📁 EXISTING SCRIPTS:
- scripts/preflight-check.sh (validates release readiness)
- scripts/release-auto.sh (automated release process)

SETUP_EOF

# Add private directory to .gitignore if not already there
if ! grep -q "private/" "$PROJECT_ROOT/.gitignore" 2>/dev/null; then
    echo -e "\n# Sparkle private keys\nprivate/" >> "$PROJECT_ROOT/.gitignore"
    print_success "Added private/ to .gitignore"
fi

print_success "Sparkle + GitHub Releases setup completed!"
print_warning "Don't forget to complete the manual steps above!"