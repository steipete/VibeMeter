import Foundation

/// Protocol defining the interface for Keychain operations.
///
/// This protocol abstracts keychain access, enabling:
/// - Secure token storage and retrieval
/// - Mock implementations for testing
/// - Consistent interface for credential management
protocol KeychainServicing {
    func saveToken(_ token: String) -> Bool
    func getToken() -> String?
    func deleteToken() -> Bool
}
