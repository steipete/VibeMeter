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

    var body: some View {
        NavigationStack {
            Form {
                VStack(alignment: .leading, spacing: 8) {
                    Text(
                        "Spending thresholds that apply to all connected providers. Limits are stored in USD and will be displayed in your selected currency (\(currencyData.selectedCode)).")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.bottom, 10)
                }

                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        LabeledContent("Amount") {
                            HStack(spacing: 8) {
                                Text(
                                    "$\(settingsManager.warningLimitUSD.formatted(.number.precision(.fractionLength(0))))")
                                    .font(.system(.body, design: .monospaced))
                                    .foregroundStyle(.primary)
                                Text("USD")
                                    .foregroundStyle(.secondary)
                            }
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            if !currencyData.isUSD {
                                HStack {
                                    Text("Approximately")
                                    Text(
                                        "\(currencyData.selectedSymbol)\(convertedWarningLimit.formatted(.number.precision(.fractionLength(2))))")
                                        .fontWeight(.medium)
                                    Text("in \(currencyData.selectedCode)")
                                }
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }

                            Text("You'll receive a notification when spending exceeds this amount.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("Warning Limit")
                        .font(.headline)
                }

                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        LabeledContent("Amount") {
                            HStack(spacing: 8) {
                                Text(
                                    "$\(settingsManager.upperLimitUSD.formatted(.number.precision(.fractionLength(0))))")
                                    .font(.system(.body, design: .monospaced))
                                    .foregroundStyle(.primary)
                                Text("USD")
                                    .foregroundStyle(.secondary)
                            }
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            if !currencyData.isUSD {
                                HStack {
                                    Text("Approximately")
                                    Text(
                                        "\(currencyData.selectedSymbol)\(convertedUpperLimit.formatted(.number.precision(.fractionLength(2))))")
                                        .fontWeight(.medium)
                                    Text("in \(currencyData.selectedCode)")
                                }
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }

                            Text("You'll receive a critical notification when spending exceeds this amount.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("Upper Limit")
                        .font(.headline)
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
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
