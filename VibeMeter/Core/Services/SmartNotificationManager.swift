import Foundation
import os.log
@preconcurrency import UserNotifications

/// Enhanced notification manager with smart alerts and cooldown management
@MainActor
public final class SmartNotificationManager: NSObject {
    
    // MARK: - Singleton
    
    public static let shared = SmartNotificationManager()
    
    // MARK: - Types
    
    /// Notification type with priority
    public enum NotificationType: String, Sendable {
        case usageWarning = "usage_warning"
        case usageCritical = "usage_critical" 
        case depletionAlert = "depletion_alert"
        case velocityAlert = "velocity_alert"
        case resetReminder = "reset_reminder"
        case milestone = "milestone"
        case prediction = "prediction"
        case sessionAlert = "session_alert"
        
        var priority: Int {
            switch self {
            case .usageCritical, .depletionAlert: return 3
            case .usageWarning, .velocityAlert, .sessionAlert: return 2
            case .prediction, .resetReminder: return 1
            case .milestone: return 0
            }
        }
        
        var sound: UNNotificationSound {
            switch self {
            case .usageCritical, .depletionAlert:
                return .defaultCritical
            case .usageWarning, .velocityAlert:
                return .default
            default:
                return .default
            }
        }
    }
    
    /// Usage status for notification decisions
    public enum UsageStatus: Int, Comparable, Sendable {
        case safe = 0
        case warning = 1
        case critical = 2
        
        public static func < (lhs: UsageStatus, rhs: UsageStatus) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
        
        public static func from(percentage: Double) -> UsageStatus {
            if percentage >= 90 { return .critical }
            if percentage >= 70 { return .warning }
            return .safe
        }
    }
    
    /// Notification state tracking per provider
    private struct NotificationState {
        var lastNotificationTime: Date = .distantPast
        var lastStatus: UsageStatus = .safe
        var lastPercentage: Double = 0
        var cooldownEndTime: Date = .distantPast
        var shownMilestones: Set<Int> = []
        var lastDataIdentifier: String = ""
        var notificationInProgress: Bool = false
    }
    
    /// Notification request data
    public struct NotificationData {
        let provider: ServiceProvider
        let type: NotificationType
        let title: String
        let body: String
        let metadata: [String: Any]
        
        var identifier: String {
            "\(provider.rawValue)_\(type.rawValue)_\(Date().timeIntervalSince1970)"
        }
    }
    
    // MARK: - Properties
    
    private let logger = Logger.vibeMeter(category: "SmartNotifications")
    private let notificationCenter = UNUserNotificationCenter.current()
    
    // State tracking
    private var providerStates: [ServiceProvider: NotificationState] = [:]
    private var isAuthorized = false
    
    // Configuration
    private let notificationCooldown: TimeInterval = 300 // 5 minutes
    private let milestones = [50, 70, 80, 90, 95]
    
    // MARK: - Initialization
    
    private override init() {
        super.init()
        notificationCenter.delegate = self
        Task {
            await setupNotifications()
        }
    }
    
    // MARK: - Public Methods
    
    /// Check and notify based on usage data
    public func checkAndNotify(
        provider: ServiceProvider,
        currentUsage: Double,
        limit: Double,
        burnRate: Double? = nil,
        prediction: PredictionEngine.PredictionInfo? = nil,
        velocity: VelocityTracker.VelocityInfo? = nil
    ) async {
        
        let percentage = min(100, (currentUsage / limit) * 100)
        let status = UsageStatus.from(percentage: percentage)
        
        // Get or create state
        var state = providerStates[provider] ?? NotificationState()
        
        // Check cooldown
        if Date() < state.cooldownEndTime {
            logger.debug("Notification in cooldown for \(provider.rawValue)")
            return
        }
        
        // Create unique identifier for this state
        let dataIdentifier = "\(provider.rawValue)-\(Int(percentage))-\(status.rawValue)"
        
        // Skip if same state
        if state.lastDataIdentifier == dataIdentifier {
            return
        }
        
        // Check milestone notifications
        await checkMilestoneNotification(
            provider: provider,
            percentage: percentage,
            state: &state
        )
        
        // Check status change notifications
        if status > state.lastStatus {
            await sendStatusNotification(
                provider: provider,
                status: status,
                percentage: percentage,
                limit: limit,
                currentUsage: currentUsage
            )
            state.lastStatus = status
            state.cooldownEndTime = Date().addingTimeInterval(notificationCooldown)
        }
        
        // Check prediction-based notifications
        if let prediction = prediction {
            await checkPredictionNotification(
                provider: provider,
                prediction: prediction,
                state: &state
            )
        }
        
        // Check velocity alerts
        if let velocity = velocity, velocity.isAccelerating {
            await checkVelocityNotification(
                provider: provider,
                velocity: velocity,
                state: &state
            )
        }
        
        // Update state
        state.lastPercentage = percentage
        state.lastDataIdentifier = dataIdentifier
        state.lastNotificationTime = Date()
        providerStates[provider] = state
    }
    
    /// Check and notify for Claude-specific session alerts
    public func checkClaudeSessionNotification(
        sessionTracking: ClaudeSessionTracker.SessionTracking,
        prediction: PredictionEngine.PredictionInfo
    ) async {
        
        var state = providerStates[.claude] ?? NotificationState()
        
        // Check if approaching session end
        if let activeSession = sessionTracking.currentSession {
            let timeRemaining = activeSession.expectedEndTime.timeIntervalSinceNow
            
            // Alert 30 minutes before session end
            if timeRemaining > 0 && timeRemaining < 1800 && !state.notificationInProgress {
                let data = NotificationData(
                    provider: .claude,
                    type: .sessionAlert,
                    title: "Claude Session Ending Soon ⏰",
                    body: "Your Claude session will end in \(Int(timeRemaining / 60)) minutes. Cost: \(activeSession.totalCost.formattedCurrency)",
                    metadata: ["sessionId": activeSession.id]
                )
                
                await sendNotification(data)
                state.notificationInProgress = true
            }
        }
        
        // Check depletion alerts
        if prediction.hoursRemaining < 1 && prediction.confidence > 70 {
            let data = NotificationData(
                provider: .claude,
                type: .depletionAlert,
                title: "Claude Tokens Running Low! 🚨",
                body: prediction.recommendation,
                metadata: ["hoursRemaining": prediction.hoursRemaining]
            )
            
            await sendNotification(data)
        }
        
        providerStates[.claude] = state
    }
    
    /// Request notification authorization
    public func requestAuthorization() async -> Bool {
        do {
            let granted = try await notificationCenter
                .requestAuthorization(options: [.alert, .sound, .badge, .criticalAlert])
            isAuthorized = granted
            logger.info("Notification authorization: \(granted)")
            return granted
        } catch {
            logger.error("Failed to request authorization: \(error)")
            return false
        }
    }
    
    /// Reset notification state for a provider
    public func resetState(for provider: ServiceProvider) {
        providerStates[provider] = NotificationState()
        logger.info("Reset notification state for \(provider.rawValue)")
    }
    
    /// Reset all notification states
    public func resetAllStates() {
        providerStates.removeAll()
        logger.info("Reset all notification states")
    }
    
    // MARK: - Private Methods
    
    private func setupNotifications() async {
        // Check current authorization
        let settings = await notificationCenter.notificationSettings()
        isAuthorized = settings.authorizationStatus == .authorized
        
        // Setup categories
        setupNotificationCategories()
    }
    
    private func setupNotificationCategories() {
        let categories: [UNNotificationCategory] = [
            UNNotificationCategory(
                identifier: NotificationType.usageWarning.rawValue,
                actions: [],
                intentIdentifiers: [],
                options: []
            ),
            UNNotificationCategory(
                identifier: NotificationType.usageCritical.rawValue,
                actions: [],
                intentIdentifiers: [],
                options: [.customDismissAction]
            ),
            UNNotificationCategory(
                identifier: NotificationType.depletionAlert.rawValue,
                actions: [
                    UNNotificationAction(
                        identifier: "VIEW_USAGE",
                        title: "View Usage",
                        options: .foreground
                    )
                ],
                intentIdentifiers: [],
                options: [.customDismissAction]
            ),
            UNNotificationCategory(
                identifier: NotificationType.prediction.rawValue,
                actions: [],
                intentIdentifiers: [],
                options: []
            )
        ]
        
        notificationCenter.setNotificationCategories(Set(categories))
    }
    
    private func checkMilestoneNotification(
        provider: ServiceProvider,
        percentage: Double,
        state: inout NotificationState
    ) async {
        
        for milestone in milestones {
            let milestoneValue = Double(milestone)
            if percentage >= milestoneValue && !state.shownMilestones.contains(milestone) {
                let data = NotificationData(
                    provider: provider,
                    type: .milestone,
                    title: "Usage Milestone - \(milestone)% 📊",
                    body: "\(provider.displayName): You've used \(milestone)% of your limit",
                    metadata: ["milestone": milestone, "percentage": percentage]
                )
                
                await sendNotification(data)
                state.shownMilestones.insert(milestone)
            }
        }
    }
    
    private func sendStatusNotification(
        provider: ServiceProvider,
        status: UsageStatus,
        percentage: Double,
        limit: Double,
        currentUsage: Double
    ) async {
        
        let type: NotificationType = status == .critical ? .usageCritical : .usageWarning
        let emoji = status == .critical ? "🚨" : "⚠️"
        
        let data = NotificationData(
            provider: provider,
            type: type,
            title: "\(provider.displayName) Usage \(emoji)",
            body: String(format: "%.0f%% used (%.2f of %.2f)", percentage, currentUsage, limit),
            metadata: [
                "percentage": percentage,
                "currentUsage": currentUsage,
                "limit": limit
            ]
        )
        
        await sendNotification(data)
    }
    
    private func checkPredictionNotification(
        provider: ServiceProvider,
        prediction: PredictionEngine.PredictionInfo,
        state: inout NotificationState
    ) async {
        
        // Alert if depleting within 2 hours and high confidence
        if prediction.hoursRemaining < 2 && prediction.confidence > 70 {
            let data = NotificationData(
                provider: provider,
                type: .depletionAlert,
                title: "Depletion Alert! ⏱️",
                body: "\(provider.displayName): \(prediction.depletionText)\n\(prediction.recommendation)",
                metadata: [
                    "hoursRemaining": prediction.hoursRemaining,
                    "confidence": prediction.confidence
                ]
            )
            
            await sendNotification(data)
            state.cooldownEndTime = Date().addingTimeInterval(notificationCooldown * 2) // Longer cooldown
        }
    }
    
    private func checkVelocityNotification(
        provider: ServiceProvider,
        velocity: VelocityTracker.VelocityInfo,
        state: inout NotificationState
    ) async {
        
        // Only notify if not recently notified
        let timeSinceLastVelocity = Date().timeIntervalSince(state.lastNotificationTime)
        if timeSinceLastVelocity < 3600 { return } // 1 hour minimum between velocity alerts
        
        let data = NotificationData(
            provider: provider,
            type: .velocityAlert,
            title: "Usage Accelerating! ⚡",
            body: "\(provider.displayName): \(velocity.description). Consider slowing down.",
            metadata: [
                "trend": velocity.trend.rawValue,
                "trendPercent": velocity.trendPercent
            ]
        )
        
        await sendNotification(data)
    }
    
    private func sendNotification(_ data: NotificationData) async {
        guard isAuthorized else {
            logger.debug("Notifications not authorized")
            return
        }
        
        let content = UNMutableNotificationContent()
        content.title = data.title
        content.body = data.body
        content.sound = data.type.sound
        content.categoryIdentifier = data.type.rawValue
        
        // Set interruption level based on priority
        if data.type.priority >= 3 {
            content.interruptionLevel = .critical
        } else if data.type.priority >= 2 {
            content.interruptionLevel = .timeSensitive
        } else {
            content.interruptionLevel = .active
        }
        
        // Add metadata
        content.userInfo = data.metadata
        
        let request = UNNotificationRequest(
            identifier: data.identifier,
            content: content,
            trigger: nil // Immediate delivery
        )
        
        do {
            try await notificationCenter.add(request)
            logger.info("Notification sent: \(data.type.rawValue) for \(data.provider.rawValue)")
        } catch {
            logger.error("Failed to send notification: \(error)")
        }
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension SmartNotificationManager: UNUserNotificationCenterDelegate {
    public nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        // Show notifications even when app is in foreground
        [.banner, .sound, .badge, .list]
    }
    
    public nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let logger = Logger.vibeMeter(category: "SmartNotifications")
        
        logger.info("User interacted with notification: \(response.notification.request.identifier)")
        
        // Handle notification actions
        switch response.actionIdentifier {
        case "VIEW_USAGE":
            // Open usage view
            await MainActor.run {
                NotificationCenter.default.post(
                    name: .showUsageDetails,
                    object: nil,
                    userInfo: response.notification.request.content.userInfo
                )
            }
            
        case UNNotificationDefaultActionIdentifier:
            // User tapped notification
            logger.debug("User tapped notification")
            
        case UNNotificationDismissActionIdentifier:
            // User dismissed notification  
            logger.debug("User dismissed notification")
            
        default:
            break
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let showUsageDetails = Notification.Name("showUsageDetails")
}