import AppKit
import SwiftUI
import Observation

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

        // Determine current state
        if !userSession.isLoggedInToAnyProvider {
            stateManager.setState(.notLoggedIn)
        } else {
            let providers = spendingData.providersWithData
            if providers.isEmpty {
                // Logged in but no data yet - loading state
                stateManager.setState(.loading)
            } else {
                // Calculate spending percentage
                let totalSpendingUSD = spendingData.totalSpendingConverted(
                    to: "USD",
                    rates: currencyData.effectiveRates)
                let gaugeValue = min(max(totalSpendingUSD / settingsManager.upperLimitUSD, 0.0), 1.0)

                // Only set new data state if the value has changed significantly (more than 1%)
                // or if we're currently in loading state (to trigger the loading->data transition)
                if case .loading = stateManager.currentState {
                    // Always animate from loading to data state
                    stateManager.setState(.data(value: gaugeValue))
                } else if case let .data(currentValue) = stateManager.currentState {
                    // Only update if the change is significant enough to warrant animation
                    if abs(currentValue - gaugeValue) > 0.01 {
                        stateManager.setState(.data(value: gaugeValue))
                    }
                } else {
                    // For any other state, set the data state
                    stateManager.setState(.data(value: gaugeValue))
                }
            }
        }

        // Determine current appearance for explicit environment injection
        let isDarkMode = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        let colorScheme: ColorScheme = isDarkMode ? .dark : .light

        // Create and render the gauge icon based on state with explicit colorScheme for ImageRenderer
        let gaugeView: some View = ZStack(alignment: .topTrailing) {
            switch stateManager.currentState {
            case .notLoggedIn:
                // Grey icon with no gauge
                GaugeIcon(value: 0, isLoading: false, isDisabled: true, animateOnAppear: true)
                    .frame(width: 18, height: 18)
                    .environment(\.colorScheme, colorScheme)
            case .loading:
                // Animated loading gauge
                GaugeIcon(
                    value: stateManager.animatedGaugeValue,
                    isLoading: true,
                    isDisabled: false,
                    animateOnAppear: true)
                    .frame(width: 18, height: 18)
                    .environment(\.colorScheme, colorScheme)
            case .data:
                // Static gauge at spending level
                GaugeIcon(
                    value: stateManager.animatedGaugeValue,
                    isLoading: false,
                    isDisabled: false,
                    animateOnAppear: true)
                    .frame(width: 18, height: 18)
                    .environment(\.colorScheme, colorScheme)
            }

            // Add status indicator if there are any provider issues
            if spendingData.hasProviderIssues {
                MenuBarStatusDot(status: spendingData.overallConnectionStatus)
                    .offset(x: 2, y: -2)
            }
        }

        let renderer = ImageRenderer(content: gaugeView)
        renderer.scale = 2.0 // Retina display

        if let nsImage = renderer.nsImage {
            // Ensure the image has the correct size
            nsImage.size = NSSize(width: 18, height: 18)
            button.image = nsImage
            // Don't use template mode since we handle light/dark mode colors in GaugeIcon
            button.image?.isTemplate = false
        } else {
            // Fallback to a system image if rendering fails
            print("GaugeIcon rendering failed, using fallback")
            button.image = NSImage(systemSymbolName: "gauge", accessibilityDescription: "VibeMeter")
            button.image?.isTemplate = true
        }

        // Set the text title if enabled and we have data
        if settingsManager.showCostInMenuBar, stateManager.currentState.showsGauge,
           !spendingData.providersWithData.isEmpty {
            // Always use total spending for consistency with the popover
            let spending = spendingData.totalSpendingConverted(
                to: currencyData.selectedCode,
                rates: currencyData.effectiveRates)

            // Update cost animation if spending changed
            stateManager.setCostValue(spending)

            // Use animated cost value for display with added spacing
            let animatedSpending = stateManager.animatedCostValue
            button
                .title =
                "  \(currencyData.selectedSymbol)\(animatedSpending.formatted(.number.precision(.fractionLength(2))))"
        } else {
            button.title = ""
        }

        // Set tooltip with spending percentage and last refresh info
        button.toolTip = createTooltipText()

        // Update accessibility description with current spending information
        button.setAccessibilityValue(createAccessibilityDescription())
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
        
        var accessibilityText = "\(statusText). Current spending: \(spendingText) of \(limitText) limit. \(Int(percentage)) percent used."
        
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
            named: UserDefaults.didChangeNotification
        )
        
        for await _ in notificationSequence {
            updateStatusItemDisplay()
        }
    }
    
    private func observeAppearanceChanges() async {
        let notificationSequence = DistributedNotificationCenter.default.notifications(
            named: Notification.Name("AppleInterfaceThemeChangedNotification")
        )
        
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
        animationTimer = Timer.scheduledTimer(withTimeInterval: 0.03, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                
                // Update animation state first
                self.stateManager.updateAnimation()
                
                // Only update frequently if animating, transitioning, or value changed
                if self.stateManager.currentState.isAnimated ||
                    self.stateManager.isTransitioning ||
                    self.stateManager.isCostTransitioning ||
                    abs(self.stateManager.animatedGaugeValue - self.lastRenderedValue) > 0.001 {
                    self.updateStatusItemDisplay()
                    self.lastRenderedValue = self.stateManager.animatedGaugeValue
                }
            }
        }
    }
    
    private func setupPeriodicTimer() {
        periodicTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateStatusItemDisplay()
            }
        }
    }

    private var lastRenderedValue: Double = 0

    deinit {
        // Cancel observation task
        observationTask?.cancel()
        
        // Note: Cannot safely invalidate MainActor-isolated timers from deinit
        // They will be cleaned up when the class is deallocated
        // customMenuWindow is also MainActor-isolated and will be cleaned up automatically
    }
}
