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

    @State
    private var warningLimitText: String = ""
    @State
    private var upperLimitText: String = ""
    @State
    private var showingResetAlert = false

    init(settingsManager: any SettingsManagerProtocol, userSessionData: MultiProviderUserSessionData) {
        self.settingsManager = settingsManager
        self.userSessionData = userSessionData
    }

    var body: some View {
        NavigationStack {
            Form {
                warningLimitSection
                upperLimitSection
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            .navigationTitle("Spending Limits")
            .onAppear {
                // Initialize text fields with current values
                warningLimitText = String(format: "%.2f", settingsManager.warningLimitUSD)
                upperLimitText = String(format: "%.2f", settingsManager.upperLimitUSD)
            }
        }
    }

    // MARK: - Computed Properties

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

    private func limitContent(amountUSD _: Double, convertedAmount: Double, description: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            let textBinding = getTextBinding(for: description)

            LabeledContent("Amount") {
                limitAmountField(textBinding: textBinding, description: description)
            }

            limitDescriptionSection(convertedAmount: convertedAmount, description: description)
        }
    }

    private func getTextBinding(for description: String) -> Binding<String> {
        if description.contains("critical") {
            $upperLimitText
        } else {
            $warningLimitText
        }
    }

    private func limitAmountField(textBinding: Binding<String>, description: String) -> some View {
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
                    handleTextFieldChange(newValue: newValue, textBinding: textBinding, description: description)
                }
            Text("USD")
                .foregroundStyle(.secondary)
        }
    }

    private func handleTextFieldChange(newValue: String, textBinding: Binding<String>, description: String) {
        let filtered = filterNumericInput(newValue)

        if filtered != newValue {
            textBinding.wrappedValue = filtered
        }

        updateLimitValue(from: filtered, description: description)
    }

    private func filterNumericInput(_ input: String) -> String {
        var filtered = ""
        var hasDecimal = false
        for char in input {
            if char.isNumber {
                filtered.append(char)
            } else if char == ".", !hasDecimal {
                filtered.append(char)
                hasDecimal = true
            }
        }
        return filtered
    }

    private func updateLimitValue(from text: String, description: String) {
        if let value = Double(text), value >= 0 {
            if description.contains("critical") {
                settingsManager.upperLimitUSD = value
            } else {
                settingsManager.warningLimitUSD = value
            }
        }
    }

    private func limitDescriptionSection(convertedAmount: Double, description: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if !currencyData.isUSD {
                currencyApproximation(convertedAmount: convertedAmount)
            }

            Text(description)
                .font(.caption)
                .foregroundStyle(.secondary)
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
            Text({
                let limitText = "Limits are stored in USD and will be displayed in your selected currency " +
                    "(\(currencyData.selectedCode)).\nSpending thresholds apply to Cursor."
                return limitText
            }())
            .font(.caption)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            Spacer()
        }
    }
}

#Preview {
    SpendingLimitsView(
        settingsManager: MockSettingsManager(),
        userSessionData: PreviewData.mockUserSession())
        .environment(PreviewData.mockCurrencyData())
        .frame(width: 600, height: 400)
}
