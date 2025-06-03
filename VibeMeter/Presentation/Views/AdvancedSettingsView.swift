import SwiftUI
import AppKit

struct AdvancedSettingsView: View {
    var body: some View {
        Form {
            headerSection
            softwareUpdatesSection
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
    }

    private var headerSection: some View {
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
}