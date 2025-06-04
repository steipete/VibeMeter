import AppKit
import SwiftUI

/// Advanced settings view for power users and technical configurations.
///
/// This view contains settings for update channels, dock visibility, and other
/// advanced options that most users won't need to change frequently.
struct AdvancedSettingsView: View {
    @Bindable var settingsManager: SettingsManager
    
    @State
    private var isCheckingForUpdates = false
    
    var body: some View {
        NavigationStack {
            Form {
                updateSection
                appearanceSection
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
                    Picker("", selection: $settingsManager.updateChannel) {
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
                    Text("Check for new versions of Vibe Meter")
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
        }
    }
    
    private var appearanceSection: some View {
        Section {
            // Show in Dock
            VStack(alignment: .leading, spacing: 4) {
                Toggle("Show in Dock", isOn: showInDockBinding)
                Text("Display Vibe Meter in the Dock. When disabled, Vibe Meter runs as a menu bar app only.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Appearance")
                .font(.headline)
        }
    }
    
    // MARK: - Bindings
    
    private var showInDockBinding: Binding<Bool> {
        Binding(
            get: { settingsManager.showInDock },
            set: { newValue in
                settingsManager.showInDock = newValue
                NSApp.setActivationPolicy(newValue ? .regular : .accessory)
            })
    }
    
    // MARK: - Helper Methods
    
    private func checkForUpdates() {
        isCheckingForUpdates = true
        NotificationCenter.default.post(name: Notification.Name("checkForUpdates"), object: nil)
        
        // Reset after a delay
        Task {
            try? await Task.sleep(for: .seconds(2))
            isCheckingForUpdates = false
        }
    }
}

// MARK: - Preview

#Preview("Advanced Settings") {
    AdvancedSettingsView(settingsManager: SettingsManager.shared)
        .frame(width: 620, height: 400)
}