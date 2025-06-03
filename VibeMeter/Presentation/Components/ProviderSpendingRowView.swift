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
            mainProviderRow

            if let providerData = spendingData.getSpendingData(for: provider),
               let usage = providerData.usageData {
                usageDataRow(usage: usage)
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 1)
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
        HStack(spacing: 10) {
            // Provider icon with consistent sizing
            Group {
                if provider.iconName.contains(".") {
                    // System symbol - use font sizing
                    Image(systemName: provider.iconName)
                        .font(.system(size: 16))
                } else {
                    // Custom asset - use resizable with explicit sizing
                    Image(provider.iconName)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                }
            }
            .foregroundStyle(provider.accentColor)
            .frame(width: 18, height: 18)

            // Provider name
            Text(provider.displayName)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)

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
                    
                    Text("\(currencyData.selectedSymbol)\(convertedSpending.formatted(.number.precision(.fractionLength(2))))")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(.primary)
                } else {
                    Text("--")
                        .font(.system(size: 13))
                        .foregroundStyle(.tertiary)
                }
            }
            .frame(minWidth: 50, alignment: .trailing)
        }
    }

    private func usageDataRow(usage: ProviderUsageData) -> some View {
        HStack(spacing: 10) {
            // Align with icon column above
            Color.clear
                .frame(width: 18)

            HStack(spacing: 6) {
                Text("\(usage.currentRequests) / \(usage.maxRequests ?? 0)")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)

                Text("requests")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)

                Spacer()

                // Usage progress bar
                if let maxRequests = usage.maxRequests, maxRequests > 0 {
                    let progress = min(max(Double(usage.currentRequests) / Double(maxRequests), 0.0), 1.0)
                    ProgressView(value: progress)
                        .progressViewStyle(LinearProgressViewStyle(tint: progressColor(for: progress)))
                        .frame(width: 60, height: 4)
                        .background(Color.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 2))
                }
            }
        }
    }

    private func progressColor(for progress: Double) -> Color {
        if progress >= 0.9 {
            .red
        } else if progress >= 0.7 {
            .orange
        } else {
            .green
        }
    }

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

private extension ServiceProvider {
    var accentColor: Color {
        switch self {
        case .cursor:
            .blue
        }
    }
}
