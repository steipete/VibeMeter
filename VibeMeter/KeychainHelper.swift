import Foundation
import KeychainAccess

final class KeychainHelper: KeychainServicing, @unchecked Sendable {
    static let shared = KeychainHelper()
    private let keychain = Keychain(service: "com.vibemeter.VibeMeter")
        .accessibility(.whenUnlockedThisDeviceOnly)
    private let tokenKey = "WorkosCursorSessionToken"

    func saveToken(_ token: String) -> Bool {
        do {
            try keychain.set(token, key: tokenKey)
            return true
        } catch {
            return false
        }
    }

    func getToken() -> String? {
        do {
            return try keychain.get(tokenKey)
        } catch {
            return nil
        }
    }

    func deleteToken() -> Bool {
        do {
            try keychain.remove(tokenKey)
            return true
        } catch {
            return false
        }
    }
}
