# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

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
./scripts/build.sh

# Code sign the app
./scripts/codesign-app.sh

# Create DMG
./scripts/create-dmg.sh

# Notarize the app
./scripts/notarize-app.sh

# Test notarization
./scripts/test-notarization.sh
```

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