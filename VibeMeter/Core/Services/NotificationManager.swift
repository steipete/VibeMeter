import Foundation
import os.log
@preconcurrency import UserNotifications

// MARK: - Notification Manager Protocol

/// Protocol defining the interface for managing user notifications.
@MainActor
public protocol NotificationManagerProtocol: Sendable {
    func requestAuthorization() async -> Bool
    func showWarningNotification(currentSpending: Double, limitAmount: Double, currencyCode: String) async
    func showUpperLimitNotification(currentSpending: Double, limitAmount: Double, currencyCode: String) async
    func resetNotificationStateIfBelow(
        limitType: NotificationLimitType,
        currentSpendingUSD: Double,
        warningLimitUSD: Double,
        upperLimitUSD: Double) async
    func resetAllNotificationStatesForNewSession() async
    func showInstanceAlreadyRunningNotification() async
}

// MARK: - Limit Type

/// Types of spending limit notifications that can be triggered.
public enum NotificationLimitType: String, CaseIterable, Sendable {
    case warning
    case upper
}

// MARK: - Modern Notification Manager

/// Manages system notifications for spending limit alerts.
///
/// NotificationManager handles:
/// - Requesting notification permissions
/// - Displaying warning and upper limit notifications
/// - Tracking notification state to prevent duplicate alerts
/// - Resetting notification states when spending drops below limits
///
/// The manager ensures that each limit notification is shown only once per session
/// and resets when the spending drops below the threshold or a new session begins.
@MainActor
public final class NotificationManager: NSObject, NotificationManagerProtocol {
    // MARK: - Properties

    private let logger = Logger.vibeMeter(category: "Notifications")

    // Track which notifications have been shown
    private var warningNotificationShown = false
    private var upperLimitNotificationShown = false

    // MARK: - Initialization

    override public init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self

        // Configure notification categories
        setupNotificationCategories()
    }

    // MARK: - Public Methods

    public func requestAuthorization() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
            logger.info("Notification authorization granted: \(granted)")
            return granted
        } catch {
            logger.error("Failed to request notification authorization: \(error)")
            return false
        }
    }

    public func showWarningNotification(currentSpending: Double, limitAmount: Double, currencyCode: String) async {
        guard !warningNotificationShown else {
            logger.debug("Warning notification already shown for this session")
            return
        }

        let symbol = ExchangeRateManager.getSymbol(for: currencyCode)
        let formatter = FloatingPointFormatStyle<Double>.number
            .precision(.fractionLength(2))
            .locale(Locale(identifier: "en_US"))
        let spendingFormatted = "\(symbol)\(currentSpending.formatted(formatter))"
        let limitFormatted = "\(symbol)\(limitAmount.formatted(formatter))"

        let content = UNMutableNotificationContent()
        content.title = "Spending Alert ⚠️"
        content.body = "You've reached \(spendingFormatted) of your \(limitFormatted) warning limit"
        content.sound = .default
        content.categoryIdentifier = "SPENDING_WARNING"

        let request = UNNotificationRequest(
            identifier: "warning_\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil)
        await scheduleNotification(request: request)
        warningNotificationShown = true

        logger.info("Warning notification scheduled: spending \(spendingFormatted) of \(limitFormatted)")
    }

    public func showUpperLimitNotification(currentSpending: Double, limitAmount: Double, currencyCode: String) async {
        guard !upperLimitNotificationShown else {
            logger.debug("Upper limit notification already shown for this session")
            return
        }

        let symbol = ExchangeRateManager.getSymbol(for: currencyCode)
        let formatter = FloatingPointFormatStyle<Double>.number
            .precision(.fractionLength(2))
            .locale(Locale(identifier: "en_US"))
        let spendingFormatted = "\(symbol)\(currentSpending.formatted(formatter))"
        let limitFormatted = "\(symbol)\(limitAmount.formatted(formatter))"

        let content = UNMutableNotificationContent()
        content.title = "Spending Limit Reached! 🚨"
        content.body = "You've exceeded your maximum limit! Current: \(spendingFormatted), Limit: \(limitFormatted)"
        content.sound = .defaultCritical
        content.categoryIdentifier = "SPENDING_CRITICAL"
        content.interruptionLevel = .critical

        let request = UNNotificationRequest(
            identifier: "upper_\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil)
        await scheduleNotification(request: request)
        upperLimitNotificationShown = true

        logger.warning("Upper limit notification scheduled: spending \(spendingFormatted) exceeded \(limitFormatted)")
    }

    public func resetNotificationStateIfBelow(
        limitType: NotificationLimitType,
        currentSpendingUSD: Double,
        warningLimitUSD: Double,
        upperLimitUSD: Double) async {
        switch limitType {
        case .warning:
            if currentSpendingUSD < warningLimitUSD, warningNotificationShown {
                warningNotificationShown = false
                logger.info("Reset warning notification state - spending below limit")
            }
        case .upper:
            if currentSpendingUSD < upperLimitUSD, upperLimitNotificationShown {
                upperLimitNotificationShown = false
                logger.info("Reset upper limit notification state - spending below limit")
            }
        }
    }

    public func resetAllNotificationStatesForNewSession() async {
        warningNotificationShown = false
        upperLimitNotificationShown = false
        logger.info("All notification states reset for new session")
    }

    public func showInstanceAlreadyRunningNotification() async {
        let content = UNMutableNotificationContent()
        content.title = "Vibe Meter Already Running"
        content
            .body =
            "Another instance of Vibe Meter is already running. The existing instance has been brought to the front."
        content.sound = .default
        content.categoryIdentifier = "APP_INSTANCE"

        let request = UNNotificationRequest(
            identifier: "instance_\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil)
        await scheduleNotification(request: request)

        logger.info("Instance already running notification scheduled")
    }

    // MARK: - Private Methods

    private func setupNotificationCategories() {
        let warningCategory = UNNotificationCategory(
            identifier: "SPENDING_WARNING",
            actions: [],
            intentIdentifiers: [],
            options: [])

        let criticalCategory = UNNotificationCategory(
            identifier: "SPENDING_CRITICAL",
            actions: [],
            intentIdentifiers: [],
            options: [.customDismissAction])

        let instanceCategory = UNNotificationCategory(
            identifier: "APP_INSTANCE",
            actions: [],
            intentIdentifiers: [],
            options: [])

        UNUserNotificationCenter.current().setNotificationCategories([
            warningCategory,
            criticalCategory,
            instanceCategory,
        ])
    }

    private func scheduleNotification(request: sending UNNotificationRequest) async {
        do {
            try await UNUserNotificationCenter.current().add(request)
            logger.debug("Notification scheduled with identifier: \(request.identifier)")
        } catch {
            logger.error("Failed to schedule notification: \(error)")
        }
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension NotificationManager: UNUserNotificationCenterDelegate {
    public nonisolated func userNotificationCenter(
        _: UNUserNotificationCenter,
        willPresent _: UNNotification) async -> UNNotificationPresentationOptions {
        // Show notifications even when app is in foreground
        [.banner, .sound, .badge]
    }

    public nonisolated func userNotificationCenter(
        _: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse) async {
        let logger = Logger.vibeMeter(category: "Notifications")
        logger.info("User interacted with notification: \(response.notification.request.identifier)")

        // Handle notification actions if needed
        switch response.actionIdentifier {
        case UNNotificationDefaultActionIdentifier:
            // User tapped the notification
            logger.debug("User tapped notification")
        case UNNotificationDismissActionIdentifier:
            // User dismissed the notification
            logger.debug("User dismissed notification")
        default:
            break
        }
    }
}
