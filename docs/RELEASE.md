# VibeMeter Release Process

This guide explains how to create and publish releases for VibeMeter, a sandboxed macOS menu bar application using Sparkle 2.x for automatic updates.

## 🎯 Release Process Overview

VibeMeter uses an automated release process that handles all the complexity of:
- Building and code signing
- Notarization with Apple
- Creating DMG disk images
- Publishing to GitHub
- Updating Sparkle appcast files

## 🚀 Creating a Release

### Step 1: Pre-flight Check
```bash
./scripts/preflight-check.sh
```
This validates your environment is ready for release.

### Step 2: Update CHANGELOG.md
Before creating any release, ensure the CHANGELOG.md file contains a proper section for the version being released:

```markdown
## [1.1.0] - 2025-06-10

### 🎨 UI Improvements
- **Enhanced feature** - Description of the improvement
...
```

**CRITICAL**: The appcast generation relies on the local CHANGELOG.md file, NOT the GitHub release description. The changelog must be added to CHANGELOG.md BEFORE running the release script.

### Step 3: Create the Release
```bash
# For stable releases:
./scripts/release.sh stable

# For pre-releases (beta, alpha, rc):
./scripts/release.sh beta 1    # Creates version-beta.1
./scripts/release.sh alpha 2   # Creates version-alpha.2
./scripts/release.sh rc 1      # Creates version-rc.1
```

**IMPORTANT**: The release script does NOT automatically increment build numbers. You must manually update the build number in Project.swift before running the script, or it will fail the pre-flight check.

The script will:
1. Validate build number is unique and incrementing
2. Generate Xcode project
3. Build, sign, and notarize the app
4. Create a DMG
5. Publish to GitHub
6. Update the appcast files with EdDSA signatures
7. Commit and push all changes

### Step 4: Verify Success
- Check the GitHub releases page
- Verify the appcast was updated correctly with proper changelog content
- Test updating from a previous version
- **Important**: Verify that the Sparkle update dialog shows the formatted changelog, not HTML tags

## ⚠️ Critical Requirements

### 1. Build Numbers MUST Increment
Sparkle uses build numbers (CFBundleVersion) to determine updates, NOT version strings!

| Version | Build | Result |
|---------|-------|--------|
| 1.0.0-beta.1 | 100 | ✅ |
| 1.0.0-beta.2 | 101 | ✅ |
| 1.0.0-beta.3 | 99  | ❌ Build went backwards |
| 1.0.0 | 101 | ❌ Duplicate build number |

### 2. Required Environment Variables
```bash
export APP_STORE_CONNECT_KEY_ID="YOUR_KEY_ID"
export APP_STORE_CONNECT_ISSUER_ID="YOUR_ISSUER_ID"
export APP_STORE_CONNECT_API_KEY_P8="-----BEGIN PRIVATE KEY-----
YOUR_PRIVATE_KEY_CONTENT
-----END PRIVATE KEY-----"
```

### 3. Prerequisites
- Xcode 16.4+ installed
- GitHub CLI authenticated: `gh auth status`
- Apple Developer ID certificate in Keychain
- Sparkle tools in `~/.local/bin/` (sign_update, generate_appcast)

## 🔐 Sparkle Sandboxing Configuration

### Critical Sparkle Requirements for Sandboxed Apps

VibeMeter is sandboxed, which requires specific configuration for Sparkle updates to work:

#### 1. Entitlements (VibeMeter.entitlements)
```xml
<!-- Required for sandbox -->
<key>com.apple.security.app-sandbox</key>
<true/>

<!-- Required for downloading updates -->
<key>com.apple.security.network.client</key>
<true/>

<!-- CRITICAL: Mach lookup exceptions for XPC communication -->
<key>com.apple.security.temporary-exception.mach-lookup.global-name</key>
<array>
    <string>com.steipete.vibemeter-spks</string>
    <string>com.steipete.vibemeter-spki</string>
</array>
```

**Note**: Both `-spks` and `-spki` are required! Missing either will cause "Failed to gain authorization" errors.

#### 2. Info.plist Configuration (in Project.swift)
```swift
"SUEnableInstallerLauncherService": true,   // Required for sandboxed apps
"SUEnableDownloaderService": false,         // False since we have network access
```

#### 3. Code Signing Requirements

The notarization script handles all signing correctly:
1. **Do NOT use --deep flag** when signing the app
2. **Do NOT modify XPC service bundle IDs** (keep as `org.sparkle-project.*`)
3. **Do NOT move XPC services** out of Sparkle.framework
4. **DO re-sign XPC services** with your Developer ID during notarization

The `notarize-app.sh` script follows Sparkle's official documentation:
```bash
# Sign XPC services with our Developer ID (per Sparkle docs)
codesign -f -s "Developer ID Application" -o runtime "Sparkle.framework/.../Installer.xpc"
codesign -f -s "Developer ID Application" -o runtime --preserve-metadata=entitlements "Sparkle.framework/.../Downloader.xpc"

# Sign the app WITHOUT --deep flag
codesign --force --sign "Developer ID Application" --entitlements VibeMeter.entitlements --options runtime VibeMeter.app
```

### Common Sparkle Errors and Solutions

| Error | Cause | Solution |
|-------|-------|----------|
| "Failed to gain authorization required to update target" | Missing mach-lookup entitlements | Ensure BOTH `-spks` and `-spki` are in entitlements |
| "You're up to date!" when update exists | Build number not incrementing | Check build numbers in appcast are correct |
| "Error launching installer" | XPC service signing issues | Ensure notarize script is re-signing XPC services |
| "XPC connection interrupted" | Bundle ID mismatch | Do NOT change XPC service bundle IDs |

## 📋 Update Channels

VibeMeter supports two update channels:

1. **Stable Channel** (`appcast.xml`)
   - Production releases only
   - Default for all users

2. **Pre-release Channel** (`appcast-prerelease.xml`)
   - Includes beta, alpha, and RC versions
   - Users opt-in via Settings

## 🐛 Common Issues and Solutions

### Appcast Shows HTML Tags Instead of Formatted Text
**Problem**: Sparkle update dialog shows escaped HTML like `&lt;h2&gt;` instead of formatted text.

**Root Cause**: The generate-appcast.sh script is escaping HTML content from GitHub release descriptions.

**Solution**: 
1. Ensure CHANGELOG.md has the proper section for the release version BEFORE running release script
2. The appcast should use local CHANGELOG.md, not GitHub release body
3. If the appcast is wrong, manually fix the generate-appcast.sh script to use local changelog content

### Build Numbers Not Incrementing
**Problem**: Sparkle doesn't detect new version as an update.

**Solution**: Always increment the build number in Project.swift before releasing.

## 🛠️ Manual Process (If Needed)

If the automated script fails, here's the manual process:

### 1. Update Build Number
Edit `Project.swift`:
```swift
"CURRENT_PROJECT_VERSION": "100",  // Increment this!
```

### 2. Clean and Build
```bash
rm -rf build DerivedData .build
./scripts/generate-xcproj.sh
./scripts/build.sh --configuration Release
```

### 3. Sign and Notarize
```bash
./scripts/notarize-app.sh build/Build/Products/Release/VibeMeter.app
```

### 4. Create DMG
```bash
./scripts/create-dmg.sh
```

### 5. Sign DMG for Sparkle
```bash
export PATH="$HOME/.local/bin:$PATH"
sign_update build/VibeMeter-X.X.X.dmg
# Copy the sparkle:edSignature value
```

### 6. Create GitHub Release
```bash
gh release create "v1.0.0-beta.1" \
  --title "VibeMeter 1.0.0-beta.1" \
  --notes "Beta release 1" \
  --prerelease \
  build/VibeMeter-1.0.0-beta.1.dmg
```

### 7. Update Appcast
```bash
./scripts/update-appcast.sh
git add appcast*.xml
git commit -m "Update appcast for v1.0.0-beta.1"
git push
```

## 🔍 Troubleshooting

### Debug Sparkle Updates
```bash
# Monitor VibeMeter logs
log stream --predicate 'process == "VibeMeter"' --level debug

# Check XPC errors
log stream --predicate 'process == "VibeMeter"' | grep -i -E "(sparkle|xpc|installer)"

# Verify XPC services
codesign -dvv "VibeMeter.app/Contents/Frameworks/Sparkle.framework/Versions/B/XPCServices/Installer.xpc"
```

### Verify Signing and Notarization
```bash
# Check app signature
./scripts/verify-app.sh build/VibeMeter-1.0.0.dmg

# Verify XPC bundle IDs (should be org.sparkle-project.*)
/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" \
  "VibeMeter.app/Contents/Frameworks/Sparkle.framework/Versions/B/XPCServices/Installer.xpc/Contents/Info.plist"
```

### Appcast Issues
```bash
# Verify appcast has correct build numbers
./scripts/verify-appcast.sh

# Check if build number is "1" (common bug)
grep '<sparkle:version>' appcast-prerelease.xml
```

## 📚 Important Links

- [Sparkle Sandboxing Guide](https://sparkle-project.org/documentation/sandboxing/)
- [Sparkle Code Signing](https://sparkle-project.org/documentation/sandboxing/#code-signing)
- [Apple Notarization](https://developer.apple.com/documentation/security/notarizing_macos_software_before_distribution)

---

**Remember**: Always use the automated release script, ensure build numbers increment, and test updates before announcing!