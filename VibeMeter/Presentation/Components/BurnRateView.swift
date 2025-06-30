import SwiftUI

/// Displays burn rate information for a provider
struct BurnRateView: View {
    let burnRateInfo: BurnRateCalculator.BurnRateInfo?
    @State private var showPopover = false
    
    var body: some View {
        if let burnRateInfo = burnRateInfo,
           let burnRate = burnRateInfo.burnRate {
            HStack(spacing: 4) {
                // Velocity indicator
                Text(burnRate.velocityIndicator.rawValue)
                    .font(.caption)
                
                // Burn rate text
                Text(burnRate.formattedRate)
                    .font(.caption)
                    .foregroundStyle(warningColor(for: burnRateInfo.warningLevel))
                    .monospacedDigit()
            }
            .onTapGesture {
                showPopover.toggle()
            }
            .popover(isPresented: $showPopover, arrowEdge: .bottom) {
                burnRatePopoverContent(burnRateInfo: burnRateInfo)
            }
            .help(helpText(for: burnRateInfo))
        }
    }
    
    @ViewBuilder
    private func burnRatePopoverContent(burnRateInfo: BurnRateCalculator.BurnRateInfo) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Burn Rate Analysis")
                .font(.headline)
            
            Divider()
            
            if let burnRate = burnRateInfo.burnRate {
                VStack(alignment: .leading, spacing: 4) {
                    Label {
                        Text(burnRate.formattedRate)
                            .monospacedDigit()
                    } icon: {
                        Image(systemName: "flame.fill")
                            .foregroundStyle(.orange)
                    }
                    
                    if let depletionTime = burnRateInfo.depletionTime {
                        Label {
                            Text("Limit reached in \(formatTimeUntil(depletionTime))")
                        } icon: {
                            Image(systemName: "clock.fill")
                            .foregroundStyle(warningColor(for: burnRateInfo.warningLevel))
                        }
                    }
                    
                    Label {
                        Text(metricDescription(for: burnRate.metric))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } icon: {
                        Image(systemName: "info.circle.fill")
                            .foregroundStyle(.blue)
                    }
                }
            }
            
            // Session information section
            if let sessionInfo = burnRateInfo.sessionInfo {
                Divider()
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Session Details")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    HStack {
                        Image(systemName: sessionInfo.isActive ? "circle.fill" : "circle")
                            .foregroundStyle(sessionInfo.isActive ? .green : .secondary)
                            .font(.caption2)
                        Text(sessionInfo.isActive ? "Active Session" : "No Active Session")
                            .font(.caption)
                            .foregroundStyle(sessionInfo.isActive ? .primary : .secondary)
                    }
                    
                    if sessionInfo.isSessionBased {
                        Label {
                            VStack(alignment: .leading, spacing: 1) {
                                Text("Started: \(formatTime(sessionInfo.sessionStartTime))")
                                Text("Ends: \(formatTime(sessionInfo.sessionEndTime))")
                            }
                            .font(.caption)
                            .monospacedDigit()
                        } icon: {
                            Image(systemName: "timer")
                                .foregroundStyle(.blue)
                        }
                    } else {
                        Label {
                            Text("Using approximate schedule")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } icon: {
                            Image(systemName: "calendar.badge.clock")
                                .foregroundStyle(.orange)
                        }
                    }
                    
                    if sessionInfo.timeRemaining > 0 {
                        Label {
                            Text("Resets in \(formatTimeUntil(sessionInfo.sessionEndTime))")
                                .font(.caption)
                        } icon: {
                            Image(systemName: "hourglass")
                                .foregroundStyle(.purple)
                        }
                        
                        // Progress bar
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Color.secondary.opacity(0.2))
                                    .frame(height: 4)
                                
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(progressColor(for: sessionInfo.sessionProgress))
                                    .frame(width: geometry.size.width * sessionInfo.sessionProgress, height: 4)
                            }
                        }
                        .frame(height: 4)
                        .padding(.top, 2)
                    }
                }
            }
        }
        .padding()
        .frame(minWidth: 300)
    }
    
    private func warningColor(for level: BurnRateCalculator.BurnRateInfo.WarningLevel) -> Color {
        switch level {
        case .none:
            return .secondary
        case .moderate:
            return .orange
        case .high:
            return .red
        }
    }
    
    private func helpText(for burnRateInfo: BurnRateCalculator.BurnRateInfo) -> String {
        guard let burnRate = burnRateInfo.burnRate else { return "" }
        
        var text = "Current burn rate: \(burnRate.formattedRate)"
        
        if let depletionTime = burnRateInfo.depletionTime {
            text += "\nLimit will be reached in \(formatTimeUntil(depletionTime))"
        }
        
        return text
    }
    
    private func metricDescription(for metric: BurnRateCalculator.MetricType) -> String {
        switch metric {
        case .tokens:
            return "Token consumption rate based on last hour of activity"
        case .spending:
            return "Spending rate based on recent usage patterns"
        case .requests:
            return "Request rate based on recent API calls"
        }
    }
    
    private func formatTimeUntil(_ date: Date) -> String {
        let interval = date.timeIntervalSinceNow
        
        if interval < 60 {
            return "less than a minute"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes) minute\(minutes == 1 ? "" : "s")"
        } else {
            let hours = Int(interval / 3600)
            let minutes = Int((interval.truncatingRemainder(dividingBy: 3600)) / 60)
            if minutes > 0 {
                return "\(hours) hour\(hours == 1 ? "" : "s") \(minutes) minute\(minutes == 1 ? "" : "s")"
            } else {
                return "\(hours) hour\(hours == 1 ? "" : "s")"
            }
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter.string(from: date)
    }
    
    private func progressColor(for progress: Double) -> Color {
        switch progress {
        case 0..<0.5:
            return .green
        case 0.5..<0.75:
            return .orange
        case 0.75...1.0:
            return .red
        default:
            return .gray
        }
    }
}

// MARK: - Preview

#Preview("Burn Rate View") {
    VStack(spacing: 20) {
        // Normal burn rate
        BurnRateView(burnRateInfo: BurnRateCalculator.BurnRateInfo(
            provider: .cursor,
            burnRate: BurnRateCalculator.BurnRate(
                ratePerMinute: 0.5,
                ratePerHour: 30,
                metric: .spending,
                velocityIndicator: .normal
            ),
            depletionTime: Date().addingTimeInterval(3600 * 5),
            warningLevel: .none,
            sessionInfo: nil
        ))
        
        // High burn rate with active session
        BurnRateView(burnRateInfo: BurnRateCalculator.BurnRateInfo(
            provider: .claude,
            burnRate: BurnRateCalculator.BurnRate(
                ratePerMinute: 100,
                ratePerHour: 6000,
                metric: .tokens,
                velocityIndicator: .veryFast
            ),
            depletionTime: Date().addingTimeInterval(3600 * 0.5),
            warningLevel: .high,
            sessionInfo: BurnRateCalculator.BurnRateInfo.SessionInfo(
                sessionStartTime: Date().addingTimeInterval(-3600 * 2), // Started 2 hours ago
                sessionEndTime: Date().addingTimeInterval(3600 * 3),   // Ends in 3 hours
                isActive: true,
                isSessionBased: true
            )
        ))
        
        // Moderate burn rate with approximate session
        BurnRateView(burnRateInfo: BurnRateCalculator.BurnRateInfo(
            provider: .claude,
            burnRate: BurnRateCalculator.BurnRate(
                ratePerMinute: 50,
                ratePerHour: 3000,
                metric: .tokens,
                velocityIndicator: .normal
            ),
            depletionTime: Date().addingTimeInterval(3600 * 2),
            warningLevel: .moderate,
            sessionInfo: BurnRateCalculator.BurnRateInfo.SessionInfo(
                sessionStartTime: Date().addingTimeInterval(-3600 * 1),
                sessionEndTime: Date().addingTimeInterval(3600 * 4),
                isActive: false,
                isSessionBased: false
            )
        ))
        
        // No burn rate
        BurnRateView(burnRateInfo: nil)
    }
    .padding()
}