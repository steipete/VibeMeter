import SwiftUI

/// Network status indicator component for displaying connectivity information.
///
/// This component shows the current network status with appropriate visual styling
/// and can be used in settings panels or debug views to give users insight into
/// their connectivity state.
struct NetworkStatusIndicator: View {
    let networkStatus: String
    let isConnected: Bool
    let compact: Bool

    init(networkStatus: String, isConnected: Bool, compact: Bool = false) {
        self.networkStatus = networkStatus
        self.isConnected = isConnected
        self.compact = compact
    }

    var body: some View {
        HStack(spacing: compact ? 4 : 6) {
            // Status icon
            Image(systemName: statusIcon)
                .font(compact ? .caption2.weight(.medium) : .caption.weight(.medium))
                .foregroundStyle(statusColor)
                .symbolEffect(
                    .pulse.byLayer,
                    options: .repeating,
                    isActive: !isConnected)

            if !compact {
                Text(networkStatus)
                    .font(.caption)
                    .foregroundStyle(statusColor)
            }
        }
        .padding(.horizontal, compact ? 4 : 6)
        .padding(.vertical, compact ? 2 : 3)
        .background(
            RoundedRectangle(cornerRadius: compact ? 4 : 6)
                .fill(statusColor.opacity(0.1)))
        .help(fullStatusDescription + " (⌘R to refresh)")
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Network status: \(fullStatusDescription)")
        .accessibilityValue(isConnected ? "Connected" : "Disconnected")
    }

    private var statusIcon: String {
        if isConnected {
            "wifi"
        } else {
            "wifi.slash"
        }
    }

    private var statusColor: Color {
        isConnected ? .statusConnected : .statusError
    }

    private var fullStatusDescription: String {
        if isConnected {
            "Network: \(networkStatus)"
        } else {
            "No internet connection"
        }
    }
}

/// Compact network status for menu bars or tight spaces
struct CompactNetworkStatus: View {
    let networkStatus: String
    let isConnected: Bool

    var body: some View {
        NetworkStatusIndicator(
            networkStatus: networkStatus,
            isConnected: isConnected,
            compact: true)
            .accessibilityLabel("Compact network status")
            .accessibilityValue(isConnected ? "Connected via \(networkStatus)" : "Disconnected")
    }
}

// MARK: - Previews

#Preview("Network Status Indicators") {
    VStack(spacing: 16) {
        Group {
            NetworkStatusIndicator(networkStatus: "WiFi", isConnected: true)
            NetworkStatusIndicator(networkStatus: "Ethernet", isConnected: true)
            NetworkStatusIndicator(networkStatus: "Cellular (Expensive)", isConnected: true)
            NetworkStatusIndicator(networkStatus: "Offline", isConnected: false)
        }

        Divider()

        Text("Compact variants:")
            .font(.caption)
            .foregroundStyle(.secondary)

        HStack(spacing: 8) {
            CompactNetworkStatus(networkStatus: "WiFi", isConnected: true)
            CompactNetworkStatus(networkStatus: "Offline", isConnected: false)
        }
    }
    .padding(20)
    .background(Color(NSColor.windowBackgroundColor))
}
