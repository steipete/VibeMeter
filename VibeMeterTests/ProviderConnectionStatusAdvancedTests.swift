import SwiftUI
@testable import VibeMeter
import XCTest

final class ProviderConnectionStatusAdvancedTests: XCTestCase {
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
        let json = Data("""
        {"type": "unknownType"}
        """.utf8)

        // When
        let decoded = try JSONDecoder().decode(ProviderConnectionStatus.self, from: json)

        // Then
        XCTAssertEqual(decoded, .disconnected)
    }

    func testCodable_MalformedError_ThrowsError() {
        // Given - Error case without message
        let json = Data("""
        {"type": "error"}
        """.utf8)

        // When/Then
        XCTAssertThrowsError(try JSONDecoder().decode(ProviderConnectionStatus.self, from: json))
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
                "Authentication required",
                "Auth error '\(error)' should be converted to user-friendly message")
        }
    }

    func testUserFriendlyError_RateLimitErrors() {
        // Given
        let rateLimitErrors = [
            "Rate limit exceeded",
            "too many requests",
            "RATE_LIMITED",
        ]

        for error in rateLimitErrors {
            // When
            let status = ProviderConnectionStatus.error(message: error)

            // Then
            XCTAssertEqual(
                status.description,
                "Too many requests",
                "Rate limit error '\(error)' should be converted to user-friendly message")
        }
    }

    func testUserFriendlyError_ServerErrors() {
        // Given
        let serverErrors = [
            "Internal server error",
            "500 server error",
            "service unavailable",
        ]

        for error in serverErrors {
            // When
            let status = ProviderConnectionStatus.error(message: error)

            // Then
            XCTAssertEqual(
                status.description,
                "Service unavailable",
                "Server error '\(error)' should be converted to user-friendly message")
        }
    }

    func testUserFriendlyError_GenericErrors() {
        // Given
        let genericErrors = [
            "Something went wrong",
            "Unknown error occurred",
            "Unexpected response",
        ]

        for error in genericErrors {
            // When
            let status = ProviderConnectionStatus.error(message: error)

            // Then
            XCTAssertEqual(
                status.description,
                "Something went wrong",
                "Generic error '\(error)' should be converted to fallback message")
        }
    }

    // MARK: - Rate Limit Description Tests

    func testRateLimitDescription_WithNilDate_ShowsGenericMessage() {
        // Given
        let status = ProviderConnectionStatus.rateLimited(until: nil)

        // When/Then
        XCTAssertEqual(status.description, "Rate limited")
    }

    func testRateLimitDescription_WithPastDate_ShowsExpiredMessage() {
        // Given
        let pastDate = Date().addingTimeInterval(-60) // 1 minute ago
        let status = ProviderConnectionStatus.rateLimited(until: pastDate)

        // When/Then
        XCTAssertEqual(status.description, "Rate limited")
    }

    func testRateLimitDescription_WithNearFutureDate_ShowsTimeRemaining() {
        // Given
        let futureDate = Date().addingTimeInterval(45) // 45 seconds from now
        let status = ProviderConnectionStatus.rateLimited(until: futureDate)

        // When
        let description = status.description

        // Then
        XCTAssertTrue(description.contains("Rate limited"))
        // The exact time might vary slightly due to test execution time
    }

    func testRateLimitDescription_WithFarFutureDate_ShowsTimeRemaining() {
        // Given
        let futureDate = Date().addingTimeInterval(3700) // Just over 1 hour from now
        let status = ProviderConnectionStatus.rateLimited(until: futureDate)

        // When
        let description = status.description

        // Then
        XCTAssertTrue(description.contains("Rate limited"))
    }

    // MARK: - Edge Cases Tests

    func testErrorStatus_WithEmptyMessage_HandlesGracefully() {
        // Given
        let status = ProviderConnectionStatus.error(message: "")

        // When/Then
        XCTAssertEqual(status.description, "Something went wrong")
        XCTAssertEqual(status.shortDescription, "Error")
    }

    func testErrorStatus_WithWhitespaceMessage_HandlesGracefully() {
        // Given
        let status = ProviderConnectionStatus.error(message: "   ")

        // When/Then
        XCTAssertEqual(status.description, "Something went wrong")
    }

    func testRateLimitStatus_WithVeryDistantFutureDate_HandlesGracefully() {
        // Given
        let veryFarDate = Date().addingTimeInterval(86400 * 365) // 1 year from now
        let status = ProviderConnectionStatus.rateLimited(until: veryFarDate)

        // When
        let description = status.description

        // Then
        XCTAssertTrue(description.contains("Rate limited"))
        XCTAssertFalse(description.isEmpty)
    }

    // MARK: - JSON Encoding/Decoding Format Tests

    func testJSONFormat_Error_IncludesMessage() throws {
        // Given
        let status = ProviderConnectionStatus.error(message: "Test error message")

        // When
        let encoded = try JSONEncoder().encode(status)
        let json = try JSONSerialization.jsonObject(with: encoded) as? [String: Any]

        // Then
        XCTAssertEqual(json?["type"] as? String, "error")
        XCTAssertEqual(json?["message"] as? String, "Test error message")
    }

    func testJSONFormat_RateLimited_IncludesDate() throws {
        // Given
        let date = Date()
        let status = ProviderConnectionStatus.rateLimited(until: date)

        // When
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let encoded = try encoder.encode(status)
        let json = try JSONSerialization.jsonObject(with: encoded) as? [String: Any]

        // Then
        XCTAssertEqual(json?["type"] as? String, "rateLimited")
        XCTAssertNotNil(json?["until"])
    }

    func testJSONFormat_SimpleStates_OnlyIncludeType() throws {
        // Given
        let simpleStatuses: [ProviderConnectionStatus] = [
            .disconnected,
            .connecting,
            .connected,
            .syncing,
            .stale,
        ]

        // When/Then
        for status in simpleStatuses {
            let encoded = try JSONEncoder().encode(status)
            let json = try JSONSerialization.jsonObject(with: encoded) as? [String: Any]

            XCTAssertEqual(json?.count, 1, "Simple states should only have 'type' field")
            XCTAssertNotNil(json?["type"], "Should have 'type' field")
        }
    }
}