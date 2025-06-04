import SwiftUI

/// Settings view for configuring spending notification thresholds.
///
/// This view allows users to edit their warning and upper spending limits
/// with currency conversion display. It shows both USD amounts (stored values)
/// and converted amounts in the user's selected currency for better understanding.
struct SpendingLimitsView: View {
    let settingsManager: any SettingsManagerProtocol
    let userSessionData: MultiProviderUserSessionData

    @Environment(CurrencyData.self)
    private var currencyData
    
    @State private var warningLimitText: String = ""
    @State private var upperLimitText: String = ""
    @State private var showingResetAlert = false

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
                description: "You'll receive a notification when spending exceeds this amount.")
        } header: {
            Text("Warning Limit").font(.headline)
        }
    }

    private var upperLimitSection: some View {
        Section {
            limitContent(
                amountUSD: settingsManager.upperLimitUSD,
                convertedAmount: convertedUpperLimit,
                description: "You'll receive a critical notification when spending exceeds this amount.")
        } header: {
            Text("Upper Limit").font(.headline)
        } footer: {
            footerContent
        }
    }

    private func limitContent(amountUSD: Double, convertedAmount: Double, description: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Determine which text binding to use
            let textBinding: Binding<String> = {
                if description.contains("critical") {
                    return $upperLimitText
                } else {
                    return $warningLimitText
                }
            }()
            
            LabeledContent("Amount") {
                HStack(spacing: 8) {
                    Text("$")
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.secondary)
                    TextField("0", text: textBinding)
                        .textFieldStyle(.plain)
                        .font(.system(.body, design: .monospaced))
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                        .onChange(of: textBinding.wrappedValue) { _, newValue in
                            // Allow only numbers and one decimal point
                            var filtered = ""
                            var hasDecimal = false
                            for char in newValue {
                                if char.isNumber {
                                    filtered.append(char)
                                } else if char == "." && !hasDecimal {
                                    filtered.append(char)
                                    hasDecimal = true
                                }
                            }
                            
                            if filtered != newValue {
                                textBinding.wrappedValue = filtered
                            }
                            
                            // Update the actual limit value
                            if let value = Double(filtered), value >= 0 {
                                if description.contains("critical") {
                                    settingsManager.upperLimitUSD = value
                                } else {
                                    settingsManager.warningLimitUSD = value
                                }
                            }
                        }
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
            Text(
                "Limits are stored in USD and will be displayed in your selected currency (\(currencyData.selectedCode)).\nSpending thresholds apply to Cursor.")
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
                    
                    Section {
                        Button("Reset to Defaults", action: {
                            showingResetAlert = true
                        })
                        .foregroundColor(.blue)
                    }
                }
                .formStyle(.grouped)
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Spending Limits")
            .onAppear {
                // Initialize with proper decimal formatting
                if settingsManager.warningLimitUSD.truncatingRemainder(dividingBy: 1) == 0 {
                    warningLimitText = String(format: "%.0f", settingsManager.warningLimitUSD)
                } else {
                    warningLimitText = String(format: "%.2f", settingsManager.warningLimitUSD)
                }
                
                if settingsManager.upperLimitUSD.truncatingRemainder(dividingBy: 1) == 0 {
                    upperLimitText = String(format: "%.0f", settingsManager.upperLimitUSD)
                } else {
                    upperLimitText = String(format: "%.2f", settingsManager.upperLimitUSD)
                }
            }
            .alert("Reset Spending Limits", isPresented: $showingResetAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Reset", role: .destructive) {
                    settingsManager.warningLimitUSD = 200.0
                    settingsManager.upperLimitUSD = 1000.0
                    warningLimitText = "200"
                    upperLimitText = "1000"
                }
            } message: {
                Text("Reset spending limits to default values?\n\nWarning limit: $200\nUpper limit: $1000")
            }
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
