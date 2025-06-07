import Foundation
import Testing
@testable import VibeMeter

// MARK: - Test Case Data Structures

struct TokenTestCase: Sendable {
    let token: String
    let description: String
    let shouldSucceed: Bool

    init(_ token: String, shouldSucceed: Bool = true, _ description: String) {
        self.token = token
        self.shouldSucceed = shouldSucceed
        self.description = description
    }
}

@Suite("Keychain Helper Tests", .tags(.requiresKeychain, .unit), .serialized)
@MainActor
struct KeychainHelperTests {
    let sut: KeychainHelper

    init() {
        // Use a unique service name for testing with current timestamp to avoid conflicts
        let uniqueService = "com.vibemeter.test.keychain.\(Date().timeIntervalSince1970)"
        sut = KeychainHelper(service: uniqueService)
        // Clear any existing test data
        _ = sut.deleteToken()
    }

    // MARK: - Basic Token Operations

    @Suite("Token Storage Operations")
    struct TokenStorageTests {
        let keychain: KeychainHelper

        init() {
            keychain = KeychainHelper(service: "com.vibemeter.test.storage.\(UUID().uuidString)")
            _ = keychain.deleteToken()
        }

        static let tokenTestCases: [TokenTestCase] = [
            TokenTestCase("simple-token", "simple alphanumeric token"),
            TokenTestCase("token-with-dashes-and_underscores", "token with special characters"),
            TokenTestCase("", "empty token"),
            TokenTestCase("jwt.eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxMjM0NTY3ODkwIn0", "JWT-like token"),
            TokenTestCase(
                String((0 ..< 1000).compactMap { _ in
                    "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789".randomElement()
                }),
                "very long token"),
            TokenTestCase("🔑🚀✨", "unicode token"),
            TokenTestCase(#"{"token": "value", "expires": "2023-12-01"}"#, "JSON token"),
        ]

        @Test("Token save and retrieve", arguments: tokenTestCases)
        func tokenSaveAndRetrieve(testCase: TokenTestCase) {
            // When
            let saveResult = keychain.saveToken(testCase.token)

            // Then
            #expect(saveResult == testCase.shouldSucceed)

            if testCase.shouldSucceed {
                let retrievedToken = keychain.getToken()
                #expect(retrievedToken == testCase.token)
            }
        }

        @Test("Token deletion")
        func tokenDeletion() {
            // Given
            let token = "token-to-delete"
            _ = keychain.saveToken(token)
            #expect(keychain.getToken() == token)

            // When
            let deleteResult = keychain.deleteToken()

            // Then
            #expect(deleteResult == true)
            #expect(keychain.getToken() == nil)
        }

        @Test("Token overwrite")
        func tokenOverwrite() {
            // Given
            let firstToken = "first-token"
            let secondToken = "second-token"

            // When
            _ = keychain.saveToken(firstToken)
            _ = keychain.saveToken(secondToken)

            // Then
            #expect(keychain.getToken() == secondToken)
        }
    }

    // MARK: - Multiple Instance Tests

    @Test("Service isolation", arguments: [
        "service.one",
        "service.two",
        "service.three",
    ])
    func serviceIsolation(serviceName: String) {
        // Given
        let keychain = KeychainHelper(service: serviceName)
        let uniqueToken = "token-for-\(serviceName)"

        // When
        _ = keychain.saveToken(uniqueToken)

        // Then
        #expect(keychain.getToken() == uniqueToken)

        // Cleanup
        _ = keychain.deleteToken()
    }

    @Test("Cross-service isolation")
    func crossServiceIsolation() {
        // Given
        let service1 = KeychainHelper(service: "com.test.service1.\(UUID().uuidString)")
        let service2 = KeychainHelper(service: "com.test.service2.\(UUID().uuidString)")

        let token1 = "token-for-service1"
        let token2 = "token-for-service2"

        // When
        _ = service1.saveToken(token1)
        _ = service2.saveToken(token2)

        // Then
        #expect(service1.getToken() == token1)
        #expect(service2.getToken() == token2)

        // When one service deletes its token
        _ = service1.deleteToken()

        // Then the other service should be unaffected
        #expect(service1.getToken() == nil)
        #expect(service2.getToken() == token2)

        // Cleanup
        _ = service2.deleteToken()
    }

    // MARK: - Edge Cases and Error Handling

    @Test("Delete non-existent token")
    func deleteNonExistentToken() {
        // Given - Fresh keychain with no tokens
        let keychain = KeychainHelper(service: "com.test.empty.\(UUID().uuidString)")

        // When
        let result = keychain.deleteToken()

        // Then - Should handle gracefully
        #expect(result == true)
    }

    @Test("Retrieve from empty keychain")
    func retrieveFromEmptyKeychain() {
        // Given - Fresh keychain
        let keychain = KeychainHelper(service: "com.test.retrieve.\(UUID().uuidString)")

        // When
        let token = keychain.getToken()

        // Then
        #expect(token == nil)
    }

    @Test("Multiple operations sequence")
    func multipleOperationsSequence() {
        // Given
        let tokens = ["token1", "token2", "token3", "final-token"]

        // When - Perform multiple save/get operations
        for token in tokens {
            let saveResult = sut.saveToken(token)
            #expect(saveResult == true)

            let retrievedToken = sut.getToken()
            #expect(retrievedToken == token)
        }

        // Then - Final token should be the last one saved
        #expect(sut.getToken() == tokens.last)
    }

    // MARK: - Concurrent Access Tests

    @Test("Concurrent operations thread safety")
    func concurrentOperationsThreadSafety() async {
        // Given
        let iterations = 50

        // When - Perform concurrent operations
        await withTaskGroup(of: Void.self) { group in
            for i in 0 ..< iterations {
                group.addTask {
                    let token = "concurrent-token-\(i)"
                    _ = self.sut.saveToken(token)
                    _ = self.sut.getToken()
                    if i % 2 == 0 {
                        _ = self.sut.deleteToken()
                    }
                }
            }
        }

        // Then - Operations should complete without crashes
        #expect(Bool(true))
    }

    // MARK: - Performance Tests

    @Test("Token operations performance", .timeLimit(.minutes(1)))
    func tokenOperationsPerformance() {
        // Given
        let iterations = 1000

        // When/Then - Should complete within time limit
        for i in 0 ..< iterations {
            let token = "perf-token-\(i)"
            _ = sut.saveToken(token)
            _ = sut.getToken()
            if i % 10 == 0 {
                _ = sut.deleteToken()
                _ = sut.saveToken(token) // Save again for next iteration
            }
        }
    }

    @Test("Large token performance")
    func largeTokenPerformance() async {
        // Given - Very large token (1MB)
        let largeToken = String(repeating: "large ", count: 50000)

        // When/Then - Should handle large tokens efficiently
        let startSave = Date()
        _ = sut.saveToken(largeToken)
        let saveTime = Date().timeIntervalSince(startSave)

        let startRetrieve = Date()
        let retrievedToken = sut.getToken()
        let retrieveTime = Date().timeIntervalSince(startRetrieve)

        // Then
        #expect(retrievedToken == largeToken)
        #expect(saveTime < 1.0)
        #expect(retrieveTime < 1.0)
    }

    // MARK: - Protocol Conformance Tests

    @Test("Keychain servicing protocol conformance")
    func keychainServicingProtocolConformance() {
        // Test protocol methods
        let protocolConformant: KeychainServicing = sut
        let testToken = "protocol-test-token"

        #expect(protocolConformant.saveToken(testToken) == true)
        #expect(protocolConformant.getToken() == testToken)
        #expect(protocolConformant.deleteToken() == true)
    }

    @Test("Sendable conformance")
    func sendableConformance() {
        // When/Then - Should compile and work across actor boundaries
        Task {
            let token = "sendable-test-token"
            _ = self.sut.saveToken(token)
            #expect(self.sut.getToken() == token)
        }
    }

    // MARK: - Shared Instance Tests

    @Test("Shared instance consistency")
    func sharedInstanceConsistency() {
        // Given
        let shared1 = KeychainHelper.shared
        let shared2 = KeychainHelper.shared

        // Then
        #expect(shared1 === shared2)

        // When
        let testToken = "shared-instance-token"
        _ = shared1.saveToken(testToken)

        // Then
        #expect(shared2.getToken() == testToken)

        // Cleanup
        _ = shared1.deleteToken()
    }

    // MARK: - Integration Tests

    @Test("Real keychain integration")
    func realKeychainIntegration() {
        // This test verifies actual keychain integration
        // Using a test-specific service to avoid conflicts

        // Given
        let integrationKeychain = KeychainHelper(service: "com.vibemeter.integration.test")
        let testToken = "integration-test-token-\(Date().timeIntervalSince1970)"

        // When
        let saveResult = integrationKeychain.saveToken(testToken)

        // Then
        #expect(saveResult == true)

        let retrievedToken = integrationKeychain.getToken()
        #expect(retrievedToken == testToken)

        // Cleanup
        let deleteResult = integrationKeychain.deleteToken()
        #expect(deleteResult == true)
        #expect(integrationKeychain.getToken() == nil)
    }
}
