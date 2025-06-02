import Foundation
@testable import VibeMeter

// Assuming NotificationManager has a protocol or can be subclassed for mocking.
// For now, let's define a simple mock class directly.

class NotificationManagerMock: NotificationManagerProtocol {
    var requestAuthorizationCalled = false
    var authorizationCompletionHandler: (@Sendable (Bool) -> Void)?
    var authorizationGrantedToReturn: Bool = true

    var showWarningNotificationCalled = false
    var lastWarningSpending: Double?
    var lastWarningCurrency: String?

    var showUpperLimitNotificationCalled = false
    var lastUpperLimitSpending: Double?
    var lastUpperLimitCurrency: String?

    var resetAllNotificationStatesCalled = false
    var resetNotificationStateIfBelowCalled = false
    var lastResetLimitType: NotificationLimitType?
    var lastResetCurrentSpendingUSD: Double?
    var lastResetWarningLimitUSD: Double?
    var lastResetUpperLimitUSD: Double?

    func requestAuthorization(completion: @escaping @Sendable (Bool) -> Void) {
        requestAuthorizationCalled = true
        authorizationCompletionHandler = completion
        // Simulate async callback if needed for more complex tests
        // For now, can call it directly or store it to be called by test.
        completion(authorizationGrantedToReturn)
    }

    func showWarningNotification(currentSpending: Double, limitAmount _: Double, currencyCode: String) {
        showWarningNotificationCalled = true
        lastWarningSpending = currentSpending
        lastWarningCurrency = currencyCode
    }

    func showUpperLimitNotification(currentSpending: Double, limitAmount _: Double, currencyCode: String) {
        showUpperLimitNotificationCalled = true
        lastUpperLimitSpending = currentSpending
        lastUpperLimitCurrency = currencyCode
    }

    func resetAllNotificationStatesForNewSession() {
        resetAllNotificationStatesCalled = true
    }

    func resetNotificationStateIfBelow(
        limitType: NotificationLimitType,
        currentSpendingUSD: Double,
        warningLimitUSD: Double,
        upperLimitUSD: Double
    ) {
        resetNotificationStateIfBelowCalled = true
        lastResetLimitType = limitType
        lastResetCurrentSpendingUSD = currentSpendingUSD
        lastResetWarningLimitUSD = warningLimitUSD
        lastResetUpperLimitUSD = upperLimitUSD
    }

    func reset() {
        requestAuthorizationCalled = false
        authorizationCompletionHandler = nil
        authorizationGrantedToReturn = true
        showWarningNotificationCalled = false
        lastWarningSpending = nil
        lastWarningCurrency = nil
        showUpperLimitNotificationCalled = false
        lastUpperLimitSpending = nil
        lastUpperLimitCurrency = nil
        resetAllNotificationStatesCalled = false
        resetNotificationStateIfBelowCalled = false
        lastResetLimitType = nil
        lastResetCurrentSpendingUSD = nil
        lastResetWarningLimitUSD = nil
        lastResetUpperLimitUSD = nil
    }
}
