# Changelog

All notable changes to VibeMeter will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.9.0] - 2025-06-02

### Added
- 🚀 **Sparkle Auto-Update Integration** - Automatic updates with secure EdDSA signing
- 🔍 **"Check for Updates" Menu Item** - Manual update checking from menu bar
- 🔧 **Improved Code Signing** - Automatic signing with development team to prevent keychain popups
- 📡 **Appcast Feed** - XML feed for update distribution via GitHub releases
- 🛠️ **Release Automation Scripts** - Complete build, sign, and release pipeline
- ⚙️ **Menu Bar Icon Fixes** - Proper visibility and sizing when logged out
- 🔗 **Login Menu Option** - Easy access to login when not authenticated

### Changed
- 📝 **Menu Bar Behavior** - Shows icon only when logged out, icon + text when logged in
- 🎨 **Menu Bar Icon Size** - Optimized to 18x18 pixels for better appearance
- 🔐 **Signing Configuration** - Uses team ID Y5PE65HELJ to avoid authentication dialogs

### Fixed
- ❌ **Menu Bar Icon Visibility** - Icon now always visible regardless of login state
- 🎯 **Menu Bar Spacing** - Eliminated excessive spacing around menu bar icon
- 🔧 **Build System** - Cleaned up conflicting menu building approaches
- ⌨️ **Keyboard Shortcuts** - Fixed conflicts between Quit (⌘⇧Q) and Logout (⌘Q)

### Security
- 🔒 **EdDSA Signing Keys** - Generated secure key pair for update verification
- 🛡️ **Private Key Protection** - Keys stored in gitignored private/ directory
- ✅ **Code Signing Identity** - Proper Apple Developer signing configuration

### Technical
- 📦 **Sparkle 2.7.0** - Added as Swift Package dependency
- 🏗️ **Swift 6 Compliance** - Maintained strict concurrency and sendable compliance
- 🧪 **Test Fixes** - Updated test expectations for new menu bar behavior
- 📋 **Release Scripts** - Local testing and GitHub release automation

## [1.0.0] - TBD

### Planned
- 🎉 **Public Release** - First stable release
- 📊 **Enhanced Analytics** - More detailed spending insights
- 🎨 **UI Polish** - Final design refinements
- 📱 **Additional Platforms** - Potential iOS companion app

---

## Version History

- **0.9.0** - Pre-release with auto-updates and improved menu bar
- **1.0.0** - Initial public release (planned)

## Development Notes

### Auto-Update Flow
1. App checks `https://raw.githubusercontent.com/steipete/VibeMeter/main/appcast.xml`
2. If newer version found, downloads from GitHub releases
3. Verifies signature using embedded public key
4. Prompts user for update installation

### Release Process
1. `./scripts/release-local.sh` - Test local builds
2. `./scripts/create-github-release.sh` - Create GitHub release with notarization
3. Commit updated `appcast.xml` to repository
4. Updates become available to all users

### Security
- All releases signed with Apple Developer ID
- Updates verified with EdDSA cryptographic signatures
- Private keys never committed to repository