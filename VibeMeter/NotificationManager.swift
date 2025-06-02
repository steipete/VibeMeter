import Foundation
import UserNotifications

enum NotificationLimitType { case warning, upper }

// Protocol for NotificationManager
protocol NotificationManagerProtocol {
    func requestAuthorization(completion: @escaping @Sendable (Bool) -> Void)
    func showWarningNotification(currentSpending: Double, limitAmount: Double, currencyCode: String)
    func showUpperLimitNotification(currentSpending: Double, limitAmount: Double, currencyCode: String)
    func resetAllNotificationStatesForNewSession()
    func resetNotificationStateIfBelow(
        limitType: NotificationLimitType,
        currentSpendingUSD: Double,
        warningLimitUSD: Double,
        upperLimitUSD: Double
    )
}

// Companion object to hold the shared instance and test helpers
final class NotificationManager {
    private nonisolated(unsafe) static var _shared: NotificationManagerProtocol = RealNotificationManager()
    static var shared: NotificationManagerProtocol { _shared }

    @MainActor
    static func _test_setSharedInstance(instance: NotificationManagerProtocol) {
        _shared = instance
    }

    @MainActor
    static func _test_resetSharedInstance() {
        _shared = RealNotificationManager()
    }

    // Private init to prevent direct instantiation of the companion object
    private init() {}
}

// The actual implementation conforming to the protocol
class RealNotificationManager: NSObject, NotificationManagerProtocol, UNUserNotificationCenterDelegate {
    private let notificationCenter = UNUserNotificationCenter.current()
    private var hasNotifiedForWarningLimitThisSession = false
    private var hasNotifiedForUpperLimitThisSession = false

    override init() {
        // Changed to public or internal (default) to be accessible by NotificationManager.shared initialization
        super.init()
        notificationCenter.delegate = self // Set the delegate
        LoggingService.info("RealNotificationManager initialized and delegate set.", category: .notification)
    }

    func requestAuthorization(completion: @escaping @Sendable (Bool) -> Void = { _ in }) {
        notificationCenter.requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error {
                LoggingService.error(
                    "Error requesting notification authorization",
                    category: .notification,
                    error: error
                )
            }
            LoggingService.info("Notification authorization status: \(granted)", category: .notification)
            DispatchQueue.main.async {
                completion(granted)
            }
        }
    }

    func showWarningNotification(currentSpending: Double, limitAmount: Double, currencyCode: String) {
        guard !hasNotifiedForWarningLimitThisSession else {
            LoggingService.info("Warning notification already shown this session.", category: .notification)
            return
        }
        let symbol = RealExchangeRateManager.getSymbol(for: currencyCode)
        let content = UNMutableNotificationContent()
        content.title = "Vibe Check! 💸"
        content
            .body =
            "Heads up! Your Cursor spend (\(symbol)\(String(format: "%.2f", currentSpending))) " +
            "is getting close to your \(symbol)\(String(format: "%.2f", limitAmount)) warning vibe!"
        content.sound = .default

        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        notificationCenter.add(request) { [weak self] error in
            if let error {
                LoggingService.error("Error showing warning notification", category: .notification, error: error)
            } else {
                LoggingService.info("Warning notification presented.", category: .notification)
                self?.hasNotifiedForWarningLimitThisSession = true
            }
        }
    }

    func showUpperLimitNotification(currentSpending: Double, limitAmount: Double, currencyCode: String) {
        guard !hasNotifiedForUpperLimitThisSession else {
            LoggingService.info("Upper limit notification already shown this session.", category: .notification)
            return
        }
        let symbol = RealExchangeRateManager.getSymbol(for: currencyCode)
        let content = UNMutableNotificationContent()
        content.title = "Vibe Overload! 🚨"
        content
            .body =
            "Whoa! Your Cursor spend (\(symbol)\(String(format: "%.2f", currentSpending))) " +
            "is hitting the \(symbol)\(String(format: "%.2f", limitAmount)) max vibe! Time to chill?"
        content.sound = .defaultCritical

        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        notificationCenter.add(request) { [weak self] error in
            if let error {
                LoggingService.error("Error showing upper limit notification", category: .notification, error: error)
            } else {
                LoggingService.info("Upper limit notification presented.", category: .notification)
                self?.hasNotifiedForUpperLimitThisSession = true
            }
        }
    }

    func resetNotificationStateIfBelow(
        limitType: NotificationLimitType,
        currentSpendingUSD: Double,
        warningLimitUSD: Double,
        upperLimitUSD: Double
    ) {
        switch limitType {
        case .warning:
            if currentSpendingUSD < warningLimitUSD {
                if hasNotifiedForWarningLimitThisSession {
                    LoggingService.info(
                        "Spending dropped below warning limit. Resetting warning notification state for this session.",
                        category: .notification
                    )
                    hasNotifiedForWarningLimitThisSession = false
                }
            }
        case .upper:
            if currentSpendingUSD < upperLimitUSD {
                if hasNotifiedForUpperLimitThisSession {
                    LoggingService.info(
                        "Spending dropped below upper limit. " +
                            "Resetting upper limit notification state for this session.",
                        category: .notification
                    )
                    hasNotifiedForUpperLimitThisSession = false
                }
            }
        }
    }

    func resetAllNotificationStatesForNewSession() {
        hasNotifiedForWarningLimitThisSession = false
        hasNotifiedForUpperLimitThisSession = false
        LoggingService.info("All notification states reset for new session.", category: .notification)
    }

    // MARK: - UNUserNotificationCenterDelegate methods (Optional - if you want notifications to show while app is foreground)

    // This method will be called when a notification is delivered to a foreground app.
    nonisolated func userNotificationCenter(
        _: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions)
            -> Void
    ) {
        LoggingService.debug(
            "Notification received in foreground: \(notification.request.content.title)",
            category: .notification
        )
        // Show the notification alert (banner), play its sound.
        completionHandler([.banner, .sound]) // Adjust options as needed, .list is for Notification Center
    }

    // This method is called when a user interacts with a notification (e.g., taps on it).
    nonisolated func userNotificationCenter(
        _: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let actionIdentifier = response.actionIdentifier
        let actionDescription = actionIdentifier == UNNotificationDefaultActionIdentifier
            ? "default" : actionIdentifier
        LoggingService.debug(
            "User interacted with notification. Action: \(actionDescription)",
            category: .notification
        )
        // Handle the action if needed
        completionHandler()
    }
}
