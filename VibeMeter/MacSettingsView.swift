import SwiftUI

struct MacSettingsView: View {
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
        TabView {
            GeneralSettingsView(
                settingsManager: settingsManager,
                dataCoordinator: dataCoordinator
            )
            .tabItem {
                Label("General", systemImage: "gear")
            }

            AccountSettingsView(dataCoordinator: dataCoordinator)
                .tabItem {
                    Label("Account", systemImage: "person.circle")
                }

            LimitsSettingsView(
                settingsManager: settingsManager,
                dataCoordinator: dataCoordinator,
                warningLimitInput: $warningLimitInput,
                upperLimitInput: $upperLimitInput,
                limitInputCurrencySymbol: $limitInputCurrencySymbol,
                limitInputCurrencyCode: $limitInputCurrencyCode
            )
            .tabItem {
                Label("Limits", systemImage: "exclamationmark.triangle")
            }
            
            AdvancedSettingsView()
                .tabItem {
                    Label("Advanced", systemImage: "gearshape.2")
                }
            
            AboutView()
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
        }
        .frame(width: 600, height: 500)
        .onAppear {
            updateLimitInputFieldsAndCurrency()
        }
        .onChange(of: dataCoordinator.exchangeRatesAvailable) {
            updateLimitInputFieldsAndCurrency()
        }
        .onChange(of: dataCoordinator.currentExchangeRates) {
            updateLimitInputFieldsAndCurrency()
        }
        .onChange(of: settingsManager.selectedCurrencyCode) {
            updateLimitInputFieldsAndCurrency()
        }
        .onChange(of: warningLimitInput) {
            saveLimits()
        }
        .onChange(of: upperLimitInput) {
            saveLimits()
        }
    }

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

    private func saveLimits() {
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
    }
}

// MARK: - General Settings Tab

struct GeneralSettingsView: View {
    @ObservedObject var settingsManager: SettingsManager
    @ObservedObject var dataCoordinator: RealDataCoordinator
    @State private var launchAtLogin: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Startup section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Startup")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        Toggle("Launch at Login", isOn: $launchAtLogin)
                            .toggleStyle(.checkbox)
                            .font(.system(size: 13))
                            .onChange(of: launchAtLogin) { _, newValue in
                                settingsManager.launchAtLoginEnabled = newValue
                            }
                    }
                    
                    // Display Preferences section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Display Preferences")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        VStack(spacing: 0) {
                            // Display Currency Row
                            SettingsRow {
                                Text("Display Currency")
                                    .font(.system(size: 13))
                                    .foregroundColor(.primary)
                                
                                Spacer()
                                
                                Picker("", selection: $settingsManager.selectedCurrencyCode) {
                                    ForEach(ExchangeRateManagerImpl.shared.supportedCurrencies, id: \.self) { currency in
                                        Text("\(currency) (\(RealExchangeRateManager.getSymbol(for: currency)))")
                                            .tag(currency)
                                    }
                                }
                                .pickerStyle(.menu)
                                .labelsHidden()
                                .fixedSize()
                            }
                            .padding(.top, 1)
                            
                            Divider()
                                .opacity(0.5)
                            
                            // Refresh Interval Row
                            SettingsRow {
                                Text("Refresh Interval")
                                    .font(.system(size: 13))
                                    .foregroundColor(.primary)
                                
                                Spacer()
                                
                                Picker("", selection: $settingsManager.refreshIntervalMinutes) {
                                    ForEach(SettingsManager.refreshIntervalOptions, id: \.self) { interval in
                                        Text("\(interval) minute\(interval == 1 ? "" : "s")")
                                            .tag(interval)
                                    }
                                }
                                .pickerStyle(.menu)
                                .labelsHidden()
                                .fixedSize()
                            }
                            .padding(.bottom, 1)
                        }
                        .background(.regularMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .strokeBorder(Color.white.opacity(0.1), lineWidth: 0.5)
                        )
                    }
                    
                    Spacer(minLength: 20)
                }
                .padding(32)
            }
        }
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear {
            launchAtLogin = settingsManager.launchAtLoginEnabled
        }
    }
}

// MARK: - Account Settings Tab

struct AccountSettingsView: View {
    @ObservedObject var dataCoordinator: RealDataCoordinator

    var body: some View {
        VStack(spacing: 25) {
            // Account Status
            HStack(alignment: .top) {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 48))
                    .foregroundColor(dataCoordinator.isLoggedIn ? .green : Color(NSColor.tertiaryLabelColor))
                    .symbolRenderingMode(.hierarchical)

                VStack(alignment: .leading, spacing: 6) {
                    Text(dataCoordinator.isLoggedIn ? "Connected" : "Not Connected")
                        .font(.system(size: 16, weight: .medium))

                    if dataCoordinator.isLoggedIn {
                        Text(dataCoordinator.userEmail ?? "Unknown email")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)

                        if let teamName = dataCoordinator.teamName {
                            Text("Team: \(teamName)")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Spacer()

                if dataCoordinator.isLoggedIn {
                    Button("Log Out") {
                        dataCoordinator.userDidRequestLogout()
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.red)
                } else {
                    Button("Log In") {
                        dataCoordinator.initiateLoginFlow()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding(24)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(Color.white.opacity(0.1), lineWidth: 0.5)
            )

            if let errorMessage = dataCoordinator.lastErrorMessage, !errorMessage.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.orange)
                    Text(errorMessage)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.orange.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 4))
            }

            Spacer()
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.windowBackgroundColor))
    }
}

// MARK: - Limits Settings Tab

struct LimitsSettingsView: View {
    @ObservedObject var settingsManager: SettingsManager
    @ObservedObject var dataCoordinator: RealDataCoordinator
    @Binding var warningLimitInput: String
    @Binding var upperLimitInput: String
    @Binding var limitInputCurrencySymbol: String
    @Binding var limitInputCurrencyCode: String

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Spending Limits section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Spending Limits")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        VStack(spacing: 0) {
                            // Warning Limit Row
                            SettingsRow {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("Warning Limit")
                                        .font(.system(size: 13))
                                        .foregroundColor(.primary)
                                    Text("Get notified when spending reaches this amount")
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                HStack(spacing: 4) {
                                    Text(limitInputCurrencySymbol)
                                        .font(.system(size: 13))
                                        .foregroundColor(.secondary)
                                    TextField("0.00", text: $warningLimitInput)
                                        .textFieldStyle(.plain)
                                        .frame(width: 80)
                                        .multilineTextAlignment(.trailing)
                                        .font(.system(size: 13))
                                }
                            }
                            .padding(.vertical, 4)
                            .padding(.top, 2)
                            
                            Divider()
                                .opacity(0.5)
                            
                            // Maximum Limit Row
                            SettingsRow {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("Maximum Limit")
                                        .font(.system(size: 13))
                                        .foregroundColor(.primary)
                                    Text("Receive urgent alerts at this spending level")
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                HStack(spacing: 4) {
                                    Text(limitInputCurrencySymbol)
                                        .font(.system(size: 13))
                                        .foregroundColor(.secondary)
                                    TextField("0.00", text: $upperLimitInput)
                                        .textFieldStyle(.plain)
                                        .frame(width: 80)
                                        .multilineTextAlignment(.trailing)
                                        .font(.system(size: 13))
                                }
                            }
                            .padding(.vertical, 4)
                            .padding(.bottom, 2)
                        }
                        .background(.regularMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .strokeBorder(Color.white.opacity(0.1), lineWidth: 0.5)
                        )
                    }
                    
                    // Info messages
                    VStack(alignment: .leading, spacing: 8) {
                        if limitInputCurrencyCode != "USD" {
                            HStack(spacing: 6) {
                                Image(systemName: "info.circle.fill")
                                    .font(.system(size: 11))
                                    .foregroundColor(.accentColor)
                                Text("Amounts are displayed in \(limitInputCurrencyCode) but stored in USD")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        if !dataCoordinator.exchangeRatesAvailable {
                            HStack(spacing: 6) {
                                Image(systemName: "wifi.exclamationmark")
                                    .font(.system(size: 11))
                                    .foregroundColor(.orange)
                                Text("Exchange rates unavailable — displaying USD amounts")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    // Reset button
                    Button(action: {
                        settingsManager.warningLimitUSD = 200.0
                        settingsManager.upperLimitUSD = 1000.0
                    }) {
                        Text("Reset to Defaults")
                            .font(.system(size: 13))
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.accentColor)
                    
                    Spacer(minLength: 20)
                }
                .padding(32)
            }
        }
        .background(Color(NSColor.windowBackgroundColor))
    }
}

// MARK: - Advanced Settings Tab

struct AdvancedSettingsView: View {
    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Updates section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Software Updates")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        VStack(spacing: 0) {
                            SettingsRow {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("Check for Updates")
                                        .font(.system(size: 13))
                                        .foregroundColor(.primary)
                                    Text("Check for new versions of VibeMeter")
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                Button(action: {
                                    if let appDelegate = NSApplication.shared.delegate as? AppDelegate,
                                       let sparkleManager = appDelegate.sparkleUpdaterManager
                                    {
                                        sparkleManager.updaterController.checkForUpdates(nil)
                                    }
                                }) {
                                    Text("Check Now")
                                        .font(.system(size: 12))
                                }
                                .buttonStyle(.bordered)
                                #if DEBUG
                                .disabled(true)
                                #endif
                            }
                        }
                        .background(.regularMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .strokeBorder(Color.white.opacity(0.1), lineWidth: 0.5)
                        )
                    }
                    
                    Spacer(minLength: 20)
                }
                .padding(32)
            }
        }
        .background(Color(NSColor.windowBackgroundColor))
    }
}

// MARK: - About Tab

struct AboutView: View {
    var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
        return "\(version) (\(build))"
    }
    
    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 24) {
                // App icon and name
                VStack(spacing: 16) {
                    Image(nsImage: NSApp.applicationIconImage)
                        .resizable()
                        .frame(width: 128, height: 128)
                    
                    Text("VibeMeter")
                        .font(.system(size: 24, weight: .medium))
                    
                    Text("Version \(appVersion)")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                .padding(.top, 40)
                
                // Description
                Text("Monitor your monthly Cursor AI spending")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                // Links
                VStack(spacing: 12) {
                    Link(destination: URL(string: "https://github.com/steipete/VibeMeter")!) {
                        HStack {
                            Image(systemName: "link")
                                .font(.system(size: 14))
                            Text("View on GitHub")
                                .font(.system(size: 14))
                        }
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.accentColor)
                    
                    Link(destination: URL(string: "https://github.com/steipete/VibeMeter/issues")!) {
                        HStack {
                            Image(systemName: "exclamationmark.bubble")
                                .font(.system(size: 14))
                            Text("Report an Issue")
                                .font(.system(size: 14))
                        }
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.accentColor)
                }
                
                Spacer()
                
                // Copyright
                Text("© 2025 Peter Steinberger")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .padding(.bottom, 32)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color(NSColor.windowBackgroundColor))
    }
}

// MARK: - Helper Views

struct SettingsRow<Content: View>: View {
    let content: () -> Content
    
    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }
    
    var body: some View {
        HStack {
            content()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}