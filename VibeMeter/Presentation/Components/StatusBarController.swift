import AppKit
import Combine
import SwiftUI

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
                stateManager.setState(.data(value: gaugeValue))
            }
        }

        // Update animation
        stateManager.updateAnimation()

        // Create and render the gauge icon based on state
        let gaugeView: some View = switch stateManager.currentState {
        case .notLoggedIn:
            // Grey icon with no gauge
            GaugeIcon(value: 0, isLoading: false, isDisabled: true)
                .frame(width: 18, height: 18)
        case .loading:
            // Animated loading gauge
            GaugeIcon(value: stateManager.animatedGaugeValue, isLoading: true, isDisabled: false)
                .frame(width: 18, height: 18)
        case .data:
            // Static gauge at spending level
            GaugeIcon(value: stateManager.animatedGaugeValue, isLoading: false, isDisabled: false)
                .frame(width: 18, height: 18)
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

            button.title = "\(currencyData.selectedSymbol)\(String(format: "%.2f", spending))"
        } else {
            button.title = ""
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

    // Methods removed - handled by CustomMenuWindow

    private func observeDataChanges() {
        // Observe settings changes
        NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
            .sink { [weak self] _ in
                self?.updateStatusItemDisplay()
            }
            .store(in: &cancellables)

        // Update display with appropriate frequency based on state
        Timer.publish(every: 0.03, on: .main, in: .common) // 30ms for smooth animations
            .autoconnect()
            .sink { [weak self] _ in
                guard let self else { return }

                // Only update frequently if animating or transitioning
                if self.stateManager.currentState.isAnimated || self.stateManager.animatedGaugeValue != self
                    .lastRenderedValue {
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
