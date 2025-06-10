# Changelog

All notable changes to VibeMeter will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### 🚀 New Features
- **Claude AI Support** - Added comprehensive Claude usage tracking via local log file analysis
- **Dual-Mode Menu Bar Gauge** - Toggle between total spending and Claude 5-hour window quota display
- **5-Hour Window Tracking** - Real-time monitoring of Claude's rolling quota with visual progress bar
- **Token Counting** - Integrated Tiktoken library with o200k_base encoding for accurate token calculation
- **Daily Usage Breakdown** - New detailed view showing Claude token usage per day with cost calculation
- **No-Login Authentication** - Claude integration works without login, using secure folder access instead
- **Claude Subscription Tiers** - Added support for Free, Pro ($20), Max 5× ($100), and Max 20× ($200) tiers
- **Automatic Re-authentication** - Cursor sessions now automatically re-authenticate when cookies expire
- **Official Claude Icon** - Extracted and integrated the official Claude app icon for better recognition
- **Login Consent Flow** - New consent dialog explains credential handling before Cursor login

### 🎨 UI Improvements
- **ClaudeQuotaView** - Dedicated 5-hour window progress display in the popover
- **ClaudeDetailView** - Table view with daily token usage breakdown and costs
- **Gauge Representation Setting** - New toggle in settings to switch between spending/quota display
- **Claude Account Type Setting** - Select subscription tier for accurate quota calculations
- **Provider Configuration** - Login/Grant Access buttons now always visible with auto-enable on click
- **Settings Navigation** - Configure Providers button opens directly to Providers tab
- **Menu Bar Highlight** - Button highlight state now properly syncs with popover visibility
- **Improved Provider Dialog** - Larger dialog (600×700) with better layout and removed logout button

### 🔧 Technical Improvements
- **Refactored ClaudeLogManager** - Made testable with dependency injection and protocol-based design
- **Comprehensive Test Suite** - Added extensive tests for Claude provider functionality with mocks
- **Sandbox Security** - Implemented security-scoped bookmarks for safe folder access
- **Protocol-Based Architecture** - ClaudeLogManagerProtocol enables better testing and flexibility
- **Folder Access Validation** - Validates home directory selection and cleans up invalid bookmarks
- **Credential Storage** - Secure storage of Cursor credentials in macOS Keychain for auto-auth
- **CAPTCHA Detection** - Automatic detection and user notification when manual intervention needed
- **WebView Preloading** - Login page preloads in background while consent dialog is shown

### 🐛 Bug Fixes
- **Fixed Claude initialization race condition** - Claude now properly initializes before data refresh
- **Fixed provider error messages** - Shortened error messages to prevent UI truncation
- **Fixed directory picker** - Now pre-selects actual home directory instead of sandboxed path
- **Fixed Claude directory validation** - Properly handles sandboxed environments and accepts any directory containing .claude/projects

## [1.1.0] - 2025-06-10

### 🎨 UI Improvements
- **Enhanced popover design** - Switched to ultra-thin translucent material with blur effect for modern look
- **Adaptive border** - Added white border that automatically adapts to light/dark mode
- **Optimized spacing** - Reduced excessive left/right margins for better content density
- **Progressive gauge colors** - Added smooth color transitions from green (low usage) to red (high usage)
- **Improved money formatting** - Show "€0" instead of "€0,00" and remove unnecessary decimal places

### ⚡ Functionality Enhancements
- **Smart gauge calculation** - Display request usage percentage (182/500 = 36%) when no money spent, then switch to spending percentage when money is spent
- **Dynamic tooltip updates** - Fixed tooltip refresh discrepancy using NSTrackingArea hover detection
- **Simplified tooltip** - Removed keyboard shortcuts section and emoji indicators for cleaner display
- **Robust window display** - Implemented multi-strategy window display system to prevent UI freezing

### 🐛 Bug Fixes
- **Fixed UI deadlock** - Resolved freezing when showing the custom menu window
- **Fixed tooltip inconsistency** - Tooltip and popover now show consistent refresh timestamps
- **Fixed gauge accuracy** - Corrected percentage calculations across all display components
- **Fixed money display** - Consistent formatting without unnecessary decimals throughout the app

### 🔧 Technical Improvements
- **Window display strategy** - Added fallback mechanisms with `orderFrontRegardless()` and async display timing
- **Hover-based updates** - Tooltip refreshes dynamically on mouse hover for real-time accuracy
- **Swift Concurrency compliance** - Added proper `@MainActor` annotations throughout the codebase
- **Code consistency** - Unified gauge calculation logic across StatusBarController and StatusBarDisplayManager

## [1.1.0-beta.1] - 2025-06-10

### 🎨 UI Improvements
- **Enhanced popover design** - Switched to ultra-thin translucent material with blur effect for modern look
- **Adaptive border** - Added white border that automatically adapts to light/dark mode
- **Optimized spacing** - Reduced excessive left/right margins for better content density
- **Progressive gauge colors** - Added smooth color transitions from green (low usage) to red (high usage)
- **Improved money formatting** - Show "€0" instead of "€0,00" and remove unnecessary decimal places

### ⚡ Functionality Enhancements
- **Smart gauge calculation** - Display request usage percentage (182/500 = 36%) when no money spent, then switch to spending percentage when money is spent
- **Dynamic tooltip updates** - Fixed tooltip refresh discrepancy using NSTrackingArea hover detection
- **Simplified tooltip** - Removed keyboard shortcuts section and emoji indicators for cleaner display
- **Robust window display** - Implemented multi-strategy window display system to prevent UI freezing

### 🐛 Bug Fixes
- **Fixed UI deadlock** - Resolved freezing when showing the custom menu window
- **Fixed tooltip inconsistency** - Tooltip and popover now show consistent refresh timestamps
- **Fixed gauge accuracy** - Corrected percentage calculations across all display components
- **Fixed money display** - Consistent formatting without unnecessary decimals throughout the app

### 🔧 Technical Improvements
- **Window display strategy** - Added fallback mechanisms with `orderFrontRegardless()` and async display timing
- **Hover-based updates** - Tooltip refreshes dynamically on mouse hover for real-time accuracy
- **Swift Concurrency compliance** - Added proper `@MainActor` annotations throughout the codebase
- **Code consistency** - Unified gauge calculation logic across StatusBarController and StatusBarDisplayManager

## [1.0.0-beta.7] - 2025-06-05

### 🐛 Bug Fixes
- Fixed invoice fetching for Cursor users without teams - teamId is now optional in API requests
- Fixed incorrect coding key for startOfMonth, causing failure to decode usage (#16)
- Fixed CI test execution by removing invalid -test-iterations parameter
- Fixed API response handling for Individual users (empty response object)

### 🔧 Improvements
- Replaced mock data with actual API responses for better testing accuracy
- Improved error handling for team ID fallback (-1 for missing teams)
- Enhanced CI workflow permissions for external PR comments (#18)
- Enabled silent project regeneration without Xcode restart

### 📝 Documentation
- Added link to code signing guide in scripts README

## [1.0.0-beta.2] - 2025-06-05

### 🔧 Improvements
- **Release process refinement** - Streamlined build and distribution workflow
- **Appcast optimization** - Improved update feed generation and validation
- **Build number management** - Enhanced version tracking for reliable updates

### 🐛 Bug Fixes
- Fixed double beta suffix in release naming
- Corrected build number synchronization in appcast
- Resolved release script version handling

### 📝 Documentation
- Updated release process documentation
- Added comprehensive release checklist
- Improved troubleshooting guides

## [1.0.0] - 2025-06-05

### 🎉 First Stable Release

VibeMeter 1.0.0 is the first stable release, featuring full app sandboxing and a robust update mechanism.

### 🔒 Security
- **Full app sandboxing enabled** - Enhanced security with proper entitlements
- **Hardened runtime** - All binaries signed with hardened runtime
- **Notarized by Apple** - Gatekeeper approved for safe distribution

### ✨ Major Features
- **Multi-provider architecture** - Extensible design ready for additional AI services
- **Automatic updates via Sparkle** - Secure EdDSA-signed updates with update channels
- **Native Swift 6** - Built with latest Swift concurrency and strict checking
- **Menu bar monitoring** - Real-time spending tracking with visual gauge
- **Currency support** - Automatic conversion for 30+ currencies

### 🛠 Technical Improvements
- Fixed Sparkle XPC service entitlements for sandboxed environment
- Proper build number management for reliable updates
- Comprehensive error handling and logging
- Network resilience with retry mechanisms

### 📦 What's Included
- Cursor AI spending monitoring
- Customizable spending limits with warnings
- Login via secure WebKit session
- Settings persistence with UserDefaults
- Launch at Login support
- Update channel selection (Stable/Pre-release)

## [1.0-beta1] - 2025-06-04

### 🎯 Major Changes
- **Multi-provider architecture** - Ready for future AI service integrations beyond Cursor
- **Advanced settings section** - New dedicated tab for power user features
- **Editable spending limits** - Customize warning and upper limit thresholds directly in settings

### ✨ New Features
- **Update channels** - Choose between stable releases or beta/pre-release versions
- **Spending limits editor** - Set custom warning ($150.50) and upper limit ($800.75) thresholds
- **Reset to defaults** - Quick reset button for spending limits
- **Improved organization** - Settings reorganized with new Advanced tab

### 🐛 Bug Fixes
- **Fixed Cursor API compatibility** - Updated to handle both camelCase and snake_case field formats
- **Fixed cached data on account switch** - Spending data now properly clears when logging out
- **Fixed decimal spending limits** - Proper support for non-integer limit values
- **Fixed build warnings** - Resolved all compilation warnings and improved code quality

### 🔧 Technical Improvements
- **Swift 6 compliance** - Full compatibility with strict concurrency checking
- **Component-based architecture** - Improved separation of concerns with specialized managers
- **Enhanced error handling** - Better resilience for API format changes
- **Improved settings persistence** - More reliable storage of user preferences

### 📝 Known Issues
- Team accounts may show individual pricing instead of team-specific rates
- Usage limits are retrieved from Cursor API but spending limits are user-defined

## [0.9.1] - 2025-06-04

### 🐛 Bug Fixes
- **Fixed Sparkle EdDSA signature generation** - Corrected update-appcast.sh script to properly embed signatures
- **Improved release automation** - Fixed GitHub release creation workflow

### 🔧 Technical Improvements
- **Build scripts** - Enhanced error handling and reliability in release scripts
- **Sparkle integration** - Ensured proper EdDSA signature format in appcast.xml

## [0.9.0] - 2025-06-04

### 🎉 Initial Release

Vibe Meter is a beautiful, native macOS menu bar app that helps you track your monthly AI spending.

### ✨ Features
- **Real-time spending tracking** for Cursor AI
- **Multi-currency support** with 20+ currencies
- **Smart notifications** when approaching spending limits
- **Animated gauge icon** showing spending progress
- **Secure authentication** via official web login
- **Auto-updates** with EdDSA signature verification

### 🏗️ Built With
- Swift 6 with strict concurrency
- Modern SwiftUI and AppKit
- Multi-provider architecture (ready for future AI services)
- Notarized by Apple for security

---

## 🚀 Getting Started

1. **Download** VibeMeter from [GitHub Releases](https://github.com/steipete/VibeMeter/releases)
2. **Install** by dragging to your Applications folder
3. **Launch** and follow the setup guide
4. **Configure** your spending preferences in Settings

## 📞 Support

- **Issues**: [GitHub Issues](https://github.com/steipete/VibeMeter/issues)
- **Twitter**: [@steipete](https://twitter.com/steipete)
- **Blog**: [Development Story](https://steipete.com/posts/vibemeter/)

---

**Thank you for using VibeMeter! 🎉**

We're excited to help you track your AI spending efficiently and beautifully. If you enjoy the app, please consider starring the repository and sharing it with others who might find it useful.

**Made with ❤️ in Vienna, Austria**