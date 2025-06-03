import AppKit
import SwiftUI
import Combine

@MainActor
final class StatusBarController: NSObject {
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var eventMonitor: Any?
    private var cancellables = Set<AnyCancellable>()
    
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
        
        popover?.contentViewController = NSHostingController(rootView: contentView)
    }
    
    func updateStatusItemDisplay() {
        guard let button = statusItem?.button else { return }
        
        // Calculate total spending in USD for gauge calculation
        let providers = spendingData.providersWithData
        let totalSpendingUSD: Double = if !providers.isEmpty {
            spendingData.totalSpendingConverted(to: "USD", rates: currencyData.currentExchangeRates)
        } else {
            0.0
        }
        
        // Calculate gauge value (0-1) based on upper limit
        let gaugeValue = min(max(totalSpendingUSD / settingsManager.upperLimitUSD, 0.0), 1.0)
        
        // Create and render the gauge icon
        let gaugeIcon = GaugeIcon(value: gaugeValue)
        let renderer = ImageRenderer(content: gaugeIcon)
        renderer.scale = 2.0 // Retina display
        
        if let nsImage = renderer.nsImage {
            button.image = nsImage
            button.image?.isTemplate = true // Allow it to adapt to dark/light mode
        }
        
        // Set the text title if enabled
        if settingsManager.showCostInMenuBar && !providers.isEmpty {
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
        
        // Update display whenever data changes
        // Note: In a production app, you'd want proper Combine publishers on your data models
        Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.updateStatusItemDisplay()
            }
            .store(in: &cancellables)
    }
    
    deinit {
        // Cleanup handled in closePopover method
    }
}