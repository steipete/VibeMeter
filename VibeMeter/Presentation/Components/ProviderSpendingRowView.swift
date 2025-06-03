import SwiftUI

struct ProviderSpendingRowView: View {
    let provider: ServiceProvider
    @Binding var selectedProvider: ServiceProvider?
    
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
        .padding(.horizontal, 4)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(selectedProvider == provider ? Color.white.opacity(0.1) : Color.clear))
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedProvider = hovering ? provider : nil
            }
        }
    }
    
    private var mainProviderRow: some View {
        HStack(spacing: 0) {
            // Icon column - fixed width to align with "Total Spending" label
            Image(systemName: provider.iconName)
                .font(.system(size: 14))
                .foregroundStyle(provider.accentColor)
                .frame(width: 20, alignment: .leading)
            
            // Provider name column - aligned with "Total Spending" text
            Text(provider.displayName)
                .font(.system(size: 12))
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 8)

            // Amount column - aligned with total spending amount
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
    }
    
    private func usageDataRow(usage: ProviderUsageData) -> some View {
        HStack(spacing: 0) {
            // Icon space to align with provider icon above
            Color.clear
                .frame(width: 20)
            
            HStack(spacing: 8) {
                Label("\(usage.currentRequests) / \(usage.maxRequests ?? 0)",
                      systemImage: "number.circle")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)

                Text("requests")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)

                Spacer()

                // Usage bar
                if let maxRequests = usage.maxRequests, maxRequests > 0 {
                    let progress = Double(usage.currentRequests) / Double(maxRequests)
                    ProgressView(value: progress)
                        .progressViewStyle(LinearProgressViewStyle(tint: progressColor(for: progress)))
                        .frame(width: 60, height: 4)
                }
            }
            .padding(.leading, 8)
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