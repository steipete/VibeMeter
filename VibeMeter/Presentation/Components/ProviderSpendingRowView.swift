import SwiftUI

/// Individual row component displaying spending data for a single service provider.
///
/// This view shows provider-specific information including provider name, icon, spending amount,
/// and usage metrics with progress indicators. It supports hover states and provides detailed
/// usage information for request quotas and consumption tracking.
struct ProviderSpendingRowView: View {
    let provider: ServiceProvider
    let loginManager: MultiProviderLoginManager?
    @Binding
    var selectedProvider: ServiceProvider?
    let showTimestamp: Bool

    @Environment(MultiProviderSpendingData.self)
    private var spendingData
    @Environment(CurrencyData.self)
    private var currencyData
    @Environment(\.colorScheme)
    private var colorScheme

    init(
        provider: ServiceProvider,
        loginManager: MultiProviderLoginManager?,
        selectedProvider: Binding<ServiceProvider?>,
        showTimestamp: Bool = true) {
        self.provider = provider
        self.loginManager = loginManager
        self._selectedProvider = selectedProvider
        self.showTimestamp = showTimestamp
    }

    var body: some View {
        VStack(spacing: 1) {
            mainProviderRow

            // Show usage data and optionally last refresh on second line
            HStack {
                // Align with icon column above (20px wide from mainProviderRow)
                Color.clear
                    .frame(width: 20)

                // Usage data badge with extended progress bar
                if let providerData = spendingData.getSpendingData(for: provider),
                   let usage = providerData.usageData,
                   let maxRequests = usage.maxRequests, maxRequests > 0 {
                    usageDataBadge(usage: usage, maxRequests: maxRequests)
                }

                Spacer()

                // Last refresh timestamp (only if enabled)
                if showTimestamp,
                   let providerData = spendingData.getSpendingData(for: provider),
                   let lastRefresh = providerData.lastSuccessfulRefresh {
                    RelativeTimestampView(
                        date: lastRefresh,
                        style: .withPrefix,
                        showFreshnessColor: false)
                        .font(.caption)
                        .foregroundStyle(.quaternary)
                }
            }
            .frame(minHeight: showTimestamp ? 12 : 16) // Slightly taller when no timestamp
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2) // Reduce vertical padding
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(selectedProvider == provider ? Color.selectionBackground(for: colorScheme) : Color.clear))
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedProvider = hovering ? provider : nil
            }
        }
        .onTapGesture {
            openProviderDashboard()
        }
        .id(providerRowId)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(providerAccessibilityLabel)
        .accessibilityHint("Double tap to open \(provider.displayName) dashboard")
        .accessibilityAddTraits(.isButton)
    }

    private var mainProviderRow: some View {
        HStack(spacing: 8) {
            // Provider icon with status badge overlay
            ZStack(alignment: .topTrailing) {
                Group {
                    if provider.iconName.contains(".") {
                        // System symbol - use font sizing
                        Image(systemName: provider.iconName)
                            .font(.body)
                    } else {
                        // Custom asset - use resizable with explicit sizing
                        Image(provider.iconName)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    }
                }
                .foregroundStyle(provider.accentColor)
                .frame(width: 16, height: 16)

                // Status badge overlay
                if let providerData = spendingData.getSpendingData(for: provider) {
                    ProviderStatusBadge(
                        status: providerData.connectionStatus,
                        size: 10)
                        .offset(x: 4, y: -4)
                }
            }
            .frame(width: 20, height: 16) // Reduce height while keeping width for alignment

            // Provider name
            Text(provider.displayName)
                .font(.body.weight(.medium))
                .foregroundStyle(.primary)
                .accessibilityAddTraits(.isHeader)

            Spacer()

            // Amount with consistent number formatting
            Group {
                if let providerData = spendingData.getSpendingData(for: provider),
                   let spendingUSD = providerData.currentSpendingUSD {
                    // Convert using current rates for consistency with total
                    let convertedSpending = currencyData.selectedCode == "USD" ? spendingUSD :
                        ExchangeRateManager.shared.convert(
                            spendingUSD,
                            from: "USD",
                            to: currencyData.selectedCode,
                            rates: currencyData.effectiveRates) ?? spendingUSD

                    Text(
                        "\(currencyData.selectedSymbol)\(convertedSpending.formatted(.number.precision(.fractionLength(2))))")
                        .font(.body.weight(.semibold).monospaced())
                        .foregroundStyle(.primary)
                        .accessibilityLabel(
                            "Spending: \(currencyData.selectedSymbol)\(convertedSpending.formatted(.number.precision(.fractionLength(2))))")
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                        .animation(.easeOut(duration: 0.3), value: spendingUSD)
                } else {
                    Text("--")
                        .font(.body)
                        .foregroundStyle(.tertiary)
                        .accessibilityLabel("No spending data")
                }
            }
        }
    }

    private func usageDataBadge(usage: ProviderUsageData, maxRequests: Int) -> some View {
        let progress = min(max(Double(usage.currentRequests) / Double(maxRequests), 0.0), 1.0)
        let progressPercentage = Int((progress * 100).rounded())
        return HStack(spacing: 6) {
            Text("\(usage.currentRequests)/\(maxRequests)")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .accessibilityLabel("Usage: \(usage.currentRequests) of \(maxRequests) requests")
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
                .animation(.easeOut(duration: 0.3), value: usage.currentRequests)

            CustomProgressBar(
                progress: progress,
                progressColor: Color.progressColor(for: progress, colorScheme: colorScheme),
                backgroundColor: Color.gaugeBackground(for: colorScheme))
                .frame(width: showTimestamp ? 60 : 80, height: 3) // Extended width, larger when no timestamp
                .accessibilityLabel("Usage progress: \(progressPercentage) percent")
                .accessibilityValue("\(usage.currentRequests) requests used out of \(maxRequests) allowed")
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
                .animation(.easeOut(duration: 0.3), value: progress)
        }
        .accessibilityElement(children: .combine)
    }

    // Progress color logic moved to ProgressColorHelper

    private func openProviderDashboard() {
        guard let loginManager,
              let authToken = loginManager.getAuthToken(for: provider) else {
            // Fallback to opening without auth
            BrowserAuthenticationHelper.openURL(provider.dashboardURL)
            return
        }

        // For providers that support authenticated browser sessions,
        // we can create a URL with the session token
        switch provider {
        case .cursor:
            if !BrowserAuthenticationHelper.openCursorDashboardWithAuth(authToken: authToken) {
                // Fallback to opening dashboard without auth
                BrowserAuthenticationHelper.openURL(provider.dashboardURL)
            }
        }
    }

    /// Unique identifier for SwiftUI performance optimization
    private var providerRowId: String {
        let providerData = spendingData.getSpendingData(for: provider)
        var hasher = Hasher()
        hasher.combine(provider.rawValue)
        hasher.combine(providerData?.currentSpendingUSD ?? 0)
        hasher.combine(providerData?.lastSuccessfulRefresh?.timeIntervalSince1970 ?? 0)
        hasher.combine(currencyData.selectedCode)
        hasher.combine(selectedProvider == provider)
        hasher.combine(showTimestamp)
        return "\(provider.rawValue)-\(hasher.finalize())"
    }

    /// Accessibility label for the entire provider row
    private var providerAccessibilityLabel: String {
        var components: [String] = [provider.displayName]

        if let providerData = spendingData.getSpendingData(for: provider),
           let spendingUSD = providerData.currentSpendingUSD {
            let convertedSpending = currencyData.selectedCode == "USD" ? spendingUSD :
                ExchangeRateManager.shared.convert(
                    spendingUSD,
                    from: "USD",
                    to: currencyData.selectedCode,
                    rates: currencyData.effectiveRates) ?? spendingUSD
            components
                .append(
                    "spending \(currencyData.selectedSymbol)\(convertedSpending.formatted(.number.precision(.fractionLength(2))))")
        } else {
            components.append("no spending data")
        }

        return components.joined(separator: ", ")
    }
}

/// Custom progress bar that works with drawingGroup() by using Canvas instead of NSProgressIndicator
private struct CustomProgressBar: View {
    let progress: Double
    let progressColor: Color
    let backgroundColor: Color
    
    @State private var animatedProgress: Double = 0
    
    var body: some View {
        Canvas { context, size in
            let cornerRadius: CGFloat = 1.5
            let backgroundRect = CGRect(origin: .zero, size: size)
            let progressWidth = size.width * animatedProgress
            let progressRect = CGRect(x: 0, y: 0, width: progressWidth, height: size.height)
            
            // Draw background
            context.fill(
                Path(roundedRect: backgroundRect, cornerRadius: cornerRadius),
                with: .color(backgroundColor))
            
            // Draw progress fill
            if animatedProgress > 0 {
                context.fill(
                    Path(roundedRect: progressRect, cornerRadius: cornerRadius),
                    with: .color(progressColor))
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.4)) {
                animatedProgress = progress
            }
        }
        .onChange(of: progress) { _, newValue in
            withAnimation(.easeOut(duration: 0.3)) {
                animatedProgress = newValue
            }
        }
    }
}

/// ServiceProvider extension defining accent colors for UI theming.
///
/// This private extension provides the accent color for each service provider,
/// used for visual consistency in icons and highlights throughout the UI.
private extension ServiceProvider {
    var accentColor: Color {
        switch self {
        case .cursor:
            .blue
        }
    }
}

// MARK: - Preview

#Preview("Provider Spending Row - With Data") {
    @Previewable @State
    var selectedProvider: ServiceProvider?

    let spendingData = MultiProviderSpendingData()
    let currencyData = CurrencyData()

    // Add sample data
    spendingData.updateSpending(
        for: .cursor,
        from: ProviderMonthlyInvoice(
            items: [
                ProviderInvoiceItem(cents: 2497, description: "Pro Usage", provider: .cursor),
            ],
            pricingDescription: nil,
            provider: .cursor,
            month: 5,
            year: 2025),
        rates: [:],
        targetCurrency: "USD")

    spendingData.updateUsage(
        for: .cursor,
        from: ProviderUsageData(
            currentRequests: 350,
            totalRequests: 4387,
            maxRequests: 500,
            startOfMonth: Date(),
            provider: .cursor))

    return VStack(spacing: 16) {
        ProviderSpendingRowView(
            provider: .cursor,
            loginManager: nil,
            selectedProvider: $selectedProvider,
            showTimestamp: true)
            .environment(spendingData)
            .environment(currencyData)

        Text("Selected: \(selectedProvider?.displayName ?? "None")")
            .font(.caption)
            .foregroundStyle(.secondary)
    }
    .padding()
    .frame(width: 320, height: 100)
    .background(Color(NSColor.windowBackgroundColor))
}

#Preview("Provider Spending Row - Loading") {
    @Previewable @State
    var selectedProvider: ServiceProvider?

    let spendingData = MultiProviderSpendingData()
    let currencyData = CurrencyData()

    return ProviderSpendingRowView(
        provider: .cursor,
        loginManager: nil,
        selectedProvider: $selectedProvider,
        showTimestamp: true)
        .environment(spendingData)
        .environment(currencyData)
        .padding()
        .frame(width: 320)
        .background(Color(NSColor.windowBackgroundColor))
}
