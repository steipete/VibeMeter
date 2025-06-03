import AppKit
import SwiftUI

// MARK: - Settings UI Components

/// A modern macOS-style settings section with proper styling
struct SettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)
                .padding(.horizontal, 4)

            VStack(spacing: 1) {
                content
            }
            .background(.background.secondary)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color(NSColor.separatorColor).opacity(0.3), lineWidth: 0.5)
            )
        }
    }
}

/// A modern macOS-style settings row with proper padding and styling
struct SettingsRow<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        HStack {
            content
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background.secondary)
    }
}

// MARK: - General Settings View

/// The general settings tab view for app preferences.
///
/// Provides:
/// - Launch at login toggle
/// - Refresh interval configuration
/// - Basic app behavior settings
struct GeneralSettingsView: View {
    let settingsManager: SettingsManager

    @State
    private var launchAtLogin: Bool
    @State
    private var refreshInterval: Int
    @State
    private var showCostInMenuBar: Bool

    private let startupManager = StartupManager()

    init(settingsManager: SettingsManager) {
        self.settingsManager = settingsManager
        _launchAtLogin = State(initialValue: settingsManager.launchAtLoginEnabled)
        _refreshInterval = State(initialValue: settingsManager.refreshIntervalMinutes)
        _showCostInMenuBar = State(initialValue: settingsManager.showCostInMenuBar)
    }

    var body: some View {
        Form {
            VStack(alignment: .leading, spacing: 8) {
                Text("General")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .padding(.top, 10)
                    .padding(.horizontal, 10)
                
                Text("Configure general application preferences and behavior.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.bottom, 10)
            }
            
            Section {
                Toggle("Launch at Login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, newValue in
                        settingsManager.launchAtLoginEnabled = newValue
                        startupManager.setLaunchAtLogin(enabled: newValue)
                    }
            } header: {
                Text("Startup")
                    .font(.headline)
            }
            
            Section {
                Toggle("Show cost in menu bar", isOn: $showCostInMenuBar)
                    .onChange(of: showCostInMenuBar) { _, newValue in
                        settingsManager.showCostInMenuBar = newValue
                    }
                
                Text("Display current spending next to the menu bar icon. When disabled, only the icon is shown.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Text("Menu Bar")
                    .font(.headline)
            }
            
            Section {
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
            } header: {
                Text("Data Refresh")
                    .font(.headline)
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .onChange(of: refreshInterval) { _, newValue in
            settingsManager.refreshIntervalMinutes = newValue
        }
        .onAppear {
            // Sync with actual launch at login status
            launchAtLogin = startupManager.isLaunchAtLoginEnabled
        }
    }
}

// MARK: - Advanced Settings View

/// The advanced settings tab view for app configuration.
///
/// Provides:
/// - Software update management
/// - Debug build detection
/// - Sparkle updater integration
struct AdvancedSettingsView: View {
    var body: some View {
        Form {
            VStack(alignment: .leading, spacing: 8) {
                Text("Advanced")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .padding(.top, 10)
                    .padding(.horizontal, 10)
                
                Text("Configure advanced application settings.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.bottom, 10)
            }
            
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
                        if let appDelegate = NSApplication.shared.delegate as? AppDelegate,
                           let sparkleManager = appDelegate.sparkleUpdaterManager {
                            sparkleManager.updaterController.checkForUpdates(nil)
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(isDebugBuild)
                }
            } header: {
                Text("Software Updates")
                    .font(.headline)
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
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

/// The about tab view displaying app information.
///
/// Shows:
/// - Application icon and name
/// - Version and build number
/// - Brief description
/// - Links to GitHub repository and issue tracker
/// - Copyright information
struct AboutView: View {
    var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
        return "\(version) (\(build))"
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("About")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .padding(.top, 10)
                        .padding(.horizontal, 10)
                    
                    Text("Information about VibeMeter.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 10)
                        .padding(.bottom, 10)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
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
                .padding(.top, 20)
                
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
                
                Spacer(minLength: 40)
                
                Text("© 2025 Peter Steinberger • MIT Licensed")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 32)
            }
            .frame(maxWidth: .infinity)
            .padding()
        }
        .scrollContentBackground(.hidden)
    }
}
