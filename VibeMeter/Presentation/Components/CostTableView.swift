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
        VStack(alignment: .leading, spacing: 16) {
            totalSpendingSection

            if !spendingData.providersWithData.isEmpty {
                providerBreakdownSection
            }

            spendingLimitsSection
        }
    }

    private var totalSpendingSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Total Spending")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)

            HStack(alignment: .firstTextBaseline) {
                if let totalSpending = currentSpendingDisplay {
                    Text(totalSpending)
                        .font(.system(size: 28, weight: .semibold, design: .rounded))
                        .foregroundStyle(.primary)
                } else {
                    Text("No data")
                        .font(.system(size: 16))
                        .foregroundStyle(.tertiary)
                }

                Spacer()
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.regularMaterial))
    }

    private var providerBreakdownSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Breakdown")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 20)

            VStack(spacing: 2) {
                ForEach(spendingData.providersWithData, id: \.self) { provider in
                    ProviderSpendingRowView(
                        provider: provider,
                        selectedProvider: $selectedProvider)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.regularMaterial))
    }

    private var spendingLimitsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Limits")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 20)
            
            VStack(spacing: 12) {
                HStack {
                    Label("Warning", systemImage: "exclamationmark.triangle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.orange)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Text("\(currencyData.selectedSymbol)\(String(format: "%.0f", convertedWarningLimit))")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.orange)
                }

                HStack {
                    Label("Limit", systemImage: "xmark.octagon.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Text("\(currencyData.selectedSymbol)\(String(format: "%.0f", convertedUpperLimit))")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.red)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 8)
        }
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.regularMaterial))
    }

    // MARK: - Helper Properties

    private var currentSpendingDisplay: String? {
        let providers = spendingData.providersWithData
        guard !providers.isEmpty else { return nil }

        let totalSpending = spendingData.totalSpendingConverted(
            to: currencyData.selectedCode,
            rates: currencyData.effectiveRates)

        return "\(currencyData.selectedSymbol)\(String(format: "%.2f", totalSpending))"
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
