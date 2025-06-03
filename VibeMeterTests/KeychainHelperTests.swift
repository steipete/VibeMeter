import XCTest
@testable import VibeMeter

final class KeychainHelperTests: XCTestCase {
    var sut: KeychainHelper!
    
    override func setUp() {
        super.setUp()
        // Use a unique service ID for each test to avoid interference
        sut = KeychainHelper(service: "com.vibemeter.test.\(UUID().uuidString)")
    }
    
    override func tearDown() {
        // Clean up any stored tokens
        _ = sut.deleteToken()
        sut = nil
        super.tearDown()
    }
    
    // MARK: - Token Storage Tests
    
    func testSaveToken_WithValidToken_ReturnsTrue() {
        // When
        let result = sut.saveToken("test-token-123")
        
        // Then
        XCTAssertTrue(result)
    }
    
    func testGetToken_AfterSaving_ReturnsStoredToken() {
        // Given
        let testToken = "test-token-value-456"
        _ = sut.saveToken(testToken)
        
        // When
        let retrievedToken = sut.getToken()
        
        // Then
        XCTAssertEqual(retrievedToken, testToken)
    }
    
    func testGetToken_WithoutSaving_ReturnsNil() {
        // When
        let token = sut.getToken()
        
        // Then
        XCTAssertNil(token)
    }
    
    func testDeleteToken_AfterSaving_RemovesToken() {
        // Given
        _ = sut.saveToken("token-to-delete")
        
        // When
        let deleteResult = sut.deleteToken()
        let retrievedToken = sut.getToken()
        
        // Then
        XCTAssertTrue(deleteResult)
        XCTAssertNil(retrievedToken)
    }
    
    func testDeleteToken_WithoutSaving_ReturnsTrue() {
        // When
        let result = sut.deleteToken()
        
        // Then
        XCTAssertTrue(result, "Deleting non-existent token should still return true")
    }
    
    // MARK: - Token Update Tests
    
    func testSaveToken_OverwritesExistingToken() {
        // Given
        _ = sut.saveToken("old-token")
        
        // When
        _ = sut.saveToken("new-token")
        let retrievedToken = sut.getToken()
        
        // Then
        XCTAssertEqual(retrievedToken, "new-token")
    }
    
    func testMultipleUpdates_PreservesLatestToken() {
        // Given
        let tokens = ["token1", "token2", "token3", "final-token"]
        
        // When
        for token in tokens {
            _ = sut.saveToken(token)
        }
        let retrievedToken = sut.getToken()
        
        // Then
        XCTAssertEqual(retrievedToken, "final-token")
    }
    
    // MARK: - Service Isolation Tests
    
    func testDifferentServices_HaveIsolatedStorage() {
        // Given
        let service1 = KeychainHelper(service: "com.test.service1")
        let service2 = KeychainHelper(service: "com.test.service2")
        
        // When
        _ = service1.saveToken("token-for-service1")
        _ = service2.saveToken("token-for-service2")
        
        let token1 = service1.getToken()
        let token2 = service2.getToken()
        
        // Then
        XCTAssertEqual(token1, "token-for-service1")
        XCTAssertEqual(token2, "token-for-service2")
        
        // Cleanup
        _ = service1.deleteToken()
        _ = service2.deleteToken()
    }
    
    func testDeleteToken_DoesNotAffectOtherServices() {
        // Given
        let service1 = KeychainHelper(service: "com.test.service3")
        let service2 = KeychainHelper(service: "com.test.service4")
        _ = service1.saveToken("token1")
        _ = service2.saveToken("token2")
        
        // When
        _ = service1.deleteToken()
        
        // Then
        XCTAssertNil(service1.getToken())
        XCTAssertEqual(service2.getToken(), "token2")
        
        // Cleanup
        _ = service2.deleteToken()
    }
    
    // MARK: - Edge Cases
    
    func testSaveToken_WithEmptyString_StoresSuccessfully() {
        // When
        let result = sut.saveToken("")
        let retrievedToken = sut.getToken()
        
        // Then
        XCTAssertTrue(result)
        XCTAssertEqual(retrievedToken, "")
    }
    
    func testSaveToken_WithVeryLongToken_StoresSuccessfully() {
        // Given
        let longToken = String(repeating: "a", count: 10000)
        
        // When
        let result = sut.saveToken(longToken)
        let retrievedToken = sut.getToken()
        
        // Then
        XCTAssertTrue(result)
        XCTAssertEqual(retrievedToken, longToken)
    }
    
    func testSaveToken_WithSpecialCharacters_StoresSuccessfully() {
        // Given
        let specialToken = "!@#$%^&*()_+-=[]{}|;':\",./<>?"
        
        // When
        let result = sut.saveToken(specialToken)
        let retrievedToken = sut.getToken()
        
        // Then
        XCTAssertTrue(result)
        XCTAssertEqual(retrievedToken, specialToken)
    }
    
    func testSaveToken_WithUnicodeCharacters_StoresSuccessfully() {
        // Given
        let unicodeToken = "🔑Token-with-emoji-🚀-and-中文"
        
        // When
        let result = sut.saveToken(unicodeToken)
        let retrievedToken = sut.getToken()
        
        // Then
        XCTAssertTrue(result)
        XCTAssertEqual(retrievedToken, unicodeToken)
    }
    
    // MARK: - Concurrent Access Tests
    
    func testConcurrentAccess_MaintainsDataIntegrity() {
        // Given
        let expectation = expectation(description: "Concurrent operations complete")
        expectation.expectedFulfillmentCount = 100
        let queue = DispatchQueue(label: "test.concurrent", attributes: .concurrent)
        
        // When
        for i in 0..<100 {
            queue.async {
                let token = "token-\(i)"
                _ = self.sut.saveToken(token)
                _ = self.sut.getToken()
                if i % 2 == 0 {
                    _ = self.sut.deleteToken()
                }
                expectation.fulfill()
            }
        }
        
        // Then
        wait(for: [expectation], timeout: 5.0)
        // Test passes if no crashes occur during concurrent access
    }
    
    // MARK: - Shared Instance Tests
    
    func testSharedInstance_UsesCorrectService() {
        // Given
        let shared = KeychainHelper.shared
        
        // When
        _ = shared.saveToken("shared-token")
        let token = shared.getToken()
        
        // Then
        XCTAssertEqual(token, "shared-token")
        
        // Cleanup
        _ = shared.deleteToken()
    }
    
    // MARK: - Protocol Conformance Tests
    
    func testKeychainHelper_ConformsToKeychainServicing() {
        // Then
        XCTAssertTrue((sut as Any) is KeychainServicing)
    }
    
    func testKeychainHelper_IsSendable() {
        // Given
        let helper = KeychainHelper(service: "test.sendable")
        
        // When/Then - This compiles because KeychainHelper is Sendable
        Task {
            _ = helper.saveToken("sendable-test")
        }
    }
    
    // MARK: - Debug Storage Tests (when in DEBUG mode)
    
    #if DEBUG
    func testDebugStorage_PersistsAcrossInstances() {
        // Given
        let service = "com.test.debug.persistence"
        let helper1 = KeychainHelper(service: service)
        _ = helper1.saveToken("persisted-token")
        
        // When
        let helper2 = KeychainHelper(service: service)
        let token = helper2.getToken()
        
        // Then
        XCTAssertEqual(token, "persisted-token")
        
        // Cleanup
        _ = helper2.deleteToken()
    }
    #endif
}