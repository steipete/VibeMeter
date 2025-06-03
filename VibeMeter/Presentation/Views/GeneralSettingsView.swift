import AppKit
import SwiftUI

struct GeneralSettingsView: View {
    let settingsManager: SettingsManager

    // Using @AppStorage for direct UserDefaults binding
    @AppStorage("launchAtLoginEnabled")
    private var launchAtLogin: Bool = false
    @AppStorage("refreshIntervalMinutes")
    private var refreshInterval: Int = 5
    @AppStorage("showCostInMenuBar")
    private var showCostInMenuBar: Bool = false
    @AppStorage("showInDock")
    private var showInDock: Bool = false
    @AppStorage("selectedCurrencyCode")
    private var selectedCurrency: String = "USD"

    private let startupManager = StartupManager()
    private let currencyManager = CurrencyManager.shared

    init(settingsManager: SettingsManager) {
        self.settingsManager = settingsManager
    }

    var body: some View {
        NavigationStack {
            Form {
                applicationSection
                currencySection
                softwareUpdatesSection
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            .navigationTitle("General Settings")
        }
        .onChange(of: refreshInterval) { _, newValue in
            validateRefreshInterval(newValue)
        }
        .onChange(of: selectedCurrency) { _, newValue in
            settingsManager.selectedCurrencyCode = newValue
        }
        .onAppear {
            setupInitialState()
        }
    }

    private var applicationSection: some View {
        Section {
            // Launch at Login
            Toggle("Launch at Login", isOn: $launchAtLogin)
                .onChange(of: launchAtLogin) { _, newValue in
                    startupManager.setLaunchAtLogin(enabled: newValue)
                }
            
            // Show cost in menu bar
            VStack(alignment: .leading, spacing: 4) {
                Toggle("Show cost in menu bar", isOn: $showCostInMenuBar)
                Text("Display current spending next to the menu bar icon. When disabled, only the icon is shown.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 8)

            // Show in Dock
            VStack(alignment: .leading, spacing: 4) {
                Toggle("Show in Dock", isOn: $showInDock)
                    .onChange(of: showInDock) { _, newValue in
                        if newValue {
                            NSApp.setActivationPolicy(.regular)
                        } else {
                            NSApp.setActivationPolicy(.accessory)
                        }
                    }
                Text("Display VibeMeter in the Dock. When disabled, VibeMeter runs as a menu bar app only.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 8)
            
            // Refresh Interval
            VStack(alignment: .leading, spacing: 4) {
                LabeledContent("Refresh Interval") {
                    Picker("", selection: $refreshInterval) {
                        Text("1 minute").tag(1)
                        Text("2 minutes").tag(2)
                        Text("5 minutes").tag(5)
                        Text("10 minutes").tag(10)
                        Text("15 minutes").tag(15)
                        Text("30 minutes").tag(30)
                        Text("1 hour").tag(60)
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                }
                Text("How often VibeMeter checks for updated spending data.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 8)
        } header: {
            Text("Application")
                .font(.headline)
        }
    }

    private var currencySection: some View {
        Section {
            VStack(alignment: .leading, spacing: 4) {
                LabeledContent("Currency") {
                    Picker("", selection: $selectedCurrency) {
                        ForEach(currencyManager.availableCurrencies, id: \.0) { code, name in
                            Text(name).tag(code)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                }
                Text("Select your preferred currency for displaying costs and limits.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Currency")
                .font(.headline)
        }
    }

    private var softwareUpdatesSection: some View {
        Section {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Check for Updates")
                    Text("Check for new versions of VibeMeter")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button("Check Now") {
                    checkForUpdates()
                }
                .buttonStyle(.bordered)
                .disabled(isDebugBuild)
            }
        } header: {
            Text("Software Updates")
                .font(.headline)
        }
    }

    private func validateRefreshInterval(_ newValue: Int) {
        if SettingsManager.refreshIntervalOptions.contains(newValue) {
            // Valid interval, it's already saved via @AppStorage
        } else {
            // Invalid interval, reset to default
            refreshInterval = 5
        }
    }

    private var isDebugBuild: Bool {
        #if DEBUG
            return true
        #else
            return false
        #endif
    }

    private func checkForUpdates() {
        if let appDelegate = NSApplication.shared.delegate as? AppDelegate,
           let sparkleManager = appDelegate.sparkleUpdaterManager {
            sparkleManager.updaterController.checkForUpdates(nil)
        }
    }

    private func setupInitialState() {
        // Sync with actual launch at login status
        launchAtLogin = startupManager.isLaunchAtLoginEnabled

        // Detect system currency if current selection is USD (default)
        if selectedCurrency == "USD" {
            if let systemCurrencyCode = currencyManager.systemCurrencyCode,
               currencyManager.isValidCurrencyCode(systemCurrencyCode) {
                selectedCurrency = systemCurrencyCode
                settingsManager.selectedCurrencyCode = systemCurrencyCode
            }
        }
    }
}
