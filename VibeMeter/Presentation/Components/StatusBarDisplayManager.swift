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
    
    /// Maximum number of cached icons to keep in memory
    private static let maxIconCacheSize = 50

    // With automatic observation tracking, we no longer need complex state comparison
    
    // MARK: - Icon Cache Types
    
    private struct IconCacheKey: Hashable {
        let state: MenuBarState
        let gaugeValue: Int // Quantized to reduce variations (0-100)
        let isDarkMode: Bool
        let hasProviderIssues: Bool
        let connectionStatus: ProviderConnectionStatus?
        
        // Custom equality to handle MenuBarState.data case
        static func == (lhs: IconCacheKey, rhs: IconCacheKey) -> Bool {
            // Compare all properties except state first
            guard lhs.gaugeValue == rhs.gaugeValue,
                  lhs.isDarkMode == rhs.isDarkMode,
                  lhs.hasProviderIssues == rhs.hasProviderIssues,
                  lhs.connectionStatus == rhs.connectionStatus else {
                return false
            }
            
            // Custom comparison for MenuBarState
            switch (lhs.state, rhs.state) {
            case (.notLoggedIn, .notLoggedIn):
                return true
            case (.loading, .loading):
                return true
            case (.data, .data):
                // For data state, we already compare gaugeValue separately
                return true
            default:
                return false
            }
        }
        
        func hash(into hasher: inout Hasher) {
            // Hash only the enum case, not associated values
            switch state {
            case .notLoggedIn:
                hasher.combine(0)
            case .loading:
                hasher.combine(1)
            case .data:
                hasher.combine(2)
            }
            hasher.combine(gaugeValue)
            hasher.combine(isDarkMode)
            hasher.combine(hasProviderIssues)
            hasher.combine(connectionStatus)
        }
    }

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
    
    // Icon cache
    private var iconCache: [IconCacheKey: NSImage] = [:]

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
    
    /// Invalidates the icon cache, forcing re-rendering on next update
    /// Call this when display-affecting settings change (e.g., appearance, display mode)
    func invalidateIconCache() {
        iconCache.removeAll()
    }

    // MARK: - Private Methods

    private func updateIcon(button: NSStatusBarButton) {
        let hasData = !spendingData.providersWithData.isEmpty
        let displayMode = settingsManager.menuBarDisplayMode
        let isDarkMode = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua

        // Always show icon when there's no data, otherwise respect user setting
        let shouldShowIcon = !hasData || displayMode.showsIcon

        if shouldShowIcon {
            // Quantize gauge value to reduce cache variations (0.01 precision = 0-100 range)
            let quantizedValue = Int(stateManager.animatedGaugeValue * 100)
            
            // Create cache key
            let cacheKey = IconCacheKey(
                state: stateManager.currentState,
                gaugeValue: quantizedValue,
                isDarkMode: isDarkMode,
                hasProviderIssues: spendingData.hasProviderIssues,
                connectionStatus: spendingData.hasProviderIssues ? spendingData.overallConnectionStatus : nil
            )
            
            // Check cache first
            if let cachedIcon = iconCache[cacheKey] {
                button.image = cachedIcon
                return
            }
            
            // Icon not in cache, render it
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
                nsImage.isTemplate = true
                
                // Cache the rendered image
                iconCache[cacheKey] = nsImage
                
                // Evict old entries if cache is too large
                if iconCache.count > Self.maxIconCacheSize {
                    // Clear entire cache when limit reached (simple strategy)
                    iconCache.removeAll()
                    iconCache[cacheKey] = nsImage // Re-add the current icon
                }
                
                button.image = nsImage
            } else {
                print("GaugeIcon rendering failed, using fallback")
                let fallbackImage = NSImage(systemSymbolName: "gauge", accessibilityDescription: "Vibe Meter")
                fallbackImage?.isTemplate = true
                button.image = fallbackImage
            }
        } else {
            button.image = nil
        }
    }

    private func updateTitle(button: NSStatusBarButton) {
        let hasData = !spendingData.providersWithData.isEmpty
        let displayMode = settingsManager.menuBarDisplayMode

        // First check if we should show money text at all
        guard displayMode.showsMoney else {
            // Icon only mode - ensure title is cleared
            button.title = ""
            return
        }

        // Only show money if we have data and the current state shows gauge
        if stateManager.currentState.showsGauge, hasData {
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
