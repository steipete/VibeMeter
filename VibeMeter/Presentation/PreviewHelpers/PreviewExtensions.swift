import SwiftUI

// MARK: - Preview Frame Extensions

public extension View {
    /// Applies standard menu bar frame sizing.
    ///
    /// - Returns: View with 250pt width frame
    func menuBarFrame() -> some View {
        frame(width: 250)
    }

    /// Applies standard settings window frame sizing.
    ///
    /// - Returns: View with 620x500pt frame
    func settingsFrame() -> some View {
        frame(width: 620, height: 500)
    }

    /// Applies standard content view frame sizing.
    ///
    /// - Returns: View with 300x400pt frame
    func contentFrame() -> some View {
        frame(width: 300, height: 400)
    }

    /// Applies standard component preview frame sizing.
    ///
    /// - Parameters:
    ///   - width: Frame width (default: 320)
    ///   - height: Frame height (optional)
    /// - Returns: View with specified frame
    func componentFrame(width: CGFloat = 320, height: CGFloat? = nil) -> some View {
        if let height {
            return frame(width: width, height: height)
        } else {
            return frame(width: width)
        }
    }

    /// Applies standard preview background styling.
    ///
    /// Uses the system window background color appropriate for macOS.
    /// - Returns: View with window background
    func previewBackground() -> some View {
        background(Color(NSColor.windowBackgroundColor))
    }

    /// Applies material background for menu-like previews.
    ///
    /// - Returns: View with thick material background
    func materialBackground() -> some View {
        background(.thickMaterial)
    }
}

// MARK: - Preview Environment Extensions

public extension View {
    /// Applies standard preview environment with empty data.
    ///
    /// Includes empty MultiProviderSpendingData and default CurrencyData.
    /// - Returns: View with standard environment
    func standardPreviewEnvironment() -> some View {
        environment(PreviewData.emptySpendingData())
            .environment(PreviewData.mockCurrencyData())
    }

    /// Applies preview environment with spending data.
    ///
    /// - Parameter spendingData: The spending data to inject
    /// - Returns: View with spending data environment
    func withSpendingEnvironment(_ spendingData: MultiProviderSpendingData) -> some View {
        environment(spendingData)
            .environment(PreviewData.mockCurrencyData())
    }

    /// Applies preview environment with currency data.
    ///
    /// - Parameter currencyData: The currency data to inject
    /// - Returns: View with currency data environment
    func withCurrencyEnvironment(_ currencyData: CurrencyData) -> some View {
        environment(PreviewData.emptySpendingData())
            .environment(currencyData)
    }

    /// Applies complete preview environment with both spending and currency data.
    ///
    /// - Parameters:
    ///   - spendingData: The spending data to inject
    ///   - currencyData: The currency data to inject
    /// - Returns: View with complete environment
    func withCompleteEnvironment(
        spending: MultiProviderSpendingData,
        currency: CurrencyData) -> some View {
        environment(spending)
            .environment(currency)
    }
}

// MARK: - Preview Layout Helpers

public extension View {
    /// Wraps view in a VStack with standard spacing for multi-component previews.
    ///
    /// - Parameter spacing: Spacing between items (default: 16)
    /// - Returns: View wrapped in VStack
    func previewStack(spacing: CGFloat = 16) -> some View {
        VStack(spacing: spacing) {
            self
        }
        .padding()
    }

    /// Wraps view in an HStack with standard spacing for side-by-side previews.
    ///
    /// - Parameter spacing: Spacing between items (default: 20)
    /// - Returns: View wrapped in HStack
    func previewRow(spacing: CGFloat = 20) -> some View {
        HStack(spacing: spacing) {
            self
        }
        .padding()
    }
}
