import SwiftUI

/// Settings view for configuring spending notification thresholds.
///
/// This view allows users to review their warning and upper spending limits
/// with currency conversion display. It shows both USD amounts (stored values)
/// and converted amounts in the user's selected currency for better understanding.
struct SpendingLimitsView: View {
    let settingsManager: any SettingsManagerProtocol
    let userSessionData: MultiProviderUserSessionData

    @Environment(CurrencyData.self)
    private var currencyData

    init(settingsManager: any SettingsManagerProtocol, userSessionData: MultiProviderUserSessionData) {
        self.settingsManager = settingsManager
        self.userSessionData = userSessionData
    }

    // MARK: - Helper Views
    
    private var warningLimitSection: some View {
        Section {
            limitContent(
                amountUSD: settingsManager.warningLimitUSD,
                convertedAmount: convertedWarningLimit,
                description: "You'll receive a notification when spending exceeds this amount."
            )
        } header: {
            Text("Warning Limit").font(.headline)
        }
    }
    
    private var upperLimitSection: some View {
        Section {
            limitContent(
                amountUSD: settingsManager.upperLimitUSD,
                convertedAmount: convertedUpperLimit,
                description: "You'll receive a critical notification when spending exceeds this amount."
            )
        } header: {
            Text("Upper Limit").font(.headline)
        } footer: {
            footerContent
        }
    }
    
    private func limitContent(amountUSD: Double, convertedAmount: Double, description: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            LabeledContent("Amount") {
                HStack(spacing: 8) {
                    Text("$\(amountUSD.formatted(.number.precision(.fractionLength(0))))")
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.primary)
                    Text("USD")
                        .foregroundStyle(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                if !currencyData.isUSD {
                    currencyApproximation(convertedAmount: convertedAmount)
                }

                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    private func currencyApproximation(convertedAmount: Double) -> some View {
        HStack {
            Text("Approximately")
            Text("\(currencyData.selectedSymbol)\(convertedAmount.formatted(.number.precision(.fractionLength(2))))")
                .fontWeight(.medium)
            Text("in \(currencyData.selectedCode)")
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }
    
    private var footerContent: some View {
        HStack {
            Spacer()
            Text("Limits are stored in USD and will be displayed in your selected currency (\(currencyData.selectedCode)).\nSpending thresholds apply to Cursor.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Form {
                    warningLimitSection
                    upperLimitSection
                }
                .formStyle(.grouped)
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Spending Limits")
        }
    }

    private var convertedWarningLimit: Double {
        currencyData
            .convertAmount(settingsManager.warningLimitUSD, from: "USD", to: currencyData.selectedCode) ??
            settingsManager.warningLimitUSD
    }

    private var convertedUpperLimit: Double {
        currencyData
            .convertAmount(settingsManager.upperLimitUSD, from: "USD", to: currencyData.selectedCode) ??
            settingsManager.upperLimitUSD
    }
}

// MARK: - Preview

#Preview("Spending Limits - USD") {
    SpendingLimitsView(
        settingsManager: MockSettingsManager(),
        userSessionData: MultiProviderUserSessionData())
        .environment(CurrencyData())
        .frame(width: 620, height: 500)
}

@MainActor
private func makeCurrencyData() -> CurrencyData {
    let currencyData = CurrencyData()
    currencyData.updateSelectedCurrency("EUR")
    currencyData.updateExchangeRates(["EUR": 0.92])
    return currencyData
}

#Preview("Spending Limits - EUR") {
    SpendingLimitsView(
        settingsManager: MockSettingsManager.withLimits(warning: 150, upper: 800),
        userSessionData: MultiProviderUserSessionData())
        .environment(makeCurrencyData())
        .frame(width: 620, height: 500)
}
