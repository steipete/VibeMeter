import SwiftUI

struct SettingsView: View {
    @ObservedObject var settingsManager: SettingsManager
    @ObservedObject var dataCoordinator: RealDataCoordinator
    
    @State private var warningLimitInput: String = ""
    @State private var upperLimitInput: String = ""
    @State private var limitInputCurrencySymbol: String = "$"
    @State private var limitInputCurrencyCode: String = "USD"
    
    private var exchangeRateManager = ExchangeRateManagerImpl.shared
    
    init(settingsManager: SettingsManager, dataCoordinator: RealDataCoordinator) {
        self.settingsManager = settingsManager
        self.dataCoordinator = dataCoordinator
    }

    var body: some View {
        VStack(spacing: 0) {
            // Content using Form for native macOS appearance
            Form {
                accountSection
                
                Divider()
                
                currencySection
                
                Divider()
                
                limitsSection
                
                Divider()
                
                refreshSection
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            .background(Color(.windowBackgroundColor))
            
            // Footer with action buttons
            footerView
        }
        .background(Color(.windowBackgroundColor))
        .onAppear {
            updateLimitInputFieldsAndCurrency()
        }
        .onChange(of: dataCoordinator.exchangeRatesAvailable) { _ in
            updateLimitInputFieldsAndCurrency()
        }
        .onChange(of: dataCoordinator.currentExchangeRates) { _ in
            updateLimitInputFieldsAndCurrency()
        }
        .onChange(of: settingsManager.selectedCurrencyCode) { _ in
            updateLimitInputFieldsAndCurrency()
        }
    }
    
    private var headerView: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.title2)
                    .foregroundColor(.green)
                
                Text("Vibe Meter")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
            }
            
            Divider()
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 8)
        .background(Color(.controlBackgroundColor))
    }
    
    private var accountSection: some View {
        Section("Account") {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Status")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 8) {
                        Circle()
                            .fill(dataCoordinator.isLoggedIn ? Color.green : Color.orange)
                            .frame(width: 8, height: 8)
                        
                        Text(dataCoordinator.isLoggedIn ? "Connected" : "Not Connected")
                            .font(.body)
                    }
                }
                
                Spacer()
                
                if !dataCoordinator.isLoggedIn {
                    Button("Sign In") {
                        dataCoordinator.initiateLoginFlow()
                    }
                    .controlSize(.small)
                }
            }
            
            if dataCoordinator.isLoggedIn {
                HStack {
                    Text("Email")
                        .frame(width: 80, alignment: .leading)
                    Text(dataCoordinator.userEmail ?? "Unknown")
                        .textSelection(.enabled)
                    Spacer()
                }
            }
            
            if let errorMessage = dataCoordinator.lastErrorMessage, !errorMessage.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                        .font(.caption)
                    
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    private var currencySection: some View {
        Section("Display Currency") {
            HStack {
                Text("Currency")
                    .frame(width: 80, alignment: .leading)
                
                Picker("Currency", selection: $settingsManager.selectedCurrencyCode) {
                    ForEach(exchangeRateManager.supportedCurrencies, id: \.self) { currency in
                        Text("\(currency) (\(RealExchangeRateManager.getSymbol(for: currency)))")
                            .tag(currency)
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            if !dataCoordinator.exchangeRatesAvailable {
                HStack(spacing: 8) {
                    Image(systemName: "wifi.exclamationmark")
                        .foregroundColor(.orange)
                        .font(.caption)
                    
                    Text("Exchange rates unavailable - showing USD")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    private var limitsSection: some View {
        Section("Spending Limits") {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Warning Limit")
                        .font(.subheadline)
                    Text("Get notified when you reach this amount")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                HStack(spacing: 4) {
                    Text(limitInputCurrencySymbol)
                        .foregroundColor(.secondary)
                    TextField("0.00", text: $warningLimitInput)
                        .textFieldStyle(.roundedBorder)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                }
            }
            
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Maximum Limit")
                        .font(.subheadline)
                    Text("Strong warning when you reach this amount")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                HStack(spacing: 4) {
                    Text(limitInputCurrencySymbol)
                        .foregroundColor(.secondary)
                    TextField("0.00", text: $upperLimitInput)
                        .textFieldStyle(.roundedBorder)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                }
            }
            
            if limitInputCurrencyCode != "USD" {
                HStack(spacing: 8) {
                    Image(systemName: "info.circle")
                        .foregroundColor(.blue)
                        .font(.caption)
                    
                    Text("Limits are displayed in \(limitInputCurrencyCode) but stored in USD")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    private var refreshSection: some View {
        Section("Auto-Refresh") {
            HStack {
                Text("Refresh Interval")
                    .frame(width: 80, alignment: .leading)
                
                Picker("Refresh Interval", selection: $settingsManager.refreshIntervalMinutes) {
                    ForEach(SettingsManager.refreshIntervalOptions, id: \.self) { interval in
                        Text("\(interval) minute\(interval == 1 ? "" : "s")")
                            .tag(interval)
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
    
    private var footerView: some View {
        VStack(spacing: 0) {
            Divider()
            
            HStack {
                Button("Reset to Defaults") {
                    resetToDefaults()
                }
                .controlSize(.small)
                
                Spacer()
                
                HStack(spacing: 12) {
                    Button("Cancel") {
                        resetInputFieldsToStoredValues()
                        closeWindow()
                    }
                    .controlSize(.regular)
                    
                    Button("Save") {
                        saveSettings()
                        closeWindow()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)
                    .keyboardShortcut(.defaultAction)
                }
            }
            .padding(20)
        }
        .background(Color(.controlBackgroundColor))
    }
    
    // MARK: - Helper Methods
    
    private func updateLimitInputFieldsAndCurrency() {
        let ratesAvailable = dataCoordinator.exchangeRatesAvailable
        let targetCurrency = settingsManager.selectedCurrencyCode
        let currentRates = dataCoordinator.currentExchangeRates

        limitInputCurrencyCode = ratesAvailable && !currentRates.isEmpty ? targetCurrency : "USD"
        limitInputCurrencySymbol = RealExchangeRateManager.getSymbol(for: limitInputCurrencyCode)

        // Warning Limit
        let warningUSD = settingsManager.warningLimitUSD
        if let convertedWarning = exchangeRateManager.convert(
            warningUSD,
            from: "USD",
            to: limitInputCurrencyCode,
            rates: currentRates
        ) {
            warningLimitInput = String(format: "%.2f", convertedWarning)
        } else {
            warningLimitInput = String(format: "%.2f", warningUSD)
        }

        // Upper Limit
        let upperUSD = settingsManager.upperLimitUSD
        if let convertedUpper = exchangeRateManager.convert(
            upperUSD,
            from: "USD",
            to: limitInputCurrencyCode,
            rates: currentRates
        ) {
            upperLimitInput = String(format: "%.2f", convertedUpper)
        } else {
            upperLimitInput = String(format: "%.2f", upperUSD)
        }
    }

    private func resetInputFieldsToStoredValues() {
        updateLimitInputFieldsAndCurrency()
    }
    
    private func resetToDefaults() {
        settingsManager.selectedCurrencyCode = "USD"
        settingsManager.warningLimitUSD = 200.0
        settingsManager.upperLimitUSD = 1000.0
        settingsManager.refreshIntervalMinutes = 5
        updateLimitInputFieldsAndCurrency()
    }

    private func saveSettings() {
        let sourceCurrencyForInput = limitInputCurrencyCode
        let currentRates = dataCoordinator.currentExchangeRates

        if let warningValue = Double(warningLimitInput) {
            if let warningUSD = exchangeRateManager.convert(
                warningValue,
                from: sourceCurrencyForInput,
                to: "USD",
                rates: currentRates
            ) {
                settingsManager.warningLimitUSD = warningUSD
            } else if sourceCurrencyForInput == "USD" {
                settingsManager.warningLimitUSD = warningValue
            }
        }

        if let upperValue = Double(upperLimitInput) {
            if let upperUSD = exchangeRateManager.convert(
                upperValue,
                from: sourceCurrencyForInput,
                to: "USD",
                rates: currentRates
            ) {
                settingsManager.upperLimitUSD = upperUSD
            } else if sourceCurrencyForInput == "USD" {
                settingsManager.upperLimitUSD = upperValue
            }
        }
        
        LoggingService.info(
            "Settings saved. Warning: \(settingsManager.warningLimitUSD) USD, Upper: \(settingsManager.upperLimitUSD) USD",
            category: .settings
        )
    }

    private func closeWindow() {
        SettingsWindowController.shared.close()
    }
}

// MARK: - Preview

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        let previewSettings = SettingsManager(userDefaults: UserDefaults(suiteName: "previewSettings") ?? UserDefaults.standard)
        previewSettings.selectedCurrencyCode = "EUR"
        
        let previewCoordinator = RealDataCoordinator(
            loginManager: LoginManager(
                settingsManager: previewSettings,
                apiClient: CursorAPIClient.shared,
                keychainService: KeychainHelper.shared
            ),
            settingsManager: previewSettings,
            exchangeRateManager: ExchangeRateManagerImpl.shared,
            apiClient: CursorAPIClient.shared,
            notificationManager: NotificationManager.shared
        )
        
        return SettingsView(settingsManager: previewSettings, dataCoordinator: previewCoordinator)
            .frame(width: 480, height: 600)
    }
}