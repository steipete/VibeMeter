# Release Process for VibeMeter

This document describes the process for creating and publishing a new release of VibeMeter.

## 🚀 Automated Release (Recommended)

The simplest way to create a release is using the automated scripts.

### What the Automation Does

The release automation handles these complex tasks automatically:
1. **Xcode Project Generation** - Regenerates if Project.swift changed
2. **Build Number Validation** - Ensures unique, incrementing build numbers
3. **Sparkle XPC Services** - Applies sandbox fixes automatically
4. **Code Signing & Notarization** - Full signing with correct entitlements
5. **DMG Creation** - Creates and signs distribution disk image
6. **GitHub Release** - Creates release with proper tagging
7. **Appcast Updates** - Extracts real build numbers from DMGs
8. **Git Management** - Commits and pushes all changes

### Quick Start

### 1. Pre-flight Check
```bash
./scripts/preflight-check.sh
```
This validates everything is ready for release. Fix any issues before proceeding.

### 2. Update Version
```bash
# For patch release (1.0.0 -> 1.0.1)
./scripts/version.sh --patch

# For minor release (1.0.0 -> 1.1.0)
./scripts/version.sh --minor

# For major release (1.0.0 -> 2.0.0)
./scripts/version.sh --major

# Always increment build number in Project.swift
# Edit: "CURRENT_PROJECT_VERSION": "201" -> "202"
```

### 3. Commit Changes
```bash
git add Project.swift
git commit -m "Bump version to X.X.X"
```

### 4. Create Release
```bash
# For stable release
./scripts/release-auto.sh stable

# For beta release
./scripts/release-auto.sh beta 1

# For alpha release
./scripts/release-auto.sh alpha 1

# For release candidate
./scripts/release-auto.sh rc 1
```

The automated script will:
- ✅ Run pre-flight checks
- ✅ Automatically regenerate Xcode project if needed
- ✅ Build the app (with xcbeautify for clean output)
- ✅ Commit Xcode project changes if generated
- ✅ Sign and notarize
- ✅ Create DMG
- ✅ Handle existing tags with interactive prompt
- ✅ Create GitHub release
- ✅ Update appcast with proper signature
- ✅ Verify appcast was updated correctly
- ✅ Commit and push changes

## 🛠️ Utility Scripts

### Verification Tools
```bash
./scripts/verify-app.sh <app-or-dmg>       # Verify signing, notarization, entitlements
./scripts/verify-appcast.sh                # Validate appcast files
```

### Version Management
```bash
./scripts/version.sh --current             # Show current version
./scripts/version.sh --patch               # Bump patch version (1.0.0 -> 1.0.1)
./scripts/version.sh --minor               # Bump minor version (1.0.0 -> 1.1.0)
./scripts/version.sh --major               # Bump major version (1.0.0 -> 2.0.0)
```

## 🎯 Critical Learnings from Beta Testing

### Sparkle Integration for Sandboxed Apps

Through extensive beta testing, we discovered that getting Sparkle to work in a sandboxed macOS app requires precise configuration:

1. **XPC Service Bundle Identifiers Must Match Convention**
   ```
   com.steipete.vibemeter-spks  # Downloader service (NOT -spkd!)
   com.steipete.vibemeter-spki  # Installer service
   ```

2. **XPC Services Must Be Relocated**
   - Copy from: `Sparkle.framework/Versions/B/XPCServices/`
   - To: `VibeMeter.app/Contents/XPCServices/`
   - Update their Info.plist bundle identifiers
   - Re-sign with sandbox entitlements

3. **SparkleUpdaterManager Requirements**
   - Implement all delegate methods, especially `standardUserDriverWillHandleShowingUpdate`
   - Add update check synchronization to prevent "sessionInProgress" errors
   - Implement gentle reminders for background apps

4. **Build Number Management**
   - Build numbers must always increase across ALL releases
   - The appcast generator now extracts actual build numbers from DMGs
   - No more hardcoded build number guessing

### Automation Improvements Made

1. **fix-sparkle-sandbox.sh** - Automatically configures XPC services
2. **extract-build-number.sh** - Reads real build numbers from DMGs
3. **release-auto.sh** - Handles Xcode project changes and applies all fixes
4. **generate-appcast.sh** - Uses actual build numbers instead of guessing

### Script Readiness for Next Release

All scripts have been updated and are ready for the next release cycle:

1. **Sparkle Fix Applied Automatically**
   - In `build.sh` for Release builds
   - In `release-auto.sh` after build step
   - XPC services will use correct bundle IDs (`-spks` and `-spki`)

2. **Build Numbers Extracted Correctly**
   - `generate-appcast.sh` uses `extract-build-number.sh`
   - No more hardcoded signatures or build numbers
   - Signatures are cached for performance

3. **Configuration Centralized**
   - GitHub username/repo in `.github-config`
   - Consistent minimum system version (15.0)
   - No more hardcoded values in scripts

4. **Error Handling Improved**
   - Missing dependency warnings
   - Better fallback mechanisms
   - Clear error messages

## ⚠️ CRITICAL: Common Release Pitfalls

### 1. Build Number Rules (MOST IMPORTANT)
**Sparkle uses build numbers (CFBundleVersion) to determine updates, NOT version strings!**

**Absolute Requirements**:
- Build numbers MUST be unique across ALL releases (stable and pre-release)
- Build numbers MUST always increase (e.g., 100 → 101 → 102)
- Build numbers can NEVER be reused or go backwards
- The scripts now validate this automatically and will refuse to build if violated

**Example**:
- beta.1: build 200 ✅
- beta.2: build 201 ✅  
- beta.3: build 199 ❌ (lower than beta.1)
- v1.0.0: build 200 ❌ (duplicate of beta.1)

### 2. Clean Build Directory
**Issue**: Old build artifacts can be packaged instead of fresh builds

**Solution**: 
- Scripts now automatically clean the build directory before each release
- This ensures a completely fresh compile every time
- Manual clean: `rm -rf build/`

### 3. Double Beta Suffix Problem
**Issue**: Creating pre-releases when MARKETING_VERSION already contains a suffix (e.g., "1.0.0-beta.1") results in doubled suffixes like "1.0.0-beta.1-beta.1"

**Solution**: 
- Always reset MARKETING_VERSION to base version (e.g., "1.0.0") before creating pre-releases
- The scripts now handle this automatically with warnings

### 4. Build Verification
**Issue**: Release scripts may package wrong builds if compilation fails

**Solution**: Scripts now:
- Verify the built app has the expected build number
- Check build number against all existing releases
- Refuse to proceed if build number already exists

### 5. Appcast Build Number Verification
**Always manually verify** build numbers in appcast match the actual compiled app:
```bash
# Check build number in DMG
hdiutil attach VibeMeter-X.X.X.dmg
defaults read "/Volumes/VibeMeter/VibeMeter.app/Contents/Info.plist" CFBundleVersion
defaults read "/Volumes/VibeMeter/VibeMeter.app/Contents/Info.plist" CFBundleShortVersionString
hdiutil detach "/Volumes/VibeMeter"
```

## Quick Summary for v1.0.0

**Current Status:**
- Version: 1.0.0
- Build: 100
- Sandboxing: ENABLED ✅
- All entitlements configured for Sparkle compatibility

**Key Changes from Beta:**
- Full app sandboxing enabled
- Fixed XPC service entitlements for network access
- Proper build number management

**Critical Reminders:**
1. **Git must be clean** - No uncommitted changes before starting release
2. **Use scripts only** - No manual workarounds, scripts handle all complexity
3. **Build numbers MUST increment** - Sparkle uses build numbers, not version strings
4. **Sequential process** - Tag → Release → Appcast → Push (cannot batch)
5. **Verify entitlements after building** - Both main app and XPC services
6. **Test updates from previous version** - Install beta and verify update to 1.0.0 works
7. **Appcast build numbers must match** - Manual verification required after generation

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

### Other Release Options

#### Quick Release (Using Existing Build)
If you already have a built, signed, and notarized app:

```bash
./scripts/release-from-existing.sh
```

#### Local Build and Release
To build everything from scratch without GitHub:

```bash
./scripts/release-local.sh
```

### Manual Release Process (If Not Using Automated Scripts)

If you need to perform the release steps manually, follow the detailed instructions in the sections below. However, the automated release process is strongly recommended as it handles all these steps automatically.

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

**CRITICAL: Build Number Management**

The `sparkle:version` field in the appcast MUST match the actual `CFBundleVersion` in the built app's Info.plist. Sparkle uses this number (not the marketing version) to determine if an update is available.

**Common Issues:**
1. **Build number mismatch**: If the appcast has a lower build number than what's installed, users will see "You're up to date!" even when a newer version exists.
2. **Same build number**: If multiple releases have the same build number, Sparkle won't see them as updates.

**Best Practice:**
- Always increment `CURRENT_PROJECT_VERSION` in Project.swift before each release
- Verify the build number matches between:
  - Project.swift: `"CURRENT_PROJECT_VERSION": "201"`
  - Built app: `defaults read /path/to/VibeMeter.app/Contents/Info.plist CFBundleVersion`
  - Appcast: `<sparkle:version>201</sparkle:version>`

#### Automatic Appcast Generation Note

The `generate-appcast.sh` script tries to automatically assign build numbers based on version strings (e.g., beta.1 = 100, beta.2 = 101). However, this often doesn't match the actual build numbers in your compiled apps. **Always manually verify and update the sparkle:version fields after running the script.**

### Step 7: Create GitHub Release and Update Appcast

**IMPORTANT: Each release requires the FULL process:**
1. Build and sign the app
2. Create the GitHub release with DMG
3. Update the appcast with the GitHub download URL
4. Commit and push the appcast

**DO NOT:**
- Build multiple versions then update appcast later
- Update appcast before the GitHub release exists
- Skip the appcast update for any release

```bash
# Create and push tag FIRST
git tag -a "vX.X.X" -m "Release X.X.X"
git push origin "vX.X.X"

# Create GitHub release with the DMG
gh release create "vX.X.X" \
    --title "VibeMeter X.X.X" \
    --notes "Release notes here" \
    build/VibeMeter-X.X.X.dmg

# NOW update appcast with the GitHub download URL
# Run generate-appcast.sh or manually update
./scripts/generate-appcast.sh

# Verify and fix build numbers in appcast
# Commit the updated appcast
git add appcast.xml appcast-prerelease.xml
git commit -m "Update appcast for version X.X.X"
git push origin main
```

**Release Order is Critical:**
1. Tag → 2. GitHub Release → 3. Appcast Update → 4. Push Appcast

## Troubleshooting

### Release Version Issues

#### "You're up to date!" when update should be available
**Cause**: Build number in appcast is lower than or equal to installed version
**Solution**: 
1. Check installed app build number
2. Ensure new release has higher build number
3. Update appcast with correct build number

#### Double beta suffix (e.g., "1.0.0-beta.1-beta.1")
**Cause**: MARKETING_VERSION already contains pre-release suffix
**Solution**:
1. Reset MARKETING_VERSION to base version in Project.swift
2. Re-run release script
3. Scripts now detect and warn about this

#### Release contains wrong app version
**Cause**: Build failed but script packaged old build
**Solution**:
1. Clean build folder: `rm -rf build/`
2. Verify Project.swift has correct version/build
3. Re-run release script
4. Always verify DMG contents before uploading

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

## Complete Release Workflow with Verification


### 📋 What Happens During Release

The release scripts perform these steps automatically:

1. **Pre-Build Validation**
   - ✅ Clean build directory (`rm -rf build/`)
   - ✅ Validate build number is unique
   - ✅ Validate build number is higher than all existing
   - ✅ Show pre-flight summary and get confirmation

2. **Build Phase**
   - ✅ Generate Xcode project
   - ✅ Build in Release configuration
   - ✅ Verify built app has correct build number

3. **Signing & Notarization**
   - ✅ Code sign with Developer ID
   - ✅ Submit for notarization
   - ✅ Wait for notarization completion
   - ✅ Staple notarization ticket

4. **App Verification** (`verify-app.sh`)
   - ✅ Verify Developer ID signature
   - ✅ Check Gatekeeper acceptance
   - ✅ Validate all entitlements
   - ✅ Verify Sparkle XPC services
   - ✅ Check XPC network entitlements

5. **DMG Creation & Verification**
   - ✅ Create styled DMG
   - ✅ Verify DMG mounts correctly
   - ✅ Run full verification on DMG contents

6. **GitHub Release**
   - ✅ Create git tag
   - ✅ Upload DMG to GitHub
   - ✅ Generate release notes

7. **Appcast Update & Validation**
   - ✅ Generate EdDSA signature
   - ✅ Update appcast XML
   - ✅ Validate XML syntax
   - ✅ Check build numbers
   - ✅ Verify GitHub URLs
   - ✅ Cross-validate appcasts

8. **Final Summary**
   - ✅ Show verification results
   - ✅ Display next steps
   - ✅ Provide release URL

### 🧪 Pre-flight Check

Before releasing, always run the pre-flight check:
```bash
./scripts/preflight-check.sh
```

This validates:
- Git status and branch
- Version and build numbers
- Required tools and authentication
- Signing configuration
- Sparkle setup
- Appcast validity

### 🔍 Manual Verification Commands

**Verify a built app or DMG:**
```bash
./scripts/verify-app.sh /path/to/VibeMeter.app
./scripts/verify-app.sh /path/to/VibeMeter-1.0.0.dmg
```

**Validate appcast files:**
```bash
./scripts/verify-appcast.sh
```

**Check specific entitlements:**
```bash
codesign -d --entitlements :- /path/to/VibeMeter.app
```

**Check notarization status:**
```bash
spctl -a -vvv /path/to/VibeMeter.app
```

**Verify XPC services:**
```bash
codesign --verify --deep /path/to/VibeMeter.app/Contents/Frameworks/Sparkle.framework/Versions/B/XPCServices/Downloader.xpc
```

### ⚠️ Common Verification Failures and Solutions

1. **"Build number already exists"**
   - Solution: Increment CURRENT_PROJECT_VERSION in Project.swift

2. **"App verification failed - missing network entitlement"**
   - Solution: Check VibeMeter.entitlements file
   - Ensure: `com.apple.security.network.client = true`

3. **"XPC service missing network access"**
   - Solution: Run `./scripts/notarize-app.sh` which applies correct entitlements

4. **"Appcast validation failed - duplicate builds"**
   - Solution: Check both appcast.xml and appcast-prerelease.xml
   - Remove duplicate entries

5. **"Not accepted by Gatekeeper"**
   - Solution: Ensure notarization completed successfully
   - Check: `xcrun notarytool log <submission-id>`

### 📊 Release Verification Matrix

| Step | What's Verified | Script | When |
|------|----------------|---------|------|
| Build Numbers | Unique & Increasing | Built into release scripts | Pre-build |
| App Signing | Developer ID | `verify-app.sh` | Post-sign |
| Notarization | Gatekeeper | `verify-app.sh` | Post-notarize |
| Entitlements | Sandbox, Network | `verify-app.sh` | Post-sign |
| XPC Services | Signing & Network | `verify-app.sh` | Post-sign |
| DMG Contents | Correct Version | `verify-app.sh` | Post-DMG |
| Appcast XML | Valid & Consistent | `verify-appcast.sh` | Post-update |
| GitHub Release | Exists & Accessible | `verify-appcast.sh` | Post-release |

## Complete Release Checklist for v1.0.0

**IMPORTANT: Always use the provided scripts for releases. Do not use manual workarounds or shortcuts. The scripts ensure consistency and handle all the complex signing, notarization, and packaging steps correctly.**

### Pre-Release
- [ ] **CRITICAL**: Ensure git working directory is clean
  ```bash
  git status  # Should show "nothing to commit, working tree clean"
  ```
- [ ] **CRITICAL**: Increment `CURRENT_PROJECT_VERSION` in Project.swift
  - Current: "100" for v1.0.0
  - Must be higher than any previous release
- [ ] Verify `MARKETING_VERSION` is set to "1.0.0"
- [ ] Update CHANGELOG.md with v1.0.0 release notes
- [ ] Verify sandboxing is enabled in VibeMeter.entitlements
- [ ] Commit all changes:
  ```bash
  git add -A
  git commit -m "Prepare for v1.0.0 release"
  git push origin main
  ```
- [ ] Verify git is clean again: `git status`
- [ ] Test build and functionality locally
- [ ] Run tests: `xcodebuild test`
- [ ] Run linter: `./scripts/lint.sh`

### Build and Sign
- [ ] Generate Xcode project: `./scripts/generate-xcproj.sh`
- [ ] Build release: `./scripts/build.sh --configuration Release`
- [ ] Verify entitlements on built app:
  ```bash
  codesign -d --entitlements :- build/Build/Products/Release/VibeMeter.app 2>/dev/null | plutil -p -
  # Should show: "com.apple.security.app-sandbox" => 1
  ```
- [ ] Verify XPC service entitlements:
  ```bash
  codesign -d --entitlements :- build/Build/Products/Release/VibeMeter.app/Contents/Frameworks/Sparkle.framework/Versions/B/XPCServices/Downloader.xpc 2>/dev/null | plutil -p -
  # Should show: "com.apple.security.network.client" => 1
  ```
- [ ] Sign and notarize: `./scripts/sign-and-notarize.sh --sign-and-notarize`
- [ ] Create DMG: `./scripts/create-dmg.sh`
- [ ] Generate EdDSA signature: `sign_update build/VibeMeter-1.0.0.dmg -p`

### Appcast Update
- [ ] Run `./scripts/generate-appcast.sh`
- [ ] **MANUALLY VERIFY** build numbers in appcast match actual app:
  ```bash
  defaults read build/Build/Products/Release/VibeMeter.app/Contents/Info.plist CFBundleVersion
  # Should match <sparkle:version> in appcast
  ```
- [ ] Update appcast with correct signature from sign_update
- [ ] Ensure appcast has proper download URLs pointing to GitHub releases

### Release (MUST be done in order)
- [ ] Create and push git tag: `git tag -a "v1.0.0" -m "Release 1.0.0" && git push origin v1.0.0`
- [ ] Create GitHub release: `./scripts/release-auto.sh stable` OR manually with `gh release create`
- [ ] Verify DMG is attached to release on GitHub
- [ ] Generate/update appcast: `./scripts/generate-appcast.sh`
- [ ] Manually verify build numbers in appcast match the built app
- [ ] Test download URL from appcast works
- [ ] Commit and push appcast: `git add appcast*.xml && git commit -m "Update appcast for v1.0.0" && git push`

### Post-Release Testing
- [ ] Install previous version (if exists)
- [ ] Open Console.app and filter for "VibeMeter"
- [ ] Check for updates - should find v1.0.0
- [ ] Verify update installs successfully
- [ ] Verify sandboxed app functions correctly:
  - [ ] Network access works (Cursor API, exchange rates)
  - [ ] Login via WebKit works
  - [ ] Settings persistence works
  - [ ] Sparkle updates work

### Post-Release
- [ ] Push updated appcast to main branch
- [ ] Monitor GitHub issues for any problems
- [ ] Update documentation if needed
- [ ] Announce release

## Scripts Overview

### Core Build Scripts

#### `generate-xcproj.sh`
Generates the Xcode project using Tuist. Must be run after modifying `Project.swift` or `Tuist.swift`.

#### `build.sh`
Builds the application with specified configuration.
- Usage: `./scripts/build.sh --configuration Release`
- Automatically generates Xcode project if needed
- Supports Debug and Release configurations

#### `sign-and-notarize.sh`
Signs and notarizes the app for distribution.
- Usage: `./scripts/sign-and-notarize.sh --app-path <path> --sign-and-notarize`
- Options:
  - `--sign-only`: Only code sign, skip notarization
  - `--sign-and-notarize`: Full signing and notarization
- Requires Apple Developer credentials

#### `create-dmg.sh`
Creates a distribution DMG from the signed app.
- Usage: `./scripts/create-dmg.sh <app-path> [dmg-path]`
- Automatically generates DMG filename if not specified
- Creates a styled DMG with background and app icon

### Version Management

#### `version.sh`
Manages version numbers in Project.swift.
- Usage:
  - Show current: `./scripts/version.sh --current`
  - Bump patch: `./scripts/version.sh --patch`
  - Bump minor: `./scripts/version.sh --minor`
  - Bump major: `./scripts/version.sh --major`
  - Set specific: `./scripts/version.sh --set 1.0.0`
  - Pre-release: `./scripts/version.sh --prerelease beta`

### Verification Scripts

#### `verify-app.sh`
Comprehensive app verification for signing, notarization, and entitlements.
- Usage: `./scripts/verify-app.sh <app-or-dmg-path>`
- **Checks:**
  - Code signing (Developer ID vs ad-hoc)
  - Notarization status
  - Gatekeeper acceptance
  - All entitlements (sandbox, network, downloads)
  - Sparkle framework presence
  - XPC service signing and entitlements
  - Build number validation
  - Sparkle public key configuration
- **Exit codes:**
  - 0: All critical checks passed
  - 1: Critical issues found

#### `verify-appcast.sh`
Validates appcast XML files for correctness and consistency.
- Usage: `./scripts/verify-appcast.sh`
- **Validates:**
  - XML syntax
  - Build number uniqueness
  - Build number ordering (newest first)
  - Download URL validity
  - GitHub release existence
  - EdDSA signature presence
  - File size validity
  - Cross-validation between stable and pre-release
- Shows detailed report with pass/fail for each check

#### `preflight-check.sh`
Comprehensive pre-flight check before creating a release.
- Usage: `./scripts/preflight-check.sh`
- **Validates:**
  - Git status (clean working directory, branch, sync with remote)
  - Version and build number configuration
  - Build number uniqueness and monotonic increase
  - Required tools (gh, tuist, Sparkle tools, xcbeautify)
  - GitHub CLI authentication
  - Code signing certificate availability
  - Notarization credentials
  - Sparkle key configuration
  - Appcast file validity
- Provides clear pass/fail status for each check
- Exits with error if any critical checks fail

#### `release-auto.sh`
Automated release script that handles the complete release process.
- Usage: 
  - Stable: `./scripts/release-auto.sh stable`
  - Pre-release: `./scripts/release-auto.sh beta 1`
- **Process:**
  1. Runs pre-flight check
  2. Generates Xcode project
  3. Builds the app with xcbeautify
  4. Signs and notarizes
  5. Creates DMG
  6. Creates GitHub release
  7. Updates appcast
  8. Commits and pushes changes
- Stops immediately on any error
- Provides clear progress updates

### Appcast Management Scripts

#### `update-appcast.sh`
Updates the stable appcast.xml with new release information.
- Usage: `./scripts/update-appcast.sh <version> <build> <dmg-path>`
- Generates EdDSA signature
- Extracts release notes from CHANGELOG.md
- Updates appcast with proper formatting

#### `generate-appcast.sh`
Regenerates appcast files from existing releases.
- Scans release directory
- Generates both stable and pre-release appcasts
- Maintains proper ordering (newest first)

### Utility Scripts

#### `format.sh`
Formats Swift code using SwiftFormat.
- Enforces consistent code style
- Runs on all Swift files in the project

#### `lint.sh`
Lints Swift code using SwiftLint.
- Checks for code quality issues
- Enforces style guidelines

#### `changelog-to-html.sh`
Converts CHANGELOG.md entries to HTML for Sparkle.
- Used by appcast update scripts
- Maintains proper HTML formatting

## Automatic Verification Features

### Build Directory Cleaning
All release scripts automatically run `rm -rf build/` before building to ensure:
- No stale artifacts are packaged
- Fresh compilation every time
- Consistent build environment

### Build Number Validation
Before building, scripts check:
- Build number doesn't already exist in any appcast
- Build number is higher than all existing releases
- Shows highest existing build and suggests next number
- **Refuses to proceed if validation fails**

### Post-Build Verification
After building, scripts verify:
- Built app has the expected build number
- App bundle exists and is valid
- **Prevents packaging wrong build**

### Signing and Notarization Verification
After signing, `verify-app.sh` automatically checks:
- Valid Developer ID signature
- Notarization acceptance by Gatekeeper
- Correct entitlements for:
  - App sandbox
  - Network access
  - Downloads folder access
  - XPC service communication
- Sparkle XPC services are properly signed
- XPC services have network entitlements

### DMG Verification
Before uploading, scripts verify:
- DMG mounts successfully
- Contains correct app version
- App in DMG passes all verification checks

### Appcast Validation
After updating appcast, `verify-appcast.sh` checks:
- Valid XML syntax
- No duplicate build numbers
- Proper build number ordering
- Valid download URLs
- GitHub releases exist
- EdDSA signatures present
- No conflicts between stable and pre-release

### Pre-flight Checks
Release scripts show summary before building:
- Current version and build number
- What will be built
- Validation status
- **Requires user confirmation**

## Verification Exit Points

The release process will automatically stop if:
1. Build number already exists
2. Build number is not higher than existing
3. Built app has wrong build number
4. App signing fails
5. Notarization fails
6. App verification fails (entitlements, etc.)
7. DMG creation fails
8. DMG verification fails
9. GitHub release creation fails
10. Appcast has critical issues

Each failure provides specific error messages to help diagnose the issue.

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

## Sandboxing Configuration

### App Sandboxing Status: ENABLED (as of v1.0.0)

VibeMeter now runs with full app sandboxing enabled for enhanced security and potential future App Store distribution.

#### Complete Sandboxing Setup

##### Main App Entitlements (VibeMeter/VibeMeter.entitlements)

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <!-- Enable app sandboxing -->
    <key>com.apple.security.app-sandbox</key>
    <true/>
    
    <!-- Network access for Cursor API and exchange rates -->
    <key>com.apple.security.network.client</key>
    <true/>
    
    <!-- Downloads folder access for Sparkle updates -->
    <key>com.apple.security.files.downloads.read-write</key>
    <true/>
    
    <!-- Required for WebKit-based login -->
    <key>com.apple.security.cs.allow-unsigned-executable-memory</key>
    <true/>
    
    <!-- Required for Sparkle framework loading -->
    <key>com.apple.security.cs.disable-library-validation</key>
    <true/>
    
    <!-- XPC service communication with Sparkle -->
    <key>com.apple.security.temporary-exception.mach-lookup.global-name</key>
    <array>
        <string>com.steipete.vibemeter-spks</string>
        <string>com.steipete.vibemeter-spkd</string>
    </array>
</dict>
</plist>
```

#### Understanding Sparkle's XPC Services

Sparkle 2.x uses two XPC (inter-process communication) services for security and reliability:

1. **Downloader.xpc** (`com.steipete.vibemeter-spks`)
   - Downloads update files from the internet
   - Runs in a separate sandboxed process for security
   - Requires `com.apple.security.network.client` to access GitHub

2. **Installer.xpc** (`com.steipete.vibemeter-spkd`)
   - Installs the downloaded update
   - Handles file operations and app replacement
   - Runs with elevated privileges when needed
   - Requires file system access entitlements

**Why XPC Services?**
- **Security**: Update operations run in isolated processes
- **Reliability**: If the main app crashes, updates can still complete
- **Sandboxing**: XPC services are ALWAYS sandboxed by macOS, even if the main app isn't

**The mach-lookup exceptions** (`-spks` and `-spkd`) allow the main app to communicate with these XPC services. Without these exceptions, Sparkle cannot initiate downloads or installations.

##### Critical: Sparkle XPC Service Entitlements

**IMPORTANT**: Sparkle's XPC services are ALWAYS sandboxed by macOS, regardless of the main app's sandbox status. These services require specific entitlements to function properly:

##### XPC Service Entitlements (Applied by notarize-app.sh)

The notarize-app.sh script automatically applies these entitlements to XPC services:

```xml
<!-- XPC services are always sandboxed -->
<key>com.apple.security.app-sandbox</key>
<true/>

<!-- Required for downloading updates -->
<key>com.apple.security.network.client</key>
<true/>

<!-- Required for file operations during update -->
<key>com.apple.security.files.user-selected.read-write</key>
<true/>

<!-- XPC service communication -->
<key>com.apple.security.temporary-exception.mach-lookup.global-name</key>
<array>
    <string>com.steipete.vibemeter-spks</string>
    <string>com.steipete.vibemeter-spki</string>
</array>
```

##### Common Errors Without Proper Entitlements

1. **DNS/Network Errors**: If `com.apple.security.network.client` is missing:
   ```
   Error Domain=NSURLErrorDomain Code=-1003 "A server with the specified hostname could not be found."
   ```

2. **XPC Service Bootstrap Failures**: 
   ```
   [0x11d60f4e0] failed to do a bootstrap look-up: xpc_error=[3: No such process]
   ```

##### Verifying XPC Service Entitlements

After building, always verify the XPC services have correct entitlements:
```bash
# Check Downloader.xpc entitlements
codesign -d --entitlements :- /path/to/VibeMeter.app/Contents/Frameworks/Sparkle.framework/Versions/B/XPCServices/Downloader.xpc 2>/dev/null | plutil -p -

# Should show:
# "com.apple.security.app-sandbox" => 1
# "com.apple.security.network.client" => 1
# "com.apple.security.files.user-selected.read-write" => 1
```

### Sparkle XPC Services for Sandboxed Apps

**CRITICAL**: For Sparkle to work in a sandboxed app, XPC services must be properly configured.

#### Lessons Learned from Beta Testing

During the development of beta releases, we discovered several critical requirements for Sparkle in sandboxed apps:

1. **XPC Service Bundle ID Naming Convention**
   - Sparkle expects specific suffixes: `-spks` (Downloader) and `-spki` (Installer)
   - NOT `-spkd` as some documentation might suggest
   - Full bundle IDs: `com.steipete.vibemeter-spks` and `com.steipete.vibemeter-spki`

2. **XPC Services Must Be in App Bundle**
   - Services cannot run from within Sparkle.framework in sandboxed apps
   - Must be copied to `VibeMeter.app/Contents/XPCServices/`
   - Must have their bundle identifiers updated to match your app

3. **Delegate Method Requirements**
   - Must implement `standardUserDriverWillHandleShowingUpdate` to avoid errors
   - Implement gentle reminders for background apps to avoid warnings
   - Handle multiple update check prevention with state tracking

4. **Common Errors and Solutions**
   - `failed to do a bootstrap look-up: xpc_error=[3: No such process]`
     - Solution: XPC services not found or wrong bundle IDs
   - `Error: Failed to gain authorization required to update target`
     - Solution: XPC services need proper entitlements and bundle IDs
   - `Error: -checkForUpdatesInBackground called but .sessionInProgress == YES`
     - Solution: Implement update check synchronization
   - `Delegate is handling showing scheduled update but does not implement standardUserDriverWillHandleShowingUpdate`
     - Solution: Add the missing delegate method

#### The Problem
When an app is sandboxed, Sparkle's XPC services (Downloader.xpc and Installer.xpc) cannot communicate with the main app unless they:
1. Are located in the app bundle's `Contents/XPCServices/` directory
2. Have bundle identifiers that match the mach-lookup exceptions in entitlements
3. Are signed with proper sandbox entitlements

#### The Solution
The `fix-sparkle-sandbox.sh` script (integrated into the build process) handles this:

```bash
# Automatically applied during notarization
./scripts/fix-sparkle-sandbox.sh /path/to/VibeMeter.app
```

This script:
1. Copies XPC services from Sparkle.framework to app's XPCServices directory
2. Renames them to match entitlements:
   - `Downloader.xpc` → `com.steipete.vibemeter-spks.xpc`
   - `Installer.xpc` → `com.steipete.vibemeter-spki.xpc`
3. Updates their Info.plist bundle identifiers
4. Signs them with sandbox entitlements

#### Required Entitlements
The main app's entitlements must include:
```xml
<key>com.apple.security.temporary-exception.mach-lookup.global-name</key>
<array>
    <string>com.steipete.vibemeter-spks</string>
    <string>com.steipete.vibemeter-spki</string>
</array>
```

#### Troubleshooting Sparkle Sandbox Issues
If you see errors like:
- `failed to do a bootstrap look-up: xpc_error=[3: No such process]`
- `Error: Failed to gain authorization required to update target`

Check:
1. XPC services exist: `ls -la /path/to/VibeMeter.app/Contents/XPCServices/`
2. Bundle IDs are correct: `plutil -p /path/to/VibeMeter.app/Contents/XPCServices/*/Contents/Info.plist | grep CFBundleIdentifier`
3. Services are signed: `codesign -dv /path/to/VibeMeter.app/Contents/XPCServices/*`

### Sandboxing Evolution

VibeMeter v1.0.0 successfully enabled full app sandboxing after resolving Sparkle XPC service issues.

#### Key Learnings

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