import AppKit
import SwiftUI

/// A special NSView that leverages SwiftUI's automatic Observable tracking to update the status bar.
///
/// This view embeds a SwiftUI view that automatically observes changes to @Observable objects
/// and triggers status bar updates when those objects change.
final class ObservableStatusBarDisplayView: NSView {
    private let hostingView: NSHostingView<ObservableTrackingView>
    
    init(statusBarButton: NSStatusBarButton,
         displayManager: StatusBarDisplayManager,
         stateManager: MenuBarStateManager,
         userSession: MultiProviderUserSessionData,
         spendingData: MultiProviderSpendingData,
         currencyData: CurrencyData,
         settingsManager: any SettingsManagerProtocol,
         orchestrator: MultiProviderDataOrchestrator) {
        
        // Create the SwiftUI tracking view
        let trackingView = ObservableTrackingView(
            displayManager: displayManager,
            button: statusBarButton,
            spendingData: spendingData,
            currencyData: currencyData,
            settingsManager: settingsManager,
            userSession: userSession,
            stateManager: stateManager,
            orchestrator: orchestrator)
        
        // Wrap it in a hosting view
        self.hostingView = NSHostingView(rootView: trackingView)
        
        super.init(frame: .zero)
        
        // Add hosting view as subview
        addSubview(hostingView)
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hostingView.topAnchor.constraint(equalTo: topAnchor),
            hostingView.leadingAnchor.constraint(equalTo: leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: trailingAnchor),
            hostingView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    /// Force display updates for the embedded SwiftUI view
    func setNeedsDisplayAndLayout() {
        hostingView.needsDisplay = true
        hostingView.needsLayout = true
    }
}

/// The actual SwiftUI view that performs the Observable tracking
private struct ObservableTrackingView: View {
    let displayManager: StatusBarDisplayManager
    let button: NSStatusBarButton
    let spendingData: MultiProviderSpendingData
    let currencyData: CurrencyData
    let settingsManager: any SettingsManagerProtocol
    let userSession: MultiProviderUserSessionData
    let stateManager: MenuBarStateManager
    let orchestrator: MultiProviderDataOrchestrator
    
    var body: some View {
        // Empty view that just observes changes
        Color.clear
            .frame(width: 0, height: 0)
            .onChange(of: spendingData.totalSpendingUSD) { _, _ in
                displayManager.updateDisplay(for: button)
            }
            .onChange(of: currencyData.selectedCode) { _, _ in
                displayManager.updateDisplay(for: button)
            }
            .onChange(of: currencyData.selectedSymbol) { _, _ in
                displayManager.updateDisplay(for: button)
            }
            .onChange(of: settingsManager.menuBarDisplayMode) { _, _ in
                displayManager.invalidateIconCache()
                displayManager.updateDisplay(for: button)
            }
            .onChange(of: userSession.isLoggedInToAnyProvider) { _, _ in
                displayManager.updateDisplay(for: button)
            }
            .onChange(of: stateManager.currentState) { _, _ in
                displayManager.updateDisplay(for: button)
            }
            .onChange(of: stateManager.animatedGaugeValue) { _, _ in
                displayManager.updateDisplay(for: button)
            }
            .onChange(of: stateManager.animatedCostValue) { _, _ in
                displayManager.updateDisplay(for: button)
            }
            .onChange(of: orchestrator.isRefreshing) { _, _ in
                displayManager.updateDisplay(for: button)
            }
    }
}