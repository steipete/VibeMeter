import SwiftUI

/// Enhanced dashboard view with key metrics grid and predictive analytics
struct EnhancedDashboardView: View {
    @Environment(\.settingsManager) private var settingsManager: (any SettingsManagerProtocol)?
    @Environment(\.userSessionData) private var userSessionData: MultiProviderUserSessionData?
    @Environment(\.loginManager) private var loginManager: MultiProviderLoginManager?
    @Environment(MultiProviderSpendingData.self) private var spendingData
    @Environment(CurrencyData.self) private var currencyData
    
    // Access shared orchestrator for analytics services
    private var orchestrator: MultiProviderDataOrchestrator? {
        MultiProviderDataOrchestrator.shared
    }
    
    private var velocityTracker: VelocityTracker {
        orchestrator?.velocityTracker ?? VelocityTracker()
    }
    
    private var predictionEngine: PredictionEngine {
        orchestrator?.predictionEngine ?? PredictionEngine()
    }
    
    private var resetTimeService: ResetTimeService {
        orchestrator?.resetTimeService ?? ResetTimeService()
    }
    
    private var autoPlanDetector: AutoPlanDetector {
        orchestrator?.autoPlanDetector ?? AutoPlanDetector()
    }
    
    @State private var selectedProvider: ServiceProvider?
    
    var body: some View {
        VStack(spacing: 0) {
            // Status header
            StatusHeaderBar()
            
            ScrollView {
                VStack(spacing: 16) {
                    // Key metrics grid
                    keyMetricsGrid
                        .padding(.horizontal, 12)
                        .padding(.top, 12)
                    
                    // Provider breakdown
                    if !loggedInProviders.isEmpty {
                        providerBreakdownSection
                            .padding(.horizontal, 12)
                    }
                    
                    // Predictive analytics
                    if let predictions = getPredictions() {
                        predictiveAnalyticsSection(predictions: predictions)
                            .padding(.horizontal, 12)
                            .padding(.bottom, 12)
                    }
                }
            }
            .scrollIndicators(.never)
            
            Divider()
                .overlay(Color.primary.opacity(0.1))
            
            // Quick actions bar
            QuickActionsBar()
        }
    }
    
    // MARK: - Key Metrics Grid
    
    private var keyMetricsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            // Current Usage Card
            if let usageMetrics = getCurrentUsageMetrics() {
                KeyMetricsCard.usage(
                    currentUsage: usageMetrics.currentUsage,
                    limit: usageMetrics.limit,
                    plan: usageMetrics.plan,
                    resetTime: usageMetrics.resetTime,
                    status: usageMetrics.status
                )
            }
            
            // Burn Rate Card
            if let burnRateMetrics = getBurnRateMetrics() {
                KeyMetricsCard.burnRate(
                    rate: burnRateMetrics.rate,
                    trend: burnRateMetrics.trend,
                    depletionTime: burnRateMetrics.depletionTime
                )
            }
            
            // Today's Summary Card
            KeyMetricsCard.todaySummary(
                totalCost: spendingData.totalSpendingConverted(
                    to: currencyData.selectedCode,
                    rates: currencyData.effectiveRates
                ),
                tokenCount: getTotalTokensToday(),
                providerCount: loggedInProviders.count,
                currencySymbol: currencyData.selectedSymbol
            )
            
            // Velocity Card
            if let velocityMetrics = getVelocityMetrics() {
                KeyMetricsCard.velocity(
                    velocity: velocityMetrics.info,
                    recommendation: velocityMetrics.recommendation
                )
            }
        }
        .frame(minHeight: 180)
    }
    
    // MARK: - Provider Breakdown Section
    
    private var providerBreakdownSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Providers")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)
            
            VStack(spacing: 8) {
                ForEach(loggedInProviders, id: \.self) { provider in
                    EnhancedProviderRow(
                        provider: provider,
                        spendingData: spendingData,
                        currencyData: currencyData,
                        burnRate: getBurnRateForProvider(provider),
                        velocity: getVelocityForProvider(provider)
                    )
                    .onTapGesture {
                        selectedProvider = provider
                        ProviderInteractionHandler.openProviderDashboard(
                            for: provider,
                            loginManager: loginManager
                        )
                    }
                }
            }
        }
    }
    
    // MARK: - Predictive Analytics Section
    
    private func predictiveAnalyticsSection(predictions: PredictionInfo) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                
                Text("Predictions")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.primary.opacity(0.7))
                
                Spacer()
                
                Text(predictions.confidence)
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.primary.opacity(0.08)))
            }
            .padding(.horizontal, 4)
            
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: predictions.icon)
                        .font(.system(size: 12))
                        .foregroundStyle(predictions.color)
                    
                    Text(predictions.message)
                        .font(.system(size: 11))
                        .foregroundStyle(.primary)
                }
                
                if let recommendation = predictions.recommendation {
                    Text(recommendation)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(predictions.color.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(predictions.color.opacity(0.2), lineWidth: 1)
                    )
            )
        }
    }
    
    // MARK: - Spending Limits Section
    
    private var spendingLimitsSection: some View {
        HStack {
            Label("Limits", systemImage: "exclamationmark.triangle.fill")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
            
            Spacer()
            
            HStack(spacing: 12) {
                Text(formattedWarningLimit)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.orange)
                
                Text("•")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                
                Text(formattedUpperLimit)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.red)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.primary.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                )
        )
    }
    
    // MARK: - Helper Properties
    
    private var loggedInProviders: [ServiceProvider] {
        userSessionData?.loggedInProviders ?? []
    }
    
    private var formattedWarningLimit: String {
        guard let settingsManager else { return "" }
        let converted = currencyData.convertAmount(
            settingsManager.warningLimitUSD,
            from: "USD",
            to: currencyData.selectedCode
        ) ?? settingsManager.warningLimitUSD
        return "\(currencyData.selectedSymbol)\(converted.formatted(.number.precision(.fractionLength(0))))"
    }
    
    private var formattedUpperLimit: String {
        guard let settingsManager else { return "" }
        let converted = currencyData.convertAmount(
            settingsManager.upperLimitUSD,
            from: "USD",
            to: currencyData.selectedCode
        ) ?? settingsManager.upperLimitUSD
        return "\(currencyData.selectedSymbol)\(converted.formatted(.number.precision(.fractionLength(0))))"
    }
    
    // MARK: - Metrics Calculation
    
    private struct UsageMetrics {
        let currentUsage: Double
        let limit: Double
        let plan: String
        let resetTime: String
        let status: KeyMetricsCard.StatusLevel
    }
    
    private func getCurrentUsageMetrics() -> UsageMetrics? {
        // Get the provider with highest usage percentage
        let providerUsages = loggedInProviders.compactMap { provider -> (ServiceProvider, Double, Double, Double)? in
            guard let data = spendingData.getSpendingData(for: provider),
                  let usage = data.usageData else { return nil }
            
            if provider == .claude {
                // For Claude, currentRequests is already a percentage (0-100)
                // totalRequests is the actual token count
                let dailyLimit = 200_000.0 // Claude's daily token limit
                let tokensUsed = Double(usage.totalRequests ?? 0)
                let dailyPercentage = (tokensUsed / dailyLimit) * 100
                return (provider, tokensUsed, dailyLimit, dailyPercentage)
            } else if let maxRequests = usage.maxRequests, maxRequests > 0 {
                let current = Double(usage.currentRequests)
                let max = Double(maxRequests)
                let percentage = (current / max) * 100
                return (provider, current, max, percentage)
            }
            return nil
        }
        
        guard let highest = providerUsages.max(by: { $0.3 < $1.3 }) else {
            return nil
        }
        
        let percentage = highest.3
        let status: KeyMetricsCard.StatusLevel = percentage >= 90 ? .critical : percentage >= 70 ? .warning : .safe
        
        // Get plan info
        let planInfo = autoPlanDetector.detectPlan(for: highest.0, currentUsage: highest.1, historicalData: [:])
        let resetInfo = resetTimeService.getResetInfo(for: highest.0)
        
        return UsageMetrics(
            currentUsage: highest.1,
            limit: highest.2,
            plan: planInfo.planType.rawValue,
            resetTime: "in \(resetInfo.timeRemainingText)",
            status: status
        )
    }
    
    private struct BurnRateMetrics {
        let rate: Double
        let trend: BurnRateCalculator.BurnRate.BurnRateTrend
        let depletionTime: String
    }
    
    private func getBurnRateMetrics() -> BurnRateMetrics? {
        // Get burn rate for primary provider (highest usage)
        guard let primaryProvider = getPrimaryProvider(),
              let burnRateInfo = spendingData.getSpendingData(for: primaryProvider)?.burnRateInfo else {
            return nil
        }
        
        return BurnRateMetrics(
            rate: burnRateInfo.burnRate?.tokensPerHour ?? 0,
            trend: burnRateInfo.burnRate?.trend ?? .steady(percentageChange: 0),
            depletionTime: {
                if let depletionTime = burnRateInfo.depletionTime {
                    let hours = depletionTime.timeIntervalSinceNow / 3600
                    if hours < 1 {
                        return "< 1h"
                    } else if hours < 24 {
                        return "\(Int(hours))h"
                    } else {
                        return "\(Int(hours / 24))d"
                    }
                } else {
                    return "No depletion"
                }
            }()
        )
    }
    
    private struct VelocityMetrics {
        let info: VelocityTracker.VelocityInfo
        let recommendation: String?
    }
    
    private func getVelocityMetrics() -> VelocityMetrics? {
        guard let primaryProvider = getPrimaryProvider() else { return nil }
        
        guard let velocity = velocityTracker.calculateVelocity(for: primaryProvider) else { return nil }
        let recommendation = velocity.recommendation ?? velocityTracker.getRecommendation(for: velocity)
        
        return VelocityMetrics(info: velocity, recommendation: recommendation)
    }
    
    private func getTotalTokensToday() -> Int? {
        // For Claude, return token count
        if let claudeData = spendingData.getSpendingData(for: .claude),
           let usage = claudeData.usageData {
            return usage.totalRequests
        }
        return nil
    }
    
    private func getPrimaryProvider() -> ServiceProvider? {
        // Return provider with highest usage percentage
        loggedInProviders.max { provider1, provider2 in
            let usage1 = getUsagePercentage(for: provider1)
            let usage2 = getUsagePercentage(for: provider2)
            return usage1 < usage2
        }
    }
    
    private func getUsagePercentage(for provider: ServiceProvider) -> Double {
        guard let data = spendingData.getSpendingData(for: provider),
              let usage = data.usageData else { return 0 }
        
        if provider == .claude {
            return Double(usage.currentRequests) // Already a percentage
        } else if let maxRequests = usage.maxRequests, maxRequests > 0 {
            return (Double(usage.currentRequests) / Double(maxRequests)) * 100
        }
        return 0
    }
    
    private func getBurnRateForProvider(_ provider: ServiceProvider) -> BurnRateCalculator.BurnRate? {
        spendingData.getSpendingData(for: provider)?.burnRateInfo?.burnRate
    }
    
    private func getVelocityForProvider(_ provider: ServiceProvider) -> VelocityTracker.VelocityInfo? {
        velocityTracker.calculateVelocity(for: provider)
    }
    
    private struct PredictionInfo {
        let message: String
        let recommendation: String?
        let confidence: String
        let icon: String
        let color: Color
    }
    
    private func getPredictions() -> PredictionInfo? {
        guard let primaryProvider = getPrimaryProvider(),
              let data = spendingData.getSpendingData(for: primaryProvider),
              let usage = data.usageData else { return nil }
        
        let currentUsage = primaryProvider == .claude ? Double(usage.totalRequests ?? 0) : Double(usage.currentRequests)
        let limit = primaryProvider == .claude ? 200_000.0 : Double(usage.maxRequests ?? 1000)
        let burnRate = getBurnRateForProvider(primaryProvider)
        
        let prediction = predictionEngine.calculatePrediction(
            for: primaryProvider,
            currentUsage: currentUsage,
            limit: limit,
            burnRate: burnRate
        )
        
        let icon: String
        let color: Color
        
        if prediction.hoursRemaining < 1 {
            icon = "exclamationmark.triangle.fill"
            color = .red
        } else if prediction.hoursRemaining < 3 {
            icon = "exclamationmark.circle.fill"
            color = .orange
        } else {
            icon = "checkmark.circle.fill"
            color = .green
        }
        
        return PredictionInfo(
            message: prediction.depletionText,
            recommendation: prediction.recommendation,
            confidence: "\(prediction.confidence) confidence",
            icon: icon,
            color: color
        )
    }
}

// MARK: - Enhanced Provider Row

struct EnhancedProviderRow: View {
    let provider: ServiceProvider
    let spendingData: MultiProviderSpendingData
    let currencyData: CurrencyData
    let burnRate: BurnRateCalculator.BurnRate?
    let velocity: VelocityTracker.VelocityInfo?
    
    @State private var isHovering = false
    
    private var providerData: ProviderSpendingData? {
        spendingData.getSpendingData(for: provider)
    }
    
    var body: some View {
        HStack(spacing: 10) {
            // Provider icon
            ProviderIconView(provider: provider, spendingData: spendingData)
                .frame(width: 20, height: 20)
            
            // Provider name and status
            VStack(alignment: .leading, spacing: 2) {
                Text(provider.displayName)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.primary)
                
                if let status = getProviderStatus() {
                    Text(status)
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
            
            // Metrics badges
            HStack(spacing: 6) {
                // Burn rate badge
                if let burnRate {
                    HStack(spacing: 2) {
                        Image(systemName: burnRate.trendIcon)
                            .font(.system(size: 8))
                        Text(burnRate.formattedRate)
                            .font(.system(size: 9, weight: .medium))
                    }
                    .foregroundStyle(burnRate.trendColor)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(burnRate.trendColor.opacity(0.1))
                    )
                }
                
                // Spending amount
                ProviderSpendingAmountView(
                    provider: provider,
                    spendingData: spendingData,
                    currencyData: currencyData
                )
                .font(.system(size: 11, weight: .semibold))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.primary.opacity(isHovering ? 0.06 : 0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                )
        )
        .scaleEffect(isHovering ? 1.02 : 1.0)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
    }
    
    private func getProviderStatus() -> String? {
        guard let data = providerData else { return nil }
        
        if provider == .claude, let session = ClaudeLogManager.shared.getSessionTracker().getActiveSession() {
            let remaining = session.expectedEndTime.timeIntervalSinceNow
            let timeText: String
            if remaining < 3600 {
                timeText = "\(Int(remaining / 60))m remaining"
            } else {
                let hours = Int(remaining / 3600)
                let minutes = Int((remaining.truncatingRemainder(dividingBy: 3600)) / 60)
                timeText = "\(hours)h \(minutes)m remaining"
            }
            return "Session active • \(timeText)"
        }
        
        switch data.connectionStatus {
        case .syncing:
            return "Syncing..."
        case .rateLimited(let until):
            if let until {
                let formatter = RelativeDateTimeFormatter()
                return "Rate limited until \(formatter.localizedString(for: until, relativeTo: Date()))"
            }
            return "Rate limited"
        case .error(let message):
            return message
        case .stale:
            return "Data may be outdated"
        default:
            return nil
        }
    }
}

// MARK: - Quick Actions Bar

struct QuickActionsBar: View {
    @Environment(\.loginManager) private var loginManager: MultiProviderLoginManager?
    
    var body: some View {
        HStack(spacing: 8) {
            Spacer()
            
            // Settings button
            Button(action: openSettings) {
                Label("Settings", systemImage: "gearshape")
                    .font(.system(size: 11))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.primary.opacity(0.08))
            )
            .foregroundStyle(.primary)
            
            // Close button
            Button(action: closePopover) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 14))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help("Close (Esc)")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            Rectangle()
                .fill(Color.primary.opacity(0.03))
        )
    }
    
    private func openSettings() {
        NSApp.openSettings()
    }
    
    private func closePopover() {
        // Find and close the custom menu window
        for window in NSApp.windows {
            if window.styleMask.contains(.borderless), 
               window.isVisible,
               window.level == .popUpMenu {
                window.orderOut(nil)
                break
            }
        }
    }
}

// MARK: - Burn Rate Extensions

private extension BurnRateCalculator.BurnRate {
    var trendIcon: String {
        switch trend {
        case .accelerating:
            return "arrow.up.right"
        case .steady:
            return "arrow.right"
        case .decelerating:
            return "arrow.down.right"
        case .erratic:
            return "arrow.up.arrow.down"
        }
    }
    
    var trendColor: Color {
        switch trend {
        case .accelerating:
            return .red
        case .steady:
            return .blue
        case .decelerating:
            return .green
        case .erratic:
            return .orange
        }
    }
}

// MARK: - Preview

#Preview {
    EnhancedDashboardView()
        .frame(width: 320, height: 600)
        .background(Color(NSColor.windowBackgroundColor))
        .environment(MultiProviderSpendingData())
        .environment(CurrencyData())
        .environment(\.settingsManager, MockSettingsManager())
        .environment(\.userSessionData, MultiProviderUserSessionData())
}