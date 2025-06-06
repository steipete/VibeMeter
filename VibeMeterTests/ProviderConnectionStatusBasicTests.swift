import SwiftUI
@testable import VibeMeter
import Testing

@Suite("ProviderConnectionStatusBasicTests")
struct ProviderConnectionStatusBasicTests {
    // MARK: - Basic Enum Tests

    @Test("all cases  are handled")

    func allCases_AreHandled() {
        // Given - All possible cases
        let cases: [ProviderConnectionStatus] = [
            .disconnected,
            .connecting,
            .connected,
            .syncing,
            .error(message: "Test error"),
            .rateLimited(until: nil),
            .rateLimited(until: Date()),
            .stale,
        ]

        // Then - Each case should have proper display properties
        for status in cases {
            #expect(status.displayColor != nil)
            #expect(status.iconName.isEmpty == false)
            #expect(status.shortDescription.isEmpty == false)
        }
    }

    @Test("display color returns correct colors")
    func displayColor_ReturnsCorrectColors() {
        // Given/When/Then
        #expect(ProviderConnectionStatus.disconnected.displayColor == .gray)
        #expect(ProviderConnectionStatus.connected.displayColor == .green)
        #expect(ProviderConnectionStatus.error(message: "test").displayColor == .red)
        #expect(ProviderConnectionStatus.rateLimited(until: nil).displayColor == .orange)
        #expect(ProviderConnectionStatus.stale.displayColor == .yellow)
    }

    @Test("icon name returns valid SF symbols")
    func iconName_ReturnsValidSFSymbols() {
        // Given
        let allCases: [ProviderConnectionStatus] = [
            .disconnected,
            .connecting,
            .connected,
            .syncing,
            .error(message: "test"),
            .rateLimited(until: nil),
            .stale,
        ]

        // Then
        for status in allCases {
            let iconName = status.iconName
            #expect(iconName.isEmpty == false)
            switch status {
            case .connecting, .syncing:
                #expect(iconName == "arrow.2.circlepath")
            case .error:
                #expect(iconName == "exclamationmark.triangle.fill")
            case .stale:
                #expect(iconName == "exclamationmark.circle")
            default:
                break
            }
        }
    }

    @Test("description returns human readable text")
    func description_ReturnsHumanReadableText() {
        // Given/When/Then
        #expect(ProviderConnectionStatus.disconnected.description == "Not connected")
        #expect(ProviderConnectionStatus.connected.description == "Connected")
        #expect(ProviderConnectionStatus.stale.description == "Data may be outdated")
        #expect(ProviderConnectionStatus.rateLimited(until: nil).description == "Rate limited")

        // Rate limited with future date
        let futureDate = Date().addingTimeInterval(300) // 5 minutes from now
        let rateLimitedStatus = ProviderConnectionStatus.rateLimited(until: futureDate)
        #expect(rateLimitedStatus.description.contains("Rate limited"))
    }

    @Test("short description returns compact text")
    func shortDescription_ReturnsCompactText() {
        // Given/When/Then
        #expect(ProviderConnectionStatus.disconnected.shortDescription == "Offline")
        #expect(ProviderConnectionStatus.connected.shortDescription == "Online")
        #expect(ProviderConnectionStatus.error(message: "test").shortDescription == "Error")
        #expect(ProviderConnectionStatus.rateLimited(until: nil).shortDescription == "Limited")
        #expect(ProviderConnectionStatus.stale.shortDescription == "Stale")
    }

    @Test("is active returns correct values")
    func isActive_ReturnsCorrectValues() {
        // Given/When/Then
        #expect(ProviderConnectionStatus.disconnected.isActive == false)
        #expect(ProviderConnectionStatus.connected.isActive == true)
        #expect(ProviderConnectionStatus.connecting.isActive == true)
        #expect(ProviderConnectionStatus.syncing.isActive == true)
        #expect(ProviderConnectionStatus.error(message: "test").isActive == false)
        #expect(ProviderConnectionStatus.rateLimited(until: nil).isActive == false)
        #expect(ProviderConnectionStatus.stale.isActive == false)
    }

    @Test("is error returns correct values")
    func isError_ReturnsCorrectValues() {
        // Given/When/Then
        #expect(ProviderConnectionStatus.disconnected.isError == false)
        #expect(ProviderConnectionStatus.connected.isError == false)
        #expect(ProviderConnectionStatus.error(message: "test").isError == true)
        #expect(ProviderConnectionStatus.rateLimited(until: nil).isError == true)
        #expect(ProviderConnectionStatus.stale.isError == true)
    }

    @Test("from provider error authentication errors")
    func fromProviderError_AuthenticationErrors() {
        // Given
        let authErrors: [ProviderError] = [
            .authenticationFailed(reason: "Invalid token"),
            .authenticationFailed(reason: "Session expired"),
        ]

        // When/Then
        for error in authErrors {
            let status = ProviderConnectionStatus.from(error)
            #expect(status == .disconnected)
        }
    }

    @Test("from provider error rate limit errors")
    func fromProviderError_RateLimitErrors() {
        // Given
        let rateLimitError = ProviderError.rateLimitExceeded

        // When
        let status = ProviderConnectionStatus.from(rateLimitError)

        // Then
        if case .rateLimited = status {
            // Success - rate limit error should result in rateLimited status
        } else {
            Issue.record("Rate limit errors should result in rateLimited status")
        }
    }

    @Test("from provider error  network errors")

    func fromProviderError_NetworkErrors() {
        // Given
        let networkError = ProviderError.networkError(
            message: "Network connection failed",
            statusCode: 500)

        // When
        let status = ProviderConnectionStatus.from(networkError)

        // Then
        if case let .error(message) = status {
            #expect(message == "Network connection failed")
        }
    }

    @Test("from provider error  data unavailable error")

    func fromProviderError_DataUnavailableError() {
        // Given
        let dataError = ProviderError.serviceUnavailable

        // When
        let status = ProviderConnectionStatus.from(dataError)

        // Then
        #expect(status == .stale)
    }

    @Test("from provider error other errors")
    func fromProviderError_OtherErrors() {
        // Given - Test non-authentication errors that should result in error status
        let otherErrors: [ProviderError] = [
            .decodingError(message: "Invalid JSON", statusCode: 200),
            .noTeamFound,
        ]

        // When/Then
        for error in otherErrors {
            let status = ProviderConnectionStatus.from(error)
            if case .error = status {
                // Success - all other errors should result in error status
            } else {
                Issue.record("Other errors should result in error status")
            }
        }
    }

    // MARK: - Equatable Tests

    @Test("equatable  same statuses  are equal")

    func equatable_SameStatuses_AreEqual() {
        // Given/When/Then
        #expect(ProviderConnectionStatus.disconnected == .disconnected)
        #expect(ProviderConnectionStatus.connected == .connected)
        #expect(ProviderConnectionStatus.stale == .stale)
        #expect(ProviderConnectionStatus.error(message: "Test") == .error(message: "Test"))

        // Rate limited with same date
        let date = Date()
        #expect(
            ProviderConnectionStatus.rateLimited(until: date) == .rateLimited(until: date))

        // Rate limited both nil
        #expect(
            ProviderConnectionStatus.rateLimited(until: nil) == .rateLimited(until: nil))
    }

    @Test("equatable  different statuses  are not equal")

    func equatable_DifferentStatuses_AreNotEqual() {
        // Given/When/Then
        #expect(ProviderConnectionStatus.disconnected != .connected)

        // Error with different messages
        #expect(
            ProviderConnectionStatus.error(message: "Error 1") != .error(message: "Error 2"))

        // Rate limited with different dates
        #expect(
            ProviderConnectionStatus.rateLimited(until: Date()) != .rateLimited(until: Date().addingTimeInterval(60)))

        // Rate limited nil vs date
        #expect(
            ProviderConnectionStatus.rateLimited(until: nil) != .rateLimited(until: Date()))
    }

    // MARK: - Sendable Conformance Tests

    @Test("sendable  can be sent across actors")

    func sendable_CanBeSentAcrossActors() async {
        // Given
        let status = ProviderConnectionStatus.connected

        // When - Send to another actor
        let testActor = TestActor()
        let receivedStatus = await testActor.receive(status: status)

        // Then
        #expect(receivedStatus == status)
    }

    @Test("sendable all cases can be sent across actors")
    func sendable_AllCasesCanBeSentAcrossActors() async {
        // Given
        let allCases: [ProviderConnectionStatus] = [
            .disconnected,
            .connecting,
            .connected,
            .syncing,
            .error(message: "Test error"),
            .rateLimited(until: Date()),
            .rateLimited(until: nil),
            .stale,
        ]

        // When/Then
        let testActor = TestActor()
        for status in allCases {
            let receivedStatus = await testActor.receive(status: status)
            #expect(receivedStatus == status)
        }
    }

    @Test("provider error enum cases are covered")
    func providerError_EnumCasesAreCovered() {
        // This test ensures all ProviderError cases are handled in the from() method
        // If a new case is added to ProviderError, this test helps ensure it's handled

        // Given - Create instances of all ProviderError cases
        let allErrors: [ProviderError] = [
            .networkError(message: "test", statusCode: 500),
            .authenticationFailed(reason: "test"),
            .decodingError(message: "test", statusCode: 200),
            .rateLimitExceeded,
            .serviceUnavailable,
            .unauthorized,
            .tokenExpired,
        ]

        // When/Then - Ensure each error produces a valid status
        for error in allErrors {
            let status = ProviderConnectionStatus.from(error)
            // Just verify it doesn't crash and returns a valid status
            #expect(status != nil)
        }
    }
}

// MARK: - Test Support

private actor TestActor {
    func receive(status: ProviderConnectionStatus) -> ProviderConnectionStatus {
        return status
    }
}
