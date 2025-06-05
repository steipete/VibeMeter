# VibeMeter Scripts Directory

This directory contains all automation scripts for VibeMeter development, building, and release management. Each script is thoroughly documented with headers explaining usage, dependencies, and examples.

## 📋 Script Categories

### 🏗️ **Core Development Scripts**

| Script | Purpose | Usage |
|--------|---------|-------|
| [`generate-xcproj.sh`](./generate-xcproj.sh) | Generate Xcode project with Tuist | `./scripts/generate-xcproj.sh` |
| [`build.sh`](./build.sh) | Build VibeMeter app with optional signing | `./scripts/build.sh [--configuration Debug\|Release] [--sign]` |
| [`format.sh`](./format.sh) | Format Swift code with SwiftFormat | `./scripts/format.sh` |
| [`lint.sh`](./lint.sh) | Run SwiftLint code analysis | `./scripts/lint.sh` |

### 🚀 **Release Management Scripts**

| Script | Purpose | Usage |
|--------|---------|-------|
| [`preflight-check.sh`](./preflight-check.sh) | Validate release readiness | `./scripts/preflight-check.sh` |
| [`release.sh`](./release.sh) | **Main release automation script** | `./scripts/release.sh <stable\|beta\|alpha\|rc> [number]` |
| [`version.sh`](./version.sh) | Manage version numbers | `./scripts/version.sh --patch\|--minor\|--major` |

### 🔐 **Code Signing & Distribution**

| Script | Purpose | Usage |
|--------|---------|-------|
| [`sign-and-notarize.sh`](./sign-and-notarize.sh) | Sign and notarize app bundles | `./scripts/sign-and-notarize.sh --sign-and-notarize` |
| [`codesign-app.sh`](./codesign-app.sh) | Code sign app bundle only | `./scripts/codesign-app.sh <app-path>` |
| [`notarize-app.sh`](./notarize-app.sh) | Notarize signed app bundle | `./scripts/notarize-app.sh <app-path>` |
| [`create-dmg.sh`](./create-dmg.sh) | Create and sign DMG files | `./scripts/create-dmg.sh <app-path> [dmg-path]` |

📝 **Related article**: [Code Signing and Notarization: Sparkle and Tears](https://steipete.me/posts/2025/code-signing-and-notarization-sparkle-and-tears)

### 📡 **Update System Scripts**

| Script | Purpose | Usage |
|--------|---------|-------|
| [`generate-appcast.sh`](./generate-appcast.sh) | Generate Sparkle appcast XML | `./scripts/generate-appcast.sh` |
| [`update-appcast.sh`](./update-appcast.sh) | Update appcast for specific release | `./scripts/update-appcast.sh <version> <build> <dmg-path>` |

### ✅ **Verification & Testing Scripts**

| Script | Purpose | Usage |
|--------|---------|-------|
| [`verify-prerelease-system.sh`](./verify-prerelease-system.sh) | Verify IS_PRERELEASE_BUILD system | `./scripts/verify-prerelease-system.sh` |
| [`verify-app.sh`](./verify-app.sh) | Verify app signing and notarization | `./scripts/verify-app.sh <app-or-dmg-path>` |
| [`verify-appcast.sh`](./verify-appcast.sh) | Validate appcast XML files | `./scripts/verify-appcast.sh` |

### 🛠️ **Utility Scripts**

| Script | Purpose | Usage |
|--------|---------|-------|
| [`changelog-to-html.sh`](./changelog-to-html.sh) | Convert changelog to HTML for appcast | `./scripts/changelog-to-html.sh <version>` |

## 🔄 **Common Workflows**

### **Development Workflow**
```bash
# 1. Generate Xcode project (after Project.swift changes)
./scripts/generate-xcproj.sh

# 2. Format and lint code
./scripts/format.sh
./scripts/lint.sh

# 3. Build and test
./scripts/build.sh --configuration Debug
```

### **Release Workflow**
```bash
# 1. Check release readiness
./scripts/preflight-check.sh

# 2. Verify IS_PRERELEASE_BUILD system
./scripts/verify-prerelease-system.sh

# 3. Create release (choose appropriate type)
./scripts/release.sh stable           # Production release
./scripts/release.sh beta 1           # Beta release
./scripts/release.sh alpha 2          # Alpha release
./scripts/release.sh rc 1             # Release candidate
```

### **Manual Build & Distribution**
```bash
# 1. Build app
./scripts/build.sh --configuration Release

# 2. Sign and notarize
./scripts/sign-and-notarize.sh --sign-and-notarize

# 3. Create DMG
./scripts/create-dmg.sh build/Build/Products/Release/VibeMeter.app

# 4. Verify final package
./scripts/verify-app.sh build/VibeMeter-*.dmg
```

## 🔧 **IS_PRERELEASE_BUILD System**

The `IS_PRERELEASE_BUILD` system ensures beta downloads automatically default to the pre-release update channel:

- **Project.swift**: Contains `"IS_PRERELEASE_BUILD": "$(IS_PRERELEASE_BUILD)"` configuration
- **release.sh**: Sets `IS_PRERELEASE_BUILD=YES` for beta builds, `NO` for stable builds
- **UpdateChannel.swift**: Checks the flag to determine default update channel
- **verify-prerelease-system.sh**: Validates the entire system is properly configured

## 📦 **Dependencies**

### **Required Tools**
- **Xcode** - iOS/macOS development environment
- **Tuist** - Project generation (`brew install tuist`)
- **GitHub CLI** - Release management (`brew install gh`)

### **Code Quality Tools**
- **SwiftFormat** - Code formatting (`brew install swiftformat`)
- **SwiftLint** - Code linting (`brew install swiftlint`)
- **xcbeautify** - Pretty build output (`brew install xcbeautify`)

### **Sparkle Tools**
- **sign_update** - EdDSA signing for appcast updates
- **generate_appcast** - Appcast XML generation
- **generate_keys** - EdDSA key generation

Install Sparkle tools:
```bash
curl -L "https://github.com/sparkle-project/Sparkle/releases/download/2.7.0/Sparkle-2.7.0.tar.xz" -o Sparkle-2.7.0.tar.xz
tar -xf Sparkle-2.7.0.tar.xz
mkdir -p ~/.local/bin
cp bin/sign_update bin/generate_appcast bin/generate_keys ~/.local/bin/
export PATH="$HOME/.local/bin:$PATH"
```

## 🔐 **Environment Variables**

### **Required for Release**
```bash
# App Store Connect API (for notarization)
export APP_STORE_CONNECT_API_KEY_P8="-----BEGIN PRIVATE KEY-----..."
export APP_STORE_CONNECT_KEY_ID="ABCDEF1234"
export APP_STORE_CONNECT_ISSUER_ID="12345678-1234-1234-1234-123456789012"
```

### **Optional for Development**
```bash
# Pre-release build flag (automatically set by release.sh)
export IS_PRERELEASE_BUILD=YES  # or NO

# CI certificate for signing
export MACOS_SIGNING_CERTIFICATE_P12_BASE64="..."
```

## 🧹 **Maintenance Notes**

### **Script Documentation Standards**
All scripts follow this documentation format:
```bash
#!/bin/bash

# =============================================================================
# VibeMeter [Script Name]
# =============================================================================
#
# [Description of what the script does]
#
# USAGE:
#   ./scripts/script-name.sh [arguments]
#
# [Additional sections as needed: FEATURES, DEPENDENCIES, EXAMPLES, etc.]
#
# =============================================================================
```

### **Script Categories by Complexity**
- **Simple Scripts**: format.sh, lint.sh - Basic single-purpose utilities
- **Medium Scripts**: build.sh, generate-xcproj.sh - Multi-step processes
- **Complex Scripts**: release.sh, sign-and-notarize.sh - Full automation workflows

### **Testing Scripts**
Most scripts can be tested safely:
- Development scripts (format.sh, lint.sh, build.sh) are safe to run anytime
- Verification scripts are read-only and safe
- Release scripts should only be run when creating actual releases

### **Script Interdependencies**
```
release.sh (main release script)
├── preflight-check.sh (validation)
├── generate-xcproj.sh (project generation)
├── build.sh (compilation)
├── sign-and-notarize.sh (code signing)
├── create-dmg.sh (packaging)
├── generate-appcast.sh (update feed)
└── verify-app.sh (verification)
```

## 🔍 **Troubleshooting**

### **Common Issues**
1. **"command not found"** - Install missing dependencies listed above
2. **"No signing identity found"** - Set up Apple Developer certificates
3. **"Notarization failed"** - Check App Store Connect API credentials
4. **"Tuist generation failed"** - Ensure Project.swift syntax is valid

### **Debug Tips**
- Run `./scripts/preflight-check.sh` to validate setup
- Check individual script headers for specific requirements
- Use `--verbose` flags where available for detailed output
- Verify environment variables are properly set

## 📝 **Adding New Scripts**

When adding new scripts:
1. Follow the documentation header format above
2. Add appropriate error handling (`set -euo pipefail`)
3. Include usage examples and dependency information
4. Update this README.md with the new script
5. Test thoroughly before committing

---

**Last Updated**: December 2024  
**Maintainer**: VibeMeter Development Team