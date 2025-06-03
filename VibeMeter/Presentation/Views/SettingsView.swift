import SwiftUI

// MARK: - Main Settings View

struct SettingsView: View {
    @ObservedObject
    var settingsManager: SettingsManager
    @ObservedObject
    var dataCoordinator: DataCoordinator

    @State
    private var selectedTab = SettingsTab.general
    @State
    private var warningLimitInput = ""
    @State
    private var upperLimitInput = ""
    @State
    private var limitInputCurrencySymbol = "$"
    @State
    private var limitInputCurrencyCode = "USD"

    private let exchangeRateManager = ExchangeRateManager.shared

    var body: some View {
        TabView(selection: $selectedTab) {
            GeneralSettingsView(
                settingsManager: settingsManager,
                dataCoordinator: dataCoordinator)
                .tabItem {
                    Label("General", systemImage: "gear")
                }
                .tag(SettingsTab.general)

            AccountSettingsView(dataCoordinator: dataCoordinator)
                .tabItem {
                    Label("Account", systemImage: "person.circle")
                }
                .tag(SettingsTab.account)

            LimitsSettingsView(
                settingsManager: settingsManager,
                dataCoordinator: dataCoordinator,
                warningLimitInput: $warningLimitInput,
                upperLimitInput: $upperLimitInput,
                limitInputCurrencySymbol: $limitInputCurrencySymbol,
                limitInputCurrencyCode: $limitInputCurrencyCode)
                .tabItem {
                    Label("Limits", systemImage: "exclamationmark.triangle")
                }
                .tag(SettingsTab.limits)

            AdvancedSettingsView()
                .tabItem {
                    Label("Advanced", systemImage: "gearshape.2")
                }
                .tag(SettingsTab.advanced)

            AboutView()
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
                .tag(SettingsTab.about)
        }
        .frame(width: 600, height: 450)
        .onAppear {
            updateLimitInputFieldsAndCurrency()
        }
        .onChange(of: dataCoordinator.exchangeRatesAvailable) { _, _ in
            updateLimitInputFieldsAndCurrency()
        }
        .onChange(of: dataCoordinator.currentExchangeRates) { _, _ in
            updateLimitInputFieldsAndCurrency()
        }
        .onChange(of: settingsManager.selectedCurrencyCode) { _, _ in
            updateLimitInputFieldsAndCurrency()
        }
        .onChange(of: warningLimitInput) { _, _ in
            saveLimits()
        }
        .onChange(of: upperLimitInput) { _, _ in
            saveLimits()
        }
    }

    private func updateLimitInputFieldsAndCurrency() {
        let ratesAvailable = dataCoordinator.exchangeRatesAvailable
        let targetCurrency = settingsManager.selectedCurrencyCode
        let currentRates = dataCoordinator.currentExchangeRates

        limitInputCurrencyCode = ratesAvailable && !currentRates.isEmpty ? targetCurrency : "USD"
        limitInputCurrencySymbol = ExchangeRateManager.getSymbol(for: limitInputCurrencyCode)

        // Warning Limit
        let warningUSD = settingsManager.warningLimitUSD
        if let convertedWarning = exchangeRateManager.convert(
            warningUSD,
            from: "USD",
            to: limitInputCurrencyCode,
            rates: currentRates) {
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
            rates: currentRates) {
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
                rates: currentRates) {
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
                rates: currentRates) {
                settingsManager.upperLimitUSD = upperUSD
            } else if sourceCurrencyForInput == "USD" {
                settingsManager.upperLimitUSD = upperValue
            }
        }
    }
}

// MARK: - Settings Tab Enum

enum SettingsTab: String, CaseIterable {
    case general = "General"
    case account = "Account"
    case limits = "Limits"
    case advanced = "Advanced"
    case about = "About"

    var icon: String {
        switch self {
        case .general: "gear"
        case .account: "person.circle"
        case .limits: "exclamationmark.triangle"
        case .advanced: "gearshape.2"
        case .about: "info.circle"
        }
    }
}

// MARK: - General Settings

struct GeneralSettingsView: View {
    @ObservedObject
    var settingsManager: SettingsManager
    @ObservedObject
    var dataCoordinator: DataCoordinator
    @State
    private var launchAtLogin = false

    var body: some View {
        Form {
            Section("Startup") {
                Toggle("Launch at Login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, newValue in
                        settingsManager.launchAtLoginEnabled = newValue
                    }
            }

            Section("Display Preferences") {
                LabeledContent("Display Currency") {
                    Picker("", selection: $settingsManager.selectedCurrencyCode) {
                        ForEach(ExchangeRateManager.shared.supportedCurrencies, id: \.self) { currency in
                            Text("\(currency) (\(ExchangeRateManager.getSymbol(for: currency)))")
                                .tag(currency)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .fixedSize()
                }

                LabeledContent("Refresh Interval") {
                    Picker("", selection: $settingsManager.refreshIntervalMinutes) {
                        ForEach(SettingsManager.refreshIntervalOptions, id: \.self) { interval in
                            Text("\(interval) minute\(interval == 1 ? "" : "s")")
                                .tag(interval)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .fixedSize()
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .onAppear {
            launchAtLogin = settingsManager.launchAtLoginEnabled
        }
    }
}

// MARK: - Account Settings

struct AccountSettingsView: View {
    @ObservedObject
    var dataCoordinator: DataCoordinator

    var body: some View {
        VStack(spacing: 20) {
            // Account Status Card
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top) {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(dataCoordinator.isLoggedIn ? .green : .secondary)
                        .symbolRenderingMode(.hierarchical)

                    VStack(alignment: .leading, spacing: 6) {
                        Text(dataCoordinator.isLoggedIn ? "Connected" : "Not Connected")
                            .font(.headline)

                        if dataCoordinator.isLoggedIn {
                            Text(dataCoordinator.userEmail ?? "Unknown email")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)

                            if let teamName = dataCoordinator.teamName {
                                Text("Team: \(teamName)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    Spacer()

                    if dataCoordinator.isLoggedIn {
                        Button("Log Out") {
                            dataCoordinator.userDidRequestLogout()
                        }
                        .foregroundColor(.red)
                    } else {
                        Button("Log In") {
                            dataCoordinator.initiateLoginFlow()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }
            .padding()
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))

            // Error message if present
            if let errorMessage = dataCoordinator.lastErrorMessage, !errorMessage.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 6))
            }

            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Limits Settings

struct LimitsSettingsView: View {
    @ObservedObject
    var settingsManager: SettingsManager
    @ObservedObject
    var dataCoordinator: DataCoordinator
    @Binding
    var warningLimitInput: String
    @Binding
    var upperLimitInput: String
    @Binding
    var limitInputCurrencySymbol: String
    @Binding
    var limitInputCurrencyCode: String

    var body: some View {
        Form {
            Section("Spending Limits") {
                VStack(alignment: .leading, spacing: 12) {
                    LabeledContent {
                        HStack(spacing: 4) {
                            Text(limitInputCurrencySymbol)
                                .foregroundStyle(.secondary)
                            TextField("0.00", text: $warningLimitInput)
                                .textFieldStyle(.plain)
                                .frame(width: 80)
                                .multilineTextAlignment(.trailing)
                        }
                    } label: {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Warning Limit")
                            Text("Get notified when spending reaches this amount")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Divider()

                    LabeledContent {
                        HStack(spacing: 4) {
                            Text(limitInputCurrencySymbol)
                                .foregroundStyle(.secondary)
                            TextField("0.00", text: $upperLimitInput)
                                .textFieldStyle(.plain)
                                .frame(width: 80)
                                .multilineTextAlignment(.trailing)
                        }
                    } label: {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Maximum Limit")
                            Text("Receive urgent alerts at this spending level")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.vertical, 8)
            }

            // Info messages
            VStack(alignment: .leading, spacing: 8) {
                if limitInputCurrencyCode != "USD" {
                    Label(
                        "Amounts are displayed in \(limitInputCurrencyCode) but stored in USD",
                        systemImage: "info.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if !dataCoordinator.exchangeRatesAvailable {
                    Label("Exchange rates unavailable — displaying USD amounts", systemImage: "wifi.exclamationmark")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }

            Button("Reset to Defaults") {
                settingsManager.warningLimitUSD = 200.0
                settingsManager.upperLimitUSD = 1000.0
            }
            .buttonStyle(.link)
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - Advanced Settings

struct AdvancedSettingsView: View {
    var body: some View {
        Form {
            Section("Software Updates") {
                LabeledContent {
                    Button("Check Now") {
                        if let appDelegate = NSApplication.shared.delegate as? AppDelegate,
                           let sparkleManager = appDelegate.sparkleUpdaterManager {
                            sparkleManager.updaterController.checkForUpdates(nil)
                        }
                    }
                    .disabled(isDebugBuild)
                } label: {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Check for Updates")
                        Text("Check for new versions of VibeMeter")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private var isDebugBuild: Bool {
        #if DEBUG
            return true
        #else
            return false
        #endif
    }
}

// MARK: - About View

struct AboutView: View {
    var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
        return "\(version) (\(build))"
    }

    var body: some View {
        VStack(spacing: 24) {
            // App info
            VStack(spacing: 16) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 128, height: 128)

                Text("VibeMeter")
                    .font(.largeTitle)
                    .fontWeight(.medium)

                Text("Version \(appVersion)")
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 40)

            Text("Monitor your monthly Cursor AI spending")
                .foregroundStyle(.secondary)

            // Links
            VStack(spacing: 12) {
                Link(destination: URL(string: "https://github.com/steipete/VibeMeter")!) {
                    Label("View on GitHub", systemImage: "link")
                }
                .buttonStyle(.link)

                Link(destination: URL(string: "https://github.com/steipete/VibeMeter/issues")!) {
                    Label("Report an Issue", systemImage: "exclamationmark.bubble")
                }
                .buttonStyle(.link)
            }

            Spacer()

            Text("© 2025 Peter Steinberger")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.bottom, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}
