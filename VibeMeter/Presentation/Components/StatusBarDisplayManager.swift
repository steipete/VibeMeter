import AppKit
import SwiftUI

/// Manages the visual display aspects of the status bar item.
///
/// This manager handles icon rendering, title updates, tooltips, and accessibility
/// for the status bar item. It is responsible for the visual representation
/// based on the current application state.
@MainActor
final class StatusBarDisplayManager {
    // MARK: - Constants

    /// Threshold for detecting currency changes based on animated value difference (in currency units)
    private static let currencyChangeThreshold: Double = 0.5

    // MARK: - Display State

    struct DisplayState: Equatable {
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
            lhs.isLoggedIn == rhs.isLoggedIn &&
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

    // MARK: - Private Properties

    private let stateManager: MenuBarStateManager
    private let settingsManager: any SettingsManagerProtocol
    private let userSession: MultiProviderUserSessionData
    private let spendingData: MultiProviderSpendingData
    private let currencyData: CurrencyData

    private var lastDisplayState: DisplayState?
    private var lastTooltip: String = ""
    private var lastAccessibilityDescription: String = ""

    // MARK: - Initialization

    init(
        stateManager: MenuBarStateManager,
        settingsManager: any SettingsManagerProtocol,
        userSession: MultiProviderUserSessionData,
        spendingData: MultiProviderSpendingData,
        currencyData: CurrencyData) {
        self.stateManager = stateManager
        self.settingsManager = settingsManager
        self.userSession = userSession
        self.spendingData = spendingData
        self.currencyData = currencyData
    }

    // MARK: - Public Methods

    /// Updates the status bar display based on current state
    func updateDisplay(for button: NSStatusBarButton) {
        let currentState = createCurrentDisplayState()

        // Check if we need to update anything
        let stateChanged = lastDisplayState != currentState
        if !stateChanged {
            return // No changes detected, skip update
        }

        let lastState = lastDisplayState
        lastDisplayState = currentState

        // Update icon if needed
        if shouldUpdateIcon(from: lastState, to: currentState) {
            updateIcon(button: button, state: currentState)
        }

        // Update title if needed
        if shouldUpdateTitle(from: lastState, to: currentState) {
            updateTitle(button: button, state: currentState)
        }

        // Update tooltip and accessibility (less frequently)
        if shouldUpdateTooltipAndAccessibility(from: lastState, to: currentState) {
            updateTooltipAndAccessibility(button: button)
        }
    }

    // MARK: - Private Methods

    private func createCurrentDisplayState() -> DisplayState {
        let isLoggedIn = userSession.isLoggedInToAnyProvider
        let providers = spendingData.providersWithData
        let hasData = !providers.isEmpty

        let totalSpending = hasData ? spendingData.totalSpendingConverted(
            to: currencyData.selectedCode,
            rates: currencyData.effectiveRates) : 0.0
        let totalSpendingUSD = hasData ? spendingData.totalSpendingConverted(
            to: "USD",
            rates: currencyData.effectiveRates) : 0.0
        let gaugeValue = hasData ? min(max(totalSpendingUSD / settingsManager.upperLimitUSD, 0.0), 1.0) : 0.0
        let isDarkMode = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        let displayMode = settingsManager.menuBarDisplayMode

        return DisplayState(
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
            animatedCostValue: stateManager.animatedCostValue)
    }

    private func shouldUpdateIcon(from lastState: DisplayState?, to currentState: DisplayState) -> Bool {
        // Calculate whether icon should be shown for both states
        let lastShouldShowIcon = lastState.map { !$0.hasData || $0.displayMode.showsIcon } ?? true
        let currentShouldShowIcon = !currentState.hasData || currentState.displayMode.showsIcon

        return lastShouldShowIcon != currentShouldShowIcon ||
            lastState?.isDarkMode != currentState.isDarkMode ||
            lastState?.isLoggedIn != currentState.isLoggedIn ||
            lastState?.hasData != currentState.hasData ||
            lastState?.hasProviderIssues != currentState.hasProviderIssues ||
            lastState?.connectionStatus != currentState.connectionStatus ||
            abs((lastState?.animatedGaugeValue ?? 0) - currentState.animatedGaugeValue) > 0.001
    }

    private func shouldUpdateTitle(from lastState: DisplayState?, to currentState: DisplayState) -> Bool {
        // Calculate whether icon should be shown for both states (affects title spacing)
        let lastShouldShowIcon = lastState.map { !$0.hasData || $0.displayMode.showsIcon } ?? true
        let currentShouldShowIcon = !currentState.hasData || currentState.displayMode.showsIcon

        let shouldUpdate = lastState?.displayMode.showsMoney != currentState.displayMode.showsMoney ||
            lastShouldShowIcon != currentShouldShowIcon ||
            lastState?.currencySymbol != currentState.currencySymbol ||
            lastState?.hasData != currentState.hasData ||
            abs((lastState?.totalSpending ?? 0) - currentState.totalSpending) > 0.01

        return shouldUpdate
    }

    private func shouldUpdateTooltipAndAccessibility(from lastState: DisplayState?,
                                                     to currentState: DisplayState) -> Bool {
        lastState?.isLoggedIn != currentState.isLoggedIn ||
            lastState?.hasData != currentState.hasData ||
            abs((lastState?.gaugeValue ?? 0) - currentState.gaugeValue) > 0.01 ||
            lastState?.currencyCode != currentState.currencyCode
    }

    private func updateIcon(button: NSStatusBarButton, state: DisplayState) {
        // Always show icon when there's no data, otherwise respect user setting
        let shouldShowIcon = !state.hasData || state.displayMode.showsIcon

        if shouldShowIcon {
            let colorScheme: ColorScheme = state.isDarkMode ? .dark : .light

            // Check if display mode changed (icon was hidden and now showing)
            let lastShouldShowIcon = lastDisplayState.map { !$0.hasData || $0.displayMode.showsIcon } ?? false
            let shouldAnimate = !lastShouldShowIcon && shouldShowIcon

            let gaugeView: some View = ZStack(alignment: .topTrailing) {
                Group {
                    switch stateManager.currentState {
                    case .notLoggedIn:
                        GaugeIcon(value: 0, isLoading: false, isDisabled: true, animateOnAppear: shouldAnimate)
                            .frame(width: 18, height: 18)
                            .environment(\.colorScheme, colorScheme)
                    case .loading:
                        GaugeIcon(
                            value: state.animatedGaugeValue,
                            isLoading: true,
                            isDisabled: false,
                            animateOnAppear: shouldAnimate)
                            .frame(width: 18, height: 18)
                            .environment(\.colorScheme, colorScheme)
                    case .data:
                        GaugeIcon(
                            value: state.animatedGaugeValue,
                            isLoading: false,
                            isDisabled: false,
                            animateOnAppear: shouldAnimate)
                            .frame(width: 18, height: 18)
                            .environment(\.colorScheme, colorScheme)
                    }
                }
                .id(shouldAnimate ? UUID() : nil) // Force view recreation when animating

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
                button.image?.isTemplate = true
            } else {
                print("GaugeIcon rendering failed, using fallback")
                button.image = NSImage(systemSymbolName: "gauge", accessibilityDescription: "Vibe Meter")
                button.image?.isTemplate = true
            }
        } else {
            button.image = nil
        }
    }

    private func updateTitle(button: NSStatusBarButton, state: DisplayState) {
        if state.displayMode.showsMoney, stateManager.currentState.showsGauge, state.hasData {
            // Check if currency changed in two ways:
            // 1. Direct currency code comparison with last state
            let lastCurrencyCode = lastDisplayState?.currencyCode
            let currencyCodeChanged = lastCurrencyCode != nil && lastCurrencyCode != state.currencyCode

            // 2. Check if animated value significantly differs from target (indicates currency change)
            let currentAnimated = stateManager.animatedCostValue
            let targetSpending = state.totalSpending
            let animatedValueMismatch = abs(currentAnimated - targetSpending) > Self
                .currencyChangeThreshold // More than 50 cent difference

            let currencyChanged = currencyCodeChanged || animatedValueMismatch

            if currencyChanged {
                // Currency changed - reset cost value immediately without animation
                stateManager.setCostValueImmediately(state.totalSpending)
            } else {
                // Normal operation - use animated transition
                stateManager.setCostValue(state.totalSpending)
            }

            // Force the animation manager to update immediately to sync with current data
            stateManager.updateAnimation()

            // Use new logic: icon is shown when there's no data OR user setting shows icon
            let shouldShowIcon = !state.hasData || state.displayMode.showsIcon
            let spacingPrefix = shouldShowIcon ? "  " : ""
            let displayValue = stateManager.animatedCostValue.formatted(.number.precision(.fractionLength(2)))

            let titleText = "\(spacingPrefix)\(state.currencySymbol)\(displayValue)"
            button.title = titleText
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
}
