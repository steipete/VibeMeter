# VibeMeter Modern Architecture (Swift 6)

This document describes the modernized architecture of VibeMeter, updated to use Swift 6 features and modern design patterns.

## Overview

VibeMeter has been restructured to follow modern Swift best practices with:
- **Swift 6 strict concurrency** with actors and async/await
- **@Observable macro** for reactive state management
- **Modern SwiftUI** patterns and APIs
- **Protocol-oriented design** with clear separation of concerns
- **Structured directory layout** for better organization

## Directory Structure

```
VibeMeter/
├── App/                        # Application lifecycle
│   └── VibeMeterApp.swift     # @main entry point and AppDelegate
├── Core/                       # Core business logic
│   ├── Models/                # Data models
│   ├── Networking/            # API clients
│   │   └── CursorAPIClient.swift
│   ├── Protocols/             # Protocol definitions
│   │   ├── CursorAPIClientProtocol.swift
│   │   ├── ExchangeRateManagerProtocol.swift
│   │   └── SettingsManagerProtocol.swift
│   ├── Services/              # Business services
│   │   ├── DataCoordinator.swift
│   │   ├── ExchangeRateManager.swift
│   │   ├── NotificationManager.swift
│   │   ├── SettingsManager.swift
│   │   └── SparkleUpdaterManager.swift
│   └── Utilities/             # Helper classes and extensions
├── Presentation/              # UI layer
│   ├── Views/                # SwiftUI views
│   │   └── SettingsView.swift
│   ├── ViewModels/           # View models (if needed)
│   └── Components/           # Reusable UI components
└── Resources/                # Assets, configs, etc.
```

## Key Architectural Changes

### 1. Actor-based API Client

The `CursorAPIClient` is now an actor, providing thread-safe API access:

```swift
public actor CursorAPIClient: CursorAPIClientProtocol {
    // Thread-safe API methods
    public func fetchTeamInfo(authToken: String) async throws -> TeamInfo
    public func fetchUserInfo(authToken: String) async throws -> UserInfo
    public func fetchMonthlyInvoice(authToken: String, month: Int, year: Int) async throws -> MonthlyInvoice
}
```

### 2. @Observable Settings Manager

Using Swift's new `@Observable` macro for automatic change tracking:

```swift
@MainActor
@Observable
public final class SettingsManager: SettingsManagerProtocol {
    // Properties automatically trigger UI updates
    public var selectedCurrencyCode: String
    public var warningLimitUSD: Double
    public var upperLimitUSD: Double
}
```

### 3. Modern DataCoordinator

Centralized state management with clear async patterns:

```swift
@MainActor
public final class DataCoordinator: DataCoordinatorProtocol, ObservableObject {
    // Published state for UI binding
    @Published public private(set) var isLoggedIn = false
    @Published public private(set) var currentSpendingUSD: Double?
    
    // Async data operations
    public func forceRefreshData(showSyncedMessage: Bool) async
}
```

### 4. SwiftUI Settings View

Modern SwiftUI with native macOS patterns:

```swift
struct SettingsView: View {
    @Bindable var settingsManager: SettingsManager
    @ObservedObject var dataCoordinator: DataCoordinator
    
    var body: some View {
        HSplitView {
            SettingsSidebar(selectedTab: $selectedTab)
            // Tab-based content
        }
    }
}
```

## Swift 6 Features Used

### Strict Concurrency
- All types marked with appropriate isolation (`@MainActor`, `actor`, `Sendable`)
- Async/await throughout for network operations
- Data race safety enforced at compile time

### Modern Language Features
- `@Observable` macro for reactive state
- Structured concurrency with `Task` groups
- Native `Logger` API for consistent logging
- Type-safe error handling with typed throws

### SwiftUI Enhancements
- `@Bindable` for two-way bindings with @Observable
- Native materials (`.regularMaterial`)
- Modern form styles (`.formStyle(.grouped)`)
- `HSplitView` for sidebar navigation

## Migration Guide

To migrate existing code to the modern structure:

1. **Run the migration script**:
   ```bash
   ./scripts/migrate-to-modern-structure.sh
   ```

2. **Update imports** in moved files to reflect new paths

3. **Replace the Project.swift**:
   ```bash
   cp Project-Modern.swift Project.swift
   ./scripts/generate-xcproj.sh
   ```

4. **Update references** to use new protocol-based types

## Testing Approach

The modernized architecture improves testability:

- **Protocol-based dependencies** enable easy mocking
- **Actor isolation** ensures thread-safe testing
- **Async testing** with modern Swift concurrency test helpers

Example test pattern:
```swift
@MainActor
class DataCoordinatorTests: XCTestCase {
    func testDataRefresh() async throws {
        let mockAPI = MockCursorAPIClient()
        let coordinator = DataCoordinator(apiClient: mockAPI)
        
        await coordinator.forceRefreshData(showSyncedMessage: false)
        
        XCTAssertEqual(coordinator.currentSpendingUSD, 100.0)
    }
}
```

## Performance Improvements

- **Reduced memory footprint** with value types and copy-on-write
- **Better concurrency** with actors preventing data races
- **Efficient UI updates** with @Observable's fine-grained tracking
- **Cached network responses** in ExchangeRateManager

## Future Enhancements

- Migration to Swift Data for persistence
- Widget support with WidgetKit
- CloudKit sync for settings
- Swift Charts for spending visualization