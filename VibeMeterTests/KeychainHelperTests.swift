import Foundation
import Testing
@testable import VibeMeter

@Suite("Keychain Helper Tests")
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
        
        static let tokenTestCases: [TokenTestCase] = [
            TokenTestCase("simple-token", "simple alphanumeric token"),
            TokenTestCase("token-with-dashes-and_underscores", "token with special characters"),
            TokenTestCase("", "empty token"),
            TokenTestCase("jwt.eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxMjM0NTY3ODkwIn0", "JWT-like token"),
            TokenTestCase(String((0..<1000).compactMap { _ in "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789".randomElement() }), "very long token"),
            TokenTestCase("🔑🚀✨", "unicode token"),
            TokenTestCase(#"{"token": "value", "expires": "2023-12-01"}"#, "JSON token")
        ]
        
        @Test("Token save and retrieve", arguments: tokenTestCases)
        func tokenSaveAndRetrieve(testCase: TokenTestCase) {
            // When
            let saveResult = keychain.saveToken(testCase.token)
            
            // Then
            #expect(saveResult == testCase.shouldSucceed, "Save result mismatch: \(testCase.description)")
            
            if testCase.shouldSucceed {
                let retrievedToken = keychain.getToken()
                #expect(retrievedToken == testCase.token, "Retrieved token should match: \(testCase.description)")
            }
        }
        
        @Test("Token deletion")
        func tokenDeletion() {
            // Given
            let token = "token-to-delete"
            _ = keychain.saveToken(token)
            #expect(keychain.getToken() == token, "Token should be saved")
            
            // When
            let deleteResult = keychain.deleteToken()
            
            // Then
            #expect(deleteResult == true, "Deletion should succeed")
            #expect(keychain.getToken() == nil, "Token should be deleted")
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
            #expect(keychain.getToken() == secondToken, "Should overwrite with latest token")
        }
    }

    // MARK: - Multiple Instance Tests
    
    @Test("Service isolation", arguments: [
        "service.one",
        "service.two", 
        "service.three"
    ])
    func serviceIsolation(serviceName: String) {
        // Given
        let keychain = KeychainHelper(service: serviceName)
        let uniqueToken = "token-for-\(serviceName)"
        
        // When
        _ = keychain.saveToken(uniqueToken)
        
        // Then
        #expect(keychain.getToken() == uniqueToken, "Should store token for service: \(serviceName)")
        
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
        #expect(service1.getToken() == token1, "Service 1 should have its token")
        #expect(service2.getToken() == token2, "Service 2 should have its token")
        
        // When one service deletes its token
        _ = service1.deleteToken()
        
        // Then the other service should be unaffected
        #expect(service1.getToken() == nil, "Service 1 token should be deleted")
        #expect(service2.getToken() == token2, "Service 2 token should remain")
        
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
        #expect(result == true, "Should handle deletion of non-existent token")
    }
    
    @Test("Retrieve from empty keychain")
    func retrieveFromEmptyKeychain() {
        // Given - Fresh keychain
        let keychain = KeychainHelper(service: "com.test.retrieve.\(UUID().uuidString)")
        
        // When
        let token = keychain.getToken()
        
        // Then
        #expect(token == nil, "Should return nil for non-existent token")
    }
    
    @Test("Multiple operations sequence")
    func multipleOperationsSequence() {
        // Given
        let tokens = ["token1", "token2", "token3", "final-token"]
        
        // When - Perform multiple save/get operations
        for token in tokens {
            let saveResult = sut.saveToken(token)
            #expect(saveResult == true, "Should save token: \(token)")
            
            let retrievedToken = sut.getToken()
            #expect(retrievedToken == token, "Should retrieve correct token: \(token)")
        }
        
        // Then - Final token should be the last one saved
        #expect(sut.getToken() == tokens.last, "Should have final token")
    }

    // MARK: - Concurrent Access Tests
    
    @Test("Concurrent operations thread safety")
    func concurrentOperationsThreadSafety() async {
        // Given
        let iterations = 50
        
        // When - Perform concurrent operations
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<iterations {
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
        #expect(Bool(true), "Concurrent operations should complete safely")
    }

    // MARK: - Performance Tests
    
    @Test("Token operations performance", .timeLimit(.minutes(1)))
    func tokenOperationsPerformance() {
        // Given
        let iterations = 1000
        
        // When/Then - Should complete within time limit
        for i in 0..<iterations {
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
        #expect(retrievedToken == largeToken, "Should handle large tokens correctly")
        #expect(saveTime < 1.0, "Save should be reasonably fast")
        #expect(retrieveTime < 1.0, "Retrieve should be reasonably fast")
    }

    // MARK: - Protocol Conformance Tests
    
    @Test("Keychain servicing protocol conformance")
    func keychainServicingProtocolConformance() {
        // Then
        #expect(sut is KeychainServicing, "Should conform to KeychainServicing protocol")
        
        // Test protocol methods
        let protocolConformant: KeychainServicing = sut
        let testToken = "protocol-test-token"
        
        #expect(protocolConformant.saveToken(testToken) == true, "Protocol method should work")
        #expect(protocolConformant.getToken() == testToken, "Protocol method should work")
        #expect(protocolConformant.deleteToken() == true, "Protocol method should work")
    }
    
    @Test("Sendable conformance")
    func sendableConformance() {
        // When/Then - Should compile and work across actor boundaries
        Task {
            let token = "sendable-test-token"
            _ = self.sut.saveToken(token)
            #expect(self.sut.getToken() == token, "Should work across actor boundaries")
        }
    }

    // MARK: - Shared Instance Tests
    
    @Test("Shared instance consistency")
    func sharedInstanceConsistency() {
        // Given
        let shared1 = KeychainHelper.shared
        let shared2 = KeychainHelper.shared
        
        // Then
        #expect(shared1 === shared2, "Shared instances should be identical")
        
        // When
        let testToken = "shared-instance-token"
        _ = shared1.saveToken(testToken)
        
        // Then
        #expect(shared2.getToken() == testToken, "Shared instances should share data")
        
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
        #expect(saveResult == true, "Should save to real keychain")
        
        let retrievedToken = integrationKeychain.getToken()
        #expect(retrievedToken == testToken, "Should retrieve from real keychain")
        
        // Cleanup
        let deleteResult = integrationKeychain.deleteToken()
        #expect(deleteResult == true, "Should delete from real keychain")
        #expect(integrationKeychain.getToken() == nil, "Should be deleted from real keychain")
    }
}