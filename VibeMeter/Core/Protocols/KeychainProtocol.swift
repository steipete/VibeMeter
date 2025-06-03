import Foundation

// Protocol for Keychain operations
protocol KeychainServicing {
    func saveToken(_ token: String) -> Bool
    func getToken() -> String?
    func deleteToken() -> Bool
}
