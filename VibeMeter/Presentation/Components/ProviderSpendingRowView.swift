import SwiftUI

struct ProviderSpendingRowView: View {
    let provider: ServiceProvider
    @Binding
    var selectedProvider: ServiceProvider?

    @Environment(MultiProviderSpendingData.self)
    private var spendingData
    @Environment(CurrencyData.self)
    private var currencyData

    var body: some View {
        VStack(spacing: 8) {
            mainProviderRow

            if let providerData = spendingData.getSpendingData(for: provider),
               let usage = providerData.usageData {
                usageDataRow(usage: usage)
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
    }

    private var mainProviderRow: some View {
        HStack(spacing: 12) {
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
            .frame(width: 20, height: 20)

            // Provider name
            Text(provider.displayName)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Amount with consistent number formatting
            Group {
                if let providerData = spendingData.getSpendingData(for: provider),
                   let spending = providerData.displaySpending {
                    Text("\(currencyData.selectedSymbol)\(String(format: "%.2f", spending))")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(.primary)
                } else {
                    Text("--")
                        .font(.system(size: 14))
                        .foregroundStyle(.tertiary)
                }
            }
            .frame(minWidth: 60, alignment: .trailing)
        }
    }

    private func usageDataRow(usage: ProviderUsageData) -> some View {
        HStack(spacing: 12) {
            // Align with icon column above
            Color.clear
                .frame(width: 20)

            HStack(spacing: 8) {
                Label("\(usage.currentRequests) / \(usage.maxRequests ?? 0)",
                      systemImage: "chart.bar.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)

                Text("requests")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)

                Spacer()

                // Usage progress bar
                if let maxRequests = usage.maxRequests, maxRequests > 0 {
                    let progress = min(max(Double(usage.currentRequests) / Double(maxRequests), 0.0), 1.0)
                    ProgressView(value: progress)
                        .progressViewStyle(LinearProgressViewStyle(tint: progressColor(for: progress)))
                        .frame(width: 80, height: 6)
                        .background(Color.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 3))
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
}

private extension ServiceProvider {
    var accentColor: Color {
        switch self {
        case .cursor:
            .blue
        }
    }
}
