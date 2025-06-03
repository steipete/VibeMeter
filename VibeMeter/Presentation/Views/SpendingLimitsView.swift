import SwiftUI

struct SpendingLimitsView: View {
    let settingsManager: any SettingsManagerProtocol
    let userSessionData: MultiProviderUserSessionData

    @Environment(CurrencyData.self)
    private var currencyData

    init(settingsManager: any SettingsManagerProtocol, userSessionData: MultiProviderUserSessionData) {
        self.settingsManager = settingsManager
        self.userSessionData = userSessionData
    }

    var body: some View {
        Form {
            VStack(alignment: .leading, spacing: 8) {
                Text("Spending Limits")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .padding(.top, 10)
                    .padding(.horizontal, 10)

                Text(
                    "Set spending thresholds that apply to all connected providers. Limits are stored in USD and will be displayed in your selected currency (\(currencyData.selectedCode)).")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.bottom, 10)
            }

            Section {
                LabeledContent("Amount") {
                    HStack(spacing: 8) {
                        Text("$\(String(format: "%.0f", settingsManager.warningLimitUSD))")
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(.primary)
                        Text("USD")
                            .foregroundStyle(.secondary)
                    }
                }

                if !currencyData.isUSD {
                    HStack {
                        Text("Approximately")
                        Text("\(currencyData.selectedSymbol)\(String(format: "%.2f", convertedWarningLimit))")
                            .fontWeight(.medium)
                        Text("in \(currencyData.selectedCode)")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                Text("You'll receive a notification when spending exceeds this amount.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Text("Warning Limit")
                    .font(.headline)
            }

            Section {
                LabeledContent("Amount") {
                    HStack(spacing: 8) {
                        Text("$\(String(format: "%.0f", settingsManager.upperLimitUSD))")
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(.primary)
                        Text("USD")
                            .foregroundStyle(.secondary)
                    }
                }

                if !currencyData.isUSD {
                    HStack {
                        Text("Approximately")
                        Text("\(currencyData.selectedSymbol)\(String(format: "%.2f", convertedUpperLimit))")
                            .fontWeight(.medium)
                        Text("in \(currencyData.selectedCode)")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                Text("You'll receive a critical notification when spending exceeds this amount.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Text("Upper Limit")
                    .font(.headline)
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
    }

    private var convertedWarningLimit: Double {
        currencyData
            .convertAmount(settingsManager.warningLimitUSD, from: "USD", to: currencyData.selectedCode) ??
            settingsManager.warningLimitUSD
    }

    private var convertedUpperLimit: Double {
        currencyData
            .convertAmount(settingsManager.upperLimitUSD, from: "USD", to: currencyData.selectedCode) ?? settingsManager
            .upperLimitUSD
    }
}
