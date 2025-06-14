import AppKit
import os

/// A view that automatically tracks Observable properties for status bar display updates.
///
/// This view leverages NSObservationTrackingEnabled to automatically update the
/// status bar display when any tracked Observable properties change.
@MainActor
final class ObservableStatusBarDisplayView: ObservableTrackingView {
    private weak var statusBarButton: NSStatusBarButton?
    private let displayManager: StatusBarDisplayManager
    private let stateManager: MenuBarStateManager
    private let userSession: MultiProviderUserSessionData
    private let spendingData: MultiProviderSpendingData
    private let currencyData: CurrencyData
    private let settingsManager: any SettingsManagerProtocol
    private let orchestrator: MultiProviderDataOrchestrator

    init(statusBarButton: NSStatusBarButton,
         displayManager: StatusBarDisplayManager,
         stateManager: MenuBarStateManager,
         userSession: MultiProviderUserSessionData,
         spendingData: MultiProviderSpendingData,
         currencyData: CurrencyData,
         settingsManager: any SettingsManagerProtocol,
         orchestrator: MultiProviderDataOrchestrator) {
        self.statusBarButton = statusBarButton
        self.displayManager = displayManager
        self.stateManager = stateManager
        self.userSession = userSession
        self.spendingData = spendingData
        self.currencyData = currencyData
        self.settingsManager = settingsManager
        self.orchestrator = orchestrator

        super.init(frame: .zero)

        // Enable layer backing for better performance
        wantsLayer = true

        // Hide the view - it's only used for tracking
        isHidden = true
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func trackObservableProperties() {
        // Track all Observable properties that affect status bar display

        // User session state
        _ = userSession.isLoggedInToAnyProvider

        // Spending data
        _ = spendingData.providersWithData
        _ = spendingData.overallConnectionStatus
        _ = spendingData.hasProviderIssues

        // Currency data
        _ = currencyData.selectedCode
        _ = currencyData.selectedSymbol
        _ = currencyData.effectiveRates

        // Settings - track display mode changes
        let previousDisplayMode = settingsManager.menuBarDisplayMode
        _ = settingsManager.menuBarDisplayMode
        _ = settingsManager.upperLimitUSD
        _ = settingsManager.displaySettingsManager.gaugeRepresentation
        
        // Check if display mode changed and invalidate cache if needed
        if previousDisplayMode != settingsManager.menuBarDisplayMode {
            displayManager.invalidateIconCache()
        }

        // Orchestrator state
        _ = orchestrator.isRefreshing

        // State manager animated values
        _ = stateManager.animatedGaugeValue
        _ = stateManager.animatedCostValue
        _ = stateManager.currentState
    }

    override func viewWillDraw() {
        super.viewWillDraw()

        // Update the status bar display whenever we're about to draw
        // This will happen automatically when tracked properties change
        updateStatusBarDisplay()
    }

    override func updateConstraints() {
        super.updateConstraints()

        // Also update on constraint changes
        updateStatusBarDisplay()
    }

    private func updateStatusBarDisplay() {
        guard let button = statusBarButton else { return }

        // Delegate to the display manager for the actual update
        displayManager.updateDisplay(for: button)

        // Update the state based on current data
        updateStatusBarState()
    }

    private func updateStatusBarState() {
        let isLoggedIn = userSession.isLoggedInToAnyProvider
        let isFetchingData = orchestrator.isRefreshing.values.contains(true)
        let providers = spendingData.providersWithData
        let hasData = !providers.isEmpty

        // Update state manager
        if isFetchingData {
            stateManager.setState(.loading)
        } else if !isLoggedIn {
            stateManager.setState(.notLoggedIn)
        } else if !hasData {
            stateManager.setState(.loading)
        } else {
            let gaugeValue: Double
            if settingsManager.displaySettingsManager.gaugeRepresentation == .claudeQuota,
               userSession.isLoggedIn(to: .claude) {
                gaugeValue = calculateClaudeQuotaPercentage()
                // Logger.vibeMeter(category: "StatusBar").info("🎨 Claude gauge value: \(gaugeValue) (percentage: \(gaugeValue * 100)%)")
            } else {
                let totalSpendingUSD = spendingData.totalSpendingConverted(
                    to: "USD",
                    rates: currencyData.effectiveRates)

                if totalSpendingUSD > 0 {
                    gaugeValue = min(max(totalSpendingUSD / settingsManager.upperLimitUSD, 0.0), 1.0)
                } else {
                    gaugeValue = calculateRequestUsagePercentage()
                }
            }

            // Only update if value changed significantly
            if case let .data(currentValue) = stateManager.currentState {
                if abs(currentValue - gaugeValue) > 0.01 {
                    stateManager.setState(.data(value: gaugeValue))
                }
            } else {
                stateManager.setState(.data(value: gaugeValue))
            }
        }
    }

    private func calculateRequestUsagePercentage() -> Double {
        let providers = spendingData.providersWithData

        for provider in providers {
            if let providerData = spendingData.getSpendingData(for: provider),
               let usageData = providerData.usageData,
               let maxRequests = usageData.maxRequests, maxRequests > 0 {
                let progress = min(Double(usageData.currentRequests) / Double(maxRequests), 1.0)
                return progress
            }
        }

        return 0.0
    }

    private func calculateClaudeQuotaPercentage() -> Double {
        guard let claudeData = spendingData.getSpendingData(for: .claude),
              let usageData = claudeData.usageData else {
            return 0.0
        }

        // currentRequests already contains the percentage (0-100) from FiveHourWindow
        // Convert to 0-1 range for the gauge
        let percentageUsed = Double(usageData.currentRequests) / 100.0
        return min(max(percentageUsed, 0.0), 1.0)
    }
}
