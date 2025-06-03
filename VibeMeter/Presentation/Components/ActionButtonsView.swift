import AppKit
import SwiftUI

/// Action buttons component providing refresh, settings, and quit functionality.
///
/// This view contains the primary action buttons for the menu bar interface, including
/// data refresh with loading animation, settings access, and application termination.
/// Each button includes hover states and appropriate visual feedback.
struct ActionButtonsView: View {
    let onRefresh: () async -> Void

    @State
    private var isRefreshing = false

    var body: some View {
        HStack(spacing: 16) {
            refreshButton
            settingsButton

            Spacer()

            quitButton
        }
    }

    private var refreshButton: some View {
        Button(action: refreshData) {
            Image(systemName: "arrow.clockwise")
                .font(.title3.weight(.medium))
                .rotationEffect(.degrees(isRefreshing ? 360 : 0))
                .animation(
                    isRefreshing ? .linear(duration: 1).repeatForever(autoreverses: false) : .default,
                    value: isRefreshing)
        }
        .buttonStyle(IconButtonStyle())
        .help("Refresh (⌘R)")
        .accessibilityLabel("Refresh spending data")
        .accessibilityHint("Updates AI service spending information from all connected providers")
        .keyboardShortcut("r", modifiers: .command)
    }

    private var settingsButton: some View {
        Button(action: openSettings) {
            Image(systemName: "gearshape")
                .font(.title3.weight(.medium))
        }
        .buttonStyle(IconButtonStyle())
        .help("Settings (⌘,)")
        .accessibilityLabel("Open settings")
        .accessibilityHint("Opens VibeMeter preferences and configuration options")
        .keyboardShortcut(",", modifiers: .command)
    }

    private var quitButton: some View {
        Button(action: quit) {
            Image(systemName: "power")
                .font(.title3.weight(.medium))
        }
        .buttonStyle(IconButtonStyle(isDestructive: true))
        .help("Quit VibeMeter (⌘Q)")
        .accessibilityLabel("Quit application")
        .accessibilityHint("Closes VibeMeter completely")
        .keyboardShortcut("q", modifiers: .command)
    }

    private func refreshData() {
        Task {
            isRefreshing = true
            await onRefresh()
            isRefreshing = false
        }
    }

    private func openSettings() {
        NSApp.openSettings()
    }

    private func quit() {
        NSApp.terminate(nil)
    }
}

// MARK: - Preview

#Preview {
    ActionButtonsView(onRefresh: {
        try? await Task.sleep(nanoseconds: 1_000_000_000)
    })
    .padding()
    .frame(width: 280)
    .background(Color(NSColor.windowBackgroundColor))
}
