import Foundation

// Protocol for CursorAPIClient
@MainActor
protocol CursorAPIClientProtocol {
    func fetchTeamInfo(authToken: String) async throws -> (id: Int, name: String)
    func fetchUserInfo(authToken: String) async throws -> CursorAPIClient
        .UserInfoResponse // Keep original response type
    func fetchMonthlyInvoice(authToken: String, month: Int, year: Int) async throws -> CursorAPIClient
        .MonthlyInvoiceResponse // Keep original response type
    // Add other methods if any that DataCoordinator or other services might call
}

// Companion object to hold the shared instance and test helpers
@MainActor
final class CursorAPIClient { // This outer class now acts as the namespace/companion
    static var shared: CursorAPIClientProtocol = RealCursorAPIClient(settingsManager: SettingsManager.shared)

    // Test-only method to inject a mock shared instance
    static func _test_setSharedInstance(instance: CursorAPIClientProtocol) {
        shared = instance
    }

    // Test-only method to reset to the real shared instance
    static func _test_resetSharedInstance() {
        shared = RealCursorAPIClient(settingsManager: SettingsManager.shared)
    }

    // Private init to prevent direct instantiation of the companion object if it's not intended to be the protocol
    // itself
    private init() {}

    // Convenience initializer for tests that creates a RealCursorAPIClient
    static func __init(
        session: URLSessionProtocol = URLSession.shared,
        settingsManager: SettingsManager
    ) -> RealCursorAPIClient {
        return RealCursorAPIClient(session: session, settingsManager: settingsManager)
    }

    // MARK: - Nested Types (Error, Details, Responses, Requests)

    // These types can remain nested within the CursorAPIClient namespace
    // or be moved to top-level if preferred, but nesting is fine.

    enum APIError: Error, Equatable {
        case networkError(ErrorDetails)
        case decodingError(ErrorDetails)
        case noTeamFound
        case teamIdNotSet
        case unauthorized
        case unknown(ErrorDetails?)

        static func == (lhs: CursorAPIClient.APIError, rhs: CursorAPIClient.APIError) -> Bool {
            switch (lhs, rhs) {
            case let (.networkError(lDetails), .networkError(rDetails)): lDetails == rDetails
            case let (.decodingError(lDetails), .decodingError(rDetails)): lDetails == rDetails
            case (.noTeamFound, .noTeamFound): true
            case (.teamIdNotSet, .teamIdNotSet): true
            case (.unauthorized, .unauthorized): true
            case let (.unknown(lDetails), .unknown(rDetails)): lDetails == rDetails
            default: false
            }
        }
    }

    struct ErrorDetails: Equatable {
        let message: String
        let statusCode: Int?

        init(message: String, statusCode: Int? = nil) {
            self.message = message
            self.statusCode = statusCode
        }
    }

    struct Team: Codable, Equatable {
        let id: Int
        let name: String
    }

    struct TeamInfoResponse: Codable, Equatable {
        let teams: [Team]
    }

    struct UserInfoResponse: Codable, Equatable {
        let email: String
        let teamId: Int? // Add team ID field that may be present in the /me response
    }

    struct InvoiceItem: Codable, Equatable {
        let cents: Int
        let description: String
    }

    struct PricingDescription: Codable, Equatable {
        let description: String
        let id: String
    }

    struct MonthlyInvoiceResponse: Codable, Equatable {
        let items: [InvoiceItem]?
        let pricingDescription: PricingDescription?

        var totalSpendingCents: Int {
            if let items {
                items.reduce(0) { $0 + $1.cents }
            } else {
                // No items means no usage charges yet this month
                0
            }
        }
    }

    struct MonthlyInvoiceRequest: Codable {
        let teamId: Int
        let month: Int
        let year: Int
        let includeUsageEvents: Bool

        init(teamId: Int, month: Int, year: Int, includeUsageEvents: Bool = false) {
            self.teamId = teamId
            self.month = month
            self.year = year
            self.includeUsageEvents = includeUsageEvents
        }
    }

    fileprivate struct EmptyRequestBody: Codable {}
}

// The actual implementation conforming to the protocol
@MainActor
class RealCursorAPIClient: CursorAPIClientProtocol {
    private let session: URLSessionProtocol
    private let settingsManager: SettingsManager // Using concrete SettingsManager here is fine for Real impl.
    private let jsonDecoder: JSONDecoder
    private let jsonEncoder: JSONEncoder

    // Initializer for RealCursorAPIClient
    init(session: URLSessionProtocol = URLSession.shared, settingsManager: SettingsManager) {
        self.session = session
        self.settingsManager = settingsManager // Injected, typically .shared for real use
        jsonDecoder = JSONDecoder()
        jsonEncoder = JSONEncoder()
        LoggingService.info("RealCursorAPIClient initialized.", category: .apiClient)
    }

    // MARK: - Request Building

    private func buildRequest(url: URL, method: String = "GET", body: Data? = nil, authToken: String) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("WorkosCursorSessionToken=\(authToken)", forHTTPHeaderField: "Cookie")

        if method == "POST" || method == "PUT" {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = body
        }

        LoggingService.debug(
            "API Request: \(method) \(url.absoluteString) - Token: ...\(String(authToken.suffix(4)))",
            category: .apiClient
        )
        if let bodyData = body, let bodyString = String(data: bodyData, encoding: .utf8) {
            LoggingService.debug("Request Body: \(bodyString)", category: .apiClient)
        }

        return request
    }

    // MARK: - Response Validation

    private func validateResponse(_ response: URLResponse, data: Data, url: URL) throws -> HTTPURLResponse {
        guard let httpResponse = response as? HTTPURLResponse else {
            LoggingService.error(
                "API request did not return HTTPURLResponse for \(url.absoluteString)",
                category: .apiClient
            )
            throw CursorAPIClient.APIError
                .networkError(CursorAPIClient.ErrorDetails(message: "Invalid response type from server."))
        }

        LoggingService.debug("API Response: \(httpResponse.statusCode) for \(url.absoluteString)", category: .apiClient)

        if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
            LoggingService.warning(
                "API request unauthorized (\(httpResponse.statusCode)) for \(url.absoluteString).",
                category: .apiClient
            )
            throw CursorAPIClient.APIError.unauthorized
        }

        guard (200 ..< 300).contains(httpResponse.statusCode) else {
            let errorMsg = "API request failed with status code: \(httpResponse.statusCode)"
            LoggingService.error(errorMsg + " for \(url.absoluteString)", category: .apiClient)
            if let responseBody = String(data: data, encoding: .utf8), !responseBody.isEmpty {
                LoggingService.debug("API Error Response Body: \(responseBody)", category: .apiClient)
            }
            throw CursorAPIClient.APIError.networkError(CursorAPIClient.ErrorDetails(
                message: errorMsg,
                statusCode: httpResponse.statusCode
            ))
        }

        return httpResponse
    }

    // MARK: - Response Decoding

    private func decodeResponse<T: Decodable>(_ type: T.Type, from data: Data, url: URL, statusCode: Int) throws -> T {
        do {
            let decodedObject = try jsonDecoder.decode(type, from: data)
            return decodedObject
        } catch let decodingError as DecodingError {
            let errorMsg =
                "Failed to decode API response for \(url.absoluteString): \(decodingError.localizedDescription)"
            LoggingService.error(errorMsg + ". Details: \(decodingError)", category: .apiClient)
            if let responseBody = String(data: data, encoding: .utf8) {
                LoggingService.debug("Data for decoding error: \(responseBody)", category: .apiClient)
            }
            throw CursorAPIClient.APIError.decodingError(CursorAPIClient.ErrorDetails(
                message: decodingError.localizedDescription,
                statusCode: statusCode
            ))
        } catch {
            let errorMsg =
                "An unknown error occurred while processing API response for \(url.absoluteString): " +
                "\(error.localizedDescription)"
            LoggingService.error(errorMsg, category: .apiClient)
            throw CursorAPIClient.APIError.unknown(CursorAPIClient.ErrorDetails(
                message: error.localizedDescription,
                statusCode: statusCode
            ))
        }
    }

    // MARK: - Main Request Method

    private func performRequest<T: Decodable>(
        url: URL,
        method: String = "GET",
        body: Data? = nil,
        authToken: String
    ) async throws -> T {
        let request = buildRequest(url: url, method: method, body: body, authToken: authToken)

        let (data, response) = try await session.data(for: request)

        let httpResponse = try validateResponse(response, data: data, url: url)

        return try decodeResponse(T.self, from: data, url: url, statusCode: httpResponse.statusCode)
    }

    func fetchTeamInfo(authToken: String) async throws -> (id: Int, name: String) {
        guard let url = URL(string: "https://www.cursor.com/api/dashboard/teams") else {
            LoggingService.critical("Invalid URL for fetchTeamInfo.", category: .apiClient)
            throw CursorAPIClient.APIError
                .networkError(CursorAPIClient.ErrorDetails(message: "Invalid API endpoint URL (teams)"))
        }
        let emptyBody = try jsonEncoder.encode(CursorAPIClient.EmptyRequestBody())

        let response: CursorAPIClient.TeamInfoResponse = try await performRequest(
            url: url,
            method: "POST",
            body: emptyBody,
            authToken: authToken
        )
        guard let firstTeam = response.teams.first else {
            LoggingService.warning("No teams found in API response.", category: .apiClient)
            throw CursorAPIClient.APIError.noTeamFound
        }
        return (id: firstTeam.id, name: firstTeam.name)
    }

    func fetchUserInfo(authToken: String) async throws -> CursorAPIClient.UserInfoResponse {
        guard let url = URL(string: "https://www.cursor.com/api/auth/me") else {
            LoggingService.critical("Invalid URL for fetchUserInfo.", category: .apiClient)
            throw CursorAPIClient.APIError
                .networkError(CursorAPIClient.ErrorDetails(message: "Invalid API endpoint URL (auth/me)"))
        }
        return try await performRequest(url: url, authToken: authToken)
    }

    func fetchMonthlyInvoice(authToken: String, month: Int, year: Int) async throws -> CursorAPIClient
        .MonthlyInvoiceResponse {
        // Use settingsManager from the RealCursorAPIClient instance
        guard let teamId = settingsManager.teamId else {
            LoggingService.error("Team ID not set, cannot fetch monthly invoice.", category: .apiClient)
            throw CursorAPIClient.APIError.teamIdNotSet
        }
        guard let url = URL(string: "https://www.cursor.com/api/dashboard/get-monthly-invoice") else {
            LoggingService.critical("Invalid URL for fetchMonthlyInvoice.", category: .apiClient)
            throw CursorAPIClient.APIError
                .networkError(CursorAPIClient.ErrorDetails(message: "Invalid API endpoint URL (get-monthly-invoice)"))
        }

        let requestBody = CursorAPIClient.MonthlyInvoiceRequest(
            teamId: teamId,
            month: month,
            year: year,
            includeUsageEvents: true
        )
        let bodyData = try jsonEncoder.encode(requestBody)

        return try await performRequest(url: url, method: "POST", body: bodyData, authToken: authToken)
    }
}
