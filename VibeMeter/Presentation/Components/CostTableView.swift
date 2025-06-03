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
        VStack(alignment: .leading, spacing: 12) {
            totalSpendingSection
            
            if !spendingData.providersWithData.isEmpty {
                providerBreakdownSection
            }
            
            spendingLimitsSection
        }
    }
    
    private var totalSpendingSection: some View {
        HStack {
            Text("Total Spending")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)

            Spacer()

            if let totalSpending = currentSpendingDisplay {
                Text(totalSpending)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(.primary)
            } else {
                Text("No data")
                    .font(.system(size: 14))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(.regularMaterial))
    }
    
    private var providerBreakdownSection: some View {
        VStack(spacing: 8) {
            ForEach(spendingData.providersWithData, id: \.self) { provider in
                ProviderSpendingRowView(
                    provider: provider,
                    selectedProvider: $selectedProvider
                )
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(.regularMaterial))
    }
    
    private var spendingLimitsSection: some View {
        VStack(spacing: 8) {
            HStack {
                Label("Warning", systemImage: "exclamationmark.triangle.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(.orange)

                Spacer()

                Text("\(currencyData.selectedSymbol)\(String(format: "%.0f", convertedWarningLimit))")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.orange)
            }

            HStack {
                Label("Limit", systemImage: "xmark.octagon.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(.red)

                Spacer()

                Text("\(currencyData.selectedSymbol)\(String(format: "%.0f", convertedUpperLimit))")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.red)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 10)
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