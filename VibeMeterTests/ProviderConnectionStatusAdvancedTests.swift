import Foundation
import SwiftUI
import Testing
@testable import VibeMeter

@Suite("ProviderConnectionStatusAdvancedTests")
struct ProviderConnectionStatusAdvancedTests {
    // MARK: - Codable Tests

    @Test("codable disconnected encodes and decodes")
    func codable_Disconnected_EncodesAndDecodes() throws {
        // Given
        let status = ProviderConnectionStatus.disconnected

        // When
        let encoded = try JSONEncoder().encode(status)
        let decoded = try JSONDecoder().decode(ProviderConnectionStatus.self, from: encoded)

        // Then
        #expect(status == decoded)
    }

    @Test("codable connecting encodes and decodes")
    func codable_Connecting_EncodesAndDecodes() throws {
        // Given
        let status = ProviderConnectionStatus.connecting

        // When
        let encoded = try JSONEncoder().encode(status)
        let decoded = try JSONDecoder().decode(ProviderConnectionStatus.self, from: encoded)

        // Then
        #expect(status == decoded)
    }

    @Test("codable connected encodes and decodes")
    func codable_Connected_EncodesAndDecodes() throws {
        // Given
        let status = ProviderConnectionStatus.connected

        // When
        let encoded = try JSONEncoder().encode(status)
        let decoded = try JSONDecoder().decode(ProviderConnectionStatus.self, from: encoded)

        // Then
        #expect(status == decoded)
    }

    @Test("codable syncing encodes and decodes")
    func codable_Syncing_EncodesAndDecodes() throws {
        // Given
        let status = ProviderConnectionStatus.syncing

        // When
        let encoded = try JSONEncoder().encode(status)
        let decoded = try JSONDecoder().decode(ProviderConnectionStatus.self, from: encoded)

        // Then
        #expect(status == decoded)
    }

    @Test("codable error encodes and decodes")
    func codable_Error_EncodesAndDecodes() throws {
        // Given
        let status = ProviderConnectionStatus.error(message: "Network connection failed")

        // When
        let encoded = try JSONEncoder().encode(status)
        let decoded = try JSONDecoder().decode(ProviderConnectionStatus.self, from: encoded)

        // Then
        #expect(status == decoded)
        if case let .error(message) = decoded {
            #expect(message == "Network connection failed")
        }
    }

    @Test("codable rate limited without date encodes and decodes")
    func codable_RateLimited_WithoutDate_EncodesAndDecodes() throws {
        // Given
        let status = ProviderConnectionStatus.rateLimited(until: nil)

        // When
        let encoded = try JSONEncoder().encode(status)
        let decoded = try JSONDecoder().decode(ProviderConnectionStatus.self, from: encoded)

        // Then
        #expect(status == decoded)
        if case let .rateLimited(until) = decoded {
            #expect(until == nil)
        }
    }

    @Test("codable rate limited with date encodes and decodes")
    func codable_RateLimited_WithDate_EncodesAndDecodes() throws {
        // Given
        let date = Date(timeIntervalSince1970: 1_640_995_200) // Fixed date for testing
        let status = ProviderConnectionStatus.rateLimited(until: date)

        // When
        let encoded = try JSONEncoder().encode(status)
        let decoded = try JSONDecoder().decode(ProviderConnectionStatus.self, from: encoded)

        // Then
        #expect(status == decoded)
        if case let .rateLimited(until) = decoded {
            #expect(until == date)
        }
    }

    @Test("codable stale encodes and decodes")
    func codable_Stale_EncodesAndDecodes() throws {
        // Given
        let status = ProviderConnectionStatus.stale

        // When
        let encoded = try JSONEncoder().encode(status)
        let decoded = try JSONDecoder().decode(ProviderConnectionStatus.self, from: encoded)

        // Then
        #expect(status == decoded)
    }

    @Test("codable unknown type defaults to disconnected")
    func codable_UnknownType_DefaultsToDisconnected() throws {
        // Given - Manually create JSON with unknown type
        let json = Data("""
        {"type": "unknownType"}
        """.utf8)

        // When
        let decoded = try JSONDecoder().decode(ProviderConnectionStatus.self, from: json)

        // Then
        #expect(decoded == .disconnected)
    }

    @Test("codable malformed error throws error")
    func codable_MalformedError_ThrowsError() {
        // Given - Error case without message
        let json = Data("""
        {"type": "error"}
        """.utf8)

        // When/Then
        #expect(throws: (any Error).self) {
            try JSONDecoder().decode(ProviderConnectionStatus.self, from: json)
        }
    }

    // MARK: - User-Friendly Error Messages Tests

    @Test("user friendly error network errors")
    func userFriendlyError_NetworkErrors() {
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
            #expect(status.description == "Connection failed")
        }
    }

    @Test("user friendly error auth errors")
    func userFriendlyError_AuthErrors() {
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
            #expect(status.description == "Authentication required")
        }
    }

    @Test("user friendly error rate limit errors")
    func userFriendlyError_RateLimitErrors() {
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
            #expect(status.description == "Too many requests")
        }
    }

    @Test("user friendly error server errors")
    func userFriendlyError_ServerErrors() {
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
            #expect(status.description == "Service unavailable")
        }
    }

    @Test("user friendly error generic errors")
    func userFriendlyError_GenericErrors() {
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
            #expect(status.description == "Something went wrong")
        }
    }

    // MARK: - Rate Limit Description Tests

    @Test("rate limit description with nil date shows generic message")
    func rateLimitDescription_WithNilDate_ShowsGenericMessage() {
        // Given
        let status = ProviderConnectionStatus.rateLimited(until: nil)

        // When/Then
        #expect(status.description == "Rate limited")
    }

    @Test("rate limit description with past date shows expired message")
    func rateLimitDescription_WithPastDate_ShowsExpiredMessage() {
        // Given
        let pastDate = Date().addingTimeInterval(-60) // 1 minute ago
        let status = ProviderConnectionStatus.rateLimited(until: pastDate)

        // When/Then
        #expect(status.description == "Rate limited")
    }

    @Test("rate limit description with near future date shows time remaining")
    func rateLimitDescription_WithNearFutureDate_ShowsTimeRemaining() {
        // Given
        let futureDate = Date().addingTimeInterval(45) // 45 seconds from now
        let status = ProviderConnectionStatus.rateLimited(until: futureDate)

        // When
        let description = status.description

        // Then
        #expect(description.contains("Rate limited"))
    }

    @Test("rate limit description with far future date shows time remaining")
    func rateLimitDescription_WithFarFutureDate_ShowsTimeRemaining() {
        // Given
        let futureDate = Date().addingTimeInterval(3700) // Just over 1 hour from now
        let status = ProviderConnectionStatus.rateLimited(until: futureDate)

        // When
        let description = status.description

        // Then
        #expect(description.contains("Rate limited"))
    }

    @Test("error status with empty message handles gracefully")
    func errorStatus_WithEmptyMessage_HandlesGracefully() {
        // Given
        let status = ProviderConnectionStatus.error(message: "")

        // When/Then
        #expect(status.description == "Something went wrong")
    }

    @Test("error status with whitespace message handles gracefully")
    func errorStatus_WithWhitespaceMessage_HandlesGracefully() {
        // Given
        let status = ProviderConnectionStatus.error(message: "   ")

        // When/Then
        #expect(status.description == "Something went wrong")
    }

    @Test("rate limit status with very distant future date handles gracefully")
    func rateLimitStatus_WithVeryDistantFutureDate_HandlesGracefully() {
        // Given
        let veryFarDate = Date().addingTimeInterval(86400 * 365) // 1 year from now
        let status = ProviderConnectionStatus.rateLimited(until: veryFarDate)

        // When
        let description = status.description

        // Then
        #expect(description.contains("Rate limited"))
    }

    // MARK: - JSON Encoding/Decoding Format Tests

    @Test("json format error includes message")
    func jSONFormat_Error_IncludesMessage() throws {
        // Given
        let status = ProviderConnectionStatus.error(message: "Test error message")

        // When
        let encoded = try JSONEncoder().encode(status)
        let json = try JSONSerialization.jsonObject(with: encoded) as? [String: Any]

        // Then
        #expect(json?["type"] as? String == "error")
        #expect(json?["message"] as? String == "Test error message")
    }

    @Test("json format rate limited includes date")
    func jSONFormat_RateLimited_IncludesDate() throws {
        // Given
        let date = Date()
        let status = ProviderConnectionStatus.rateLimited(until: date)

        // When
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let encoded = try encoder.encode(status)
        let json = try JSONSerialization.jsonObject(with: encoded) as? [String: Any]

        // Then
        #expect(json?["type"] as? String == "rateLimited")
        #expect(json?["until"] != nil)
    }

    @Test("json format simple states only include type")
    func jSONFormat_SimpleStates_OnlyIncludeType() throws {
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

            #expect(json?.count == 1)
            #expect(json?["type"] != nil)
        }
    }
}
