# Vibe Meter

A beautiful, native macOS menu bar application that helps you track your monthly AI spending with real-time monitoring and smart notifications.


## ✨ Features

- **📊 Real-time Spending Tracking** - Monitor your AI service costs directly from your menu bar
- **🔄 Multi-Provider Support** - Currently supports Cursor AI with extensible architecture for future services
- **💰 Multi-Currency Support** - View spending in USD, EUR, GBP, JPY, and 20+ other currencies
- **🔔 Smart Notifications** - Customizable spending limit alerts to keep you on budget
- **🎨 Animated Gauge Display** - Beautiful visual indicator showing spending progress
- **🔐 Secure Authentication** - Safe login via provider's official web authentication
- **⚡ Lightweight & Native** - Built with Swift 6, optimized for performance and battery life
- **🔄 Auto-Updates** - Secure automatic updates with EdDSA signature verification
- **🌓 Dark Mode Support** - Seamlessly adapts to your system appearance
- **🖱️ Right-Click Menu** - Quick access to settings and actions via context menu
- **📊 Enhanced UI** - Professional cost table with centered icons and full-width progress bars

## 🚀 Quick Start

1. **Download Vibe Meter** from the [latest release](https://github.com/steipete/VibeMeter/releases)
2. **Install** by dragging Vibe Meter.app to your Applications folder
3. **Launch** and click the menu bar icon to get started
4. **Login** to your Cursor AI account when prompted
5. **Configure** spending limits and currency preferences in Settings

## 📋 Requirements

- **macOS 15.0** or later (Sequoia)
- **Cursor AI account** (free or paid)
- **Internet connection** for real-time data sync

## 🎯 How It Works

Vibe Meter connects securely to your Cursor AI account and monitors your monthly usage:

- **Automatic Sync** - Updates spending data every 5 minutes
- **Visual Indicators** - Gauge fills up as you approach your spending limits
- **Progress Notifications** - Alerts at 80% and 100% of your warning threshold
- **Currency Conversion** - Real-time exchange rates for accurate international tracking

## ⚙️ Configuration

### Spending Limits
- **Warning Limit** - Get notified when you reach 80% (default: $20)
- **Upper Limit** - Maximum threshold for visual indicators (default: $30)

### Display Options
- **Show Cost in Menu Bar** - Toggle cost display next to the icon
- **Currency Selection** - Choose from 20+ supported currencies
- **Notification Preferences** - Customize alert frequency and triggers

## 🛠️ Development

Want to contribute? Vibe Meter is built with modern Swift technologies:

### Tech Stack
- **Swift 6** with strict concurrency
- **SwiftUI** for settings and UI components
- **AppKit** for menu bar integration
- **Combine** for reactive data flow
- **Tuist** for project generation

### Getting Started

1. **Clone the repository:**
   ```bash
   git clone https://github.com/steipete/VibeMeter.git
   cd VibeMeter
   ```

2. **Install Tuist:**
   ```bash
   curl -Ls https://install.tuist.io | bash
   ```

3. **Generate and open project:**
   ```bash
   ./scripts/generate-xcproj.sh
   ```

4. **Build and run:**
   - Open `VibeMeter.xcworkspace` in Xcode
   - Select the VibeMeter scheme and press ⌘R

### Key Commands

```bash
# Code formatting
./scripts/format.sh

# Linting
./scripts/lint.sh

# Run tests
xcodebuild -workspace VibeMeter.xcworkspace -scheme VibeMeter -configuration Debug test

# Build release
./scripts/build.sh
```

## 🏗️ Architecture

Vibe Meter follows clean architecture principles:

- **Multi-Provider System** - Extensible design for supporting multiple AI services
- **Reactive State Management** - Combine-based data flow with `@Observable` models  
- **Service Layer** - Modular services for API clients, authentication, and notifications
- **Protocol-Oriented Design** - Extensive use of protocols for testability and flexibility

## 🔐 Privacy & Security

- **Local Authentication** - Login credentials never stored, uses secure web authentication
- **Encrypted Storage** - Sensitive data protected using macOS Keychain
- **No Tracking** - Vibe Meter doesn't collect any analytics or usage data
- **Secure Updates** - All updates cryptographically signed and verified

## 🤝 Contributing

We welcome contributions! When contributing to Vibe Meter:

- Follow Swift 6 best practices with strict concurrency
- Use the provided formatting script: `./scripts/format.sh`
- Ensure all tests pass before submitting
- Update documentation for significant changes

## 📖 Documentation

- [Architecture Overview](docs/MODERN-ARCHITECTURE.md)
- [Release Process](docs/RELEASE.md)
- [Code Signing Setup](docs/SIGNING-AND-NOTARIZATION.md)
- [CI/CD Pipeline](docs/CI-SETUP.md)

## 🐛 Support

Found a bug or have a feature request?

1. Check [existing issues](https://github.com/steipete/VibeMeter/issues)
2. Create a [new issue](https://github.com/steipete/VibeMeter/issues/new) with details
3. For urgent issues, mention [@steipete](https://twitter.com/steipete) on Twitter

## 🎉 Roadmap

**Current Status (v0.9.x):** Feature-complete beta with Cursor AI support, preparing for v1.0 release

**Version 1.0:**
- Production-ready release with full Cursor AI integration
- Comprehensive testing and stability improvements
- Enhanced error handling and user feedback

**Version 1.x:**
- Additional AI service providers (OpenAI, Anthropic, etc.)
- Enhanced analytics and spending insights
- Team usage tracking for organizations
- Export functionality for financial records

## 📝 License

MIT License - see [LICENSE](LICENSE) file for details.

---

## 👨‍💻 About

Created by [Peter Steinberger](https://steipete.com) ([@steipete](https://twitter.com/steipete))

Read about the development process: [Building a native macOS app with AI](https://steipete.com/posts/vibemeter/)

**Made with ❤️ in Vienna, Austria**