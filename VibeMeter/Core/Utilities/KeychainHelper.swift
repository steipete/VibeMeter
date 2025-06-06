import Foundation
import KeychainAccess

#if DEBUG
/// Mock keychain storage for debug builds that persists across app restarts.
///
/// This class provides a file-based alternative to the system keychain for debug builds,
/// storing credentials in JSON format in the Application Support directory. This allows
/// for easier debugging and testing without affecting the actual keychain.
final class DebugKeychainStorage: @unchecked Sendable {
    private var storage: [String: String] = [:]
    private let queue = DispatchQueue(label: "com.vibemeter.debugkeychain")
    private let storageURL: URL

    init() {
        // Store in Application Support to persist across app restarts
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appFolder = appSupport.appendingPathComponent("VibeMeter-Debug")
        try? FileManager.default.createDirectory(at: appFolder, withIntermediateDirectories: true)
        storageURL = appFolder.appendingPathComponent("debug-keychain.json")

        loadFromDisk()
    }

    private func loadFromDisk() {
        guard FileManager.default.fileExists(atPath: storageURL.path) else { return }

        do {
            let data = try Data(contentsOf: storageURL)
            storage = try JSONDecoder().decode([String: String].self, from: data)
        } catch {
            print("Debug keychain: Failed to load from disk: \(error)")
        }
    }

    private func saveToDisk() {
        do {
            let data = try JSONEncoder().encode(storage)
            try data.write(to: storageURL)
        } catch {
            print("Debug keychain: Failed to save to disk: \(error)")
        }
    }

    func set(_ value: String, key: String) {
        queue.sync {
            storage[key] = value
            saveToDisk()
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
            saveToDisk()
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
        // Include service name in token key to ensure proper isolation
        self.tokenKey = "\(service).authToken"
        #else
        // Production builds use stricter security
        self.keychain = Keychain(service: service)
            .accessibility(.whenUnlockedThisDeviceOnly)
            .synchronizable(false)
        self.tokenKey = "authToken" // Generic token key
        #endif
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
