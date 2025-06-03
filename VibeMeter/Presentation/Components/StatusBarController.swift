import AppKit
import SwiftUI
import Combine

@MainActor
final class StatusBarController: NSObject {
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var eventMonitor: Any?
    private var cancellables = Set<AnyCancellable>()
    private let stateManager = MenuBarStateManager()
    
    private let settingsManager: any SettingsManagerProtocol
    private let userSession: MultiProviderUserSessionData
    private let loginManager: MultiProviderLoginManager
    private let spendingData: MultiProviderSpendingData
    private let currencyData: CurrencyData
    
    init(settingsManager: any SettingsManagerProtocol,
         userSession: MultiProviderUserSessionData,
         loginManager: MultiProviderLoginManager,
         spendingData: MultiProviderSpendingData,
         currencyData: CurrencyData) {
        self.settingsManager = settingsManager
        self.userSession = userSession
        self.loginManager = loginManager
        self.spendingData = spendingData
        self.currencyData = currencyData
        super.init()
        
        setupStatusItem()
        setupPopover()
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
    
    private func setupPopover() {
        popover = NSPopover()
        popover?.contentSize = NSSize(width: 320, height: 400)
        popover?.behavior = .transient
        popover?.animates = true
        
        let contentView = VibeMeterMainView(
            settingsManager: settingsManager,
            userSessionData: userSession,
            loginManager: loginManager
        )
        .environment(spendingData)
        .environment(currencyData)
        .environment(GravatarService.shared)
        
        popover?.contentViewController = NSHostingController(rootView: contentView)
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
                let totalSpendingUSD = spendingData.totalSpendingConverted(to: "USD", rates: currencyData.currentExchangeRates)
                let gaugeValue = min(max(totalSpendingUSD / settingsManager.upperLimitUSD, 0.0), 1.0)
                stateManager.setState(.data(value: gaugeValue))
            }
        }
        
        // Update animation
        stateManager.updateAnimation()
        
        // Create and render the gauge icon based on state
        let gaugeView: some View = {
            switch stateManager.currentState {
            case .notLoggedIn:
                // Grey icon with no gauge
                return GaugeIcon(value: 0, isLoading: false, isDisabled: true)
                    .frame(width: 18, height: 18)
            case .loading:
                // Animated loading gauge
                return GaugeIcon(value: stateManager.animatedGaugeValue, isLoading: true, isDisabled: false)
                    .frame(width: 18, height: 18)
            case .data:
                // Static gauge at spending level
                return GaugeIcon(value: stateManager.animatedGaugeValue, isLoading: false, isDisabled: false)
                    .frame(width: 18, height: 18)
            }
        }()
        
        let renderer = ImageRenderer(content: gaugeView)
        renderer.scale = 2.0 // Retina display
        
        if let nsImage = renderer.nsImage {
            button.image = nsImage
            button.image?.isTemplate = true // Allow it to adapt to dark/light mode
        } else {
            // Fallback to a system image if rendering fails
            button.image = NSImage(systemSymbolName: "gauge", accessibilityDescription: "VibeMeter")
            button.image?.isTemplate = true
        }
        
        // Set the text title if enabled and we have data
        if settingsManager.showCostInMenuBar && stateManager.currentState.showsGauge && !spendingData.providersWithData.isEmpty {
            let providers = spendingData.providersWithData
            let spending: Double = if providers.count == 1,
                                      let providerData = spendingData.getSpendingData(for: providers[0]),
                                      let providerSpending = providerData.displaySpending {
                providerSpending
            } else {
                spendingData.totalSpendingConverted(
                    to: currencyData.selectedCode,
                    rates: currencyData.currentExchangeRates
                )
            }
            
            button.title = "\(currencyData.selectedSymbol)\(String(format: "%.2f", spending))"
        } else {
            button.title = ""
        }
    }
    
    @objc private func togglePopover() {
        if let popover = popover {
            if popover.isShown {
                closePopover()
            } else {
                showPopover()
            }
        }
    }
    
    private func showPopover() {
        guard let button = statusItem?.button else { return }
        
        popover?.show(relativeTo: button.bounds, of: button, preferredEdge: NSRectEdge.minY)
        
        // Monitor for clicks outside the popover to close it
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.closePopover()
        }
    }
    
    private func closePopover() {
        popover?.performClose(nil)
        
        if let eventMonitor = eventMonitor {
            NSEvent.removeMonitor(eventMonitor)
            self.eventMonitor = nil
        }
    }
    
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
                if self.stateManager.currentState.isAnimated || self.stateManager.animatedGaugeValue != self.lastRenderedValue {
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
        // Cleanup handled in closePopover method
    }
}