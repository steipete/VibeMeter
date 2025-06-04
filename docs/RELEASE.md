# Release Process for VibeMeter

This document describes the process for creating and publishing a new release of VibeMeter.

## Prerequisites

### Required Tools
- **Xcode 16.4+** - For building the app
- **GitHub CLI** (`gh`) - Install with `brew install gh`
- **Tuist** - Install with `curl -Ls https://install.tuist.io | bash`
- **Apple Developer Certificate** - "Developer ID Application" certificate in Keychain
- **App Store Connect API Key** - For notarization
- **Sparkle Tools** - sign_update, generate_appcast, generate_keys (installed automatically)

### Environment Variables
Ensure these are set for notarization:
```bash
export APP_STORE_CONNECT_KEY_ID="YOUR_KEY_ID"
export APP_STORE_CONNECT_ISSUER_ID="YOUR_ISSUER_ID"
export APP_STORE_CONNECT_API_KEY_P8="-----BEGIN PRIVATE KEY-----..."
```

### Sparkle EdDSA Keys
- **Private Key**: Stored securely in macOS Keychain
- **Public Key**: `oIgha2beQWnyCXgOIlB8+oaUzFNtWgkqq6jKXNNDhv4=` (in Info.plist)
- **Tools Location**: `~/.local/bin/` (sign_update, generate_appcast, generate_keys)
- **Backup Location**: Private key exported to secure location

## Release Types

VibeMeter supports both stable and pre-release versions through separate update channels.

### Release Channels

- **🟢 Stable Channel** (`appcast.xml`) - Production-ready releases for all users
- **🟡 Pre-release Channel** (`appcast-prerelease.xml`) - Beta, alpha, and RC versions for testing

### Version Management

Use the version management script to prepare releases:

```bash
# Show current version
./scripts/version.sh --current

# Bump version for stable releases
./scripts/version.sh --patch        # 0.9.1 -> 0.9.2
./scripts/version.sh --minor        # 0.9.1 -> 0.10.0  
./scripts/version.sh --major        # 0.9.1 -> 1.0.0

# Create pre-release versions
./scripts/version.sh --prerelease beta    # 0.9.2 -> 0.9.2-beta.1
./scripts/version.sh --prerelease alpha   # 0.9.2 -> 0.9.2-alpha.1
./scripts/version.sh --prerelease rc      # 0.9.2 -> 0.9.2-rc.1

# Set specific version
./scripts/version.sh --set 1.0.0
```

### Creating Releases

#### 1. Universal Release Script (Recommended)

```bash
# Create stable release
./scripts/release.sh --stable

# Create pre-releases  
./scripts/release.sh --prerelease beta 1     # Creates 0.9.2-beta.1
./scripts/release.sh --prerelease alpha 2    # Creates 0.9.2-alpha.2
./scripts/release.sh --prerelease rc 1       # Creates 0.9.2-rc.1
```

#### 2. Individual Release Scripts

```bash
# Stable releases only
./scripts/create-github-release.sh

# Pre-releases only
./scripts/create-prerelease.sh beta 1        # Creates beta.1
./scripts/create-prerelease.sh alpha 2       # Creates alpha.2
./scripts/create-prerelease.sh rc 1          # Creates rc.1
```

#### 3. Quick Release (Using Existing Build)
If you already have a built, signed, and notarized app:

```bash
./scripts/release-from-existing.sh
```

#### 4. Full Release (Build from Source)
To build everything from scratch:

```bash
./scripts/release-local.sh
```

### Complete Release Workflow

#### Stable Release Workflow

1. **Prepare Release:**
   ```bash
   # Bump version (choose appropriate type)
   ./scripts/version.sh --patch
   
   # Review changes
   git diff Project.swift
   
   # Commit version bump
   git add Project.swift
   git commit -m "Bump version to 0.9.2"
   ```

2. **Create Release:**
   ```bash
   ./scripts/release.sh --stable
   ```

3. **Post-Release:**
   ```bash
   # Commit updated appcast files (both stable and pre-release)
   git add appcast*.xml
   git commit -m "Update appcast for v0.9.2"
   git push origin main
   ```

#### Pre-release Workflow

1. **Prepare Pre-release:**
   ```bash
   # Create pre-release version
   ./scripts/version.sh --prerelease beta
   
   # Commit version bump
   git add Project.swift
   git commit -m "Bump version to 0.9.2-beta.1"
   ```

2. **Create Pre-release:**
   ```bash
   ./scripts/release.sh --prerelease beta 1
   ```

3. **Post-Release:**
   ```bash
   # Commit updated pre-release appcast
   git add appcast-prerelease.xml
   git commit -m "Update pre-release appcast for v0.9.2-beta.1"
   git push origin main
   ```

### Update Channel System

VibeMeter users can choose their update channel in **Settings → General → Update Channel**:

- **Stable Only**: Receives updates from `appcast.xml` (stable releases only)
- **Include Pre-releases**: Receives updates from `appcast-prerelease.xml` (both stable and pre-release versions)

The `SparkleUpdaterManager` dynamically provides the appropriate feed URL based on user preference using the `feedURLString(for:)` delegate method.

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

### Step 5: Generate EdDSA Signature
```bash
# Generate EdDSA signature using Sparkle tools
export PATH="$HOME/.local/bin:$PATH"
sign_update build/VibeMeter-X.X.X.dmg

# Output includes both signature and file size:
# sparkle:edSignature="7kvxbN+PyzPQjL7JbIIwjlxyRsG2//P6drllJG+soJJgkngvweLu8luyG2NxSKI/0jwRoLGXNzgxojgPLduXBA==" length="3510654"
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
- **Primary**: macOS Keychain (account: "ed25519")
- **Public Key**: In Info.plist as `SUPublicEDKey`
- **Backup**: Export private key to secure location

### Sparkle Tools Setup
```bash
# Install Sparkle tools (first time only)
curl -L "https://github.com/sparkle-project/Sparkle/releases/download/2.7.0/Sparkle-2.7.0.tar.xz" -o Sparkle-2.7.0.tar.xz
tar -xf Sparkle-2.7.0.tar.xz
mkdir -p ~/.local/bin
cp bin/sign_update ~/.local/bin/
cp bin/generate_appcast ~/.local/bin/
cp bin/generate_keys ~/.local/bin/
export PATH="$HOME/.local/bin:$PATH"
```

### Key Generation (if needed)
```bash
# Generate new EdDSA keys using Sparkle tools
export PATH="$HOME/.local/bin:$PATH"
generate_keys

# Output shows public key for Info.plist:
# <key>SUPublicEDKey</key>
# <string>oIgha2beQWnyCXgOIlB8+oaUzFNtWgkqq6jKXNNDhv4=</string>
```

### Backup and Restore Keys
```bash
# Export private key from Keychain
generate_keys -x sparkle_private_key_backup

# Import private key to Keychain
generate_keys -f sparkle_private_key_backup

# Verify public key
generate_keys -p
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
- [ ] Generate EdDSA signature: `sign_update build/VibeMeter-X.X.X.dmg`

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
- `version.sh` - Version management and bumping
- `release.sh` - Universal release script (stable and pre-release)
- `create-github-release.sh` - Stable release automation
- `create-prerelease.sh` - Pre-release creation
- `update-appcast.sh` - Update stable appcast.xml
- `update-prerelease-appcast.sh` - Update pre-release appcast
- `setup-sparkle-release.sh` - Initial Sparkle setup
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
# Check Sparkle tools are installed
which sign_update generate_appcast generate_keys

# Check private key exists in Keychain
generate_keys -p

# Verify public key in Info.plist matches Keychain
grep "SUPublicEDKey" VibeMeter/Info.plist

# Check certificates
security find-identity -v -p codesigning
```

## Deep Notarization Details

VibeMeter uses comprehensive signing for Sparkle components:

1. **XPC Services**: Signed with sandbox entitlements
2. **Sparkle Executables**: All binaries signed individually
3. **Nested Apps**: Updater.app signed as bundle
4. **Frameworks**: All frameworks signed
5. **Main App**: Signed last with hardened runtime

See `scripts/notarize-app.sh` for the complete signing order and entitlements.

## Sandboxing Experiments and Findings

### App Sandboxing Status: DISABLED

**IMPORTANT**: VibeMeter currently runs with app sandboxing **disabled** (`com.apple.security.app-sandbox = false`) due to Sparkle framework compatibility requirements.

### Experiment History

During development of v1.0-beta.1 and v1.0-beta.2, we conducted extensive experiments with sandboxing:

#### Initial Sandboxing Attempt
- **Goal**: Enable app sandboxing for better security
- **Problem**: Sparkle framework failed to function with basic sandboxing
- **Symptoms**: 
  - Console errors: "gentle reminders not supported for background apps"
  - Update downloads failed
  - XPC service communication failures

#### Entitlements Experimentation
We tried various combinations of entitlements to make Sparkle work with sandboxing:

```xml
<!-- Attempted entitlements that did NOT work with sandboxing -->
<key>com.apple.security.app-sandbox</key>
<true/>
<key>com.apple.security.network.client</key>
<true/>
<key>com.apple.security.files.downloads.read-write</key>
<true/>
<key>com.apple.security.automation.apple-events</key>
<true/>
<key>com.apple.security.cs.allow-jit</key>
<true/>
<key>com.apple.security.cs.allow-unsigned-executable-memory</key>
<true/>
<key>com.apple.security.cs.disable-library-validation</key>
<true/>
```

#### Final Working Solution
**Current entitlements configuration** (VibeMeter/VibeMeter.entitlements):

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <!-- Sandboxing DISABLED for Sparkle compatibility -->
    <key>com.apple.security.app-sandbox</key>
    <false/>
    
    <!-- Required entitlements for Sparkle functionality -->
    <key>com.apple.security.network.client</key>
    <true/>
    <key>com.apple.security.files.downloads.read-write</key>
    <true/>
    <key>com.apple.security.cs.allow-unsigned-executable-memory</key>
    <true/>
    <key>com.apple.security.cs.disable-library-validation</key>
    <true/>
</dict>
</plist>
```

#### Key Findings
1. **Sparkle 2.7.0 compatibility**: Requires sandboxing to be disabled for full functionality
2. **XPC Services**: Sparkle's XPC services (Downloader, Installer) work properly only without sandboxing
3. **Network access**: Required for appcast downloads and update file downloads
4. **File system access**: Required for update installation and temporary file handling
5. **Memory execution**: Required for Sparkle framework runtime operations
6. **Library validation**: Must be disabled for proper framework loading

#### Comparison with Working Project (CodeLooper)
We analyzed the ../CodeLooper project configuration and found:
- **Sandboxing**: Also disabled (`com.apple.security.app-sandbox = false`)
- **Entitlements**: Similar comprehensive entitlements for network and file access
- **Sparkle version**: Also using 2.7.0 with same requirements

#### Future Sandboxing Considerations
For future attempts to enable sandboxing:

1. **Monitor Sparkle updates**: Check if newer versions support sandboxing better
2. **Alternative update mechanisms**: Consider App Store distribution for automatic updates
3. **Reduced permissions**: Try minimal entitlements if Sparkle improves sandbox compatibility
4. **Test environment**: Always test with sandboxing in isolated environment first

### Testing Procedure for Sandboxing
If attempting to re-enable sandboxing:

1. **Change entitlements**:
   ```xml
   <key>com.apple.security.app-sandbox</key>
   <true/>
   ```

2. **Test update mechanism**:
   ```bash
   # Build and install app
   ./scripts/build.sh --configuration Debug
   open build/Build/Products/Debug/VibeMeter.app
   
   # Check console for errors
   log stream --predicate 'process == "VibeMeter"' --level debug
   ```

3. **Verify XPC services**:
   ```bash
   # Check if Sparkle services start
   ps aux | grep -E "(Downloader|Installer)" | grep -v grep
   ```

4. **Test update download**:
   - Trigger manual update check
   - Monitor download progress
   - Verify update installation

### Console Error Fixes Applied
Fixed specific console errors encountered during development:

1. **UNErrorDomain Code=1**: Added notification authorization request in AppDelegate
2. **Sparkle gentle reminders**: Added `supportsGentleScheduledUpdateReminders` property
3. **Icon services**: Added proper entitlements for system service access
4. **Swift 6 concurrency**: Fixed async/await usage in MultiProviderDataProcessor

These fixes are **independent of sandboxing** and work with the current disabled-sandbox configuration.