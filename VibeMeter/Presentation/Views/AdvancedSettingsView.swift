import SwiftUI

/// Advanced settings view for power users and update preferences.
///
/// This view contains advanced configuration options that most users won't need
/// to modify, including update channel selection and system-level preferences.
struct AdvancedSettingsView: View {
    @Bindable var settingsManager: SettingsManager
    @State private var isCheckingForUpdates = false
    
    var body: some View {
        NavigationStack {
            Form {
                updateSection
                systemSection
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            .navigationTitle("Advanced Settings")
        }
    }
    
    private var updateSection: some View {
        Section {
            // Update Channel
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Update Channel")
                    Spacer()
                    Picker("", selection: updateChannelBinding) {
                        ForEach(UpdateChannel.allCases) { channel in
                            Text(channel.displayName).tag(channel)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                }
                Text(settingsManager.updateChannel.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            // Check for Updates
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Check for Updates")
                    Text("Manually check for new versions")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Button("Check Now") {
                    checkForUpdates()
                }
                .buttonStyle(.bordered)
                .disabled(isCheckingForUpdates)
            }
            .padding(.top, 8)
        } header: {
            Text("Updates")
                .font(.headline)
        } footer: {
            Text("Pre-release channel provides early access to beta versions and new features. Choose Stable for production use.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
    
    private var systemSection: some View {
        Section {
            // Show in Dock
            VStack(alignment: .leading, spacing: 4) {
                Toggle("Show in Dock", isOn: showInDockBinding)
                Text("Display VibeMeter in the Dock. When disabled, VibeMeter runs as a menu bar app only.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("System Integration")
                .font(.headline)
        }
    }
    
    // MARK: - Bindings
    
    private var updateChannelBinding: Binding<UpdateChannel> {
        Binding(
            get: { settingsManager.updateChannel },
            set: { newValue in
                settingsManager.updateChannel = newValue
                
                // Update Sparkle's feed URL when channel changes
                if let updaterManager = (NSApp.delegate as? AppDelegate)?.sparkleUpdaterManager {
                    updaterManager.updateFeedURL()
                }
            }
        )
    }
    
    private var showInDockBinding: Binding<Bool> {
        Binding(
            get: { settingsManager.showInDock },
            set: { settingsManager.showInDock = $0 }
        )
    }
    
    // MARK: - Actions
    
    private func checkForUpdates() {
        isCheckingForUpdates = true
        
        // Get the Sparkle updater from AppDelegate
        guard let appDelegate = NSApp.delegate as? AppDelegate,
              let updaterManager = appDelegate.sparkleUpdaterManager else {
            isCheckingForUpdates = false
            return
        }
        
        // Trigger update check
        updaterManager.updaterController.updater.checkForUpdates()
        
        // Reset the checking state after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            isCheckingForUpdates = false
        }
    }
}

#Preview {
    AdvancedSettingsView(settingsManager: MockSettingsManager())
        .frame(width: 600, height: 400)
}