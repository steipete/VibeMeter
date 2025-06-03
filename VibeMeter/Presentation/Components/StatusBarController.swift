import AppKit
import Combine
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
    private var cancellables = Set<AnyCancellable>()
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

        // Determine current appearance
        let isDarkMode = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        let colorScheme: ColorScheme = isDarkMode ? .dark : .light

        // Create and render the gauge icon based on state with proper environment
        let gaugeView: some View = ZStack(alignment: .topTrailing) {
            switch stateManager.currentState {
            case .notLoggedIn:
                // Grey icon with no gauge
                GaugeIcon(value: 0, isLoading: false, isDisabled: true)
                    .frame(width: 18, height: 18)
                    .environment(\.colorScheme, colorScheme)
            case .loading:
                // Animated loading gauge
                GaugeIcon(value: stateManager.animatedGaugeValue, isLoading: true, isDisabled: false)
                    .frame(width: 18, height: 18)
                    .environment(\.colorScheme, colorScheme)
            case .data:
                // Static gauge at spending level
                GaugeIcon(value: stateManager.animatedGaugeValue, isLoading: false, isDisabled: false)
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
            tooltip += "\n\(refreshText)"
        } else {
            tooltip += "\nNever updated"
        }
        
        return tooltip
    }

    private func observeDataChanges() {
        // Observe settings changes
        NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
            .sink { [weak self] _ in
                self?.updateStatusItemDisplay()
            }
            .store(in: &cancellables)

        // Observe appearance changes (dark/light mode)
        DistributedNotificationCenter.default
            .publisher(for: Notification.Name("AppleInterfaceThemeChangedNotification"))
            .sink { [weak self] _ in
                // Delay slightly to ensure the appearance change has propagated
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self?.updateStatusItemDisplay()
                }
            }
            .store(in: &cancellables)

        // Update display with appropriate frequency based on state
        Timer.publish(every: 0.03, on: .main, in: .common) // 30ms for smooth animations
            .autoconnect()
            .sink { [weak self] _ in
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
            .store(in: &cancellables)

        // Also update periodically for data changes (less frequently)
        Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.updateStatusItemDisplay()
            }
            .store(in: &cancellables)
    }

    private var lastRenderedValue: Double = 0

    deinit {
        // Can't call MainActor methods from deinit, so just set to nil
        customMenuWindow = nil
    }
}
