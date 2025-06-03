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

    @Environment(MultiProviderSpendingData.self)
    private var spendingData
    @Environment(CurrencyData.self)
    private var currencyData

    var body: some View {
        VStack(spacing: 2) {
            HStack(spacing: 0) {
                mainProviderRow

                // Integrate usage data inline instead of separate row
                if let providerData = spendingData.getSpendingData(for: provider),
                   let usage = providerData.usageData,
                   let maxRequests = usage.maxRequests, maxRequests > 0 {
                    Divider()
                        .frame(height: 16)
                        .padding(.horizontal, 8)

                    usageDataBadge(usage: usage, maxRequests: maxRequests)
                }
            }

            // Show last refresh timestamp if available
            if let providerData = spendingData.getSpendingData(for: provider),
               let lastRefresh = providerData.lastSuccessfulRefresh {
                lastRefreshRow(date: lastRefresh)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(selectedProvider == provider ? Color.white.opacity(0.08) : Color.clear))
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedProvider = hovering ? provider : nil
            }
        }
        .onTapGesture {
            openProviderDashboard()
        }
    }

    private var mainProviderRow: some View {
        HStack(spacing: 8) {
            // Provider icon with status badge overlay
            ZStack(alignment: .topTrailing) {
                Group {
                    if provider.iconName.contains(".") {
                        // System symbol - use font sizing
                        Image(systemName: provider.iconName)
                            .font(.system(size: 14))
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
            .frame(width: 20, height: 20) // Give space for badge

            // Provider name
            Text(provider.displayName)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.primary)

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
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(.primary)
                } else {
                    Text("--")
                        .font(.system(size: 12))
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }

    private func usageDataBadge(usage: ProviderUsageData, maxRequests: Int) -> some View {
        let progress = min(max(Double(usage.currentRequests) / Double(maxRequests), 0.0), 1.0)
        return HStack(spacing: 4) {
            Text("\(usage.currentRequests)/\(maxRequests)")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)

            ProgressView(value: progress)
                .progressViewStyle(LinearProgressViewStyle(tint: ProgressColorHelper.color(for: progress)))
                .frame(width: 40, height: 3)
                .background(Color.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 1.5))
        }
    }

    private func lastRefreshRow(date: Date) -> some View {
        HStack {
            // Align with icon column above (20px wide from mainProviderRow)
            Color.clear
                .frame(width: 20)

            RelativeTimestampView(
                date: date,
                style: .withPrefix,
                showFreshnessColor: false)
                .font(.system(size: 9))
                .foregroundStyle(.quaternary)

            Spacer()
        }
    }

    // Progress color logic moved to ProgressColorHelper

    private func openProviderDashboard() {
        guard let loginManager,
              let authToken = loginManager.getAuthToken(for: provider) else {
            // Fallback to opening without auth
            openProviderURL(provider.dashboardURL)
            return
        }

        // For providers that support authenticated browser sessions,
        // we can create a URL with the session token
        switch provider {
        case .cursor:
            openCursorDashboardWithAuth(authToken: authToken)
        }
    }

    private func openCursorDashboardWithAuth(authToken: String) {
        // Create a temporary HTML file that sets the cookie and redirects to dashboard
        let htmlContent = """
        <!DOCTYPE html>
        <html>
        <head>
            <title>Redirecting to Cursor Dashboard...</title>
            <script>
                // Set the authentication cookie
                document.cookie = "WorkosCursorSessionToken=\(authToken); domain=.cursor.com; path=/";
                // Redirect to analytics
                window.location.href = "https://www.cursor.com/analytics";
            </script>
        </head>
        <body>
            <p>Redirecting to Cursor Dashboard...</p>
        </body>
        </html>
        """

        // Write to temporary file and open
        let tempDir = FileManager.default.temporaryDirectory
        let tempFile = tempDir.appendingPathComponent("cursor_redirect.html")

        do {
            try htmlContent.write(to: tempFile, atomically: true, encoding: .utf8)
            NSWorkspace.shared.open(tempFile)
        } catch {
            // Fallback to opening dashboard without auth
            openProviderURL(provider.dashboardURL)
        }
    }

    private func openProviderURL(_ url: URL) {
        NSWorkspace.shared.open(url)
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
            selectedProvider: $selectedProvider)
            .environment(spendingData)
            .environment(currencyData)

        Text("Selected: \(selectedProvider?.displayName ?? "None")")
            .font(.caption)
            .foregroundStyle(.secondary)
    }
    .padding()
    .frame(width: 320)
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
        selectedProvider: $selectedProvider)
        .environment(spendingData)
        .environment(currencyData)
        .padding()
        .frame(width: 320)
        .background(Color(NSColor.windowBackgroundColor))
}
