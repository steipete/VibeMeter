import SwiftUI

struct CostTableView: View {
    let settingsManager: any SettingsManagerProtocol

    @Environment(MultiProviderSpendingData.self)
    private var spendingData
    @Environment(CurrencyData.self)
    private var currencyData

    @State
    private var selectedProvider: ServiceProvider?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            totalSpendingSection

            if !spendingData.providersWithData.isEmpty {
                providerBreakdownSection
            }

            spendingLimitsSection
        }
    }

    private var totalSpendingSection: some View {
        HStack(alignment: .center) {
            Text("Total Spending")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
            
            Spacer()
            
            if let totalSpending = currentSpendingDisplay {
                Text(totalSpending)
                    .font(.system(size: 24, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
            } else {
                Text("No data")
                    .font(.system(size: 14))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(.thickMaterial))
    }

    private var providerBreakdownSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Breakdown")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 14)

            VStack(spacing: 1) {
                ForEach(spendingData.providersWithData, id: \.self) { provider in
                    ProviderSpendingRowView(
                        provider: provider,
                        selectedProvider: $selectedProvider)
                }
            }
            .padding(.horizontal, 6)
            .padding(.bottom, 4)
        }
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(.thickMaterial))
    }

    private var spendingLimitsSection: some View {
        HStack(alignment: .center) {
            Text("Limits")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
            
            Spacer()
            
            Text("\(currencyData.selectedSymbol)\(convertedWarningLimit.formatted(.number.precision(.fractionLength(0))))")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.orange)
            
            Text("•")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)
            
            Text("\(currencyData.selectedSymbol)\(convertedUpperLimit.formatted(.number.precision(.fractionLength(0))))")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.red)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(.thickMaterial))
    }

    // MARK: - Helper Properties

    private var currentSpendingDisplay: String? {
        let providers = spendingData.providersWithData
        guard !providers.isEmpty else { return nil }

        let totalSpending = spendingData.totalSpendingConverted(
            to: currencyData.selectedCode,
            rates: currencyData.effectiveRates)

        return "\(currencyData.selectedSymbol)\(totalSpending.formatted(.number.precision(.fractionLength(2))))"
    }

    private var convertedWarningLimit: Double {
        currencyData.convertAmount(
            settingsManager.warningLimitUSD,
            from: "USD",
            to: currencyData.selectedCode) ?? settingsManager.warningLimitUSD
    }

    private var convertedUpperLimit: Double {
        currencyData.convertAmount(
            settingsManager.upperLimitUSD,
            from: "USD",
            to: currencyData.selectedCode) ?? settingsManager.upperLimitUSD
    }
}
