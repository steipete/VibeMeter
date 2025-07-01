import SwiftUI

/// A card component for displaying key metrics in the dashboard grid
struct KeyMetricsCard: View {
    let icon: String
    let iconGradient: LinearGradient
    let title: String
    let value: String
    let subtitle: String
    let trend: TrendIndicator?
    let progress: Double?
    let status: StatusLevel?
    let helpText: String?
    
    @State private var isHovering = false
    
    enum TrendIndicator {
        case up(String)
        case down(String)
        case steady(String)
        
        var color: Color {
            switch self {
            case .up: return .red
            case .down: return .green
            case .steady: return .blue
            }
        }
        
        var text: String {
            switch self {
            case .up(let text), .down(let text), .steady(let text):
                return text
            }
        }
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
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header with icon and title
            HStack(spacing: 8) {
                // Icon with gradient background
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(iconGradient)
                        .frame(width: 32, height: 32)
                        .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
                    
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.white)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text(title)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                        
                        if let helpText {
                            Image(systemName: "questionmark.circle.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(.tertiary)
                                .help(helpText)
                        }
                    }
                    
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(value)
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundStyle(.primary)
                        
                        if let status {
                            Text(status.emoji)
                                .font(.system(size: 10))
                        }
                    }
                }
                
                Spacer()
                
                if let trend {
                    VStack(alignment: .trailing, spacing: 2) {
                        Image(systemName: {
                            switch trend {
                            case .up: return "arrow.up.right"
                            case .down: return "arrow.down.right"
                            case .steady: return "arrow.right"
                            }
                        }())
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(trend.color)
                        
                        Text(trend.text)
                            .font(.system(size: 9))
                            .foregroundStyle(trend.color.opacity(0.8))
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.top, 10)
            .padding(.bottom, 8)
            
            // Progress bar if provided
            if let progress {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.primary.opacity(0.1))
                            .frame(height: 3)
                        
                        RoundedRectangle(cornerRadius: 2)
                            .fill(progressColor(for: progress))
                            .frame(width: geometry.size.width * min(progress, 1.0), height: 3)
                    }
                }
                .frame(height: 3)
                .padding(.horizontal, 10)
                .padding(.bottom, 6)
            }
            
            // Subtitle
            Text(subtitle)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10)
                .padding(.bottom, 10)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.primary.opacity(isHovering ? 0.06 : 0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                )
        )
        .scaleEffect(isHovering ? 1.02 : 1.0)
        .shadow(color: .black.opacity(isHovering ? 0.15 : 0.05), radius: isHovering ? 8 : 4, y: 2)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovering = hovering
            }
        }
    }
    
    private func progressColor(for value: Double) -> Color {
        switch value {
        case 0..<0.7:
            return .green
        case 0.7..<0.9:
            return .orange
        default:
            return .red
        }
    }
}

// MARK: - Convenience Initializers

extension KeyMetricsCard {
    /// Initialize a usage card
    static func usage(
        currentUsage: Double,
        limit: Double,
        plan: String,
        resetTime: String,
        status: StatusLevel
    ) -> KeyMetricsCard {
        let percentage = limit > 0 ? (currentUsage / limit) * 100 : 0
        let formattedUsage = TokenFormatter.format(Int(currentUsage))
        let formattedLimit = TokenFormatter.format(Int(limit))
        
        return KeyMetricsCard(
            icon: "chart.pie.fill",
            iconGradient: LinearGradient(
                colors: [Color.blue, Color.purple],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            title: "Daily Limit",
            value: "\(Int(percentage))%",
            subtitle: "\(plan) • Resets \(resetTime)",
            trend: nil,
            progress: percentage / 100,
            status: status,
            helpText: "Daily usage: \(formattedUsage) of \(formattedLimit) tokens (\(Int(percentage))%)"
        )
    }
    
    /// Initialize a burn rate card
    static func burnRate(
        rate: Double,
        trend: BurnRateCalculator.BurnRate.BurnRateTrend,
        depletionTime: String
    ) -> KeyMetricsCard {
        let trendIndicator: TrendIndicator = {
            switch trend {
            case .accelerating:
                return .up("+\(Int(trend.percentageChange))%")
            case .decelerating:
                return .down("\(Int(trend.percentageChange))%")
            case .steady:
                return .steady("Stable")
            case .erratic:
                return .steady("Variable")
            }
        }()
        
        return KeyMetricsCard(
            icon: "flame.fill",
            iconGradient: LinearGradient(
                colors: [Color.orange, Color.red],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            title: "Burn Rate",
            value: TokenFormatter.formatRate(rate),
            subtitle: "Depletes in \(depletionTime)",
            trend: trendIndicator,
            progress: nil,
            status: nil,
            helpText: "Rate of token consumption per hour"
        )
    }
    
    /// Initialize a today's summary card
    static func todaySummary(
        totalCost: Double,
        tokenCount: Int?,
        providerCount: Int,
        currencySymbol: String
    ) -> KeyMetricsCard {
        let valueText: String
        if let tokens = tokenCount {
            valueText = TokenFormatter.format(tokens)
        } else {
            valueText = "\(currencySymbol)\(String(format: "%.2f", totalCost))"
        }
        
        return KeyMetricsCard(
            icon: "calendar",
            iconGradient: LinearGradient(
                colors: [Color.green, Color.teal],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            title: "Today",
            value: valueText,
            subtitle: "\(providerCount) provider\(providerCount == 1 ? "" : "s") active",
            trend: nil,
            progress: nil,
            status: nil,
            helpText: "Total usage across all providers today"
        )
    }
    
    /// Initialize a velocity card
    static func velocity(
        velocity: VelocityTracker.VelocityInfo,
        recommendation: String?
    ) -> KeyMetricsCard {
        let trendIndicator: TrendIndicator = {
            switch velocity.trend {
            case .increasing:
                return .up("\(velocity.formattedTrend)")
            case .decreasing:
                return .down("\(velocity.formattedTrend)")
            case .stable:
                return .steady("Stable")
            case .starting:
                return .steady("New")
            }
        }()
        
        return KeyMetricsCard(
            icon: "speedometer",
            iconGradient: LinearGradient(
                colors: [Color.purple, Color.pink],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            title: "Velocity",
            value: velocity.formattedRate,
            subtitle: recommendation ?? "Usage acceleration",
            trend: trendIndicator,
            progress: nil,
            status: nil,
            helpText: "How quickly your usage is changing"
        )
    }
}

// MARK: - Preview

#Preview("Key Metrics Cards") {
    VStack(spacing: 12) {
        HStack(spacing: 12) {
            KeyMetricsCard.usage(
                currentUsage: 150_000,
                limit: 200_000,
                plan: "Claude Pro",
                resetTime: "in 2h 15m",
                status: .warning
            )
            
            KeyMetricsCard.burnRate(
                rate: 8500,
                trend: BurnRateCalculator.BurnRate.BurnRateTrend.accelerating(percentageChange: 15),
                depletionTime: "3h 45m"
            )
        }
        
        HStack(spacing: 12) {
            KeyMetricsCard.todaySummary(
                totalCost: 4.97,
                tokenCount: 45_320,
                providerCount: 2,
                currencySymbol: "$"
            )
            
            KeyMetricsCard.velocity(
                velocity: VelocityTracker.VelocityInfo(
                    current: 1250,
                    average24h: 1100,
                    average7d: 980,
                    trend: .increasing,
                    trendPercent: 27,
                    peakHour: 14,
                    isAccelerating: false
                ),
                recommendation: "Peak hours: 2-4 PM"
            )
        }
    }
    .padding()
    .frame(width: 400, height: 300)
    .background(Color(NSColor.windowBackgroundColor))
}