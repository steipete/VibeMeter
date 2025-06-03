import AppKit
import Observation
import SwiftUI

/// Manages the macOS status bar item and its associated dropdown menu.
///
/// StatusBarController is responsible for creating and maintaining the menu bar presence
/// of the application. It handles the status item display, updates the gauge icon based
/// on spending data, manages the dropdown menu window, and responds to appearance changes
/// for proper dark/light mode support.
@MainActor
final class StatusBarController: NSObject {
    private var statusItem: NSStatusItem?
    private var customMenuWindow: CustomMenuWindow?
    private var observationTask: Task<Void, Never>?
    private var animationTimer: Timer?
    private var periodicTimer: Timer?
    private let stateManager = MenuBarStateManager()

    private let settingsManager: any SettingsManagerProtocol
    private let userSession: MultiProviderUserSessionData
    private let loginManager: MultiProviderLoginManager
    private let spendingData: MultiProviderSpendingData
    private let currencyData: CurrencyData
    private weak var orchestrator: MultiProviderDataOrchestrator?
    
    // Change detection state
    private struct DisplayState: Equatable {
        let isLoggedIn: Bool
        let hasData: Bool
        let gaugeValue: Double
        let totalSpending: Double
        let currencyCode: String
        let currencySymbol: String
        let displayMode: MenuBarDisplayMode
        let isDarkMode: Bool
        let hasProviderIssues: Bool
        let connectionStatus: ProviderConnectionStatus
        let animatedGaugeValue: Double
        let animatedCostValue: Double
        
        static func == (lhs: DisplayState, rhs: DisplayState) -> Bool {
            return lhs.isLoggedIn == rhs.isLoggedIn &&
                   lhs.hasData == rhs.hasData &&
                   abs(lhs.gaugeValue - rhs.gaugeValue) < 0.001 &&
                   abs(lhs.totalSpending - rhs.totalSpending) < 0.01 &&
                   lhs.currencyCode == rhs.currencyCode &&
                   lhs.currencySymbol == rhs.currencySymbol &&
                   lhs.displayMode == rhs.displayMode &&
                   lhs.isDarkMode == rhs.isDarkMode &&
                   lhs.hasProviderIssues == rhs.hasProviderIssues &&
                   lhs.connectionStatus == rhs.connectionStatus &&
                   abs(lhs.animatedGaugeValue - rhs.animatedGaugeValue) < 0.001 &&
                   abs(lhs.animatedCostValue - rhs.animatedCostValue) < 0.01
        }
    }
    
    private var lastDisplayState: DisplayState?
    private var lastTooltip: String = ""
    private var lastAccessibilityDescription: String = ""

    init(settingsManager: any SettingsManagerProtocol,
         userSession: MultiProviderUserSessionData,
         loginManager: MultiProviderLoginManager,
         spendingData: MultiProviderSpendingData,
         currencyData: CurrencyData,
         orchestrator: MultiProviderDataOrchestrator) {
        self.settingsManager = settingsManager
        self.userSession = userSession
        self.loginManager = loginManager
        self.spendingData = spendingData
        self.currencyData = currencyData
        self.orchestrator = orchestrator
        super.init()

        setupStatusItem()
        setupCustomMenu()
        observeDataChanges()
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            button.imagePosition = .imageLeading
            button.action = #selector(togglePopover)
            button.target = self

            // Accessibility support for menu bar button
            button.setAccessibilityTitle("VibeMeter")
            button.setAccessibilityRole(.button)
            button.setAccessibilityHelp("Shows AI service spending information and opens VibeMeter menu")

            updateStatusItemDisplay()
        }
    }

    private func setupCustomMenu() {
        let contentView = CustomMenuContainer {
            VibeMeterMainView(
                settingsManager: settingsManager,
                userSessionData: userSession,
                loginManager: loginManager,
                onRefresh: { [weak self] in
                    await self?.orchestrator?.refreshAllProviders(showSyncedMessage: true)
                })
                .environment(spendingData)
                .environment(currencyData)
                .environment(GravatarService.shared)
        }

        customMenuWindow = CustomMenuWindow(contentView: contentView)
    }

    func updateStatusItemDisplay() {
        guard let button = statusItem?.button else { return }

        // Calculate current display state
        let isLoggedIn = userSession.isLoggedInToAnyProvider
        let providers = spendingData.providersWithData
        let hasData = !providers.isEmpty
        
        // Update state manager first
        if !isLoggedIn {
            stateManager.setState(.notLoggedIn)
        } else if !hasData {
            stateManager.setState(.loading)
        } else {
            let totalSpendingUSD = spendingData.totalSpendingConverted(
                to: "USD",
                rates: currencyData.effectiveRates)
            let gaugeValue = min(max(totalSpendingUSD / settingsManager.upperLimitUSD, 0.0), 1.0)

            // Only set new data state if the value has changed significantly
            if case .loading = stateManager.currentState {
                stateManager.setState(.data(value: gaugeValue))
            } else if case let .data(currentValue) = stateManager.currentState {
                if abs(currentValue - gaugeValue) > 0.01 {
                    stateManager.setState(.data(value: gaugeValue))
                }
            } else {
                stateManager.setState(.data(value: gaugeValue))
            }
        }
        
        // Calculate current display values
        let totalSpending = hasData ? spendingData.totalSpendingConverted(
            to: currencyData.selectedCode,
            rates: currencyData.effectiveRates) : 0.0
        let totalSpendingUSD = hasData ? spendingData.totalSpendingConverted(
            to: "USD",
            rates: currencyData.effectiveRates) : 0.0
        let gaugeValue = hasData ? min(max(totalSpendingUSD / settingsManager.upperLimitUSD, 0.0), 1.0) : 0.0
        let isDarkMode = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        let displayMode = settingsManager.menuBarDisplayMode
        
        // Create current display state
        let currentState = DisplayState(
            isLoggedIn: isLoggedIn,
            hasData: hasData,
            gaugeValue: gaugeValue,
            totalSpending: totalSpending,
            currencyCode: currencyData.selectedCode,
            currencySymbol: currencyData.selectedSymbol,
            displayMode: displayMode,
            isDarkMode: isDarkMode,
            hasProviderIssues: spendingData.hasProviderIssues,
            connectionStatus: spendingData.overallConnectionStatus,
            animatedGaugeValue: stateManager.animatedGaugeValue,
            animatedCostValue: stateManager.animatedCostValue
        )
        
        // Check if we need to update anything
        let stateChanged = lastDisplayState != currentState
        if !stateChanged {
            return // No changes detected, skip update
        }
        
        let lastState = lastDisplayState
        lastDisplayState = currentState
        
        // Update icon if needed
        let iconNeedsUpdate = lastState?.displayMode.showsIcon != currentState.displayMode.showsIcon ||
                            lastState?.isDarkMode != currentState.isDarkMode ||
                            lastState?.isLoggedIn != currentState.isLoggedIn ||
                            lastState?.hasData != currentState.hasData ||
                            lastState?.hasProviderIssues != currentState.hasProviderIssues ||
                            lastState?.connectionStatus != currentState.connectionStatus ||
                            abs((lastState?.animatedGaugeValue ?? 0) - currentState.animatedGaugeValue) > 0.001
        
        if iconNeedsUpdate {
            updateIcon(button: button, state: currentState)
        }
        
        // Update title if needed
        let titleNeedsUpdate = lastState?.displayMode.showsMoney != currentState.displayMode.showsMoney ||
                             lastState?.displayMode.showsIcon != currentState.displayMode.showsIcon ||
                             lastState?.currencySymbol != currentState.currencySymbol ||
                             lastState?.hasData != currentState.hasData ||
                             abs((lastState?.animatedCostValue ?? 0) - currentState.animatedCostValue) > 0.01
        
        if titleNeedsUpdate {
            updateTitle(button: button, state: currentState)
        }
        
        // Update tooltip and accessibility (less frequently)
        let tooltipNeedsUpdate = lastState?.isLoggedIn != currentState.isLoggedIn ||
                               lastState?.hasData != currentState.hasData ||
                               abs((lastState?.gaugeValue ?? 0) - currentState.gaugeValue) > 0.01 ||
                               lastState?.currencyCode != currentState.currencyCode
        
        if tooltipNeedsUpdate {
            updateTooltipAndAccessibility(button: button)
        }
    }
    
    private func updateIcon(button: NSStatusBarButton, state: DisplayState) {
        if state.displayMode.showsIcon {
            let colorScheme: ColorScheme = state.isDarkMode ? .dark : .light
            
            let gaugeView: some View = ZStack(alignment: .topTrailing) {
                switch stateManager.currentState {
                case .notLoggedIn:
                    GaugeIcon(value: 0, isLoading: false, isDisabled: true, animateOnAppear: true)
                        .frame(width: 18, height: 18)
                        .environment(\.colorScheme, colorScheme)
                case .loading:
                    GaugeIcon(
                        value: state.animatedGaugeValue,
                        isLoading: true,
                        isDisabled: false,
                        animateOnAppear: true)
                        .frame(width: 18, height: 18)
                        .environment(\.colorScheme, colorScheme)
                case .data:
                    GaugeIcon(
                        value: state.animatedGaugeValue,
                        isLoading: false,
                        isDisabled: false,
                        animateOnAppear: true)
                        .frame(width: 18, height: 18)
                        .environment(\.colorScheme, colorScheme)
                }

                if state.hasProviderIssues {
                    MenuBarStatusDot(status: state.connectionStatus)
                        .offset(x: 2, y: -2)
                }
            }

            let renderer = ImageRenderer(content: gaugeView)
            renderer.scale = 2.0

            if let nsImage = renderer.nsImage {
                nsImage.size = NSSize(width: 18, height: 18)
                button.image = nsImage
                button.image?.isTemplate = false
            } else {
                print("GaugeIcon rendering failed, using fallback")
                button.image = NSImage(systemSymbolName: "gauge", accessibilityDescription: "VibeMeter")
                button.image?.isTemplate = true
            }
        } else {
            button.image = nil
        }
    }
    
    private func updateTitle(button: NSStatusBarButton, state: DisplayState) {
        if state.displayMode.showsMoney, stateManager.currentState.showsGauge, state.hasData {
            stateManager.setCostValue(state.totalSpending)
            let spacingPrefix = state.displayMode.showsIcon ? "  " : ""
            button.title = "\(spacingPrefix)\(state.currencySymbol)\(state.animatedCostValue.formatted(.number.precision(.fractionLength(2))))"
        } else {
            button.title = ""
        }
    }
    
    private func updateTooltipAndAccessibility(button: NSStatusBarButton) {
        let tooltip = createTooltipText()
        let accessibility = createAccessibilityDescription()
        
        // Only update if text actually changed
        if tooltip != lastTooltip {
            button.toolTip = tooltip
            lastTooltip = tooltip
        }
        
        if accessibility != lastAccessibilityDescription {
            button.setAccessibilityValue(accessibility)
            lastAccessibilityDescription = accessibility
        }
    }

    @objc
    private func togglePopover() {
        guard let button = statusItem?.button,
              let window = customMenuWindow else { return }

        if window.isVisible {
            window.hide()
        } else {
            window.show(relativeTo: button)
        }
    }

    /// Shows the popover menu (used for initial display when not logged in)
    func showPopover() {
        guard let button = statusItem?.button,
              let window = customMenuWindow else { return }

        if !window.isVisible {
            window.show(relativeTo: button)
        }
    }

    // Methods removed - handled by CustomMenuWindow

    private func createTooltipText() -> String {
        guard userSession.isLoggedInToAnyProvider else {
            return "VibeMeter - Not logged in to any provider"
        }

        let providers = spendingData.providersWithData
        guard !providers.isEmpty else {
            return "VibeMeter - Loading data..."
        }

        // Calculate spending percentage
        let totalSpendingUSD = spendingData.totalSpendingConverted(
            to: "USD",
            rates: currencyData.effectiveRates)
        let upperLimit = settingsManager.upperLimitUSD
        let percentage = (totalSpendingUSD / upperLimit * 100).rounded()

        // Get most recent refresh date
        let mostRecentRefresh = providers
            .compactMap { provider in
                spendingData.getSpendingData(for: provider)?.lastSuccessfulRefresh
            }
            .max()

        var tooltip = "VibeMeter - \(Int(percentage))% of limit"

        if let lastRefresh = mostRecentRefresh {
            let refreshText = RelativeTimeFormatter.string(from: lastRefresh, style: .withPrefix)
            let freshnessIndicator = RelativeTimeFormatter.isFresh(lastRefresh) ? "🟢" : "🟡"
            tooltip += "\n\(freshnessIndicator) \(refreshText)"

            // Add data freshness context
            if !RelativeTimeFormatter.isFresh(lastRefresh, withinMinutes: 15) {
                tooltip += " (May be outdated)"
            }
        } else {
            tooltip += "\n🔴 Never updated"
        }

        // Add keyboard shortcuts info
        tooltip += "\n\nKeyboard shortcuts:"
        tooltip += "\n⌘R - Refresh data"
        tooltip += "\n⌘, - Open Settings"
        tooltip += "\n⌘Q - Quit VibeMeter"
        tooltip += "\nESC - Close menu"

        return tooltip
    }

    /// Creates accessibility-friendly description for VoiceOver users
    private func createAccessibilityDescription() -> String {
        guard userSession.isLoggedInToAnyProvider else {
            return "Not logged in to any AI service provider. Click to open VibeMeter and log in."
        }

        let providers = spendingData.providersWithData
        guard !providers.isEmpty else {
            return "Loading AI service spending data. Please wait."
        }

        // Calculate spending percentage
        let totalSpendingUSD = spendingData.totalSpendingConverted(
            to: "USD",
            rates: currencyData.effectiveRates)
        let upperLimit = settingsManager.upperLimitUSD
        let percentage = (totalSpendingUSD / upperLimit * 100).rounded()

        // Convert to user's preferred currency for accessibility
        let userSpending = spendingData.totalSpendingConverted(
            to: currencyData.selectedCode,
            rates: currencyData.effectiveRates)
        let userLimit = settingsManager.upperLimitUSD * currencyData.effectiveRates[
            currencyData.selectedCode,
            default: 1.0
        ]

        let spendingText =
            "\(currencyData.selectedSymbol)\(userSpending.formatted(.number.precision(.fractionLength(2))))"
        let limitText = "\(currencyData.selectedSymbol)\(userLimit.formatted(.number.precision(.fractionLength(2))))"

        // Provide context about spending level
        let statusText = switch percentage {
        case 0 ..< 50:
            "Low usage"
        case 50 ..< 80:
            "Moderate usage"
        case 80 ..< 100:
            "High usage, approaching limit"
        default:
            "Over limit"
        }

        // Add refresh information for accessibility
        let refreshProviders = spendingData.providersWithData
        let mostRecentRefresh = refreshProviders
            .compactMap { provider in
                spendingData.getSpendingData(for: provider)?.lastSuccessfulRefresh
            }
            .max()

        var accessibilityText =
            "\(statusText). Current spending: \(spendingText) of \(limitText) limit. \(Int(percentage)) percent used."

        if let lastRefresh = mostRecentRefresh {
            let refreshText = RelativeTimeFormatter.string(from: lastRefresh, style: .medium)
            accessibilityText += " Data \(refreshText)."
        } else {
            accessibilityText += " Data never updated."
        }

        accessibilityText += " Click to view details."

        return accessibilityText
    }

    private func observeDataChanges() {
        // Start modern observation using structured concurrency
        observationTask = Task { @MainActor [weak self] in
            guard let self else { return }

            // Set up notification observers and model observation using structured concurrency
            await withTaskGroup(of: Void.self) { group in
                // Observe settings changes
                group.addTask {
                    await self.observeSettingsChanges()
                }

                // Observe appearance changes
                group.addTask {
                    await self.observeAppearanceChanges()
                }

                // Observe @Observable model changes
                group.addTask {
                    await self.observeModelChanges()
                }
            }
        }

        // Set up animation timer
        setupAnimationTimer()

        // Set up periodic update timer
        setupPeriodicTimer()
    }

    private func observeSettingsChanges() async {
        let notificationSequence = NotificationCenter.default.notifications(
            named: UserDefaults.didChangeNotification)

        for await _ in notificationSequence {
            updateStatusItemDisplay()
        }
    }

    private func observeAppearanceChanges() async {
        let notificationSequence = DistributedNotificationCenter.default.notifications(
            named: Notification.Name("AppleInterfaceThemeChangedNotification"))

        for await _ in notificationSequence {
            // Delay slightly to ensure the appearance change has propagated
            try? await Task.sleep(for: .milliseconds(100))
            updateStatusItemDisplay()
        }
    }

    private func observeModelChanges() async {
        // Use withObservationTracking to observe @Observable models
        while !Task.isCancelled {
            withObservationTracking {
                // Track changes to observable models
                _ = userSession.isLoggedInToAnyProvider
                _ = spendingData.providersWithData.count
                _ = currencyData.selectedCode
                _ = settingsManager.upperLimitUSD
            } onChange: {
                Task { @MainActor in
                    self.updateStatusItemDisplay()
                }
            }

            // Small delay to prevent excessive updates
            try? await Task.sleep(for: .milliseconds(50))
        }
    }

    private func setupAnimationTimer() {
        // Start with a slower interval and adapt based on animation needs
        startAdaptiveAnimationTimer()
    }
    
    private func startAdaptiveAnimationTimer(interval: TimeInterval = 0.1) {
        animationTimer?.invalidate()
        
        animationTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }

                // Update animation state first
                self.stateManager.updateAnimation()

                let isActivelyAnimating = self.stateManager.currentState.isAnimated ||
                    self.stateManager.isTransitioning ||
                    self.stateManager.isCostTransitioning
                
                let valueChanged = abs(self.stateManager.animatedGaugeValue - self.lastRenderedValue) > 0.001

                // Always update animation state, but only update display if needed
                if isActivelyAnimating || valueChanged {
                    self.updateStatusItemDisplay()
                    self.lastRenderedValue = self.stateManager.animatedGaugeValue
                } else {
                    // Still call updateStatusItemDisplay but change detection will prevent unnecessary work
                    self.updateStatusItemDisplay()
                }
                
                // Adapt timer frequency based on animation state
                let currentInterval = interval
                let targetInterval: TimeInterval
                
                if isActivelyAnimating {
                    // High frequency for smooth animations (30fps)
                    targetInterval = 0.033
                } else if valueChanged {
                    // Medium frequency for value changes (15fps)
                    targetInterval = 0.067
                } else {
                    // Low frequency when idle (5fps)
                    targetInterval = 0.2
                }
                
                // Only restart timer if frequency needs to change significantly
                if abs(currentInterval - targetInterval) > 0.01 {
                    self.startAdaptiveAnimationTimer(interval: targetInterval)
                }
            }
        }
    }

    private func setupPeriodicTimer() {
        // Periodic timer for tooltip updates and other non-critical updates
        // Run every 30 seconds to reduce CPU usage while keeping tooltips reasonably fresh
        periodicTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                // Only update if not actively animating to avoid conflicts
                guard let self,
                      !self.stateManager.currentState.isAnimated,
                      !self.stateManager.isTransitioning,
                      !self.stateManager.isCostTransitioning else { return }
                
                self.updateStatusItemDisplay()
            }
        }
    }

    private var lastRenderedValue: Double = 0

    deinit {
        // Cancel observation task
        observationTask?.cancel()

        // Note: Timer invalidation cannot be safely done from deinit in Swift 6 strict concurrency
        // Timers will be cleaned up when the class is deallocated
        // customMenuWindow is also MainActor-isolated and will be cleaned up automatically
    }
}
