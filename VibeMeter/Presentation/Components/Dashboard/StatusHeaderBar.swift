import SwiftUI

/// Enhanced status header bar with real-time indicators
struct StatusHeaderBar: View {
    @Environment(MultiProviderSpendingData.self) private var spendingData
    @Environment(\.userSessionData) private var userSessionData: MultiProviderUserSessionData?
    
    @State private var isPulsing = false
    
    private var overallStatus: StatusLevel {
        let maxPercentage = spendingData.providersWithData.compactMap { provider -> Double? in
            guard let data = spendingData.getSpendingData(for: provider),
                  let usage = data.usageData else { return nil }
            
            if provider == .claude {
                // For Claude, currentRequests is already a percentage
                return Double(usage.currentRequests)
            } else if let maxRequests = usage.maxRequests, maxRequests > 0 {
                return (Double(usage.currentRequests) / Double(maxRequests)) * 100
            }
            return nil
        }.max() ?? 0
        
        switch maxPercentage {
        case 90...:
            return .critical
        case 70..<90:
            return .warning
        default:
            return .safe
        }
    }
    
    private var isSyncing: Bool {
        spendingData.providersWithData.contains { provider in
            spendingData.getSpendingData(for: provider)?.connectionStatus == .syncing
        }
    }
    
    private var connectedProviderCount: Int {
        userSessionData?.loggedInProviders.count ?? 0
    }
    
    enum StatusLevel {
        case safe
        case warning
        case critical
        
        var color: Color {
            switch self {
            case .safe: return .green
            case .warning: return .orange
            case .critical: return .red
            }
        }
        
        var emoji: String {
            switch self {
            case .safe: return "🟢"
            case .warning: return "🟡"
            case .critical: return "🔴"
            }
        }
        
        var text: String {
            switch self {
            case .safe: return "Safe Usage"
            case .warning: return "High Usage"
            case .critical: return "Critical Usage"
            }
        }
        
        var description: String {
            switch self {
            case .safe: return "Less than 70% of daily limit used"
            case .warning: return "70-90% of daily limit used"
            case .critical: return "Over 90% of daily limit used"
            }
        }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Status indicator with tooltip
            HStack(spacing: 6) {
                Text(overallStatus.emoji)
                    .font(.system(size: 12))
                
                VStack(alignment: .leading, spacing: 0) {
                    Text(overallStatus.text)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.primary)
                    
                    Text(overallStatus.description)
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(overallStatus.color.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(overallStatus.color.opacity(0.3), lineWidth: 1)
                    )
            )
            
            Spacer()
            
            // Connected providers badge
            if connectedProviderCount > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "link.circle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    
                    Text("\(connectedProviderCount)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.primary)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(
                    Capsule()
                        .fill(Color.primary.opacity(0.08))
                )
                .help("\(connectedProviderCount) provider\(connectedProviderCount == 1 ? "" : "s") connected")
            }
            
            // Sync indicator
            if isSyncing {
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 6, height: 6)
                        .scaleEffect(isPulsing ? 1.2 : 0.8)
                        .opacity(isPulsing ? 0.6 : 1.0)
                        .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: isPulsing)
                        .onAppear {
                            isPulsing = true
                        }
                    
                    Text("Syncing")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(
                    Capsule()
                        .fill(Color.blue.opacity(0.1))
                )
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            Rectangle()
                .fill(Color.primary.opacity(0.03))
                .overlay(
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.primary.opacity(0.05),
                                    Color.clear
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(height: 1),
                    alignment: .bottom
                )
        )
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 0) {
        StatusHeaderBar()
        
        Spacer()
    }
    .frame(width: 320, height: 400)
    .background(Color(NSColor.windowBackgroundColor))
    .environment(MultiProviderSpendingData())
    .environment(\.userSessionData, MultiProviderUserSessionData())
}