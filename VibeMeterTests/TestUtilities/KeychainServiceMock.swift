import Foundation
@testable import VibeMeter

// Mock implementation of KeychainServicing protocol
// The protocol is now defined in VibeMeter/KeychainProtocol.swift

class KeychainServiceMock: KeychainServicing {
    private var storedToken: String?
    var saveTokenCalled = false
    var getTokenCalled = false
    var deleteTokenCalled = false
    var saveTokenShouldSucceed = true
    var deleteTokenShouldSucceed = true

    func saveToken(_ token: String) -> Bool {
        saveTokenCalled = true
        if saveTokenShouldSucceed {
            storedToken = token
            return true
        }
        return false
    }

    func getToken() -> String? {
        getTokenCalled = true
        return storedToken
    }

    func deleteToken() -> Bool {
        deleteTokenCalled = true
        if deleteTokenShouldSucceed {
            storedToken = nil
            return true
        }
        return false
    }

    // Helper to reset state for tests
    func reset() {
        storedToken = nil
        saveTokenCalled = false
        getTokenCalled = false
        deleteTokenCalled = false
        saveTokenShouldSucceed = true
        deleteTokenShouldSucceed = true
    }
}
