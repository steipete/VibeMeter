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

    // With automatic observation tracking, we no longer need complex state comparison

    // MARK: - Private Properties

    private let stateManager: MenuBarStateManager
    private let settingsManager: any SettingsManagerProtocol
    private let userSession: MultiProviderUserSessionData
    private let spendingData: MultiProviderSpendingData
    private let currencyData: CurrencyData

    private let tooltipProvider: StatusBarTooltipProvider
    private let accessibilityProvider: StatusBarAccessibilityProvider

    private var lastCurrencyCode: String?
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

        self.tooltipProvider = StatusBarTooltipProvider(
            userSession: userSession,
            spendingData: spendingData,
            currencyData: currencyData,
            settingsManager: settingsManager)
        self.accessibilityProvider = StatusBarAccessibilityProvider(
            userSession: userSession,
            spendingData: spendingData,
            currencyData: currencyData,
            settingsManager: settingsManager)
    }

    // MARK: - Public Methods

    /// Updates the status bar display based on current state
    func updateDisplay(for button: NSStatusBarButton) {
        // With automatic observation tracking, we always update when called
        // The tracking view ensures this is only called when needed

        updateIcon(button: button)
        updateTitle(button: button)
        updateTooltipAndAccessibility(button: button)
    }

    // MARK: - Private Methods

    private func updateIcon(button: NSStatusBarButton) {
        let hasData = !spendingData.providersWithData.isEmpty
        let displayMode = settingsManager.menuBarDisplayMode
        let isDarkMode = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua

        // Always show icon when there's no data, otherwise respect user setting
        let shouldShowIcon = !hasData || displayMode.showsIcon

        if shouldShowIcon {
            let colorScheme: ColorScheme = isDarkMode ? .dark : .light
            let shouldAnimate = false // Let automatic tracking handle updates smoothly

            let gaugeView: some View = ZStack(alignment: .topTrailing) {
                Group {
                    switch stateManager.currentState {
                    case .notLoggedIn:
                        GaugeIcon(value: 0, isLoading: false, isDisabled: true, animateOnAppear: shouldAnimate)
                            .environment(\.colorScheme, colorScheme)
                    case .loading:
                        GaugeIcon(
                            value: stateManager.animatedGaugeValue,
                            isLoading: true,
                            isDisabled: false,
                            animateOnAppear: shouldAnimate)
                            .environment(\.colorScheme, colorScheme)
                    case .data:
                        GaugeIcon(
                            value: stateManager.animatedGaugeValue,
                            isLoading: false,
                            isDisabled: false,
                            animateOnAppear: shouldAnimate)
                            .environment(\.colorScheme, colorScheme)
                    }
                }
                .id(shouldAnimate ? UUID() : nil) // Force view recreation when animating

                if spendingData.hasProviderIssues {
                    MenuBarStatusDot(status: spendingData.overallConnectionStatus)
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

    private func updateTitle(button: NSStatusBarButton) {
        let hasData = !spendingData.providersWithData.isEmpty
        let displayMode = settingsManager.menuBarDisplayMode

        if displayMode.showsMoney, stateManager.currentState.showsGauge, hasData {
            let totalSpending = spendingData.totalSpendingConverted(
                to: currencyData.selectedCode,
                rates: currencyData.effectiveRates)

            // Check if currency changed
            let currencyChanged = lastCurrencyCode != nil && lastCurrencyCode != currencyData.selectedCode
            lastCurrencyCode = currencyData.selectedCode

            if currencyChanged {
                // Currency changed - reset cost value immediately without animation
                stateManager.setCostValueImmediately(totalSpending)
            } else {
                // Normal operation - use animated transition
                stateManager.setCostValue(totalSpending)
            }

            // Force the animation manager to update immediately to sync with current data
            stateManager.updateAnimation()

            // Use new logic: icon is shown when there's no data OR user setting shows icon
            let shouldShowIcon = !hasData || displayMode.showsIcon
            let spacingPrefix = shouldShowIcon ? "  " : ""

            // Format the display value without unnecessary decimals
            let displayValue: String = if stateManager.animatedCostValue == 0 {
                // Show just "0" for zero amounts
                "0"
            } else {
                // Show 0-2 decimal places as needed, no grouping separators
                NumberFormatter.vibeMeterCurrency.string(from: NSNumber(value: stateManager.animatedCostValue)) ?? "0"
            }

            let titleText = "\(spacingPrefix)\(currencyData.selectedSymbol)\(displayValue)"
            button.title = titleText
        } else {
            button.title = ""
        }
    }

    private func updateTooltipAndAccessibility(button: NSStatusBarButton) {
        let tooltip = tooltipProvider.createTooltipText()
        let accessibility = accessibilityProvider.createAccessibilityDescription()

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

    /// Calculates the request usage percentage across all providers
    private func calculateRequestUsagePercentage() -> Double {
        let providers = spendingData.providersWithData

        // Use same logic as ProviderUsageBadgeView for consistency
        for provider in providers {
            if let providerData = spendingData.getSpendingData(for: provider),
               let usageData = providerData.usageData,
               let maxRequests = usageData.maxRequests, maxRequests > 0 {
                // Calculate percentage using same formula as progress bar
                let progress = min(Double(usageData.currentRequests) / Double(maxRequests), 1.0)
                return progress
            }
        }

        return 0.0
    }
}
