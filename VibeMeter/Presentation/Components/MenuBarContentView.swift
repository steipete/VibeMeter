import AppKit
import SwiftUI

@MainActor
struct MenuBarContentView: View {
    @ObservedObject
    var settingsManager: SettingsManager
    @ObservedObject
    var dataCoordinator: DataCoordinator

    var body: some View {
        VStack(spacing: 0) {
            if dataCoordinator.isLoggedIn {
                LoggedInMenuContent(dataCoordinator: dataCoordinator)
            } else {
                LoggedOutMenuContent(dataCoordinator: dataCoordinator)
            }
        }
        .frame(minWidth: 200, maxWidth: 250)
    }
}

// MARK: - Logged In Content

struct LoggedInMenuContent: View {
    @ObservedObject
    var dataCoordinator: DataCoordinator

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // User info
            if let email = dataCoordinator.userEmail {
                Text(email.truncated(to: 20))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Current spending
            if let spending = dataCoordinator.currentSpendingConverted {
                Text("\(dataCoordinator.selectedCurrencySymbol)\(spending, specifier: "%.2f")")
                    .font(.headline)
            } else if let spendingUSD = dataCoordinator.currentSpendingUSD {
                Text("$\(spendingUSD, specifier: "%.2f")")
                    .font(.headline)
            }

            // Limits (compact)
            HStack {
                Text("⚠️")
                if let warning = dataCoordinator.warningLimitConverted {
                    Text("\(dataCoordinator.selectedCurrencySymbol)\(warning, specifier: "%.0f")")
                } else {
                    Text("$\(dataCoordinator.settingsManager.warningLimitUSD, specifier: "%.0f")")
                }

                Spacer()

                Text("🚨")
                if let upper = dataCoordinator.upperLimitConverted {
                    Text("\(dataCoordinator.selectedCurrencySymbol)\(upper, specifier: "%.0f")")
                } else {
                    Text("$\(dataCoordinator.settingsManager.upperLimitUSD, specifier: "%.0f")")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            Divider()

            // Actions
            VStack(spacing: 4) {
                Button("Refresh") {
                    Task {
                        await dataCoordinator.forceRefreshData(showSyncedMessage: true)
                    }
                }
                .keyboardShortcut("r")

                Button("Settings...") {
                    NSApp.activate(ignoringOtherApps: true)
                    NSApp.openSettings()
                }
                .keyboardShortcut(",")

                Button("Log Out") {
                    dataCoordinator.userDidRequestLogout()
                }
                .keyboardShortcut("q")
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, alignment: .leading)

            Divider()

            Button("Quit VibeMeter") {
                NSApp.terminate(nil)
            }
            .keyboardShortcut("Q")
            .buttonStyle(.plain)
        }
        .padding(12)
    }
}

// MARK: - Logged Out Content

struct LoggedOutMenuContent: View {
    @ObservedObject
    var dataCoordinator: DataCoordinator

    var body: some View {
        VStack(spacing: 8) {
            Button("Login") {
                dataCoordinator.initiateLoginFlow()
            }
            .keyboardShortcut("l")
            .buttonStyle(.borderedProminent)

            Divider()

            Button("Settings...") {
                NSApp.activate(ignoringOtherApps: true)
                NSApp.openSettings()
            }
            .keyboardShortcut(",")
            .buttonStyle(.plain)

            Divider()

            Button("Quit VibeMeter") {
                NSApp.terminate(nil)
            }
            .keyboardShortcut("Q")
            .buttonStyle(.plain)
        }
        .padding(12)
    }
}

// MARK: - Helper Extension

private extension String {
    func truncated(to length: Int) -> String {
        if count > length {
            return String(prefix(length - 3)) + "..."
        }
        return self
    }
}
