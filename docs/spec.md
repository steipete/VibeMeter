## Software Specification: VibeMeter
https://aistudio.google.com/prompts/1K2XHHytMLpeecOT1sjHqmRXdpodqT-ge
https://www.cursor.com/settings

**Version:** 3.0
**Date:** June 4, 2025

**1. Overview & Purpose**

VibeMeter is a macOS menu bar application designed with a **multi-provider architecture** to monitor monthly spending across multiple AI service providers. While currently supporting only Cursor AI, the application is architected to easily add support for OpenAI, Anthropic, GitHub Copilot, and other services. It provides at-a-glance cost information via an animated gauge icon, configurable spending limits with system notifications, multi-currency support, and a modern SwiftUI-based interface. The application uses provider-specific authentication methods (WebKit-based OAuth flows) to obtain session tokens for secure API access.

**2. Target Platform**

*   **Operating System:** macOS 15.0+ (Sequoia)
*   **Architecture:** Universal Binary (Apple Silicon & Intel)
*   **Swift Version:** Swift 6 with strict concurrency checking
*   **Minimum Deployment Target:** macOS 15.0

**3. Architecture & Core Components**

**3.1. Multi-Provider Architecture**

The application uses a provider-agnostic architecture enabling support for multiple AI services:

*   **ProviderProtocol:** Generic interface that all service providers must implement
*   **ServiceProvider Enum:** Defines supported providers (currently: .cursor, extensible for others)
*   **ProviderFactory:** Creates provider instances based on service type
*   **ProviderRegistry:** Manages enabled/disabled state of providers
*   **Multi-Provider Models:** Observable models that maintain state for all providers simultaneously

**Key Architectural Patterns:**
*   **Orchestrator Pattern:** MultiProviderDataOrchestrator coordinates between specialized managers
*   **Component-Based UI:** StatusBarController delegates to specialized component managers
*   **Actor Isolation:** Background operations isolated in actors for thread safety
*   **Delegation Pattern:** Loose coupling between components via protocols and callbacks
*   **Observable State:** Swift's @Observable macro for fine-grained reactive updates

**3.2. Core Components**

1.  **StatusBarController:** Component-based architecture managing the NSStatusItem with:
    *   **StatusBarDisplayManager:** Handles menu bar text and icon display
    *   **StatusBarMenuManager:** Manages popover window and menu interactions
    *   **StatusBarAnimationController:** Controls gauge icon animations
    *   **StatusBarObserver:** Observes data changes and triggers UI updates
2.  **MultiProviderDataOrchestrator:** Central coordinator (@MainActor @Observable) delegating to:
    *   **SessionStateManager:** Manages login/logout flows across providers
    *   **NetworkStateManager:** Monitors connectivity and handles network state changes
    *   **CurrencyOrchestrator:** Coordinates currency conversion operations
    *   **BackgroundDataProcessor:** Actor handling concurrent API operations
3.  **MultiProviderLoginManager:** Handles WebKit-based authentication for multiple providers
4.  **AuthenticationTokenManager:** Manages secure token storage and retrieval per provider
5.  **Provider Implementations:** Service-specific implementations conforming to ProviderProtocol:
    *   **CursorProvider:** Actor-based implementation for Cursor AI API interactions
    *   **ProviderFactory:** Creates provider instances based on ServiceProvider enum
    *   **ProviderRegistry:** Manages enabled/disabled state of providers
6.  **ExchangeRateManager:** Actor managing currency conversions with caching and fallback rates
7.  **SettingsManager:** @Observable model with specialized managers:
    *   **SessionSettingsManager:** Provider session persistence
    *   **DisplaySettingsManager:** UI preferences
    *   **SpendingLimitsManager:** Limit configuration
    *   **AppBehaviorSettingsManager:** App behavior settings
8.  **NotificationManager:** Handles system notifications for spending alerts with per-session tracking
9.  **Observable Data Models:** Using Swift's @Observable macro for reactive state:
    *   **MultiProviderSpendingData:** Tracks spending/usage across all providers
    *   **MultiProviderUserSessionData:** Manages authentication state for all providers
    *   **CurrencyData:** Maintains currency selection and exchange rates
    *   **ProviderConnectionStatus:** Tracks connection state per provider

**4. Detailed Feature Specifications**

**4.1. Menu Bar Display**

*   **Icon:** Custom animated gauge icon (GaugeIcon.swift) with three states:
    *   **Not Logged In:** Greyed out gauge with disabled appearance
    *   **Loading:** Animated blue gradient gauge with shimmer effect
    *   **Data:** Color-coded gauge (teal→green→yellow→orange→red) based on spending percentage
*   **Text Display (Optional):**
    *   Controlled by `showCostInMenuBar` setting (default: false/icon-only)
    *   Format: `[CUR_SYMBOL][Total Spending]` (e.g., `$45.23`)
    *   Shows total spending across ALL connected providers
    *   Animated transitions between values using MenuBarStateManager
*   **Custom Popover:** 
    *   Uses CustomMenuWindow (not native NSMenu) for rich SwiftUI content
    *   Fixed size: 300x400 (logged in) or 300x280 (logged out)
    *   Modern SwiftUI Material (.regularMaterial) background replacing NSVisualEffectView

**4.2. Popover Content**

**When Logged Out (LoggedOutContentView):**
*   Large gauge icon with "No providers connected" message
*   Login buttons for each available provider
*   Quick access to Settings

**When Logged In (LoggedInContentView):**
*   **Header Section:**
    *   User avatar (Gravatar) and email from most recent provider session
    *   Total spending display with animated transitions
    *   Circular progress gauge showing spending vs upper limit
*   **Cost Breakdown (CostTableView):**
    *   Per-provider spending rows with hover effects
    *   Usage data (requests/tokens) display
    *   Warning/Upper limit indicators with color coding
*   **Footer Actions:**
    *   Settings button
    *   Refresh button with loading state
    *   Quit button

**4.3. Multi-Provider Features**

*   **Simultaneous Connections:** Users can be logged into multiple providers at once
*   **Aggregate Spending:** Total spending calculated across all connected providers
*   **Provider Management:** Enable/disable providers via ProviderRegistry
*   **Independent Sessions:** Each provider maintains its own authentication state
*   **Unified Display:** Single gauge icon represents combined spending percentage

**4.4. Authentication System**

*   **Per-Provider Login:** Each provider has independent login state and window
*   **LoginWebViewManager:** Manages multiple WKWebView instances for concurrent logins
*   **AuthenticationTokenManager:** Secure token storage in Keychain per provider
*   **Provider-Specific Auth:**
    *   Cursor: OAuth via `https://authenticator.cursor.sh/` extracting `WorkosCursorSessionToken`
    *   Future providers will have their own auth flows defined in ServiceProvider enum
*   **Session Validation:** Tokens validated on startup and during data fetch
*   **Automatic Retry:** Failed auth triggers re-login prompt

**4.5. Data Fetching & Provider APIs**

**Generic Provider Interface (ProviderProtocol):**
*   `fetchTeamInfo()` → ProviderTeamInfo
*   `fetchUserInfo()` → ProviderUserInfo  
*   `fetchMonthlyInvoice()` → ProviderMonthlyInvoice
*   `fetchUsageData()` → ProviderUsageData
*   `validateToken()` → Bool

**Cursor Provider Implementation:**
*   **Team Info:** `POST /api/dashboard/teams` (returns first team)
*   **User Info:** `GET /api/auth/me` (returns email and teamId)
*   **Monthly Invoice:** `POST /api/dashboard/get-monthly-invoice` with month/year/teamId
*   **Usage Data:** `GET /api/usage` (GPT-4 usage as primary metric)
*   **Error Handling:** Specific handling for 401 (unauthorized), 429 (rate limit), team not found

**Data Orchestration:**
*   **BackgroundDataProcessor:** Actor processing API calls concurrently on background threads
*   **Refresh Timers:** Per-provider timers based on user settings (default 5 min)
*   **Parallel Fetching:** All providers refreshed concurrently via TaskGroup
*   **Session Consistency:** Validates stored sessions against keychain tokens on startup
*   **Network State Integration:** Automatic refresh on network connectivity changes
*   **Connection Status Tracking:** Real-time monitoring of provider connection states
*   **Swift 6 Concurrency:** Complete actor isolation for data race safety

**4.6. Settings Window (MultiProviderSettingsView)**

**Tab-based Interface (NavigationStack-based):**
1. **General Tab:**
   *   Currency selector (USD, EUR, GBP, JPY, AUD, CAD, CHF, CNY, SEK, NZD)
   *   Refresh interval (1, 2, 5, 10, 15, 30, 60 minutes)
   *   Show cost in menu bar toggle
   *   Show in Dock toggle
   
2. **Limits Tab:**
   *   Warning limit input with live currency conversion
   *   Upper limit input with live currency conversion
   *   Visual gauge preview showing current spending
   *   All limits stored in USD, displayed in selected currency

3. **Providers Tab (ProvidersSettingsView):**
   *   List of all supported providers with connection status
   *   Login/Logout buttons per provider
   *   Provider details on click (team info, usage stats)
   *   Enable/disable providers (future feature)

4. **About Tab:**
   *   App version and build info
   *   Sparkle update status
   *   GitHub/support links

**4.7. Currency Management**

*   **Supported Currencies:** USD, EUR, GBP, JPY, AUD, CAD, CHF, CNY, SEK, NZD
*   **Base Currency:** USD (all limits and API data in USD)
*   **Exchange Rate Source:** Frankfurter.app API (no key required)
*   **Caching:** 1-hour cache validity with automatic refresh
*   **CurrencyData Model:** Observable model maintaining rates and conversions
*   **Fallback Behavior:** Falls back to USD display if rates unavailable
*   **Currency Symbols:** Automatic symbol selection based on currency code

**4.8. Notifications System**

*   **NotificationManager:** Handles macOS User Notifications with per-session tracking
*   **Trigger Conditions:**
    *   Warning: Total spending >= warning limit
    *   Upper: Total spending >= upper limit
*   **Notification Content:**
    *   Warning: "Spending Alert ⚠️" with current/limit amounts
    *   Upper: "Spending Limit Reached! 🚨" with critical alert
*   **Reset Logic:** Notifications reset when spending drops below thresholds
*   **Permissions:** Requests notification authorization on first trigger

**4.9. Additional Features**

*   **Gravatar Integration:** Displays user avatars based on email
*   **Launch at Login:** Via StartupManager using ServiceManagement framework
*   **Auto-Updates:** Sparkle framework integration (disabled in debug builds)
*   **Single Instance:** Ensures only one app instance runs at a time
*   **Analytics WebView:** Opens provider dashboards in external browser

**5. Data Storage & Persistence**

**macOS Keychain (per provider):**
*   Authentication tokens stored securely via KeychainHelper
*   Service identifiers: `com.vibemeter.[provider]` (e.g., `com.vibemeter.cursor`)

**UserDefaults (SettingsManager):**
*   `providerSessions`: JSON-encoded dictionary of ProviderSession objects
*   `enabledProviders`: Array of enabled provider identifiers
*   `selectedCurrencyCode`: String (default: "USD")
*   `refreshIntervalMinutes`: Int (default: 5)
*   `warningLimitUSD`: Double (default: 200.0)
*   `upperLimitUSD`: Double (default: 1000.0)
*   `launchAtLoginEnabled`: Bool
*   `showCostInMenuBar`: Bool (default: false)
*   `showInDock`: Bool (default: false)

**6. Error Handling**

*   **Network Errors:** Graceful degradation with error states in UI
*   **Authentication Failures:** Automatic logout and re-login prompt
*   **API Errors:** Provider-specific error handling (401, 429, 503)
*   **Team Not Found:** Special handling to clear invalid session data
*   **Currency Conversion Failures:** Falls back to USD display
*   **Concurrent Operations:** All async operations use Swift concurrency

**7. Technical Implementation**

*   **Swift 6:** Complete concurrency checking with strict data race safety
*   **Modern Swift Observation:** @Observable macro for reactive state management (not Combine)
*   **Component-Based Architecture:** StatusBarController delegates to specialized component managers
*   **Enhanced String Formatting:** .formatted() APIs replacing legacy string interpolation
*   **Architecture:** Multi-provider with orchestrator pattern, observable models, and background actors
*   **UI Framework:** SwiftUI for all windows and views with macOS 15 APIs
*   **Menu Bar:** Custom NSStatusItem with component-based management
*   **Concurrency:** Multiple actors (BackgroundDataProcessor, CursorProvider, ExchangeRateManager), async/await, @MainActor isolation
*   **Delegation Pattern:** Extensive use of delegation for loose coupling between components
*   **Testing:** Protocol-based design enabling comprehensive mocking
*   **Logging:** LoggingService with structured logging to Console.app

**8. Build System & Dependencies**

**Project Management:**
*   **Tuist:** Project generation with Swift 6 patches
*   **Build Scripts:** Comprehensive automation for building, signing, notarization
*   **CI/CD:** GitHub Actions support (see CI-SETUP.md)

**Dependencies (Swift Package Manager):**
*   **swift-log (1.6.1+):** Structured logging
*   **KeychainAccess (4.0.0+):** Simplified keychain operations
*   **Sparkle (2.0.0+):** Auto-update framework

**Code Signing & Distribution:**
*   **Hardened Runtime:** Enabled for notarization
*   **Entitlements:** Network access, user notifications
*   **DMG Creation:** Automated via create-dmg.sh
*   **Notarization:** App Store Connect API integration

**9. File Organization**

```
VibeMeter/
├── App/                    # App entry point
│   └── VibeMeterApp.swift  # Main app with @Observable environment
├── Core/
│   ├── Extensions/         # Swift extensions
│   │   ├── Color+Theme.swift
│   │   └── URL+QueryItems.swift
│   ├── Models/            # Data models (@Observable)
│   │   ├── CurrencyData.swift
│   │   ├── MenuBarDisplayMode.swift
│   │   ├── MultiProviderUserSession.swift
│   │   ├── ProviderConnectionStatus.swift
│   │   ├── ProviderSession.swift
│   │   └── ProviderSpendingData.swift
│   ├── Protocols/         # Core protocols
│   │   ├── KeychainProtocol.swift
│   │   └── URLSessionProtocol.swift
│   ├── Providers/         # Provider implementations
│   │   ├── Cursor/
│   │   │   ├── CursorAPIClient.swift
│   │   │   ├── CursorDataTransformer.swift
│   │   │   ├── CursorResilienceManager.swift
│   │   │   └── CursorResponseModels.swift
│   │   ├── CursorProvider.swift
│   │   ├── ProviderProtocol.swift
│   │   └── ServiceProvider.swift
│   ├── Services/          # Business logic services
│   │   ├── AuthenticationTokenManager.swift
│   │   ├── BackgroundDataProcessor.swift
│   │   ├── CurrencyManager.swift
│   │   ├── CurrencyOrchestrator.swift
│   │   ├── ExchangeRateManager.swift
│   │   ├── GravatarService.swift
│   │   ├── LoggingService.swift
│   │   ├── LoginWebViewManager.swift
│   │   ├── MultiProviderDataOrchestrator.swift
│   │   ├── MultiProviderLoginManager.swift
│   │   ├── NetworkConnectivityMonitor.swift
│   │   ├── NetworkStateManager.swift
│   │   ├── NotificationManager.swift
│   │   ├── ProviderStateManager.swift
│   │   ├── SessionStateManager.swift
│   │   ├── Settings/      # Specialized settings managers
│   │   │   ├── AppBehaviorSettingsManager.swift
│   │   │   ├── DisplaySettingsManager.swift
│   │   │   ├── SessionSettingsManager.swift
│   │   │   └── SpendingLimitsManager.swift
│   │   ├── SettingsManager.swift
│   │   ├── SparkleUpdaterManager.swift
│   │   └── StartupManager.swift
│   └── Utilities/         # Helper classes
│       ├── BrowserAuthenticationHelper.swift
│       ├── CurrencyConversionHelper.swift
│       ├── KeychainHelper.swift
│       ├── NSApplication+openSettings.swift
│       ├── NetworkRetryHandler.swift
│       ├── RelativeTimeFormatter.swift
│       ├── StringExtensions+MenuBar.swift
│       ├── StringExtensions.swift
│       └── UserDefaultsBacked.swift
├── Presentation/
│   ├── Components/        # Reusable UI components
│   │   ├── ActionButtonsView.swift
│   │   ├── ButtonStyles.swift
│   │   ├── CostTableView.swift
│   │   ├── GaugeIcon.swift
│   │   ├── MenuBarState.swift
│   │   ├── NetworkStatusIndicator.swift
│   │   ├── Provider/
│   │   │   ├── ProviderInteractionHandler.swift
│   │   │   └── ProviderSpendingAmountView.swift
│   │   ├── ProviderIconView.swift
│   │   ├── ProviderSpendingRowView.swift
│   │   ├── ProviderStatusBadge.swift
│   │   ├── ProviderUsageBadgeView.swift
│   │   ├── SettingsUIComponents.swift
│   │   ├── StatusBarAnimationController.swift
│   │   ├── StatusBarController.swift
│   │   ├── StatusBarDisplayManager.swift
│   │   ├── StatusBarMenuManager.swift
│   │   ├── StatusBarObserver.swift
│   │   ├── UserAvatarView.swift
│   │   └── UserHeaderView.swift
│   ├── PreviewHelpers/    # SwiftUI preview support
│   │   ├── MockServices.swift
│   │   ├── MockSettingsManager.swift
│   │   ├── PreviewData.swift
│   │   └── PreviewExtensions.swift
│   ├── Utilities/         # UI utilities
│   │   ├── CommonViewModifiers.swift
│   │   └── ShimmerEffect.swift
│   └── Views/             # SwiftUI views
│       ├── AboutView.swift
│       ├── AnalyticsWebView.swift
│       ├── GeneralSettingsView.swift
│       ├── LoggedInContentView.swift
│       ├── LoggedOutContentView.swift
│       ├── MultiProviderSettingsView.swift
│       ├── ProviderDetailView.swift
│       ├── ProviderRowView.swift
│       ├── ProvidersSettingsView.swift
│       ├── SettingsComponents.swift
│       ├── SpendingLimitsView.swift
│       └── VibeMeterMainView.swift
└── Resources/             # Assets and configs
    ├── Assets.xcassets/
    └── VibeMeter.entitlements
```

**10. Future Extensibility**

*   **Additional Providers:** Architecture supports OpenAI, Anthropic, GitHub Copilot
*   **Provider Features:** Usage quotas, billing cycles, team management
*   **UI Enhancements:** Spending trends, historical data, export functionality
*   **Platform Expansion:** iOS/iPadOS companion apps via shared Swift packages