import SwiftUI
@testable import VibeMeter
import XCTest

final class ProviderConnectionStatusBasicTests: XCTestCase {
    // MARK: - Basic Enum Tests

    func testAllCases_AreHandled() {
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
            XCTAssertNotNil(status.displayColor, "Status \(status) should have a display color")
            XCTAssertFalse(status.iconName.isEmpty, "Status \(status) should have an icon name")
            XCTAssertFalse(status.description.isEmpty, "Status \(status) should have a description")
            XCTAssertFalse(status.shortDescription.isEmpty, "Status \(status) should have a short description")
        }
    }

    // MARK: - Display Properties Tests

    func testDisplayColor_ReturnsCorrectColors() {
        // Given/When/Then
        XCTAssertEqual(ProviderConnectionStatus.disconnected.displayColor, .gray)
        XCTAssertEqual(ProviderConnectionStatus.connecting.displayColor, .blue)
        XCTAssertEqual(ProviderConnectionStatus.connected.displayColor, .green)
        XCTAssertEqual(ProviderConnectionStatus.syncing.displayColor, .blue)
        XCTAssertEqual(ProviderConnectionStatus.error(message: "test").displayColor, .red)
        XCTAssertEqual(ProviderConnectionStatus.rateLimited(until: nil).displayColor, .orange)
        XCTAssertEqual(ProviderConnectionStatus.stale.displayColor, .yellow)
    }

    func testIconName_ReturnsValidSFSymbols() {
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
            XCTAssertFalse(iconName.isEmpty, "Icon name should not be empty for \(status)")

            // Verify these are valid SF Symbol names
            switch status {
            case .disconnected:
                XCTAssertEqual(iconName, "circle")
            case .connecting, .syncing:
                XCTAssertEqual(iconName, "arrow.2.circlepath")
            case .connected:
                XCTAssertEqual(iconName, "checkmark.circle.fill")
            case .error:
                XCTAssertEqual(iconName, "exclamationmark.triangle.fill")
            case .rateLimited:
                XCTAssertEqual(iconName, "clock.fill")
            case .stale:
                XCTAssertEqual(iconName, "exclamationmark.circle")
            }
        }
    }

    func testDescription_ReturnsHumanReadableText() {
        // Given/When/Then
        XCTAssertEqual(ProviderConnectionStatus.disconnected.description, "Not connected")
        XCTAssertEqual(ProviderConnectionStatus.connecting.description, "Connecting...")
        XCTAssertEqual(ProviderConnectionStatus.connected.description, "Connected")
        XCTAssertEqual(ProviderConnectionStatus.syncing.description, "Updating...")
        XCTAssertEqual(ProviderConnectionStatus.stale.description, "Data may be outdated")

        // Rate limited without date
        XCTAssertEqual(ProviderConnectionStatus.rateLimited(until: nil).description, "Rate limited")

        // Rate limited with future date
        let futureDate = Date().addingTimeInterval(300) // 5 minutes from now
        let rateLimitedStatus = ProviderConnectionStatus.rateLimited(until: futureDate)
        XCTAssertTrue(rateLimitedStatus.description.contains("Rate limited"))
    }

    func testShortDescription_ReturnsCompactText() {
        // Given/When/Then
        XCTAssertEqual(ProviderConnectionStatus.disconnected.shortDescription, "Offline")
        XCTAssertEqual(ProviderConnectionStatus.connecting.shortDescription, "Connecting")
        XCTAssertEqual(ProviderConnectionStatus.connected.shortDescription, "Online")
        XCTAssertEqual(ProviderConnectionStatus.syncing.shortDescription, "Syncing")
        XCTAssertEqual(ProviderConnectionStatus.error(message: "test").shortDescription, "Error")
        XCTAssertEqual(ProviderConnectionStatus.rateLimited(until: nil).shortDescription, "Limited")
        XCTAssertEqual(ProviderConnectionStatus.stale.shortDescription, "Stale")
    }

    func testIsActive_ReturnsCorrectValues() {
        // Given/When/Then
        XCTAssertFalse(ProviderConnectionStatus.disconnected.isActive)
        XCTAssertTrue(ProviderConnectionStatus.connecting.isActive)
        XCTAssertFalse(ProviderConnectionStatus.connected.isActive)
        XCTAssertTrue(ProviderConnectionStatus.syncing.isActive)
        XCTAssertFalse(ProviderConnectionStatus.error(message: "test").isActive)
        XCTAssertFalse(ProviderConnectionStatus.rateLimited(until: nil).isActive)
        XCTAssertFalse(ProviderConnectionStatus.stale.isActive)
    }

    func testIsError_ReturnsCorrectValues() {
        // Given/When/Then
        XCTAssertFalse(ProviderConnectionStatus.disconnected.isError)
        XCTAssertFalse(ProviderConnectionStatus.connecting.isError)
        XCTAssertFalse(ProviderConnectionStatus.connected.isError)
        XCTAssertFalse(ProviderConnectionStatus.syncing.isError)
        XCTAssertTrue(ProviderConnectionStatus.error(message: "test").isError)
        XCTAssertTrue(ProviderConnectionStatus.rateLimited(until: nil).isError)
        XCTAssertTrue(ProviderConnectionStatus.stale.isError)
    }

    // MARK: - Factory Methods Tests

    func testFromProviderError_AuthenticationErrors() {
        // Given
        let authErrors: [ProviderError] = [
            .authenticationFailed(reason: "Invalid token"),
            .authenticationFailed(reason: "Session expired"),
        ]

        // When/Then
        for error in authErrors {
            let status = ProviderConnectionStatus.from(error)
            XCTAssertEqual(status, .disconnected, "Authentication errors should result in disconnected status")
        }
    }

    func testFromProviderError_RateLimitErrors() {
        // Given
        let rateLimitError = ProviderError.rateLimitExceeded

        // When
        let status = ProviderConnectionStatus.from(rateLimitError)

        // Then
        if case .rateLimited = status {
            // Success - rate limit error should result in rateLimited status
        } else {
            XCTFail("Rate limit errors should result in rateLimited status")
        }
    }

    func testFromProviderError_NetworkErrors() {
        // Given
        let networkError = ProviderError.networkError(
            message: "Network connection failed",
            statusCode: 500)

        // When
        let status = ProviderConnectionStatus.from(networkError)

        // Then
        if case let .error(message) = status {
            XCTAssertEqual(message, "Network connection failed")
        } else {
            XCTFail("Network errors should result in error status")
        }
    }

    func testFromProviderError_DataUnavailableError() {
        // Given
        let dataError = ProviderError.serviceUnavailable

        // When
        let status = ProviderConnectionStatus.from(dataError)

        // Then
        XCTAssertEqual(status, .stale, "Service unavailable errors should result in stale status")
    }

    func testFromProviderError_OtherErrors() {
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
                XCTFail("Other errors should result in error status")
            }
        }
    }

    // MARK: - Equatable Tests

    func testEquatable_SameStatuses_AreEqual() {
        // Given/When/Then
        XCTAssertEqual(ProviderConnectionStatus.disconnected, .disconnected)
        XCTAssertEqual(ProviderConnectionStatus.connecting, .connecting)
        XCTAssertEqual(ProviderConnectionStatus.connected, .connected)
        XCTAssertEqual(ProviderConnectionStatus.syncing, .syncing)
        XCTAssertEqual(ProviderConnectionStatus.stale, .stale)

        // Error with same message
        XCTAssertEqual(
            ProviderConnectionStatus.error(message: "Test"),
            .error(message: "Test"))

        // Rate limited with same date
        let date = Date()
        XCTAssertEqual(
            ProviderConnectionStatus.rateLimited(until: date),
            .rateLimited(until: date))

        // Rate limited both nil
        XCTAssertEqual(
            ProviderConnectionStatus.rateLimited(until: nil),
            .rateLimited(until: nil))
    }

    func testEquatable_DifferentStatuses_AreNotEqual() {
        // Given/When/Then
        XCTAssertNotEqual(ProviderConnectionStatus.disconnected, .connected)
        XCTAssertNotEqual(ProviderConnectionStatus.connecting, .syncing)

        // Error with different messages
        XCTAssertNotEqual(
            ProviderConnectionStatus.error(message: "Error 1"),
            .error(message: "Error 2"))

        // Rate limited with different dates
        XCTAssertNotEqual(
            ProviderConnectionStatus.rateLimited(until: Date()),
            .rateLimited(until: Date().addingTimeInterval(60)))

        // Rate limited nil vs date
        XCTAssertNotEqual(
            ProviderConnectionStatus.rateLimited(until: nil),
            .rateLimited(until: Date()))
    }

    // MARK: - Sendable Conformance Tests

    func testSendable_CanBeSentAcrossActors() async {
        // Given
        let status = ProviderConnectionStatus.connected

        // When - Send to another actor
        let testActor = TestActor()
        let receivedStatus = await testActor.receive(status: status)

        // Then
        XCTAssertEqual(receivedStatus, status)
    }

    func testSendable_AllCasesCanBeSentAcrossActors() async {
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
            XCTAssertEqual(receivedStatus, status)
        }
    }

    func testProviderError_EnumCasesAreCovered() {
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
            XCTAssertNotNil(status)
        }
    }

    // MARK: - Helper Types

    private actor TestActor {
        func receive(status: ProviderConnectionStatus) -> ProviderConnectionStatus {
            status
        }
    }
}
