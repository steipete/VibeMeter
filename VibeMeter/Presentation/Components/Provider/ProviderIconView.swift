import SwiftUI

/// Displays a provider icon with status badge overlay.
///
/// This view handles rendering of both system and custom provider icons
/// with consistent sizing and status badge positioning.
struct ProviderIconView: View {
    let provider: ServiceProvider
    let spendingData: MultiProviderSpendingData
    
    var body: some View {
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

#Preview {
    let spendingData = MultiProviderSpendingData()
    
    HStack(spacing: 16) {
        ProviderIconView(provider: .cursor, spendingData: spendingData)
        
        // Add some connection status examples
        let connectingData = MultiProviderSpendingData()
        ProviderIconView(provider: .cursor, spendingData: connectingData)
    }
    .padding()
    .background(Color(NSColor.windowBackgroundColor))
}