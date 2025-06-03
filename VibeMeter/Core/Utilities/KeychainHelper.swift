import Foundation
import KeychainAccess

#if DEBUG
/// Mock keychain storage for debug builds to avoid password prompts
final class DebugKeychainStorage: @unchecked Sendable {
    private var storage: [String: String] = [:]
    private let queue = DispatchQueue(label: "com.vibemeter.debugkeychain")
    
    func set(_ value: String, key: String) {
        queue.sync {
            storage[key] = value
        }
    }
    
    func get(_ key: String) -> String? {
        queue.sync {
            storage[key]
        }
    }
    
    func remove(_ key: String) {
        queue.sync {
            _ = storage.removeValue(forKey: key)
        }
    }
}
#endif

/// Helper class for secure storage of authentication tokens in the macOS Keychain.
///
/// KeychainHelper provides:
/// - Secure token storage with device-only accessibility for multiple providers
/// - Token retrieval and deletion per provider
/// - Thread-safe operations through Sendable conformance
///
/// All tokens are stored with `.whenUnlockedThisDeviceOnly` accessibility
/// to ensure they're only accessible when the device is unlocked.
final class KeychainHelper: KeychainServicing, @unchecked Sendable {
    #if DEBUG
    private let debugStorage = DebugKeychainStorage()
    #else
    private let keychain: Keychain
    #endif
    private let tokenKey: String

    /// Creates a KeychainHelper for a specific service provider.
    /// - Parameter service: Service identifier for keychain storage
    init(service: String) {
        #if DEBUG
        // In debug builds, we use in-memory storage to avoid keychain prompts
        #else
        // Production builds use stricter security
        self.keychain = Keychain(service: service)
            .accessibility(.whenUnlockedThisDeviceOnly)
            .synchronizable(false)
        #endif
        
        self.tokenKey = "authToken" // Generic token key
    }

    /// Legacy shared instance for backward compatibility during transition.
    static let shared = KeychainHelper(service: "com.steipete.vibemeter")

    func saveToken(_ token: String) -> Bool {
        #if DEBUG
        debugStorage.set(token, key: tokenKey)
        return true
        #else
        do {
            try keychain.set(token, key: tokenKey)
            return true
        } catch {
            return false
        }
        #endif
    }

    func getToken() -> String? {
        #if DEBUG
        return debugStorage.get(tokenKey)
        #else
        do {
            return try keychain.get(tokenKey)
        } catch {
            return nil
        }
        #endif
    }

    func deleteToken() -> Bool {
        #if DEBUG
        debugStorage.remove(tokenKey)
        return true
        #else
        do {
            try keychain.remove(tokenKey)
            return true
        } catch {
            return false
        }
        #endif
    }
}
