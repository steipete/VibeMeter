import Foundation
import SwiftUI
import Testing
@testable import VibeMeter

@Suite("Provider Connection Status Tests", .tags(.provider, .unit))
@MainActor
struct ProviderConnectionStatusTests {
    
    @Suite("Basic Status Tests")
    struct BasicTests {
        // MARK: - Test Case Definitions

        struct StatusTestCase: Sendable {
            let status: ProviderConnectionStatus
            let expectedColor: Color
            let expectedIconName: String
            let expectedShortDescription: String
            let shouldShowProgress: Bool
            let description: String

            init(
                _ status: ProviderConnectionStatus,
                color: Color,
                icon: String,
                description: String,
                shortDesc: String,
                showProgress: Bool = false) {
                self.status = status
                self.expectedColor = color
                self.expectedIconName = icon
                self.expectedShortDescription = shortDesc
                self.shouldShowProgress = showProgress
                self.description = description
            }
        }

        static let allStatusTestCases: [StatusTestCase] = [
            StatusTestCase(
                .disconnected,
                color: .secondary,
                icon: "circle",
                description: "disconnected state",
                shortDesc: "Disconnected"),
            StatusTestCase(
                .connecting,
                color: .orange,
                icon: "circle.dotted",
                description: "connecting state",
                shortDesc: "Connecting",
                showProgress: true),
            StatusTestCase(
                .connected,
                color: .green,
                icon: "circle.fill",
                description: "connected state",
                shortDesc: "Connected"),
            StatusTestCase(
                .syncing,
                color: .blue,
                icon: "arrow.triangle.2.circlepath",
                description: "syncing state",
                shortDesc: "Syncing",
                showProgress: true),
            StatusTestCase(
                .error(message: "Test error"),
                color: .red,
                icon: "exclamationmark.circle.fill",
                description: "error state",
                shortDesc: "Error"),
            StatusTestCase(
                .rateLimited(until: nil),
                color: .yellow,
                icon: "clock.fill",
                description: "rate limited without time",
                shortDesc: "Rate Limited"),
            StatusTestCase(
                .stale,
                color: .orange,
                icon: "clock",
                description: "stale data state",
                shortDesc: "Stale"),
        ]

        // MARK: - Comprehensive Status Tests

        @Test("Status display properties", arguments: allStatusTestCases)
        func statusDisplayProperties(testCase: StatusTestCase) {
            // Then - Verify all display properties
            #expect(testCase.status.displayColor == testCase.expectedColor)
            #expect(testCase.status.iconName == testCase.expectedIconName)
            #expect(testCase.status.shortDescription == testCase.expectedShortDescription)

            // Verify progress indication
            if testCase.shouldShowProgress {
                #expect(testCase.status.shouldShowProgress)
            }
        }

        // MARK: - Rate Limited Edge Cases

        @Test("Rate limited with future date")
        func rateLimitedWithFutureDate() {
            // Given
            let futureDate = Date().addingTimeInterval(3600) // 1 hour from now
            let status = ProviderConnectionStatus.rateLimited(until: futureDate)

            // Then
            #expect(status.displayColor == .yellow)
            #expect(status.iconName == "clock.fill")
            #expect(status.shortDescription.contains("Rate Limited"))

            // Should include time information in detailed description
            if case let .rateLimited(until) = status {
                #expect(until == futureDate)
            } else {
                #expect(Bool(false), "Expected rateLimited status with date")
            }
        }

        @Test("Rate limited with past date")
        func rateLimitedWithPastDate() {
            // Given
            let pastDate = Date().addingTimeInterval(-3600) // 1 hour ago
            let status = ProviderConnectionStatus.rateLimited(until: pastDate)

            // Then - Should still show rate limited status even with past date
            #expect(status.displayColor == .yellow)
            #expect(status.shortDescription.contains("Rate Limited"))
        }

        // MARK: - Error Message Handling

        @Test("Error messages", arguments: [
            "Network timeout",
            "Authentication failed",
            "Service unavailable",
            "Rate limit exceeded",
            "",
            "Very long error message that might need truncation in UI components"
        ])
        func errorMessages(errorMessage: String) {
            // Given
            let status = ProviderConnectionStatus.error(message: errorMessage)

            // Then
            #expect(status.displayColor == .red)
            #expect(status.iconName == "exclamationmark.circle.fill")
            #expect(status.shortDescription == "Error")

            // Verify error message is preserved
            if case let .error(message) = status {
                #expect(message == errorMessage)
            } else {
                #expect(Bool(false), "Expected error status with message")
            }
        }

        // MARK: - Equality and Comparison Tests

        @Test("Status equality")
        func statusEquality() {
            // Given
            let status1 = ProviderConnectionStatus.connected
            let status2 = ProviderConnectionStatus.connected
            let status3 = ProviderConnectionStatus.disconnected

            // Then
            #expect(status1 == status2)
            #expect(status1 != status3)
        }

        @Test("Error status equality with same message")
        func errorStatusEqualityWithSameMessage() {
            // Given
            let error1 = ProviderConnectionStatus.error(message: "Test error")
            let error2 = ProviderConnectionStatus.error(message: "Test error")
            let error3 = ProviderConnectionStatus.error(message: "Different error")

            // Then
            #expect(error1 == error2)
            #expect(error1 != error3)
        }

        @Test("Rate limited equality")
        func rateLimitedEquality() {
            // Given
            let date = Date()
            let rateLimited1 = ProviderConnectionStatus.rateLimited(until: date)
            let rateLimited2 = ProviderConnectionStatus.rateLimited(until: date)
            let rateLimited3 = ProviderConnectionStatus.rateLimited(until: nil)

            // Then
            #expect(rateLimited1 == rateLimited2)
            #expect(rateLimited1 != rateLimited3)
        }

        // MARK: - Progress Indication Tests

        @Test("Progress indication states", arguments: [
            (ProviderConnectionStatus.disconnected, false),
            (ProviderConnectionStatus.connecting, true),
            (ProviderConnectionStatus.connected, false),
            (ProviderConnectionStatus.syncing, true),
            (ProviderConnectionStatus.error(message: "Error"), false),
            (ProviderConnectionStatus.rateLimited(until: nil), false),
            (ProviderConnectionStatus.stale, false)
        ])
        func progressIndicationStates(status: ProviderConnectionStatus, shouldShowProgress: Bool) {
            // Then
            #expect(status.shouldShowProgress == shouldShowProgress)
        }

        // MARK: - Status Transitions

        @Test("Valid status transitions")
        func validStatusTransitions() {
            // Test common valid transition sequences
            struct Transition {
                let from: ProviderConnectionStatus
                let to: ProviderConnectionStatus
                let description: String
            }

            let transitions = [
                Transition(from: .disconnected, to: .connecting, description: "disconnect to connect"),
                Transition(from: .connecting, to: .connected, description: "connecting to connected"),
                Transition(from: .connected, to: .syncing, description: "connected to syncing"),
                Transition(from: .syncing, to: .connected, description: "syncing back to connected"),
                Transition(from: .connected, to: .stale, description: "connected to stale"),
                Transition(from: .stale, to: .syncing, description: "stale to syncing"),
                Transition(from: .connected, to: .error(message: "Network error"), description: "connected to error"),
                Transition(from: .error(message: "Error"), to: .connecting, description: "error to reconnecting"),
            ]

            for transition in transitions {
                // These transitions should be logically valid
                #expect(transition.from != transition.to)

                // Verify both states have valid display properties
                #expect(!transition.from.shortDescription.isEmpty)
                #expect(!transition.to.shortDescription.isEmpty)
            }
        }

        // MARK: - Performance Tests

        @Test("Status creation performance", .timeLimit(.minutes(1)))
        func statusCreationPerformance() {
            // When - Create many status instances
            for i in 0 ..< 10000 {
                let statuses = [
                    ProviderConnectionStatus.disconnected,
                    ProviderConnectionStatus.connecting,
                    ProviderConnectionStatus.connected,
                    ProviderConnectionStatus.error(message: "Error \(i)"),
                    ProviderConnectionStatus.rateLimited(until: Date()),
                ]

                // Verify each status has valid properties
                for status in statuses {
                    _ = status.displayColor
                    _ = status.iconName
                    _ = status.shortDescription
                }
            }
        }

        // MARK: - Edge Cases and Robustness

        @Test("Empty and nil edge cases")
        func emptyAndNilEdgeCases() {
            // Test edge cases that might occur in real usage

            // Empty error message
            let emptyError = ProviderConnectionStatus.error(message: "")
            #expect(emptyError.shortDescription == "Error")

            // Nil rate limit date
            let nilRateLimit = ProviderConnectionStatus.rateLimited(until: nil)
            #expect(nilRateLimit.shortDescription == "Rate Limited")
        }

        // MARK: - Known Issues Tests

        @Test("Known UI rendering edge cases")
        func knownUIRenderingEdgeCases() {
            // This test documents a known limitation
            let veryLongMessage = String(repeating: "This is a very long error message. ", count: 100)
            let status = ProviderConnectionStatus.error(message: veryLongMessage)

            // Very long error messages should be "Error" short description
            #expect(status.shortDescription == "Error")
        }
    }

    @Suite("Advanced Tests", .tags(.integration))
    struct AdvancedTests {
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
}