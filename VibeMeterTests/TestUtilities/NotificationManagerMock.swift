import Foundation
@testable import VibeMeter

@MainActor
final class NotificationManagerMock: NotificationManagerProtocol, MockResetProtocol, @unchecked Sendable {
    var requestAuthorizationCalled = false
    var authorizationGrantedToReturn: Bool = true

    var showWarningNotificationCalled = false
    var lastWarningSpending: Double?
    var lastWarningLimit: Double?
    var lastWarningCurrency: String?

    var showUpperLimitNotificationCalled = false
    var lastUpperLimitSpending: Double?
    var lastUpperLimitAmount: Double?
    var lastUpperLimitCurrency: String?

    var resetAllNotificationStatesCalled = false
    var resetNotificationStateIfBelowCalled = false
    var lastResetLimitType: NotificationLimitType?
    var lastResetCurrentSpendingUSD: Double?
    var lastResetWarningLimitUSD: Double?
    var lastResetUpperLimitUSD: Double?

    func requestAuthorization() async -> Bool {
        requestAuthorizationCalled = true
        return authorizationGrantedToReturn
    }

    func showWarningNotification(currentSpending: Double, limitAmount: Double, currencyCode: String) async {
        showWarningNotificationCalled = true
        lastWarningSpending = currentSpending
        lastWarningLimit = limitAmount
        lastWarningCurrency = currencyCode
    }

    func showUpperLimitNotification(currentSpending: Double, limitAmount: Double, currencyCode: String) async {
        showUpperLimitNotificationCalled = true
        lastUpperLimitSpending = currentSpending
        lastUpperLimitAmount = limitAmount
        lastUpperLimitCurrency = currencyCode
    }

    func resetNotificationStateIfBelow(
        limitType: NotificationLimitType,
        currentSpendingUSD: Double,
        warningLimitUSD: Double,
        upperLimitUSD: Double) async {
        resetNotificationStateIfBelowCalled = true
        lastResetLimitType = limitType
        lastResetCurrentSpendingUSD = currentSpendingUSD
        lastResetWarningLimitUSD = warningLimitUSD
        lastResetUpperLimitUSD = upperLimitUSD
    }

    func resetAllNotificationStatesForNewSession() async {
        resetAllNotificationStatesCalled = true
    }

    func reset() {
        resetTracking()
        resetReturnValues()
    }

    func resetTracking() {
        requestAuthorizationCalled = false
        showWarningNotificationCalled = false
        showUpperLimitNotificationCalled = false
        resetAllNotificationStatesCalled = false
        resetNotificationStateIfBelowCalled = false
    }

    func resetReturnValues() {
        authorizationGrantedToReturn = true
        lastWarningSpending = nil
        lastWarningLimit = nil
        lastWarningCurrency = nil
        lastUpperLimitSpending = nil
        lastUpperLimitAmount = nil
        lastUpperLimitCurrency = nil
        lastResetLimitType = nil
        lastResetCurrentSpendingUSD = nil
        lastResetWarningLimitUSD = nil
        lastResetUpperLimitUSD = nil
    }
}
