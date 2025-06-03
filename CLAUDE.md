# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## General Rules

- Keep NSApplication+openSettings. This is the only reliable way to show settings.
- Use modern SwiftUI material API, do not wrap NSVisualEffectsView.
- We support Swift 6 and macOS 15 only.
- Don't care about backwards compatibility, always properly refactor.

## Project Overview

VibeMeter is a macOS menu bar application that monitors monthly spending on the Cursor AI service. It's a native Swift 6 application using AppKit and SwiftUI, built with Tuist for project generation.

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

# Code sign and notarize (requires Apple Developer credentials)
./scripts/sign-and-notarize.sh --sign-and-notarize

# Or just code sign for development
./scripts/sign-and-notarize.sh --sign-only

# Create DMG
./scripts/create-dmg.sh

# Individual scripts (if needed)
./scripts/codesign-app.sh build/Build/Products/Release/VibeMeter.app
./scripts/notarize-app.sh build/Build/Products/Release/VibeMeter.app
```

### Code Signing & Notarization Setup

For distribution, you need Apple Developer credentials. See `docs/SIGNING-AND-NOTARIZATION.md` for detailed setup instructions.

Required environment variables for notarization:
- `APP_STORE_CONNECT_API_KEY_P8` - App Store Connect API key content
- `APP_STORE_CONNECT_KEY_ID` - API Key ID  
- `APP_STORE_CONNECT_ISSUER_ID` - API Key Issuer ID

## Architecture

### Core Components

1. **DataCoordinator** (`VibeMeter/DataCoordinator.swift`)
   - Central data management and state coordination
   - Manages all service dependencies and data flow
   - Publishes state changes for UI updates via Combine
   - Handles data fetching, currency conversion, and notification triggers

2. **MenuBarController** (`VibeMeter/MenuBarController.swift`)
   - Manages the NSStatusItem and dropdown menu
   - Observes DataCoordinator state changes
   - Updates menu bar display text and menu items

3. **Service Layer**
   - **CursorAPIClient**: Handles all Cursor API interactions (teams, user info, invoices)
   - **LoginManager**: Manages WebKit-based authentication and cookie storage
   - **ExchangeRateManager**: Fetches and caches currency exchange rates
   - **SettingsManager**: Persists user preferences via UserDefaults
   - **NotificationManager**: Handles macOS user notifications
   - **StartupManager**: Manages Launch at Login functionality

### Key Design Patterns

- **Protocol-Oriented Design**: Most services have protocol definitions for testability
- **Dependency Injection**: Services are injected into DataCoordinator
- **Combine Framework**: Used for reactive state management
- **Swift Concurrency**: async/await for network operations
- **MVVM-like Structure**: DataCoordinator acts as the view model layer

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

- **System Frameworks**:
  - AppKit, SwiftUI, WebKit, Combine, UserNotifications, ServiceManagement

## Development Tips

- Always run `./scripts/generate-xcproj.sh` after modifying `Project.swift` or `Tuist.swift`
- The generate script includes patches for Swift 6 Sendable compliance
- Use `LoggingService` for consistent logging to Console.app
- Currency symbols and exchange rates gracefully fall back to USD on failure
- Test files follow naming convention: `<Component>Tests.swift`