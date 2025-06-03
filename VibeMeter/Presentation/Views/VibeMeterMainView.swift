import SwiftUI

@MainActor
struct VibeMeterMainView: View {
    let settingsManager: any SettingsManagerProtocol
    let userSessionData: MultiProviderUserSessionData
    let loginManager: MultiProviderLoginManager
    
    @Environment(MultiProviderSpendingData.self)
    private var spendingData
    @Environment(CurrencyData.self)
    private var currencyData
    @Environment(\.colorScheme)
    private var colorScheme
    
    @State private var isHovering = false
    @State private var selectedProvider: ServiceProvider?
    
    var body: some View {
        ZStack {
            // Dark glass background for better contrast
            VisualEffectBlur(material: .underWindowBackground, blendingMode: .behindWindow)
            
            VStack(spacing: 0) {
                if userSessionData.isLoggedInToAnyProvider {
                    loggedInContent
                } else {
                    loggedOutContent
                }
            }
        }
        .frame(width: 320, height: userSessionData.isLoggedInToAnyProvider ? 400 : 300)
        .background(.clear)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
    }
    
    // MARK: - Logged In Content
    
    private var loggedInContent: some View {
        VStack(spacing: 0) {
            // Header
            headerSection
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            
            Divider()
                .overlay(Color.white.opacity(0.1))
            
            // Cost table
            costTableView
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            
            Spacer()
            
            // Action buttons
            actionButtons
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
        }
    }
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                // User avatar using Gravatar
                if let email = userSessionData.mostRecentSession?.userEmail,
                   let gravatarURL = GravatarService.shared.gravatarURL(for: email) {
                    AsyncImage(url: gravatarURL) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 40, height: 40)
                                .clipShape(Circle())
                        case .failure(_), .empty:
                            // Fallback to initial
                            Circle()
                                .fill(LinearGradient(
                                    colors: [Color.blue, Color.purple],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ))
                                .frame(width: 40, height: 40)
                                .overlay(
                                    Text(userInitial)
                                        .font(.system(size: 18, weight: .medium))
                                        .foregroundStyle(.white)
                                )
                        @unknown default:
                            Circle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: 40, height: 40)
                        }
                    }
                } else {
                    // No email, show initial
                    Circle()
                        .fill(LinearGradient(
                            colors: [Color.blue, Color.purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(width: 40, height: 40)
                        .overlay(
                            Text(userInitial)
                                .font(.system(size: 18, weight: .medium))
                                .foregroundStyle(.white)
                        )
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    if let email = userSessionData.mostRecentSession?.userEmail {
                        Text(email)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.primary)
                    }
                    
                    Text("\(userSessionData.loggedInProviders.count) provider\(userSessionData.loggedInProviders.count == 1 ? "" : "s") connected")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
            }
        }
    }
    
    private var costTableView: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Total spending header
            HStack {
                Text("Total Spending")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                if let totalSpending = currentSpendingDisplay {
                    Text(totalSpending)
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(.primary)
                } else {
                    Text("No data")
                        .font(.system(size: 14))
                        .foregroundStyle(.tertiary)
                }
            }
            
            // Provider breakdown
            if !spendingData.providersWithData.isEmpty {
                VStack(spacing: 8) {
                    ForEach(spendingData.providersWithData, id: \.self) { provider in
                        providerRow(for: provider)
                    }
                }
                .padding(.top, 8)
            }
            
            // Spending limits
            VStack(spacing: 8) {
                HStack {
                    Label("Warning", systemImage: "exclamationmark.triangle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.orange)
                    
                    Spacer()
                    
                    Text("\(currencyData.selectedSymbol)\(String(format: "%.0f", convertedWarningLimit))")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.orange)
                }
                
                HStack {
                    Label("Limit", systemImage: "xmark.octagon.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.red)
                    
                    Spacer()
                    
                    Text("\(currencyData.selectedSymbol)\(String(format: "%.0f", convertedUpperLimit))")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.red)
                }
            }
            .padding(.top, 12)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.black.opacity(0.1))
            )
        }
    }
    
    private func providerRow(for provider: ServiceProvider) -> some View {
        HStack {
            Image(systemName: provider.iconName)
                .font(.system(size: 14))
                .foregroundStyle(provider.accentColor)
                .frame(width: 20)
            
            Text(provider.displayName)
                .font(.system(size: 12))
                .foregroundStyle(.primary)
            
            Spacer()
            
            if let providerData = spendingData.getSpendingData(for: provider),
               let spending = providerData.displaySpending {
                Text("\(currencyData.selectedSymbol)\(String(format: "%.2f", spending))")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.primary)
            } else {
                Text("--")
                    .font(.system(size: 12))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(selectedProvider == provider ? Color.white.opacity(0.1) : Color.clear)
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedProvider = hovering ? provider : nil
            }
        }
    }
    
    private var actionButtons: some View {
        HStack(spacing: 16) {
            // Refresh button
            Button(action: refreshData) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 14, weight: .medium))
            }
            .buttonStyle(IconButtonStyle())
            .help("Refresh")
            
            // Settings button
            Button(action: openSettings) {
                Image(systemName: "gearshape")
                    .font(.system(size: 14, weight: .medium))
            }
            .buttonStyle(IconButtonStyle())
            .help("Settings")
            
            Spacer()
            
            // Quit button
            Button(action: quit) {
                Image(systemName: "power")
                    .font(.system(size: 14, weight: .medium))
            }
            .buttonStyle(IconButtonStyle(isDestructive: true))
            .help("Quit VibeMeter")
        }
    }
    
    // MARK: - Logged Out Content
    
    private var loggedOutContent: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // App icon and title
            VStack(spacing: 12) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 64, height: 64)
                
                Text("VibeMeter")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(.primary)
                
                Text("Multi-Provider Cost Tracking")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
            
            // Login button
            Button(action: { loginManager.showLoginWindow(for: .cursor) }) {
                Label("Login to Cursor", systemImage: "person.crop.circle.badge.plus")
                    .font(.system(size: 14, weight: .medium))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(ProminentGlassButtonStyle())
            .padding(.horizontal, 40)
            
            Spacer()
            
            // Bottom buttons
            HStack(spacing: 16) {
                Button(action: openSettings) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 14, weight: .medium))
                }
                .buttonStyle(IconButtonStyle())
                .help("Settings")
                
                Spacer()
                
                Button(action: quit) {
                    Image(systemName: "power")
                        .font(.system(size: 14, weight: .medium))
                }
                .buttonStyle(IconButtonStyle(isDestructive: true))
                .help("Quit VibeMeter")
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
    }
    
    // MARK: - Helper Properties and Methods
    
    private var userInitial: String {
        guard let email = userSessionData.mostRecentSession?.userEmail,
              let firstChar = email.first else { return "?" }
        return String(firstChar).uppercased()
    }
    
    private var currentSpendingDisplay: String? {
        let providers = spendingData.providersWithData
        guard !providers.isEmpty else { return nil }
        
        let totalSpending = spendingData.totalSpendingConverted(
            to: currencyData.selectedCode,
            rates: currencyData.currentExchangeRates)
        
        return "\(currencyData.selectedSymbol)\(String(format: "%.2f", totalSpending))"
    }
    
    private var convertedWarningLimit: Double {
        currencyData.convertAmount(
            settingsManager.warningLimitUSD,
            from: "USD",
            to: currencyData.selectedCode) ?? settingsManager.warningLimitUSD
    }
    
    private var convertedUpperLimit: Double {
        currencyData.convertAmount(
            settingsManager.upperLimitUSD,
            from: "USD",
            to: currencyData.selectedCode) ?? settingsManager.upperLimitUSD
    }
    
    private func refreshData() {
        Task {
            // TODO: Implement multi-provider data refresh
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

// MARK: - Visual Effect View

struct VisualEffectBlur: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

// MARK: - Button Styles

struct GlassButtonStyle: ButtonStyle {
    let isDestructive: Bool
    
    init(isDestructive: Bool = false) {
        self.isDestructive = isDestructive
    }
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(configuration.isPressed ? 
                        Color.white.opacity(0.2) : 
                        Color.white.opacity(0.1))
            )
            .foregroundStyle(isDestructive ? .red : .primary)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct ProminentGlassButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(LinearGradient(
                        colors: [
                            Color.blue.opacity(configuration.isPressed ? 0.6 : 0.8),
                            Color.purple.opacity(configuration.isPressed ? 0.6 : 0.8)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
            )
            .foregroundStyle(.white)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct IconButtonStyle: ButtonStyle {
    let isDestructive: Bool
    @State private var isHovering = false
    
    init(isDestructive: Bool = false) {
        self.isDestructive = isDestructive
    }
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(8)
            .background(
                Circle()
                    .fill((isHovering || configuration.isPressed) ? 
                        Color.white.opacity(0.15) : 
                        Color.clear)
            )
            .foregroundStyle(isDestructive ? 
                (isHovering ? .red : .red.opacity(0.8)) : 
                (isHovering ? .primary : .secondary))
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
            .animation(.easeInOut(duration: 0.15), value: isHovering)
            .onHover { hovering in
                isHovering = hovering
            }
    }
}

// MARK: - Provider Extensions

private extension ServiceProvider {
    var accentColor: Color {
        switch self {
        case .cursor:
            return .blue
        }
    }
}

// MARK: - Preview

#Preview("Logged Out") {
    VibeMeterMainView(
        settingsManager: MockSettingsManager(),
        userSessionData: MultiProviderUserSessionData(),
        loginManager: MultiProviderLoginManager(
            providerFactory: ProviderFactory(settingsManager: MockSettingsManager())
        )
    )
    .environment(MultiProviderSpendingData())
    .environment(CurrencyData())
}

#Preview("Logged In") {
    let userSessionData = MultiProviderUserSessionData()
    userSessionData.handleLoginSuccess(
        for: .cursor,
        email: "user@example.com",
        teamName: "Example Team",
        teamId: 123
    )
    
    let spendingData = MultiProviderSpendingData()
    spendingData.updateSpending(
        for: .cursor,
        from: ProviderMonthlyInvoice(
            items: [ProviderInvoiceItem(cents: 2500, description: "Usage", provider: .cursor)],
            pricingDescription: nil,
            provider: .cursor,
            month: 5,
            year: 2025
        ),
        rates: [:],
        targetCurrency: "USD"
    )
    
    return VibeMeterMainView(
        settingsManager: MockSettingsManager(),
        userSessionData: userSessionData,
        loginManager: MultiProviderLoginManager(
            providerFactory: ProviderFactory(settingsManager: MockSettingsManager())
        )
    )
    .environment(spendingData)
    .environment(CurrencyData())
}

// MARK: - Mock Settings Manager for Preview

@MainActor
private class MockSettingsManager: SettingsManagerProtocol {
    var providerSessions: [ServiceProvider: ProviderSession] = [:]
    var selectedCurrencyCode: String = "USD"
    var warningLimitUSD: Double = 200
    var upperLimitUSD: Double = 500
    var refreshIntervalMinutes: Int = 5
    var launchAtLoginEnabled: Bool = false
    var showCostInMenuBar: Bool = true
    var showInDock: Bool = false
    var enabledProviders: Set<ServiceProvider> = [.cursor]
    
    func clearUserSessionData() {
        providerSessions.removeAll()
    }
    
    func clearUserSessionData(for provider: ServiceProvider) {
        providerSessions.removeValue(forKey: provider)
    }
    
    func getSession(for provider: ServiceProvider) -> ProviderSession? {
        providerSessions[provider]
    }
    
    func updateSession(for provider: ServiceProvider, session: ProviderSession) {
        providerSessions[provider] = session
    }
}
