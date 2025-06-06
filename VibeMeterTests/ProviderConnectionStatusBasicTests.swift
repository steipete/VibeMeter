import Foundation
import SwiftUI
import Testing
@testable import VibeMeter

@Suite("Provider Connection Status Tests")
struct ProviderConnectionStatusBasicTests {
    
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
            showProgress: Bool = false
        ) {
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
            shortDesc: "Disconnected"
        ),
        StatusTestCase(
            .connecting,
            color: .orange,
            icon: "circle.dotted",
            description: "connecting state",
            shortDesc: "Connecting",
            showProgress: true
        ),
        StatusTestCase(
            .connected,
            color: .green,
            icon: "circle.fill",
            description: "connected state",
            shortDesc: "Connected"
        ),
        StatusTestCase(
            .syncing,
            color: .blue,
            icon: "arrow.triangle.2.circlepath",
            description: "syncing state",
            shortDesc: "Syncing",
            showProgress: true
        ),
        StatusTestCase(
            .error(message: "Test error"),
            color: .red,
            icon: "exclamationmark.circle.fill",
            description: "error state",
            shortDesc: "Error"
        ),
        StatusTestCase(
            .rateLimited(until: nil),
            color: .yellow,
            icon: "clock.fill",
            description: "rate limited without time",
            shortDesc: "Rate Limited"
        ),
        StatusTestCase(
            .stale,
            color: .orange,
            icon: "clock",
            description: "stale data state",
            shortDesc: "Stale"
        )
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
        if case .rateLimited(let until) = status {
            #expect(until == futureDate)
        } else {
            Issue.record("Expected condition not met")
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
        if case .error(let message) = status {
            #expect(message == errorMessage)
        } else {
            Issue.record("Expected condition not met")
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
        let transitions: [(from: ProviderConnectionStatus, to: ProviderConnectionStatus, description: String)] = [
            (.disconnected, .connecting, "disconnect to connect"),
            (.connecting, .connected, "connecting to connected"),
            (.connected, .syncing, "connected to syncing"),
            (.syncing, .connected, "syncing back to connected"),
            (.connected, .stale, "connected to stale"),
            (.stale, .syncing, "stale to syncing"),
            (.connected, .error(message: "Network error"), "connected to error"),
            (.error(message: "Error"), .connecting, "error to reconnecting")
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
        for i in 0..<10_000 {
            let statuses = [
                ProviderConnectionStatus.disconnected,
                ProviderConnectionStatus.connecting,
                ProviderConnectionStatus.connected,
                ProviderConnectionStatus.error(message: "Error \(i)"),
                ProviderConnectionStatus.rateLimited(until: Date())
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
        withKnownIssue("Very long error messages may need UI truncation") {
            // This test documents a known limitation
            let veryLongMessage = String(repeating: "This is a very long error message. ", count: 100)
            let status = ProviderConnectionStatus.error(message: veryLongMessage)
            
            // This might need special handling in UI components
            #expect(status.shortDescription.count < 100)
        }
    }
}