import AppKit
import os.log
import SwiftUI

// MARK: - Logged Out Menu Content

/// Menu content displayed when no providers are logged in.
///
/// This view shows the application branding, login options for supported providers,
/// and basic navigation options. It serves as the entry point for new users to
/// connect their accounts and start tracking spending.
struct LoggedOutMenuContent: View {
    let loginManager: MultiProviderLoginManager
    
    private let logger = Logger(subsystem: "com.vibemeter", category: "LoggedOutMenuContent")

    var body: some View {
        VStack(spacing: 8) {
            headerSection
            
            Divider()
            
            loginButtonsSection
            
            Divider()
            
            navigationSection
            
            Divider()
            
            quitButtonSection
        }
        .padding(12)
        .onAppear {
            logger.info("LoggedOutMenuContent appeared")
        }
    }
    
    // MARK: - View Components
    
    private var headerSection: some View {
        VStack(spacing: 4) {
            Text("VibeMeter")
                .font(.headline)
                .padding(.top, 4)

            Text("Multi-Provider Cost Tracking")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }
    
    private var loginButtonsSection: some View {
        VStack(spacing: 6) {
            ForEach(ServiceProvider.allCases, id: \.self) { provider in
                Group {
                    if provider == .cursor {
                        Button("Login to \(provider.displayName)") {
                            logger.info("User clicked login button for \(provider.displayName)")
                            loginManager.showLoginWindow(for: provider)
                        }
                        .keyboardShortcut("l")
                    } else {
                        Button("Login to \(provider.displayName)") {
                            logger.info("User clicked login button for \(provider.displayName)")
                            loginManager.showLoginWindow(for: provider)
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }
    
    private var navigationSection: some View {
        Button("Settings...") {
            NSApp.openSettings()
        }
        .keyboardShortcut(",")
        .buttonStyle(.plain)
    }
    
    private var quitButtonSection: some View {
        Button("Quit VibeMeter") {
            NSApp.terminate(nil)
        }
        .keyboardShortcut("Q")
        .buttonStyle(.plain)
    }
}