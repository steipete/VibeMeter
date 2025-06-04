import SwiftUI

/// Displays the spending amount for a provider with currency conversion and loading states.
///
/// This view handles the display of provider spending amounts, including currency conversion,
/// loading shimmer effects, and proper accessibility labeling.
struct ProviderSpendingAmountView: View {
    let provider: ServiceProvider
    let spendingData: MultiProviderSpendingData
    let currencyData: CurrencyData

    var body: some View {
        Group {
            if let providerData = spendingData.getSpendingData(for: provider),
               let spendingUSD = providerData.currentSpendingUSD {
                // Convert using current rates for consistency with total
                let convertedSpending = currencyData.selectedCode == "USD" ? spendingUSD :
                    ExchangeRateManager.shared.convert(
                        spendingUSD,
                        from: "USD",
                        to: currencyData.selectedCode,
                        rates: currencyData.effectiveRates) ?? spendingUSD

                Text(
                    "\(currencyData.selectedSymbol)\(convertedSpending.formatted(.number.precision(.fractionLength(2))))")
                    .font(.body.weight(.semibold).monospaced())
                    .foregroundStyle(.primary)
                    .accessibilityLabel(
                        "Spending: \(currencyData.selectedSymbol)\(convertedSpending.formatted(.number.precision(.fractionLength(2))))")
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    .animation(.easeOut(duration: 0.3), value: spendingUSD)
            } else {
                // Check if we're in a loading state vs no data
                if let providerData = spendingData.getSpendingData(for: provider),
                   providerData.connectionStatus == .connecting || providerData.connectionStatus == .syncing {
                    // Show shimmer while loading
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.secondary.opacity(0.2))
                        .frame(width: 60, height: 20)
                        .shimmer()
                        .accessibilityLabel("Loading spending data")
                } else {
                    // Show placeholder when no data available
                    Text("--")
                        .font(.body)
                        .foregroundStyle(.tertiary)
                        .accessibilityLabel("No spending data")
                }
            }
        }
    }
}

// MARK: - Preview

#Preview("With Data") {
    let spendingData = MultiProviderSpendingData()
    let currencyData = CurrencyData()

    // Add sample data
    spendingData.updateSpending(
        for: .cursor,
        from: ProviderMonthlyInvoice(
            items: [
                ProviderInvoiceItem(cents: 2497, description: "Pro Usage", provider: .cursor),
            ],
            pricingDescription: nil,
            provider: .cursor,
            month: 5,
            year: 2025),
        rates: [:],
        targetCurrency: "USD")

    return ProviderSpendingAmountView(
        provider: .cursor,
        spendingData: spendingData,
        currencyData: currencyData)
        .padding()
        .background(Color(NSColor.windowBackgroundColor))
}

#Preview("Loading") {
    let spendingData = MultiProviderSpendingData()
    let currencyData = CurrencyData()

    return ProviderSpendingAmountView(
        provider: .cursor,
        spendingData: spendingData,
        currencyData: currencyData)
        .padding()
        .background(Color(NSColor.windowBackgroundColor))
}
