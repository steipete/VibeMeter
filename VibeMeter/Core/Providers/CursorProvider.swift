import Foundation
import os.log

// MARK: - Cursor Provider Implementation

/// Cursor AI service provider implementation.
///
/// This provider handles authentication, API calls, and data management
/// specifically for the Cursor AI service while conforming to the generic
/// ProviderProtocol for multi-tenancy support.
public actor CursorProvider: ProviderProtocol {
    // MARK: - ProviderProtocol Conformance

    public let provider: ServiceProvider = .cursor

    // MARK: - Properties

    private let settingsManager: any SettingsManagerProtocol
    private let logger = Logger.vibeMeter(category: "CursorProvider")

    // MARK: - Component Dependencies

    private let apiClient: CursorAPIClient
    private let resilienceManager: CursorResilienceManager

    // MARK: - Initialization

    public init(
        settingsManager: any SettingsManagerProtocol,
        urlSession: URLSessionProtocol = URLSession.shared) {
        self.settingsManager = settingsManager
        self.apiClient = CursorAPIClient(urlSession: urlSession)
        self.resilienceManager = CursorResilienceManager()
    }

    // MARK: - ProviderProtocol Implementation

    public func fetchTeamInfo(authToken: String) async throws -> ProviderTeamInfo {
        logger.debug("Fetching Cursor team info")

        return try await resilienceManager.executeWithResilience {
            let response = try await self.apiClient.fetchTeams(authToken: authToken)
            return try CursorDataTransformer.transformTeamInfo(from: response)
        }
    }

    public func fetchUserInfo(authToken: String) async throws -> ProviderUserInfo {
        logger.debug("Fetching Cursor user info")

        return try await resilienceManager.executeWithResilience {
            let response = try await self.apiClient.fetchUserInfo(authToken: authToken)
            return CursorDataTransformer.transformUserInfo(from: response)
        }
    }

    public func fetchMonthlyInvoice(authToken: String, month: Int, year: Int,
                                    teamId: Int?) async throws -> ProviderMonthlyInvoice {
        logger.debug("Fetching Cursor invoice for \(month)/\(year)")

        // Determine the team ID to use - either provided or stored
        let effectiveTeamId: Int? = if let providedTeamId = teamId {
            providedTeamId
        } else {
            await getTeamId()
        }

        // Filter out invalid team IDs using the centralized validation
        let validTeamId: Int? = CursorAPIConstants.isValidTeamId(effectiveTeamId) ? effectiveTeamId : nil

        logger.debug("Using team ID for invoice request: \(validTeamId?.description ?? "nil")")

        return try await resilienceManager.executeWithResilience {
            let response = try await self.apiClient.fetchInvoice(
                authToken: authToken,
                month: month,
                year: year,
                teamId: validTeamId)
            return CursorDataTransformer.transformInvoice(from: response, month: month, year: year)
        }
    }

    public func fetchUsageData(authToken: String) async throws -> ProviderUsageData {
        logger.debug("Fetching Cursor usage data")

        return try await resilienceManager.executeWithResilience {
            let response = try await self.apiClient.fetchUsage(authToken: authToken)
            return try CursorDataTransformer.transformUsageData(from: response)
        }
    }

    public func validateToken(authToken: String) async -> Bool {
        await apiClient.validateToken(authToken: authToken)
    }

    public nonisolated func getAuthenticationURL() -> URL {
        CursorAPIConstants.authenticationURL
    }

    public nonisolated func extractAuthToken(from callbackData: [String: Any]) -> String? {
        // Extract cursor_auth_token from callback data
        if let token = callbackData["cursor_auth_token"] as? String {
            return token
        }

        // Extract from cookies if available
        if let cookies = callbackData["cookies"] as? [HTTPCookie] {
            for cookie in cookies where cookie.name == "WorkosCursorSessionToken" {
                return cookie.value
            }
        }

        return nil
    }

    // MARK: - Private Methods

    private func getTeamId() async -> Int? {
        // Access team ID from provider-specific settings
        await settingsManager.getSession(for: .cursor)?.teamId
    }

    // MARK: - Resilience Methods

    /// Gets the current health status of the provider.
    public func getHealthStatus() async -> ProviderHealthStatus {
        await resilienceManager.getHealthStatus()
    }

    /// Manually resets the circuit breaker for this provider.
    public func resetCircuitBreaker() async {
        await resilienceManager.resetCircuitBreaker()
    }
}
