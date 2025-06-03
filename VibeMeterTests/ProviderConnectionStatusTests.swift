import SwiftUI
@testable import VibeMeter
import XCTest

final class ProviderConnectionStatusTests: XCTestCase {
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

    // MARK: - Codable Tests

    func testCodable_Disconnected_EncodesAndDecodes() throws {
        // Given
        let status = ProviderConnectionStatus.disconnected

        // When
        let encoded = try JSONEncoder().encode(status)
        let decoded = try JSONDecoder().decode(ProviderConnectionStatus.self, from: encoded)

        // Then
        XCTAssertEqual(status, decoded)
    }

    func testCodable_Connecting_EncodesAndDecodes() throws {
        // Given
        let status = ProviderConnectionStatus.connecting

        // When
        let encoded = try JSONEncoder().encode(status)
        let decoded = try JSONDecoder().decode(ProviderConnectionStatus.self, from: encoded)

        // Then
        XCTAssertEqual(status, decoded)
    }

    func testCodable_Connected_EncodesAndDecodes() throws {
        // Given
        let status = ProviderConnectionStatus.connected

        // When
        let encoded = try JSONEncoder().encode(status)
        let decoded = try JSONDecoder().decode(ProviderConnectionStatus.self, from: encoded)

        // Then
        XCTAssertEqual(status, decoded)
    }

    func testCodable_Syncing_EncodesAndDecodes() throws {
        // Given
        let status = ProviderConnectionStatus.syncing

        // When
        let encoded = try JSONEncoder().encode(status)
        let decoded = try JSONDecoder().decode(ProviderConnectionStatus.self, from: encoded)

        // Then
        XCTAssertEqual(status, decoded)
    }

    func testCodable_Error_EncodesAndDecodes() throws {
        // Given
        let status = ProviderConnectionStatus.error(message: "Network connection failed")

        // When
        let encoded = try JSONEncoder().encode(status)
        let decoded = try JSONDecoder().decode(ProviderConnectionStatus.self, from: encoded)

        // Then
        XCTAssertEqual(status, decoded)

        if case let .error(message) = decoded {
            XCTAssertEqual(message, "Network connection failed")
        } else {
            XCTFail("Decoded status should be error case")
        }
    }

    func testCodable_RateLimited_WithoutDate_EncodesAndDecodes() throws {
        // Given
        let status = ProviderConnectionStatus.rateLimited(until: nil)

        // When
        let encoded = try JSONEncoder().encode(status)
        let decoded = try JSONDecoder().decode(ProviderConnectionStatus.self, from: encoded)

        // Then
        XCTAssertEqual(status, decoded)

        if case let .rateLimited(until) = decoded {
            XCTAssertNil(until)
        } else {
            XCTFail("Decoded status should be rateLimited case")
        }
    }

    func testCodable_RateLimited_WithDate_EncodesAndDecodes() throws {
        // Given
        let date = Date(timeIntervalSince1970: 1_640_995_200) // Fixed date for testing
        let status = ProviderConnectionStatus.rateLimited(until: date)

        // When
        let encoded = try JSONEncoder().encode(status)
        let decoded = try JSONDecoder().decode(ProviderConnectionStatus.self, from: encoded)

        // Then
        XCTAssertEqual(status, decoded)

        if case let .rateLimited(until) = decoded {
            XCTAssertEqual(until, date)
        } else {
            XCTFail("Decoded status should be rateLimited case")
        }
    }

    func testCodable_Stale_EncodesAndDecodes() throws {
        // Given
        let status = ProviderConnectionStatus.stale

        // When
        let encoded = try JSONEncoder().encode(status)
        let decoded = try JSONDecoder().decode(ProviderConnectionStatus.self, from: encoded)

        // Then
        XCTAssertEqual(status, decoded)
    }

    func testCodable_UnknownType_DefaultsToDisconnected() throws {
        // Given - Manually create JSON with unknown type
        let json = """
        {"type": "unknownType"}
        """.data(using: .utf8)!

        // When
        let decoded = try JSONDecoder().decode(ProviderConnectionStatus.self, from: json)

        // Then
        XCTAssertEqual(decoded, .disconnected)
    }

    func testCodable_MalformedError_ThrowsError() {
        // Given - Error case without message
        let json = """
        {"type": "error"}
        """.data(using: .utf8)!

        // When/Then
        XCTAssertThrowsError(try JSONDecoder().decode(ProviderConnectionStatus.self, from: json))
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

    // MARK: - User-Friendly Error Messages Tests

    func testUserFriendlyError_NetworkErrors() {
        // Given
        let networkErrors = [
            "Network connection failed",
            "CONNECTION_TIMEOUT",
            "network unavailable",
        ]

        for error in networkErrors {
            // When
            let status = ProviderConnectionStatus.error(message: error)

            // Then
            XCTAssertEqual(
                status.description,
                "Connection failed",
                "Network error '\(error)' should be converted to user-friendly message")
        }
    }

    func testUserFriendlyError_AuthErrors() {
        // Given
        let authErrors = [
            "Unauthorized access",
            "Authentication required",
            "auth token expired",
        ]

        for error in authErrors {
            // When
            let status = ProviderConnectionStatus.error(message: error)

            // Then
            XCTAssertEqual(
                status.description,
                "Authentication failed",
                "Auth error '\(error)' should be converted to user-friendly message")
        }
    }

    func testUserFriendlyError_TimeoutErrors() {
        // Given
        let timeoutErrors = [
            "Request timeout",
            "TIMEOUT occurred",
            "operation timed out",
        ]

        for error in timeoutErrors {
            // When
            let status = ProviderConnectionStatus.error(message: error)

            // Then
            XCTAssertEqual(
                status.description,
                "Request timed out",
                "Timeout error '\(error)' should be converted to user-friendly message")
        }
    }

    func testUserFriendlyError_TeamNotFound() {
        // Given
        let teamErrors = [
            "Team not found",
            "TEAM NOT FOUND for user",
        ]

        for error in teamErrors {
            // When
            let status = ProviderConnectionStatus.error(message: error)

            // Then
            XCTAssertEqual(
                status.description,
                "Team not found",
                "Team error '\(error)' should be converted to user-friendly message")
        }
    }

    func testUserFriendlyError_GenericError_Truncated() {
        // Given
        let longError = String(repeating: "a", count: 100)

        // When
        let status = ProviderConnectionStatus.error(message: longError)

        // Then
        XCTAssertEqual(
            status.description,
            String(longError.prefix(50)),
            "Long error should be truncated to 50 characters")
    }

    func testUserFriendlyError_GenericError_Preserved() {
        // Given
        let shortError = "Custom error message"

        // When
        let status = ProviderConnectionStatus.error(message: shortError)

        // Then
        XCTAssertEqual(status.description, shortError, "Short error should be preserved as-is")
    }

    // MARK: - Factory Methods Tests

    func testFromProviderError_Unauthorized() {
        // When
        let status = ProviderConnectionStatus.from(ProviderError.unauthorized)

        // Then
        if case let .error(message) = status {
            XCTAssertEqual(message, "Authentication failed")
        } else {
            XCTFail("Should create error status")
        }
    }

    func testFromProviderError_RateLimitExceeded() {
        // When
        let status = ProviderConnectionStatus.from(ProviderError.rateLimitExceeded)

        // Then
        if case let .rateLimited(until) = status {
            XCTAssertNil(until)
        } else {
            XCTFail("Should create rateLimited status")
        }
    }

    func testFromProviderError_NetworkError() {
        // Given
        let networkError = ProviderError.networkError(message: "Connection lost", statusCode: 500)

        // When
        let status = ProviderConnectionStatus.from(networkError)

        // Then
        if case let .error(message) = status {
            XCTAssertEqual(message, "Connection lost")
        } else {
            XCTFail("Should create error status")
        }
    }

    func testFromProviderError_AllCases() {
        // Given
        let providerErrors: [ProviderError] = [
            .unauthorized,
            .rateLimitExceeded,
            .networkError(message: "test", statusCode: 500),
            .noTeamFound,
            .teamIdNotSet,
            .serviceUnavailable,
            .decodingError(message: "test", statusCode: 400),
            .unsupportedProvider(.cursor),
            .authenticationFailed(reason: "test"),
            .tokenExpired,
        ]

        // When/Then
        for error in providerErrors {
            let status = ProviderConnectionStatus.from(error)
            XCTAssertNotNil(status, "Should create status for error: \(error)")

            // Verify specific mappings
            switch error {
            case .rateLimitExceeded:
                if case .rateLimited = status {
                    // Expected
                } else {
                    XCTFail("Rate limit error should create rateLimited status")
                }
            default:
                if case .error = status {
                    // Expected
                } else {
                    XCTFail("Non-rate-limit error should create error status")
                }
            }
        }
    }

    func testFromNetworkRetryError_RateLimited() {
        // Given
        let retryAfter: TimeInterval = 300 // 5 minutes
        let retryError = NetworkRetryHandler.RetryableError.rateLimited(retryAfter: retryAfter)

        // When
        let status = ProviderConnectionStatus.from(retryError)

        // Then
        XCTAssertNotNil(status)
        if case let .rateLimited(until) = status {
            XCTAssertNotNil(until)
            // Verify the date is approximately correct (within 1 second)
            let expectedDate = Date(timeIntervalSinceNow: retryAfter)
            XCTAssertEqual(until!.timeIntervalSince1970, expectedDate.timeIntervalSince1970, accuracy: 1.0)
        } else {
            XCTFail("Should create rateLimited status")
        }
    }

    func testFromNetworkRetryError_ServerError() {
        // Given
        let serverError = NetworkRetryHandler.RetryableError.serverError(statusCode: 503)

        // When
        let status = ProviderConnectionStatus.from(serverError)

        // Then
        XCTAssertNotNil(status)
        if case let .error(message) = status {
            XCTAssertEqual(message, "Server error")
        } else {
            XCTFail("Should create error status")
        }
    }

    func testFromNetworkRetryError_AllCases() {
        // Given
        let retryErrors: [NetworkRetryHandler.RetryableError] = [
            .rateLimited(retryAfter: 300),
            .serverError(statusCode: 500),
            .networkTimeout,
            .connectionError,
        ]

        // When/Then
        for error in retryErrors {
            let status = ProviderConnectionStatus.from(error)
            XCTAssertNotNil(status, "Should create status for retry error: \(error)")
        }
    }

    // MARK: - Equatable Tests

    func testEquatable_SameValues_AreEqual() {
        // Given
        let status1 = ProviderConnectionStatus.error(message: "test")
        let status2 = ProviderConnectionStatus.error(message: "test")
        let date = Date()
        let rateLimited1 = ProviderConnectionStatus.rateLimited(until: date)
        let rateLimited2 = ProviderConnectionStatus.rateLimited(until: date)

        // Then
        XCTAssertEqual(status1, status2)
        XCTAssertEqual(rateLimited1, rateLimited2)
        XCTAssertEqual(ProviderConnectionStatus.connected, ProviderConnectionStatus.connected)
    }

    func testEquatable_DifferentValues_AreNotEqual() {
        // Given
        let status1 = ProviderConnectionStatus.error(message: "test1")
        let status2 = ProviderConnectionStatus.error(message: "test2")
        let date1 = Date()
        let date2 = Date().addingTimeInterval(100)
        let rateLimited1 = ProviderConnectionStatus.rateLimited(until: date1)
        let rateLimited2 = ProviderConnectionStatus.rateLimited(until: date2)

        // Then
        XCTAssertNotEqual(status1, status2)
        XCTAssertNotEqual(rateLimited1, rateLimited2)
        XCTAssertNotEqual(ProviderConnectionStatus.connected, ProviderConnectionStatus.disconnected)
    }

    // MARK: - Sendable Conformance Tests

    func testProviderConnectionStatus_IsSendable() {
        // Then
        XCTAssertTrue(ProviderConnectionStatus.self is any Sendable.Type, "ProviderConnectionStatus should be Sendable")
    }

    func testConcurrentAccess_ThreadSafety() async {
        // Given
        let status = ProviderConnectionStatus.connected
        let taskCount = 50

        // When - Perform concurrent reads
        await withTaskGroup(of: Bool.self) { group in
            for _ in 0 ..< taskCount {
                group.addTask {
                    let color = status.displayColor
                    let icon = status.iconName
                    let description = status.description
                    let isActive = status.isActive

                    return color == .green && icon == "checkmark.circle.fill" &&
                        description == "Connected" && !isActive
                }
            }

            // Collect results
            var results: [Bool] = []
            for await result in group {
                results.append(result)
            }

            // Then
            XCTAssertEqual(results.count, taskCount, "All tasks should complete")
            XCTAssertTrue(results.allSatisfy(\.self), "All concurrent reads should succeed")
        }
    }
}
