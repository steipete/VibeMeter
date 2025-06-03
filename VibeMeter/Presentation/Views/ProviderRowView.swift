import SwiftUI

struct ProviderRowView: View {
    let provider: ServiceProvider
    let userSessionData: MultiProviderUserSessionData
    let loginManager: MultiProviderLoginManager
    let providerRegistry: ProviderRegistry
    let showDetail: () -> Void

    private var session: ProviderSessionState? {
        userSessionData.getSession(for: provider)
    }

    private var isLoggedIn: Bool {
        userSessionData.isLoggedIn(to: provider)
    }

    private var isEnabled: Bool {
        providerRegistry.isEnabled(provider)
    }

    var body: some View {
        HStack(spacing: 16) {
            // Provider icon
            providerIcon(for: provider)
                .font(.title2)
                .foregroundStyle(.primary)
                .frame(width: 32, height: 32)

            // Provider info
            VStack(alignment: .leading, spacing: 4) {
                Text(provider.displayName)
                    .font(.headline)

                if let session, isLoggedIn {
                    Text(session.userEmail ?? "Unknown user")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    if let teamName = session.teamName {
                        Text("Team: \(teamName)")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                } else if isEnabled {
                    Text("Not connected")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Disabled")
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                }

                if let errorMessage = session?.lastErrorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            Spacer()

            // Status indicator
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)

            // Action buttons
            HStack(spacing: 8) {
                if isEnabled, !isLoggedIn {
                    Button("Login") {
                        loginManager.showLoginWindow(for: provider)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }

                if isLoggedIn {
                    Button("Logout") {
                        loginManager.logOut(from: provider)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

                Button("Details") {
                    showDetail()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
    }

    private var statusColor: Color {
        if !isEnabled {
            .gray
        } else if isLoggedIn {
            .green
        } else {
            .orange
        }
    }

    private func providerIcon(for provider: ServiceProvider) -> Image {
        if provider.iconName.contains(".") {
            Image(systemName: provider.iconName)
        } else {
            Image(provider.iconName)
        }
    }
}
