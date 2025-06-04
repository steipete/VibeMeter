import AppKit
import SwiftUI

/// General settings view for application-wide preferences and behavior.
///
/// This view contains settings for launch behavior, currency selection, refresh intervals,
/// menu bar display options, and dock visibility. It provides the core configuration
/// options that affect the overall application experience.
struct GeneralSettingsView: View {
    @Bindable var settingsManager: SettingsManager

    @State
    private var hasUserMadeCurrencyChoice = UserDefaults.standard
        .bool(forKey: SettingsManager.Keys.hasUserCurrencyPreference)

    private let startupManager = StartupManager()
    private let currencyManager = CurrencyManager.shared

    var body: some View {
        NavigationStack {
            Form {
                applicationSection
                displaySection
                currencySection
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            .navigationTitle("General Settings")
        }
        .task {
            // Sync launch at login status
            settingsManager.launchAtLoginEnabled = startupManager.isLaunchAtLoginEnabled

            // Auto-detect system currency on first launch
            if !hasUserMadeCurrencyChoice, settingsManager.selectedCurrencyCode == "USD" {
                if let systemCurrencyCode = currencyManager.systemCurrencyCode,
                   currencyManager.isValidCurrencyCode(systemCurrencyCode) {
                    settingsManager.selectedCurrencyCode = systemCurrencyCode
                    hasUserMadeCurrencyChoice = true
                    UserDefaults.standard.set(true, forKey: SettingsManager.Keys.hasUserCurrencyPreference)
                }
            }
        }
    }

    private var applicationSection: some View {
        Section {
            // Launch at Login
            VStack(alignment: .leading, spacing: 4) {
                Toggle("Launch at Login", isOn: launchAtLoginBinding)
                Text("Automatically start Vibe Meter when you log into your Mac.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }


        } header: {
            Text("Application")
                .font(.headline)
        }
    }

    private var displaySection: some View {
        Section {
            // Menu bar display mode
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Menu Bar Display")
                    Spacer()
                    Picker("", selection: $settingsManager.menuBarDisplayMode) {
                        ForEach(MenuBarDisplayMode.allCases) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                }
                Text(settingsManager.menuBarDisplayMode.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Refresh Interval
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Refresh Interval")
                    Spacer()
                    Picker("", selection: $settingsManager.refreshIntervalMinutes) {
                        ForEach(SettingsManager.refreshIntervalOptions, id: \.self) { minutes in
                            Text(formatInterval(minutes)).tag(minutes)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                }
                Text("How often Vibe Meter checks for updated spending data.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 8)
        } header: {
            Text("Display & Updates")
                .font(.headline)
        }
    }

    private var currencySection: some View {
        Section {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Currency")
                    Spacer()
                    Picker("", selection: currencyBinding) {
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
        }
    }

    // MARK: - Bindings

    private var launchAtLoginBinding: Binding<Bool> {
        Binding(
            get: { settingsManager.launchAtLoginEnabled },
            set: { newValue in
                settingsManager.launchAtLoginEnabled = newValue
                startupManager.setLaunchAtLogin(enabled: newValue)
            })
    }


    private var currencyBinding: Binding<String> {
        Binding(
            get: { settingsManager.selectedCurrencyCode },
            set: { newValue in
                settingsManager.selectedCurrencyCode = newValue
                hasUserMadeCurrencyChoice = true
                UserDefaults.standard.set(true, forKey: SettingsManager.Keys.hasUserCurrencyPreference)
            })
    }

    // MARK: - Helper Methods

    private func formatInterval(_ minutes: Int) -> String {
        switch minutes {
        case 1: "1 minute"
        case 60: "1 hour"
        default: "\(minutes) minutes"
        }
    }

}

// MARK: - Preview

#Preview("General Settings") {
    GeneralSettingsView(settingsManager: SettingsManager.shared)
        .frame(width: 620, height: 550)
}
