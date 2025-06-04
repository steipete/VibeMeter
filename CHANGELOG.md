# Changelog

All notable changes to VibeMeter will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.9.1] - 2025-06-04

### 🔄 Updates
- **Test release for Sparkle auto-update** - Verifying that automatic updates work correctly
- **Fixed notarization script** - Resolved API key format issues for proper notarization

### 🔧 Technical Improvements  
- **Improved build scripts** - Fixed shell script errors in notarization process
- **Updated changelog rendering** - Ensured proper HTML formatting for Sparkle update window

## [0.9.0] - 2025-06-04

### 🎨 User Interface
- **Redesigned cost table layout** - Provider icons and spending amounts are now centered with improved visual hierarchy
- **Enhanced provider display** - Moved provider breakdown to the top with full-width usage progress bars
- **Professional styling** - Cleaner, less chaotic layout with better spacing and alignment

### 🐛 Bug Fixes
- **Fixed authentication loop** - Resolved issue where login would fail despite correct credentials
- **Fixed progressive disclosure animations** - Smooth transitions when expanding/collapsing cost details
- **Improved error messages** - More user-friendly authentication error descriptions

### 🏗️ Architecture
- **Removed circuit breaker pattern** - Simplified error handling by removing unnecessary retry complexity
- **Enhanced authentication state management** - Replaced boolean flags with proper state enum
- **Improved loading states** - Better visual feedback during login and data fetching

### 🔧 Technical Improvements
- **Swift 6 compliance** - Fixed all concurrency warnings and actor isolation issues
- **Code organization** - Created dedicated component files for provider icons and usage badges
- **Build system** - Resolved duplicate file issues and improved project structure

## [1.0.0] - 2025-06-03

🎉 **Initial Release** - Welcome to VibeMeter, your AI spending companion!

### ✨ Core Features

- **📊 Real-time Spending Tracking** - Monitor your Cursor AI costs directly from the menu bar
- **🎨 Animated Gauge Display** - Beautiful visual indicator showing spending progress with smooth animations
- **💰 Multi-Currency Support** - View spending in USD, EUR, GBP, JPY, and 20+ other currencies with live exchange rates
- **🔔 Smart Notifications** - Customizable spending limit alerts to keep you on budget
- **🔐 Secure Authentication** - Safe login via Cursor's official web authentication system
- **⚙️ Comprehensive Settings** - Full preferences window with spending limits, currency selection, and display options

### 🎯 User Experience

- **🚀 Instant Onboarding** - Popover automatically appears on first launch for easy setup
- **⚡ Lightweight Performance** - Native Swift 6 app optimized for minimal resource usage
- **🌓 Dark Mode Support** - Seamlessly adapts to your system appearance preferences
- **🔄 Auto-Updates** - Secure automatic updates with EdDSA cryptographic verification
- **📱 Native macOS Integration** - Perfect menu bar citizen with proper sizing and behavior

### 🏗️ Technical Excellence

- **🏛️ Multi-Provider Architecture** - Extensible design ready for future AI service integrations
- **🔄 Reactive State Management** - Combine-based data flow with `@Observable` models
- **🧪 Comprehensive Testing** - Full test suite covering core functionality and edge cases
- **📦 Modern Build System** - Tuist-based project generation with automated CI/CD pipeline
- **🔒 Security First** - Keychain storage, sandboxed environment, and code signing

### 🔧 Configuration Options

- **Spending Limits** - Warning threshold (default: $20) and upper limit (default: $30)
- **Display Preferences** - Toggle cost display in menu bar, currency selection
- **Notification Settings** - Customize alert frequency and spending thresholds
- **Auto-Launch** - Optional startup integration for continuous monitoring

### 🛡️ Privacy & Security

- **No Data Collection** - VibeMeter doesn't track or collect any user analytics
- **Local Storage** - All data stored securely on your device using macOS Keychain
- **Secure Communication** - Direct API communication with Cursor's authenticated endpoints
- **Code Signing** - Fully signed and notarized for macOS security compliance

---

## 🚀 Getting Started

1. **Download** VibeMeter from [GitHub Releases](https://github.com/steipete/VibeMeter/releases)
2. **Install** by dragging to your Applications folder
3. **Launch** and follow the setup guide
4. **Configure** your spending preferences in Settings

## 🔮 What's Next

Future releases will include:
- **Additional AI Providers** - OpenAI, Anthropic, and more
- **Enhanced Analytics** - Detailed spending insights and trends
- **Team Features** - Organization usage tracking and management
- **Export Capabilities** - Financial reporting and data export options

## 📞 Support

- **Issues**: [GitHub Issues](https://github.com/steipete/VibeMeter/issues)
- **Twitter**: [@steipete](https://twitter.com/steipete)
- **Blog**: [Development Story](https://steipete.com/posts/vibemeter/)

---

**Thank you for using VibeMeter! 🎉**

We're excited to help you track your AI spending efficiently and beautifully. If you enjoy the app, please consider starring the repository and sharing it with others who might find it useful.

**Made with ❤️ in Vienna, Austria**