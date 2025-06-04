# Changelog

All notable changes to VibeMeter will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.9.0] - 2025-06-04

### 🎨 User Interface
- **Redesigned cost table layout** - Provider icons and spending amounts are now centered with improved visual hierarchy
- **Enhanced provider display** - Moved provider breakdown to the top with full-width usage progress bars
- **Professional styling** - Cleaner, less chaotic layout with better spacing and alignment

### 🐛 Bug Fixes
- **Fixed authentication loop** - Resolved issue where login would fail despite correct credentials
- **Fixed progressive disclosure animations** - Smooth transitions when expanding/collapsing cost details
- **Improved error messages** - More user-friendly authentication error descriptions
- **Fixed Sparkle auto-update** - Corrected EdDSA public key format to match Sparkle's requirements

### 🏗️ Architecture
- **Removed circuit breaker pattern** - Simplified error handling by removing unnecessary retry complexity
- **Enhanced authentication state management** - Replaced boolean flags with proper state enum
- **Improved loading states** - Better visual feedback during login and data fetching

### 🔧 Technical Improvements
- **Swift 6 compliance** - Fixed all concurrency warnings and actor isolation issues
- **Code organization** - Created dedicated component files for provider icons and usage badges
- **Build system** - Resolved duplicate file issues and improved project structure
- **Sparkle compatibility** - Now uses the same key format as the working CodeLooper implementation

### 🔐 Security
- **Notarized by Apple** - This release is properly signed and notarized for macOS security

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