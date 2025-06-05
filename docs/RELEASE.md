# VibeMeter Release Process

This guide explains how to create and publish releases for VibeMeter, a sandboxed macOS menu bar application using Sparkle for automatic updates.

## 🚀 Quick Start Guide

### Prerequisites Checklist
- [ ] Xcode 16.4+ installed
- [ ] GitHub CLI (`gh`) authenticated: `gh auth status`
- [ ] Tuist installed: `curl -Ls https://install.tuist.io | bash`
- [ ] Apple Developer ID certificate in Keychain
- [ ] Notarization credentials set as environment variables
- [ ] Sparkle tools installed in `~/.local/bin/`

### Creating a Release in 5 Steps

1. **Pre-flight Check**
   ```bash
   ./scripts/preflight-check.sh
   ```

2. **Update Version & Build Number**
   ```bash
   # Increment build number in Project.swift (REQUIRED for every release!)
   # Edit: "CURRENT_PROJECT_VERSION": "207" -> "208"
   
   # For version changes:
   ./scripts/version.sh --patch  # 1.0.0 -> 1.0.1
   ./scripts/version.sh --minor  # 1.0.0 -> 1.1.0
   ./scripts/version.sh --major  # 1.0.0 -> 2.0.0
   ```

3. **Commit Changes**
   ```bash
   git add Project.swift
   git commit -m "Bump version to X.X.X build YYY"
   git push
   ```

4. **Create Release**
   ```bash
   # Stable release
   ./scripts/release.sh stable
   
   # Pre-release (beta, alpha, rc)
   ./scripts/release.sh beta 1
   ./scripts/release.sh alpha 1
   ./scripts/release.sh rc 1
   ```

5. **Verify Success**
   - Check GitHub releases page
   - Test update from previous version
   - Monitor Console.app for any errors

## 📋 What the Release Script Does

The `release.sh` script automates the entire release process:

1. ✅ Validates build numbers are unique and incrementing
2. ✅ Cleans build directory for fresh compilation
3. ✅ Generates Xcode project if needed
4. ✅ Builds the app in Release configuration
5. ✅ Signs and notarizes with Apple Developer ID
6. ✅ Creates and signs DMG disk image
7. ✅ Creates GitHub release with proper tagging
8. ✅ Generates appcast with EdDSA signatures
9. ✅ Commits and pushes all changes

## ⚠️ Critical Requirements

### Build Numbers Are Everything
**Sparkle uses build numbers (CFBundleVersion) to determine updates, NOT version strings!**

| Example | Build | Result |
|---------|-------|--------|
| 1.0.0-beta.1 | 200 | ✅ |
| 1.0.0-beta.2 | 201 | ✅ |
| 1.0.0-beta.3 | 199 | ❌ Build number went backwards |
| 1.0.0 | 201 | ❌ Duplicate build number |

### Required Environment Variables
```bash
export APP_STORE_CONNECT_KEY_ID="YOUR_KEY_ID"
export APP_STORE_CONNECT_ISSUER_ID="YOUR_ISSUER_ID"
export APP_STORE_CONNECT_API_KEY_P8="-----BEGIN PRIVATE KEY-----
YOUR_PRIVATE_KEY_CONTENT
-----END PRIVATE KEY-----"
```

## 🔧 Sparkle Configuration for Sandboxed Apps

### The Challenge
VibeMeter is a sandboxed app, which requires special configuration for Sparkle's automatic updates to work properly.

### Current Configuration (Working)

1. **Info.plist Keys** (in Project.swift)
   ```swift
   "SUEnableInstallerLauncherService": true,
   "SUEnableDownloaderService": false,  // False because we have network access
   ```

2. **Entitlements** (VibeMeter.entitlements)
   ```xml
   <key>com.apple.security.app-sandbox</key>
   <true/>
   <key>com.apple.security.network.client</key>
   <true/>
   <key>com.apple.security.temporary-exception.mach-lookup.global-name</key>
   <array>
       <string>com.steipete.vibemeter-spki</string>
   </array>
   ```

3. **XPC Services - CRITICAL**
   - Must remain inside: `Sparkle.framework/Versions/B/XPCServices/`
   - Do NOT copy to app bundle
   - Do NOT modify XPC service bundle IDs
   - Do NOT re-sign XPC services during build
   - Notarization will handle proper signing

### 🚨 Critical Sparkle Learnings

After extensive debugging, here are the key findings:

1. **XPC Service Bundle IDs Must Match**
   - Sparkle's Installer.xpc uses: `org.sparkle-project.InstallerLauncher`
   - Your app tries to connect to this exact bundle ID
   - Do NOT change the XPC service bundle IDs!

2. **Mach Lookup Entitlements**
   - The `-spki` suffix in entitlements is a Sparkle convention
   - Sparkle internally maps this to the correct XPC service
   - Only the main app needs this entitlement, NOT the XPC services

3. **Build Process Must Not Modify XPC Services**
   - Don't re-sign XPC services during build
   - Don't copy them out of Sparkle.framework
   - Don't modify their Info.plist files
   - Let the notarization process handle signing

4. **Downloader Service Not Needed**
   - Since VibeMeter has `com.apple.security.network.client`
   - Set `SUEnableDownloaderService` to `false`
   - This simplifies the sandbox configuration

### Important Sparkle Documentation Links
- [Sandboxing Guide](https://sparkle-project.org/documentation/sandboxing/)
- [XPC Services](https://sparkle-project.org/documentation/api/protocols/spuupdaterdelegate#updater:willextractupdate:)

## 🛠️ Utility Scripts

### Version Management
```bash
./scripts/version.sh --current   # Show current version
./scripts/version.sh --patch     # Increment patch version
./scripts/version.sh --minor     # Increment minor version
./scripts/version.sh --major     # Increment major version
```

### Verification Tools
```bash
./scripts/verify-app.sh <app-or-dmg>    # Verify signing and notarization
./scripts/verify-appcast.sh             # Validate appcast XML files
./scripts/preflight-check.sh            # Pre-release validation
```

### Build and Sign
```bash
./scripts/build.sh --configuration Release      # Build the app
./scripts/sign-and-notarize.sh --sign-and-notarize  # Sign and notarize
./scripts/create-dmg.sh                         # Create DMG
```

## 📝 Release Channels

VibeMeter supports two update channels:

1. **Stable Channel** (`appcast.xml`)
   - Production-ready releases only
   - Default for all users

2. **Pre-release Channel** (`appcast-prerelease.xml`)
   - Includes beta, alpha, and RC versions
   - Users opt-in via Settings → General

## 🔍 Troubleshooting

### Common Issues

1. **"You're up to date!" when update exists**
   - Check build numbers are incrementing
   - Verify appcast was pushed to GitHub
   - Ensure appcast has correct build number (not "1")

2. **Update Error: Failed to gain authorization**
   - Check XPC services are unmodified
   - Verify entitlements match exactly
   - Ensure Sparkle framework wasn't re-signed during build
   - Check Console.app for XPC connection errors

3. **"An error occurred while launching the installer"**
   - XPC service bundle ID mismatch
   - Missing or incorrect mach-lookup entitlements
   - XPC services were modified during build

4. **Notarization fails**
   - Check environment variables are set
   - Verify Developer ID certificate is valid
   - Ensure all embedded binaries are signed

### Console Debugging
```bash
# Monitor VibeMeter logs
log stream --predicate 'process == "VibeMeter"' --level debug

# Check for Sparkle errors
log stream --predicate 'process == "VibeMeter"' | grep -i -E "(sparkle|xpc|installer)"

# Look for specific errors
log stream --predicate 'subsystem == "com.apple.security"'
```

### Verifying XPC Services
```bash
# Check XPC service bundle IDs
/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" \
  "/path/to/VibeMeter.app/Contents/Frameworks/Sparkle.framework/Versions/B/XPCServices/Installer.xpc/Contents/Info.plist"
# Should output: org.sparkle-project.InstallerLauncher

# Verify XPC services are signed
codesign -dvv "/path/to/VibeMeter.app/Contents/Frameworks/Sparkle.framework/Versions/B/XPCServices/Installer.xpc"
```

## 🔐 Security and Backup

### Critical Files to Backup
- Sparkle EdDSA private key (in Keychain)
- Developer ID certificate (.p12)
- App Store Connect API key (.p8)
- `.github-config` file

### Verify Sparkle Keys
```bash
# Check public key matches
grep "SUPublicEDKey" Project.swift

# Verify private key in Keychain
export PATH="$HOME/.local/bin:$PATH"
generate_keys -p
```

## 📋 Manual Release Process

If you need to perform steps manually (not recommended):

1. **Update Project.swift**
   - Increment `CURRENT_PROJECT_VERSION`
   - Update `MARKETING_VERSION` if needed

2. **Clean Build**
   ```bash
   rm -rf build DerivedData .build
   rm -rf build/SourcePackages  # Clean SPM cache
   ```

3. **Generate and Build**
   ```bash
   ./scripts/generate-xcproj.sh
   ./scripts/build.sh --configuration Release
   ```

4. **Sign and Notarize**
   ```bash
   ./scripts/sign-and-notarize.sh --sign-and-notarize
   ```

5. **Create DMG**
   ```bash
   ./scripts/create-dmg.sh
   ```

6. **Generate Signature**
   ```bash
   sign_update build/VibeMeter-X.X.X.dmg
   ```

7. **Create GitHub Release**
   ```bash
   git tag -a "vX.X.X" -m "Release X.X.X"
   git push origin "vX.X.X"
   gh release create "vX.X.X" --title "VibeMeter X.X.X" build/VibeMeter-X.X.X.dmg
   ```

8. **Update Appcast**
   ```bash
   ./scripts/generate-appcast.sh
   git add appcast*.xml
   git commit -m "Update appcast for vX.X.X"
   git push
   ```

## 📚 Additional Documentation

- **Sparkle Sandboxing**: https://sparkle-project.org/documentation/sandboxing/
- **Apple Notarization**: https://developer.apple.com/documentation/security/notarizing_macos_software_before_distribution
- **Project Architecture**: See CLAUDE.md for codebase details

---

**Remember**: Always increment build numbers, use the automated scripts, and test updates before announcing releases!