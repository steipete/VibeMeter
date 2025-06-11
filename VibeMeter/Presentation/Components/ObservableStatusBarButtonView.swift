import AppKit
import SwiftUI

/// A custom NSView that leverages automatic observation tracking for the status bar button.
///
/// With NSObservationTrackingEnabled, methods like draw(_:) and updateConstraints()
/// automatically track Observable property access and invalidate when those properties change.
@MainActor
final class ObservableStatusBarButtonView: NSView {
    private let userSession: MultiProviderUserSessionData
    private let spendingData: MultiProviderSpendingData
    private let currencyData: CurrencyData
    private let settingsManager: any SettingsManagerProtocol

    init(userSession: MultiProviderUserSessionData,
         spendingData: MultiProviderSpendingData,
         currencyData: CurrencyData,
         settingsManager: any SettingsManagerProtocol) {
        self.userSession = userSession
        self.spendingData = spendingData
        self.currencyData = currencyData
        self.settingsManager = settingsManager

        super.init(frame: .zero)

        // Enable layer-backed view for better performance
        wantsLayer = true
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func updateConstraints() {
        super.updateConstraints()

        // With automatic observation tracking, accessing Observable properties here
        // will cause this method to be called again when those properties change
        _ = userSession.isLoggedInToAnyProvider
        _ = spendingData.providersWithData.count
        _ = currencyData.selectedCode

        // Trigger display update when constraints update
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        // Accessing Observable properties in draw(_:) will automatically
        // invalidate the view when these properties change
        _ = userSession.isLoggedInToAnyProvider
        _ = !spendingData.providersWithData.isEmpty
        _ = currencyData.selectedCode

        // The actual drawing is handled by the status bar button's
        // title and image properties, but we can trigger updates here
        if let button = superview as? NSStatusBarButton {
            // Force the button to update its display
            button.needsDisplay = true
        }
    }
}
