# Release Process for VibeMeter

This document describes the process for creating and publishing a new release of VibeMeter.

## Prerequisites

### Required Tools
- **Xcode 16.4+** - For building the app
- **GitHub CLI** (`gh`) - Install with `brew install gh`
- **Tuist** - Install with `curl -Ls https://install.tuist.io | bash`
- **Apple Developer Certificate** - "Developer ID Application" certificate in Keychain
- **App Store Connect API Key** - For notarization

### Environment Variables
Ensure these are set for notarization:
```bash
export APP_STORE_CONNECT_KEY_ID="YOUR_KEY_ID"
export APP_STORE_CONNECT_ISSUER_ID="YOUR_ISSUER_ID"
export APP_STORE_CONNECT_API_KEY_P8="-----BEGIN PRIVATE KEY-----..."
```

### Sparkle Keys
- **Private Key**: Stored in `private/sparkle_private_key` (gitignored)
- **Public Key**: `MCowBQYDK2VwAyEArLg3Mlihl14FWJJpZDg97VRt+CWAbQt7P8DleufK1cY=` (in Project.swift)
- **Backup Location**: `/Users/steipete/Library/CloudStorage/Dropbox/certificates/May2025/VibeMeter/`

## Release Types

### 1. Quick Release (Using Existing Build)
If you already have a built, signed, and notarized app:

```bash
./scripts/release-from-existing.sh
```

This script will:
- Create DMG from existing app
- Sign the DMG with Sparkle EdDSA signature
- Update `appcast.xml` with release info
- Commit and push changes
- Create GitHub release with DMG

### 2. Full Release (Build from Source)
To build everything from scratch:

```bash
./scripts/release-local.sh
```

This script will:
- Generate Xcode project with Tuist
- Build Release configuration
- Code sign with Developer ID
- Notarize with Apple (if flag is set)
- Create DMG
- Sign with Sparkle
- Update appcast and create release

## Manual Release Process

If you prefer to do it step by step:

### Step 1: Update Version Numbers
Edit `Project.swift`:
- `MARKETING_VERSION` - Marketing version (e.g., "1.0.0")
- `CURRENT_PROJECT_VERSION` - Build number (increment for each build)

```swift
"MARKETING_VERSION": "1.0.0",
"CURRENT_PROJECT_VERSION": "100",
```

### Step 2: Build the App
```bash
# Generate Xcode project
./scripts/generate-xcproj.sh

# Build with xcodebuild
xcodebuild -workspace VibeMeter.xcworkspace \
           -scheme VibeMeter \
           -configuration Release \
           clean build

# Path to built app
APP_PATH="build/Build/Products/Release/VibeMeter.app"
```

### Step 3: Sign and Notarize
```bash
# Sign and notarize the app
./scripts/sign-and-notarize.sh --sign-and-notarize
```

### Step 4: Create DMG
```bash
./scripts/create-dmg.sh
# Output: build/VibeMeter-X.X.X.dmg
```

### Step 5: Sign with Sparkle
```bash
# Get EdDSA signature using private key
openssl pkeyutl -sign -in build/VibeMeter-X.X.X.dmg \
    -inkey private/sparkle_private_key \
    -out /tmp/sig.bin

SPARKLE_SIG=$(base64 < /tmp/sig.bin)
echo "sparkle:edSignature=\"$SPARKLE_SIG\""
rm /tmp/sig.bin
```

### Step 6: Update appcast.xml
Update the appcast.xml file with:
- New version info
- Download URL
- EdDSA signature from previous step
- File size
- HTML description from changelog

### Step 7: Create GitHub Release
```bash
# Commit appcast
git add appcast.xml CHANGELOG.md
git commit -m "Release version X.X.X"

# Create and push tag
git tag -a "vX.X.X" -m "Release X.X.X"
git push origin main
git push origin "vX.X.X"

# Create release
gh release create "vX.X.X" \
    --title "VibeMeter X.X.X" \
    --notes "Release notes here" \
    build/VibeMeter-X.X.X.dmg
```

## Troubleshooting

### Notarization fails
- Check API credentials are correct
- Ensure P8 key content has proper format (including headers)
- Verify Developer ID certificate is valid
- Check that all frameworks are properly signed

### Sparkle signature issues
- Ensure private key exists in `private/sparkle_private_key`
- The public key in Project.swift must match the private key
- Use the OpenSSL method shown above for signing

### GitHub release fails
- Ensure `gh auth status` shows you're logged in
- Check the tag doesn't already exist
- Verify DMG file path is correct

### Build errors
- Run `./scripts/generate-xcproj.sh` if project structure changed
- Ensure all dependencies are resolved
- Check that Swift 6 strict concurrency is satisfied

## Version Numbering

We use semantic versioning:
- Format: `MAJOR.MINOR.PATCH` (e.g., "1.0.0")
- Increment PATCH for bug fixes
- Increment MINOR for new features
- Increment MAJOR for breaking changes

Build numbers should always increment, even for the same version.

## Testing Updates

To test the Sparkle update mechanism:

1. Build a version with a lower version number
2. Install and run it
3. Push the new release with higher version
4. Check if the app detects and installs the update

Test the startup update check:
- The app checks for updates 2 seconds after launch
- Monitor Console.app for update check logs

## Security Notes

- **Never commit private keys** to the repository
- The Sparkle private key is in `private/` (gitignored)
- Keep your Developer ID certificate secure
- Rotate API keys periodically
- Always notarize releases for Gatekeeper
- Deep sign all Sparkle framework components

## Changelog and Release Notes System

### Overview
VibeMeter uses a markdown-to-HTML conversion system:

1. **CHANGELOG.md** - Source of truth in Keep a Changelog format
2. **HTML conversion** - Automated conversion for Sparkle display
3. **Inline HTML in appcast.xml** - Rich formatting in update dialog

### Updating Release Notes

#### 1. Update CHANGELOG.md
Add new version entry following Keep a Changelog format:

```markdown
## [1.0.0] - 2025-06-03

### Added
- **Sparkle Integration**: Automatic updates with secure EdDSA signing
- **Menu Bar Enhancements**: Check for Updates menu item
- **Security**: Deep notarization for all components

### Fixed
- Menu bar text display during data refresh
- Currency symbol updates

### Security
- Hardened runtime with proper entitlements
- Signed XPC services for Sparkle framework
```

#### 2. Generate HTML (Automatic)
The `update-appcast.sh` script automatically:
- Extracts the version section from CHANGELOG.md
- Converts markdown to HTML
- Includes it in appcast.xml

### Automatic Update Checks
The app checks for updates automatically:

- **On Startup**: Checks 2 seconds after launch (background)
- **Periodic**: Based on Sparkle's automatic check interval
- **Manual**: Via "Check for Updates..." in menu bar

Configuration in `SparkleUpdaterManager.swift`:
```swift
// Enable automatic update checks
controller.updater.automaticallyChecksForUpdates = true

// Check for updates on startup
private func scheduleStartupUpdateCheck() {
    Task { @MainActor in
        try? await Task.sleep(for: .seconds(2))
        Self.staticLogger.info("Checking for updates on startup")
        self.updaterController.updater.checkForUpdatesInBackground()
    }
}
```

## EdDSA Key Management

### Key Storage and Backup
- **Primary**: `private/sparkle_private_key` (gitignored)
- **Public Key**: In Project.swift as `SUPublicEDKey`
- **Backup Location**: `/Users/steipete/Library/CloudStorage/Dropbox/certificates/May2025/VibeMeter/`

### Key Generation (if needed)
```bash
# Generate new EdDSA keys
openssl genpkey -algorithm Ed25519 -out sparkle_private_key
openssl pkey -in sparkle_private_key -pubout -outform DER | base64 > sparkle_public_key
```

### Restoring Keys
If keys are lost, restore from backup:
```bash
cp /Users/steipete/Library/CloudStorage/Dropbox/certificates/May2025/VibeMeter/sparkle_* private/
```

## Complete Release Checklist

### Pre-Release
- [ ] Update version numbers in Project.swift
- [ ] Update CHANGELOG.md with new version
- [ ] Test build and functionality
- [ ] Run tests: `xcodebuild test`
- [ ] Run linter: `./scripts/lint.sh`

### Build and Sign
- [ ] Generate Xcode project: `./scripts/generate-xcproj.sh`
- [ ] Build release: `./scripts/build.sh --configuration Release`
- [ ] Sign and notarize: `./scripts/sign-and-notarize.sh --sign-and-notarize`
- [ ] Create DMG: `./scripts/create-dmg.sh`
- [ ] Sign DMG with EdDSA

### Release
- [ ] Update appcast.xml with signature and file size
- [ ] Commit and push changelog updates
- [ ] Create GitHub release with signed DMG
- [ ] Test Sparkle update from previous version
- [ ] Verify release notes display correctly

### Post-Release
- [ ] Test automatic update check on startup
- [ ] Monitor for any update issues
- [ ] Update documentation if needed
- [ ] Announce release

## Scripts Overview

### Core Scripts
- `generate-xcproj.sh` - Generate Xcode project with Tuist
- `build.sh` - Build the application
- `sign-and-notarize.sh` - Code sign and notarize
- `create-dmg.sh` - Create distribution DMG
- `notarize-app.sh` - Deep notarization with Sparkle support

### Release Scripts
- `setup-sparkle-release.sh` - Initial Sparkle setup
- `create-github-release.sh` - Full release automation
- `update-appcast.sh` - Update appcast.xml
- `release-local.sh` - Local release for testing
- `changelog-to-html.sh` - Convert markdown to HTML

### Utility Scripts
- `format.sh` - Format Swift code
- `lint.sh` - Lint Swift code
- `fix-trailing-newlines.sh` - Fix file formatting
- `codesign-app.sh` - Sign app bundle

## Backup

Important files to backup:
- **Sparkle EdDSA Keys**: `private/` directory + Dropbox backup
- **Developer ID Certificate**: (.p12) in secure location
- **App Store Connect API Key**: (.p8) in secure location
- **Release Scripts**: All scripts in `scripts/` directory
- **Appcast**: `appcast.xml` (version controlled)
- **Changelog**: `CHANGELOG.md` (version controlled)

### Backup Verification
Regularly verify backup integrity:
```bash
# Check private key exists
ls -la private/sparkle_private_key

# Check Dropbox backup
ls -la "/Users/steipete/Library/CloudStorage/Dropbox/certificates/May2025/VibeMeter/"

# Verify public key matches
grep "SUPublicEDKey" Project.swift
```

## Deep Notarization Details

VibeMeter uses comprehensive signing for Sparkle components:

1. **XPC Services**: Signed with sandbox entitlements
2. **Sparkle Executables**: All binaries signed individually
3. **Nested Apps**: Updater.app signed as bundle
4. **Frameworks**: All frameworks signed
5. **Main App**: Signed last with hardened runtime

See `scripts/notarize-app.sh` for the complete signing order and entitlements.