import SwiftUI
import Charts

/// Main analytics dashboard view with comprehensive usage insights
struct AnalyticsDashboardView: View {
    @StateObject private var viewModel = AnalyticsDashboardViewModel()
    @State private var selectedProvider: ServiceProvider = .claude
    @State private var selectedTimeRange: TimeRange = .day
    
    enum TimeRange: String, CaseIterable {
        case hour = "1H"
        case day = "24H"
        case week = "7D"
        case month = "30D"
        
        var interval: TimeInterval {
            switch self {
            case .hour: return 3600
            case .day: return 86400
            case .week: return 604800
            case .month: return 2592000
            }
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header with provider selector
                headerView
                
                // Real-time stats cards
                realTimeStatsView
                
                // Burn rate chart
                burnRateChartView
                
                // Velocity and trends
                velocityTrendsView
                
                // Session analysis (Claude only)
                if selectedProvider == .claude {
                    sessionAnalysisView
                }
                
                // Predictions and recommendations
                predictionsView
                
                // Anomaly alerts
                anomalyAlertsView
            }
            .padding()
        }
        .frame(minWidth: 800, minHeight: 600)
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear {
            viewModel.startMonitoring()
        }
        .onDisappear {
            viewModel.stopMonitoring()
        }
    }
    
    // MARK: - Header View
    
    private var headerView: some View {
        HStack {
            Text("Analytics Dashboard")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Spacer()
            
            // Provider selector
            Picker("Provider", selection: $selectedProvider) {
                ForEach(ServiceProvider.allCases, id: \.self) { provider in
                    Text(provider.displayName).tag(provider)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .frame(width: 200)
            
            // Time range selector
            Picker("Time Range", selection: $selectedTimeRange) {
                ForEach(TimeRange.allCases, id: \.self) { range in
                    Text(range.rawValue).tag(range)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .frame(width: 150)
        }
    }
    
    // MARK: - Real-time Stats
    
    private var realTimeStatsView: some View {
        HStack(spacing: 15) {
            // Current usage
            StatCard(
                title: "Current Usage",
                value: viewModel.getCurrentUsageText(for: selectedProvider),
                trend: viewModel.getUsageTrend(for: selectedProvider),
                color: .blue
            )
            
            // Burn rate
            StatCard(
                title: "Burn Rate",
                value: viewModel.getBurnRateText(for: selectedProvider),
                trend: viewModel.getBurnRateTrend(for: selectedProvider),
                color: .orange
            )
            
            // Time remaining
            StatCard(
                title: "Time Remaining",
                value: viewModel.getTimeRemainingText(for: selectedProvider),
                trend: nil,
                color: .green
            )
            
            // Efficiency
            StatCard(
                title: "Efficiency",
                value: viewModel.getEfficiencyText(for: selectedProvider),
                trend: viewModel.getEfficiencyTrend(for: selectedProvider),
                color: .purple
            )
        }
    }
    
    // MARK: - Burn Rate Chart
    
    private var burnRateChartView: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Burn Rate History")
                .font(.headline)
            
            Chart(viewModel.getBurnRateHistory(for: selectedProvider, range: selectedTimeRange)) { dataPoint in
                LineMark(
                    x: .value("Time", dataPoint.timestamp),
                    y: .value("Rate", dataPoint.rate)
                )
                .foregroundStyle(.orange)
                .interpolationMethod(.catmullRom)
                
                AreaMark(
                    x: .value("Time", dataPoint.timestamp),
                    y: .value("Rate", dataPoint.rate)
                )
                .foregroundStyle(.orange.opacity(0.1))
            }
            .frame(height: 200)
            .chartYAxisLabel("Tokens/Hour")
            .chartXAxis {
                AxisMarks(values: .automatic) { _ in
                    AxisGridLine()
                    AxisTick()
                    AxisValueLabel(format: .dateTime.hour())
                }
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(10)
    }
    
    // MARK: - Velocity Trends
    
    private var velocityTrendsView: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Usage Velocity & Trends")
                .font(.headline)
            
            HStack(spacing: 20) {
                // Velocity gauge
                VelocityGauge(velocity: viewModel.getVelocity(for: selectedProvider))
                
                // Trend indicators
                VStack(alignment: .leading, spacing: 8) {
                    TrendRow(label: "Current", value: viewModel.getCurrentVelocityText(for: selectedProvider))
                    TrendRow(label: "24h Avg", value: viewModel.get24hVelocityText(for: selectedProvider))
                    TrendRow(label: "7d Avg", value: viewModel.get7dVelocityText(for: selectedProvider))
                    TrendRow(label: "Peak Hour", value: viewModel.getPeakHourText(for: selectedProvider))
                }
                
                Spacer()
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(10)
    }
    
    // MARK: - Session Analysis
    
    private var sessionAnalysisView: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Session Analysis")
                .font(.headline)
            
            if let analysis = viewModel.getSessionAnalysis() {
                HStack(spacing: 30) {
                    // Session stats
                    VStack(alignment: .leading, spacing: 5) {
                        StatRow(label: "Active Sessions", value: "\(analysis.totalSessions)")
                        StatRow(label: "Avg Length", value: analysis.formattedAverageLength)
                        StatRow(label: "Utilization", value: "\(Int(analysis.utilizationRate))%")
                    }
                    
                    // Gap analysis
                    VStack(alignment: .leading, spacing: 5) {
                        StatRow(label: "Total Gaps", value: "\(analysis.totalGaps)")
                        StatRow(label: "Avg Gap", value: analysis.formattedAverageGap)
                        StatRow(label: "Sessions/Hour", value: String(format: "%.1f", analysis.sessionsPerHour))
                    }
                    
                    Spacer()
                    
                    // Visual session timeline
                    SessionTimeline(sessions: analysis.recentSessions)
                        .frame(width: 300)
                }
                
                // Anomalies
                if !analysis.anomalies.isEmpty {
                    Divider()
                    VStack(alignment: .leading, spacing: 5) {
                        ForEach(analysis.anomalies, id: \.self) { anomaly in
                            Label(anomaly, systemImage: "exclamationmark.triangle")
                                .foregroundColor(.orange)
                                .font(.caption)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(10)
    }
    
    // MARK: - Predictions
    
    private var predictionsView: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Predictions & Recommendations")
                .font(.headline)
            
            if let prediction = viewModel.getPrediction(for: selectedProvider) {
                HStack(spacing: 30) {
                    // Depletion forecast
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "clock.arrow.circlepath")
                                .foregroundColor(.blue)
                            Text("Depletion: \(prediction.depletionText)")
                                .fontWeight(.medium)
                        }
                        
                        Text("Confidence: \(prediction.confidence)% (\(prediction.confidenceLevel))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        ProgressView(value: Double(100 - prediction.confidence), total: 100)
                            .progressViewStyle(LinearProgressViewStyle())
                    }
                    
                    Divider()
                        .frame(height: 50)
                    
                    // Recommendations
                    VStack(alignment: .leading, spacing: 8) {
                        Text(prediction.recommendation)
                            .font(.callout)
                        
                        if prediction.recommendedDailyLimit > 0 {
                            HStack {
                                Image(systemName: "speedometer")
                                    .foregroundColor(.green)
                                Text("Recommended: \(Int(prediction.recommendedDailyLimit))/day")
                                    .font(.caption)
                            }
                        }
                    }
                    
                    Spacer()
                }
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(10)
    }
    
    // MARK: - Anomaly Alerts
    
    private var anomalyAlertsView: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Active Alerts")
                    .font(.headline)
                
                Spacer()
                
                if !viewModel.activeAlerts.isEmpty {
                    Text("\(viewModel.activeAlerts.count)")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.red.opacity(0.2))
                        .cornerRadius(10)
                }
            }
            
            if viewModel.activeAlerts.isEmpty {
                Text("No active alerts")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                ForEach(viewModel.activeAlerts) { alert in
                    AlertRow(alert: alert)
                }
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(10)
    }
}

// MARK: - Supporting Views

struct StatCard: View {
    let title: String
    let value: String
    let trend: String?
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            HStack(alignment: .bottom) {
                Text(value)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(color)
                
                if let trend = trend {
                    Text(trend)
                        .font(.caption)
                        .foregroundColor(trend.contains("↑") ? .green : .red)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }
}

struct VelocityGauge: View {
    let velocity: VelocityTracker.VelocityInfo?
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.gray.opacity(0.2), lineWidth: 10)
            
            Circle()
                .trim(from: 0, to: velocityProgress)
                .stroke(velocityColor, lineWidth: 10)
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut, value: velocityProgress)
            
            VStack {
                Text(velocity?.trendEmoji ?? "➡️")
                    .font(.title)
                Text("\(Int(velocity?.trendPercent ?? 0))%")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .frame(width: 80, height: 80)
    }
    
    private var velocityProgress: Double {
        guard let velocity = velocity else { return 0 }
        return min(1.0, abs(velocity.trendPercent) / 100)
    }
    
    private var velocityColor: Color {
        guard let velocity = velocity else { return .gray }
        switch velocity.trend {
        case .increasing: return .orange
        case .decreasing: return .green
        case .stable: return .blue
        }
    }
}

struct SessionTimeline: View {
    let sessions: [ClaudeSessionTracker.Session]
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background line
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 4)
                    .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                
                // Session blocks
                ForEach(Array(sessions.prefix(5).enumerated()), id: \.element.id) { index, session in
                    if !session.isGap {
                        Rectangle()
                            .fill(session.isActive ? Color.green : Color.blue)
                            .frame(width: 40, height: 20)
                            .cornerRadius(4)
                            .position(
                                x: CGFloat(index) * 60 + 20,
                                y: geometry.size.height / 2
                            )
                    }
                }
            }
        }
        .frame(height: 40)
    }
}

struct TrendRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
        }
    }
}

struct StatRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
        }
    }
}

struct AlertRow: View {
    let alert: RealTimeMonitor.RealTimeStats.Alert
    
    var body: some View {
        HStack {
            Image(systemName: iconName)
                .foregroundColor(iconColor)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(alert.message)
                    .font(.caption)
                
                HStack {
                    Text(alert.provider.displayName)
                    Text("•")
                    Text(alert.type.rawValue)
                    Text("•")
                    Text(alert.timestamp, style: .relative)
                }
                .font(.caption2)
                .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
    
    private var iconName: String {
        switch alert.severity {
        case .critical: return "exclamationmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .info: return "info.circle.fill"
        }
    }
    
    private var iconColor: Color {
        switch alert.severity {
        case .critical: return .red
        case .warning: return .orange
        case .info: return .blue
        }
    }
}