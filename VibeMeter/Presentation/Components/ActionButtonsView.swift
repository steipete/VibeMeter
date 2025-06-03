import SwiftUI
import AppKit

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
                .font(.system(size: 14, weight: .medium))
                .rotationEffect(.degrees(isRefreshing ? 360 : 0))
                .animation(
                    isRefreshing ? .linear(duration: 1).repeatForever(autoreverses: false) : .default,
                    value: isRefreshing)
        }
        .buttonStyle(IconButtonStyle())
        .help("Refresh")
    }
    
    private var settingsButton: some View {
        Button(action: openSettings) {
            Image(systemName: "gearshape")
                .font(.system(size: 14, weight: .medium))
        }
        .buttonStyle(IconButtonStyle())
        .help("Settings")
    }
    
    private var quitButton: some View {
        Button(action: quit) {
            Image(systemName: "power")
                .font(.system(size: 14, weight: .medium))
        }
        .buttonStyle(IconButtonStyle(isDestructive: true))
        .help("Quit VibeMeter")
    }
    
    private func refreshData() {
        Task {
            isRefreshing = true
            await onRefresh()
            isRefreshing = false
        }
    }

    private func openSettings() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.openSettings()
    }

    private func quit() {
        NSApp.terminate(nil)
    }
}