# VibeMeter Modern Architecture (Swift 6)

This document describes the current architecture of VibeMeter, built with Swift 6 and modern design patterns.

## Overview

VibeMeter follows modern Swift best practices with:
- **Swift 6 strict concurrency** with actors and async/await
- **@Observable macro** for reactive state management (not Combine)
- **Modern SwiftUI** patterns and APIs
- **Multi-provider architecture** ready for multiple AI services
- **Component-based UI architecture** for modularity
- **Orchestrator pattern** for coordinating complex operations
- **Protocol-oriented design** with clear separation of concerns
- **Structured directory layout** for better organization

## Directory Structure

```
VibeMeter/
├── App/                        # Application lifecycle
│   └── VibeMeterApp.swift     # @main entry point
├── Core/                       # Core business logic
│   ├── Models/                # Data models (@Observable)
│   │   ├── CurrencyData.swift
│   │   ├── MultiProviderUserSession.swift
│   │   ├── ProviderConnectionStatus.swift
│   │   └── ProviderSpendingData.swift
│   ├── Protocols/             # Protocol definitions
│   │   ├── KeychainProtocol.swift
│   │   └── URLSessionProtocol.swift
│   ├── Providers/             # Provider implementations
│   │   ├── Cursor/            # Cursor-specific implementation
│   │   ├── CursorProvider.swift
│   │   ├── ProviderProtocol.swift
│   │   └── ServiceProvider.swift
│   ├── Services/              # Business services
│   │   ├── MultiProviderDataOrchestrator.swift
│   │   ├── SessionStateManager.swift
│   │   ├── NetworkStateManager.swift
│   │   ├── CurrencyOrchestrator.swift
│   │   ├── BackgroundDataProcessor.swift
│   │   ├── ExchangeRateManager.swift
│   │   ├── NotificationManager.swift
│   │   ├── SettingsManager.swift
│   │   └── Settings/          # Specialized settings managers
│   └── Utilities/             # Helper classes and extensions
├── Presentation/              # UI layer
│   ├── Components/            # Reusable UI components
│   │   ├── StatusBarController.swift
│   │   ├── StatusBarDisplayManager.swift
│   │   ├── StatusBarMenuManager.swift
│   │   ├── StatusBarAnimationController.swift
│   │   └── StatusBarObserver.swift
│   ├── Views/                 # SwiftUI views
│   │   ├── LoggedInContentView.swift
│   │   ├── LoggedOutContentView.swift
│   │   └── MultiProviderSettingsView.swift
│   └── PreviewHelpers/        # SwiftUI preview support
└── Resources/                 # Assets, configs, etc.
```

## Key Architectural Components

### 1. Multi-Provider Data Orchestrator

The `MultiProviderDataOrchestrator` is the central coordinator, delegating to specialized managers:

```swift
@MainActor
@Observable
public final class MultiProviderDataOrchestrator {
    // Delegated responsibilities
    private let sessionStateManager: SessionStateManager
    private let networkStateManager: NetworkStateManager
    private let currencyOrchestrator: CurrencyOrchestrator
    private let backgroundDataProcessor: BackgroundDataProcessor
    
    // Coordinated operations
    public func startMonitoring()
    public func refreshData(forProvider: ServiceProvider)
    public func handleNetworkChange()
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

### 3. Component-Based StatusBarController

Modular UI management with specialized components:

```swift
@MainActor
public final class StatusBarController {
    // Component managers
    private let displayManager: StatusBarDisplayManager
    private let menuManager: StatusBarMenuManager
    private let animationController: StatusBarAnimationController
    private let observer: StatusBarObserver
    
    // Delegates UI responsibilities to components
    public func updateDisplay()
    public func showMenu()
    public func animateIcon()
}
```

### 4. Actor-based Provider Implementation

Thread-safe provider operations:

```swift
public actor CursorProvider: ProviderProtocol {
    private let apiClient: CursorAPIClient
    private let dataTransformer: CursorDataTransformer
    private let resilienceManager: CursorResilienceManager
    
    // Actor-isolated API methods
    public func fetchSpendingData() async throws -> ProviderSpendingData
    public func validateAuthentication() async -> Bool
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

## Architectural Patterns

### Orchestrator Pattern
The `MultiProviderDataOrchestrator` coordinates between multiple specialized managers, each handling specific concerns:
- **SessionStateManager**: Authentication flows
- **NetworkStateManager**: Network connectivity monitoring
- **CurrencyOrchestrator**: Currency conversion operations
- **BackgroundDataProcessor**: Concurrent API operations

### Component-Based UI Architecture
The `StatusBarController` delegates UI responsibilities to specialized components:
- **Display Management**: Icon and text updates
- **Menu Management**: Popover window handling
- **Animation Control**: Gauge icon animations
- **State Observation**: Data change monitoring

### Multi-Provider Design
- **Provider Protocol**: Common interface for all AI services
- **Provider Registry**: Dynamic provider management
- **Provider Factory**: Service instantiation
- **Isolated State**: Each provider maintains independent state

## Testing Approach

The architecture is designed for comprehensive testing:

- **Protocol-based dependencies** enable easy mocking
- **Actor isolation** ensures thread-safe testing
- **Component isolation** allows focused unit tests
- **Observable state** simplifies UI testing

Test organization:
```
VibeMeterTests/
├── Core Tests/
│   ├── MultiProviderDataOrchestratorTests.swift
│   ├── CursorProviderTests.swift
│   └── NetworkStateManagerTests.swift
├── TestUtilities/
│   ├── MockServices.swift
│   ├── MockProviders.swift
│   └── TestHelpers.swift
└── UI Tests/
    └── StatusBarControllerTests.swift
```

## Performance Optimizations

- **Actor isolation** prevents data races and ensures thread safety
- **Fine-grained updates** with @Observable's property-level tracking
- **Component-based UI** reduces unnecessary redraws
- **Background processing** keeps UI responsive
- **Smart caching**:
  - Exchange rates cached for 1 hour
  - Provider data refreshed based on user settings
  - Connection status prevents unnecessary API calls
- **Network resilience**:
  - Automatic retry with exponential backoff
  - Graceful degradation on network issues
  - Connection state tracking

## Data Flow

1. **User Interaction** → StatusBarController
2. **StatusBarController** → Component managers handle UI
3. **Component managers** → MultiProviderDataOrchestrator
4. **Orchestrator** → Delegates to specialized managers
5. **Background operations** → Actor-isolated processing
6. **State updates** → @Observable models notify UI
7. **UI updates** → Components reflect new state

## Security & Privacy

- **Keychain storage** for authentication tokens
- **No credential persistence** - uses secure web auth
- **Provider isolation** - credentials never cross providers
- **Secure networking** - all API calls over HTTPS
- **No analytics** - no user tracking or data collection

## Future Extensibility

The architecture supports:
- **Additional providers** through ProviderProtocol
- **New UI components** via component architecture
- **Extended functionality** through orchestrator pattern
- **Platform expansion** with shared business logic