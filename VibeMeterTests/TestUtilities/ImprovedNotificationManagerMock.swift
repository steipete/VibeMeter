import Foundation
import Testing
@testable import VibeMeter

// MARK: - Call Recording Types

enum NotificationManagerCall: Sendable {
    case requestAuthorization
    case showWarningNotification(currentSpending: Double, limitAmount: Double, currencyCode: String)
    case showUpperLimitNotification(currentSpending: Double, limitAmount: Double, currencyCode: String)
    case resetAllNotificationStates
    case resetNotificationStateIfBelow(
        limitType: NotificationLimitType,
        currentSpendingUSD: Double,
        warningLimitUSD: Double,
        upperLimitUSD: Double)
    case showInstanceAlreadyRunningNotification
}

// MARK: - Improved Mock Using Generic Protocol

@MainActor
final class ImprovedNotificationManagerMock: NotificationManagerProtocol, MockResetProtocol {
    // Call tracking
    var calls: [NotificationManagerCall] = []

    // Response configuration
    private let responseBuilder = MockResponseBuilder<Bool>()
    var authorizationGrantedToReturn: Bool = true

    // MARK: - NotificationManagerProtocol Implementation

    func requestAuthorization() async -> Bool {
        calls.append(.requestAuthorization)
        return authorizationGrantedToReturn
    }

    func showWarningNotification(currentSpending: Double, limitAmount: Double, currencyCode: String) async {
        calls.append(.showWarningNotification(
            currentSpending: currentSpending,
            limitAmount: limitAmount,
            currencyCode: currencyCode))
    }

    func showUpperLimitNotification(currentSpending: Double, limitAmount: Double, currencyCode: String) async {
        calls.append(.showUpperLimitNotification(
            currentSpending: currentSpending,
            limitAmount: limitAmount,
            currencyCode: currencyCode))
    }

    func resetAllNotificationStatesForNewSession() async {
        calls.append(.resetAllNotificationStates)
    }

    func resetNotificationStateIfBelow(
        limitType: NotificationLimitType,
        currentSpendingUSD: Double,
        warningLimitUSD: Double,
        upperLimitUSD: Double) async {
        calls.append(.resetNotificationStateIfBelow(
            limitType: limitType,
            currentSpendingUSD: currentSpendingUSD,
            warningLimitUSD: warningLimitUSD,
            upperLimitUSD: upperLimitUSD))
    }

    func showInstanceAlreadyRunningNotification() async {
        calls.append(.showInstanceAlreadyRunningNotification)
    }

    // MARK: - MockResetProtocol Implementation

    func reset() {
        calls.removeAll()
        authorizationGrantedToReturn = true
        responseBuilder.reset()
    }

    func resetTracking() {
        calls.removeAll()
    }

    func resetReturnValues() {
        authorizationGrantedToReturn = true
        responseBuilder.reset()
    }

    // MARK: - Convenience Methods for Testing

    /// Check if a specific method was called
    func wasCalled(_ method: NotificationManagerCall) -> Bool {
        calls.contains { call in
            switch (call, method) {
            case (.requestAuthorization, .requestAuthorization),
                 (.resetAllNotificationStates, .resetAllNotificationStates),
                 (.showInstanceAlreadyRunningNotification, .showInstanceAlreadyRunningNotification):
                true
            case let (.showWarningNotification(cs1, la1, cc1), .showWarningNotification(cs2, la2, cc2)):
                cs1 == cs2 && la1 == la2 && cc1 == cc2
            case let (.showUpperLimitNotification(cs1, la1, cc1), .showUpperLimitNotification(cs2, la2, cc2)):
                cs1 == cs2 && la1 == la2 && cc1 == cc2
            case let (
                .resetNotificationStateIfBelow(lt1, cs1, wl1, ul1),
                .resetNotificationStateIfBelow(lt2, cs2, wl2, ul2)):
                lt1 == lt2 && cs1 == cs2 && wl1 == wl2 && ul1 == ul2
            default:
                false
            }
        }
    }

    /// Get the last warning notification call
    var lastWarningNotification: (spending: Double, limit: Double, currency: String)? {
        for call in calls.reversed() {
            if case let .showWarningNotification(spending, limit, currency) = call {
                return (spending, limit, currency)
            }
        }
        return nil
    }

    /// Get the last upper limit notification call
    var lastUpperLimitNotification: (spending: Double, limit: Double, currency: String)? {
        for call in calls.reversed() {
            if case let .showUpperLimitNotification(spending, limit, currency) = call {
                return (spending, limit, currency)
            }
        }
        return nil
    }

    /// Count calls of a specific type
    func callCount(for methodType: NotificationMethodType) -> Int {
        calls.count(where: { call in
            switch (call, methodType) {
            case (_, .requestAuthorization) where call.isRequestAuthorization:
                true
            case (_, .showWarning) where call.isShowWarning:
                true
            case (_, .showUpperLimit) where call.isShowUpperLimit:
                true
            case (_, .resetAll) where call.isResetAll:
                true
            case (_, .resetIfBelow) where call.isResetIfBelow:
                true
            case (_, .showInstanceRunning) where call.isShowInstanceRunning:
                true
            default:
                false
            }
        })
    }
}

// MARK: - Helper Types

enum NotificationMethodType {
    case requestAuthorization
    case showWarning
    case showUpperLimit
    case resetAll
    case resetIfBelow
    case showInstanceRunning
}

// MARK: - Call Type Extensions

extension NotificationManagerCall {
    var isRequestAuthorization: Bool {
        if case .requestAuthorization = self { return true }
        return false
    }

    var isShowWarning: Bool {
        if case .showWarningNotification = self { return true }
        return false
    }

    var isShowUpperLimit: Bool {
        if case .showUpperLimitNotification = self { return true }
        return false
    }

    var isResetAll: Bool {
        if case .resetAllNotificationStates = self { return true }
        return false
    }

    var isResetIfBelow: Bool {
        if case .resetNotificationStateIfBelow = self { return true }
        return false
    }

    var isShowInstanceRunning: Bool {
        if case .showInstanceAlreadyRunningNotification = self { return true }
        return false
    }
}

// MARK: - Test Verification Extensions

extension ImprovedNotificationManagerMock {
    /// Verify that authorization was requested
    func verifyAuthorizationRequested(times: Int = 1, sourceLocation: SourceLocation = #_sourceLocation) {
        let count = callCount(for: .requestAuthorization)
        #expect(count == times,
                "Expected requestAuthorization to be called \(times) time(s), but was called \(count) time(s)",
                sourceLocation: sourceLocation)
    }

    /// Verify that a warning notification was shown
    func verifyWarningNotificationShown(sourceLocation: SourceLocation = #_sourceLocation) {
        #expect(callCount(for: .showWarning) > 0,
                "Expected showWarningNotification to be called",
                sourceLocation: sourceLocation)
    }

    /// Verify no notifications were shown
    func verifyNoNotificationsShown(sourceLocation: SourceLocation = #_sourceLocation) {
        let warningCount = callCount(for: .showWarning)
        let upperLimitCount = callCount(for: .showUpperLimit)
        #expect(warningCount == 0 && upperLimitCount == 0,
                "Expected no notifications, but found \(warningCount) warnings and \(upperLimitCount) upper limit notifications",
                sourceLocation: sourceLocation)
    }
}
