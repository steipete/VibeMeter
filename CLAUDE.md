# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## General Rules

- Keep NSApplication+openSettings. This is the only reliable way to show settings.
- Use modern SwiftUI material API, do not wrap NSVisualEffectsView.
- We support Swift 6 and macOS 15 only.
- Don't care about backwards compatibility, always properly refactor.
- App is fully sandboxed as of v1.0.0 - maintain sandbox compatibility.

## Project Overview

VibeMeter is a macOS menu bar application that monitors monthly spending on AI services, starting with Cursor AI. It's a native Swift 6 application using AppKit and SwiftUI, built with Tuist for project generation. Version 1.0.0 features a multi-provider architecture ready for future AI service integrations.

## Build Commands

### Project Generation
```bash
# Generate Xcode project (required before building)
./scripts/generate-xcproj.sh
```

### Build & Run
```bash
# Build the app
xcodebuild -workspace VibeMeter.xcworkspace -scheme VibeMeter -configuration Debug build

# Run tests
xcodebuild -workspace VibeMeter.xcworkspace -scheme VibeMeter -configuration Debug test
```

### Code Quality
```bash
# Format code
./scripts/format.sh

# Lint code
./scripts/lint.sh

# Fix trailing newlines
./scripts/fix-trailing-newlines.sh
```

### Distribution
```bash
# Build release version
./scripts/build.sh --configuration Release

# Create releases (automated process)
./scripts/preflight-check.sh                     # Check if ready to release
./scripts/release-auto.sh stable                 # Create stable release
./scripts/release-auto.sh beta 1                 # Create pre-release (beta.1)
./scripts/release-auto.sh alpha 2                # Create pre-release (alpha.2)
./scripts/release-auto.sh rc 1                   # Create release candidate

# Code sign and notarize (requires Apple Developer credentials)
./scripts/sign-and-notarize.sh --sign-and-notarize

# Or just code sign for development
./scripts/sign-and-notarize.sh --sign-only

# Create DMG
./scripts/create-dmg.sh

# Generate EdDSA signature for Sparkle updates
export PATH="$HOME/.local/bin:$PATH"
sign_update build/VibeMeter-X.X.X.dmg

# Individual scripts (if needed)
./scripts/codesign-app.sh build/Build/Products/Release/VibeMeter.app
./scripts/notarize-app.sh build/Build/Products/Release/VibeMeter.app
```

### Sparkle EdDSA Signing

VibeMeter uses Sparkle for automatic updates with cryptographic verification:

```bash
# Install Sparkle tools (first time setup)
curl -L "https://github.com/sparkle-project/Sparkle/releases/download/2.7.0/Sparkle-2.7.0.tar.xz" -o Sparkle-2.7.0.tar.xz
tar -xf Sparkle-2.7.0.tar.xz
mkdir -p ~/.local/bin
cp bin/sign_update ~/.local/bin/
cp bin/generate_appcast ~/.local/bin/
cp bin/generate_keys ~/.local/bin/
export PATH="$HOME/.local/bin:$PATH"

# Generate EdDSA keys (first time only)
generate_keys

# Generate signature for releases
sign_update VibeMeter-1.0.dmg
# Output: sparkle:edSignature="..." length="..."

# Generate appcast XML
generate_appcast /path/to/releases/
```

**Key Details:**
- Private key stored in macOS Keychain (account: "ed25519")
- Public key: `oIgha2beQWnyCXgOIlB8+oaUzFNtWgkqq6jKXNNDhv4=` (in Info.plist)
- EdDSA signatures provide cryptographic verification of updates
- XPC services use bundle ID suffixes: `-spks` (Downloader) and `-spki` (Installer)

### Code Signing & Notarization Setup

For distribution, you need Apple Developer credentials. See `docs/SIGNING-AND-NOTARIZATION.md` for detailed setup instructions.

Required environment variables for notarization:
- `APP_STORE_CONNECT_API_KEY_P8` - App Store Connect API key content
- `APP_STORE_CONNECT_KEY_ID` - API Key ID  
- `APP_STORE_CONNECT_ISSUER_ID` - API Key Issuer ID

### Update Channels

VibeMeter supports two update channels via Sparkle:

- **Stable Only**: Users receive only production-ready releases (`appcast.xml`)
- **Include Pre-releases**: Users receive both stable and pre-release versions (`appcast-prerelease.xml`)

Update channel selection is available in General Settings. The SparkleUpdaterManager dynamically provides the appropriate feed URL based on user preference.

## Architecture

### Core Components

1. **MultiProviderDataOrchestrator** (`VibeMeter/Core/Services/MultiProviderDataOrchestrator.swift`)
   - Central coordinator using orchestrator pattern
   - Delegates to specialized managers for separation of concerns
   - @MainActor @Observable class for reactive state management
   - Coordinates data fetching, currency conversion, and notification triggers

2. **StatusBarController** (`VibeMeter/Presentation/Components/StatusBarController.swift`)
   - Component-based architecture with specialized managers:
     - StatusBarDisplayManager: Menu bar text and icon display
     - StatusBarMenuManager: Popover window management
     - StatusBarAnimationController: Gauge icon animations
     - StatusBarObserver: Data change monitoring
   - Handles all menu bar UI interactions

3. **Service Layer**
   - **Providers**:
     - CursorProvider: Actor-based Cursor AI API implementation
     - ProviderFactory: Creates provider instances
     - ProviderRegistry: Manages enabled/disabled providers
   - **State Management**:
     - SessionStateManager: Login/logout flows
     - NetworkStateManager: Network connectivity monitoring
     - CurrencyOrchestrator: Currency conversion coordination
   - **Background Processing**:
     - BackgroundDataProcessor: Actor for concurrent API operations
   - **Other Services**:
     - MultiProviderLoginManager: WebKit-based authentication
     - ExchangeRateManager: Actor-based currency rate management
     - SettingsManager: @Observable preferences with specialized sub-managers
     - NotificationManager: macOS user notifications
     - StartupManager: Launch at Login functionality

4. **Data Models** (using @Observable)
   - **MultiProviderUserSessionData**: User authentication state across providers
   - **MultiProviderSpendingData**: Spending data aggregation and calculations
   - **CurrencyData**: Currency conversion and exchange rate management
   - **ProviderConnectionStatus**: Real-time connection state tracking

### Key Design Patterns

- **Orchestrator Pattern**: MultiProviderDataOrchestrator coordinates between managers
- **Component-Based Architecture**: StatusBarController delegates to specialized components
- **Actor Pattern**: Thread-safe background operations (providers, data processor)
- **Protocol-Oriented Design**: Most services have protocol definitions for testability
- **Dependency Injection**: Services are injected via initializers
- **Observable State**: Swift's @Observable macro for reactive updates (not Combine)
- **Swift Concurrency**: async/await for network operations, actors for thread safety
- **Delegation Pattern**: Loose coupling between components

### Testing Strategy

- Unit tests use mock implementations of service protocols
- Test utilities in `VibeMeterTests/TestUtilities/` provide mocks for all major services
- Tests cover initialization, data fetching, currency conversion, and notification logic

### Important Implementation Details

1. **Authentication**: Uses WKWebView to capture Cursor session cookies from `authenticator.cursor.sh`
2. **Currency Conversion**: All limits stored in USD, converted for display using Frankfurter.app API
3. **Menu Bar App**: LSUIElement = true, no main window
4. **Settings Window**: SwiftUI-based, managed by SettingsWindowController
5. **Swift 6 Compliance**: Strict concurrency checking enabled, all UI updates on MainActor

## Dependencies

- **Swift Packages**:
  - swift-log (1.6.1+): Logging infrastructure
  - KeychainAccess (4.0.0+): Secure credential storage
  - Sparkle (2.0.0+): Automatic updates with cryptographic verification

- **System Frameworks**:
  - AppKit, SwiftUI, WebKit, Combine, UserNotifications, ServiceManagement

## Development Tips

- Always run `./scripts/generate-xcproj.sh` after modifying `Project.swift` or `Tuist.swift`
- The generate script includes patches for Swift 6 Sendable compliance
- Use `LoggingService` for consistent logging to Console.app
- Currency symbols and exchange rates gracefully fall back to USD on failure
- Test files follow naming convention: `<Component>Tests.swift`