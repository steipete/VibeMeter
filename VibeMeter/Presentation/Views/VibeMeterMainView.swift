import SwiftUI

/// Main view for the VibeMeter menu bar application that displays either logged-in or logged-out content.
///
/// This view serves as the primary interface for the application, conditionally showing
/// either the full spending dashboard when users are logged in to providers or a login
/// interface when no providers are connected.
@MainActor
struct VibeMeterMainView: View {
    @Environment(\.settingsManager)
    private var settingsManager: (any SettingsManagerProtocol)?
    @Environment(\.userSessionData)
    private var userSessionData: MultiProviderUserSessionData?
    @Environment(\.loginManager)
    private var loginManager: MultiProviderLoginManager?
    @Environment(\.refreshAction)
    private var onRefresh: (@Sendable () async -> Void)?

    @State
    private var claudeLogManager = ClaudeLogManager.shared

    var body: some View {
        if settingsManager != nil,
           let userSessionData,
           loginManager != nil,
           onRefresh != nil {
            Group {
                // Always show the main UI - most computers will have Claude
                LoggedInContentView()
            }
            .frame(minWidth: 320)
            .fixedSize()
            .accessibilityElement(children: .contain)
            .accessibilityLabel("VibeMeter main interface")
            .accessibilityHint(userSessionData.isLoggedInToAnyProvider || claudeLogManager.hasAccess ?
                "Shows AI service spending dashboard and controls" :
                "Shows login options for AI service providers")
        } else {
            // Fallback view when dependencies are missing
            VStack(spacing: 16) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.largeTitle)
                    .foregroundStyle(.orange)

                Text("Configuration Error")
                    .font(.headline)

                Text("Required dependencies not available")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(minWidth: 320)
            .fixedSize()
            .padding()
            .background(
                // Use an invisible view to handle key events
                Color.clear
                    .contentShape(Rectangle())
                    .focusable()
                    .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { _ in
                        // Set up ESC key handling when window becomes key
                        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                            if event.keyCode == 53 { // ESC key
                                // Look for any borderless window that might be our menu
                                for window in NSApp.windows {
                                    if window.styleMask.contains(.borderless), window.isVisible,
                                       window.level == .popUpMenu {
                                        window.orderOut(nil)
                                        return nil // Consume the event
                                    }
                                }
                            }
                            return event // Pass through other events
                        }
                    })
        }
    }
}

// MARK: - Preview

#Preview("Logged Out") {
    VibeMeterMainView()
        .settingsManager(MockSettingsManager())
        .userSessionData(MultiProviderUserSessionData())
        .loginManager(MultiProviderLoginManager(
            providerFactory: ProviderFactory(settingsManager: MockSettingsManager())))
        .refreshAction {}
        .environment(MultiProviderSpendingData())
        .environment(CurrencyData())
}

#Preview("Logged In") {
    let userSessionData = MultiProviderUserSessionData()
    userSessionData.handleLoginSuccess(
        for: .cursor,
        email: "user@example.com",
        teamName: "Example Team",
        teamId: 123)

    let spendingData = MultiProviderSpendingData()
    spendingData.updateSpending(
        for: .cursor,
        from: ProviderMonthlyInvoice(
            items: [ProviderInvoiceItem(cents: 2500, description: "Usage", provider: .cursor)],
            pricingDescription: nil,
            provider: .cursor,
            month: 5,
            year: 2025),
        rates: [:],
        targetCurrency: "USD")

    spendingData.updateUsage(
        for: .cursor,
        from: ProviderUsageData(
            currentRequests: 1535,
            totalRequests: 4387,
            maxRequests: 500,
            startOfMonth: Date(),
            provider: .cursor))

    return VibeMeterMainView()
        .settingsManager(MockSettingsManager())
        .userSessionData(userSessionData)
        .loginManager(MultiProviderLoginManager(
            providerFactory: ProviderFactory(settingsManager: MockSettingsManager())))
        .refreshAction {}
        .environment(spendingData)
        .environment(CurrencyData())
}

// MARK: - Helper Methods

private extension VibeMeterMainView {
    func handleEscapeKey() -> KeyPress.Result {
        for window in NSApp.windows {
            if window.styleMask.contains(.borderless), window.isVisible, window.level == .popUpMenu {
                window.orderOut(nil)
                return .handled
            }
        }
        return .ignored
    }

    func openSettingsToProvidersTab() {
        // Open settings window first
        NSApp.openSettings()

        // Post notification to switch to providers tab after a brief delay
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(150))
            NotificationCenter.default.post(
                name: .openSettingsTab,
                object: MultiProviderSettingsTab.providers)
        }
    }
}
