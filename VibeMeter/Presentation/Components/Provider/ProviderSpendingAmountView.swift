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
            if let spendingUSD = providerSpendingUSD {
                spendingText(for: spendingUSD)
            } else if isLoadingData {
                loadingShimmer
            } else {
                noDataPlaceholder
            }
        }
    }

    // MARK: - Helper Views

    private var providerSpendingUSD: Double? {
        spendingData.getSpendingData(for: provider)?.currentSpendingUSD
    }

    private var isLoadingData: Bool {
        guard let providerData = spendingData.getSpendingData(for: provider) else { return false }
        return providerData.connectionStatus == .connecting || providerData.connectionStatus == .syncing
    }

    private func spendingText(for spendingUSD: Double) -> some View {
        let convertedSpending = currencyData.selectedCode == "USD" ? spendingUSD :
            ExchangeRateManager.shared.convert(
                spendingUSD,
                from: "USD",
                to: currencyData.selectedCode,
                rates: currencyData.effectiveRates) ?? spendingUSD

        // Format without unnecessary decimals
        let formattedAmount: String
        if convertedSpending == 0 {
            formattedAmount = "\(currencyData.selectedSymbol)0"
        } else {
            let formatter = NumberFormatter.vibeMeterCurrency
            let amount = formatter.string(from: NSNumber(value: convertedSpending)) ?? "0"
            formattedAmount = "\(currencyData.selectedSymbol)\(amount)"
        }

        return Text(formattedAmount)
            .font(.body.weight(.semibold).monospaced())
            .foregroundStyle(.primary)
            .accessibilityLabel("Spending: \(formattedAmount)")
            .transition(.opacity.combined(with: .scale(scale: 0.95)))
            .animation(.easeOut(duration: 0.3), value: spendingUSD)
    }

    private var loadingShimmer: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(Color.secondary.opacity(0.2))
            .frame(width: 60, height: 20)
            .shimmer()
            .accessibilityLabel("Loading spending data")
    }

    private var noDataPlaceholder: some View {
        Text("--")
            .font(.body)
            .foregroundStyle(.tertiary)
            .accessibilityLabel("No spending data")
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
