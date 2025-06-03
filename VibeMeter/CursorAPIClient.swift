import Foundation

// MARK: - Protocol

@MainActor
protocol CursorAPIClientProtocol: Sendable {
    func fetchTeamInfo(authToken: String) async throws -> TeamInfo
    func fetchUserInfo(authToken: String) async throws -> UserInfo
    func fetchMonthlyInvoice(authToken: String, month: Int, year: Int) async throws -> MonthlyInvoice
}

// MARK: - Models

struct TeamInfo: Equatable, Sendable {
    let id: Int
    let name: String
}

struct UserInfo: Equatable, Sendable {
    let email: String
    let teamId: Int?
}

struct MonthlyInvoice: Equatable, Sendable {
    let items: [InvoiceItem]
    let pricingDescription: PricingDescription?
    
    var totalSpendingCents: Int {
        items.reduce(0) { $0 + $1.cents }
    }
}

struct InvoiceItem: Codable, Equatable, Sendable {
    let cents: Int
    let description: String
}

struct PricingDescription: Codable, Equatable, Sendable {
    let description: String
    let id: String
}

// MARK: - Errors

enum CursorAPIError: Error, Equatable {
    case networkError(message: String, statusCode: Int?)
    case decodingError(message: String, statusCode: Int?)
    case noTeamFound
    case teamIdNotSet
    case unauthorized
    case invalidURL(endpoint: String)
    case unknown(message: String?)
    
    var errorDetails: ErrorDetails {
        switch self {
        case .networkError(let message, let statusCode):
            return ErrorDetails(message: message, statusCode: statusCode)
        case .decodingError(let message, let statusCode):
            return ErrorDetails(message: message, statusCode: statusCode)
        case .noTeamFound:
            return ErrorDetails(message: "No teams found for the authenticated user")
        case .teamIdNotSet:
            return ErrorDetails(message: "Team ID not configured")
        case .unauthorized:
            return ErrorDetails(message: "Authentication failed", statusCode: 401)
        case .invalidURL(let endpoint):
            return ErrorDetails(message: "Invalid URL for endpoint: \(endpoint)")
        case .unknown(let message):
            return ErrorDetails(message: message ?? "Unknown error occurred")
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

// MARK: - API Client

@MainActor
final class CursorAPIClient: CursorAPIClientProtocol {
    // MARK: - Static Properties
    
    static let shared: CursorAPIClientProtocol = CursorAPIClient(
        settingsManager: SettingsManager.shared
    )
    
    // MARK: - Properties
    
    private let session: URLSessionProtocol
    private let settingsManager: SettingsManagerProtocol
    private let jsonDecoder: JSONDecoder
    private let jsonEncoder: JSONEncoder
    private let baseURL = "https://www.cursor.com/api"
    
    // MARK: - Initialization
    
    init(
        session: URLSessionProtocol = URLSession.shared,
        settingsManager: SettingsManagerProtocol
    ) {
        self.session = session
        self.settingsManager = settingsManager
        self.jsonDecoder = JSONDecoder()
        self.jsonEncoder = JSONEncoder()
        LoggingService.info("CursorAPIClient initialized", category: .apiClient)
    }
    
    // MARK: - Public Methods
    
    func fetchTeamInfo(authToken: String) async throws -> TeamInfo {
        let response: TeamInfoResponse = try await performRequest(
            endpoint: "/dashboard/teams",
            method: .post,
            body: EmptyRequestBody(),
            authToken: authToken
        )
        
        guard let firstTeam = response.teams.first else {
            LoggingService.warning("No teams found in API response", category: .apiClient)
            throw CursorAPIError.noTeamFound
        }
        
        return TeamInfo(id: firstTeam.id, name: firstTeam.name)
    }
    
    func fetchUserInfo(authToken: String) async throws -> UserInfo {
        let response: UserInfoResponse = try await performRequest(
            endpoint: "/auth/me",
            method: .get,
            body: nil as String?,
            authToken: authToken
        )
        
        return UserInfo(email: response.email, teamId: response.teamId)
    }
    
    func fetchMonthlyInvoice(authToken: String, month: Int, year: Int) async throws -> MonthlyInvoice {
        guard let teamId = settingsManager.teamId else {
            LoggingService.error("Team ID not set, cannot fetch monthly invoice", category: .apiClient)
            throw CursorAPIError.teamIdNotSet
        }
        
        let requestBody = MonthlyInvoiceRequest(
            teamId: teamId,
            month: month,
            year: year,
            includeUsageEvents: true
        )
        
        let response: MonthlyInvoiceResponse = try await performRequest(
            endpoint: "/dashboard/get-monthly-invoice",
            method: .post,
            body: requestBody,
            authToken: authToken
        )
        
        return MonthlyInvoice(
            items: response.items ?? [],
            pricingDescription: response.pricingDescription
        )
    }
    
    // MARK: - Private Methods
    
    private enum HTTPMethod: String {
        case get = "GET"
        case post = "POST"
        case put = "PUT"
        case delete = "DELETE"
    }
    
    private func performRequest<T: Decodable, B: Encodable>(
        endpoint: String,
        method: HTTPMethod,
        body: B? = nil,
        authToken: String
    ) async throws -> T {
        let url = try buildURL(endpoint: endpoint)
        let request = try buildRequest(
            url: url,
            method: method,
            body: body,
            authToken: authToken
        )
        
        let (data, response) = try await session.data(for: request)
        let httpResponse = try validateResponse(response, data: data, url: url)
        
        return try decodeResponse(T.self, from: data, url: url, statusCode: httpResponse.statusCode)
    }
    
    private func buildURL(endpoint: String) throws -> URL {
        guard let url = URL(string: baseURL + endpoint) else {
            LoggingService.critical("Invalid URL for endpoint: \(endpoint)", category: .apiClient)
            throw CursorAPIError.invalidURL(endpoint: endpoint)
        }
        return url
    }
    
    private func buildRequest<B: Encodable>(
        url: URL,
        method: HTTPMethod,
        body: B?,
        authToken: String
    ) throws -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.setValue("WorkosCursorSessionToken=\(authToken)", forHTTPHeaderField: "Cookie")
        
        if method == .post || method == .put {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            if let body = body {
                request.httpBody = try jsonEncoder.encode(body)
            }
        }
        
        logRequest(request, method: method, url: url, authToken: authToken)
        return request
    }
    
    private func validateResponse(_ response: URLResponse, data: Data, url: URL) throws -> HTTPURLResponse {
        guard let httpResponse = response as? HTTPURLResponse else {
            LoggingService.error(
                "API request did not return HTTPURLResponse for \(url.absoluteString)",
                category: .apiClient
            )
            throw CursorAPIError.networkError(
                message: "Invalid response type from server",
                statusCode: nil
            )
        }
        
        LoggingService.debug(
            "API Response: \(httpResponse.statusCode) for \(url.absoluteString)",
            category: .apiClient
        )
        
        switch httpResponse.statusCode {
        case 401, 403:
            LoggingService.warning(
                "API request unauthorized (\(httpResponse.statusCode)) for \(url.absoluteString)",
                category: .apiClient
            )
            throw CursorAPIError.unauthorized
            
        case 200..<300:
            return httpResponse
            
        default:
            let errorMsg = "API request failed with status code: \(httpResponse.statusCode)"
            LoggingService.error("\(errorMsg) for \(url.absoluteString)", category: .apiClient)
            
            if let responseBody = String(data: data, encoding: .utf8), !responseBody.isEmpty {
                LoggingService.debug("API Error Response Body: \(responseBody)", category: .apiClient)
            }
            
            throw CursorAPIError.networkError(
                message: errorMsg,
                statusCode: httpResponse.statusCode
            )
        }
    }
    
    private func decodeResponse<T: Decodable>(
        _ type: T.Type,
        from data: Data,
        url: URL,
        statusCode: Int
    ) throws -> T {
        do {
            return try jsonDecoder.decode(type, from: data)
        } catch let decodingError as DecodingError {
            let errorMsg = "Failed to decode API response for \(url.absoluteString): \(decodingError.localizedDescription)"
            LoggingService.error("\(errorMsg). Details: \(decodingError)", category: .apiClient)
            
            if let responseBody = String(data: data, encoding: .utf8) {
                LoggingService.debug("Data for decoding error: \(responseBody)", category: .apiClient)
            }
            
            throw CursorAPIError.decodingError(
                message: decodingError.localizedDescription,
                statusCode: statusCode
            )
        } catch {
            let errorMsg = "An unknown error occurred while processing API response for \(url.absoluteString): \(error.localizedDescription)"
            LoggingService.error(errorMsg, category: .apiClient)
            
            throw CursorAPIError.unknown(message: error.localizedDescription)
        }
    }
    
    private func logRequest(_ request: URLRequest, method: HTTPMethod, url: URL, authToken: String) {
        LoggingService.debug(
            "API Request: \(method.rawValue) \(url.absoluteString) - Token: ...\(String(authToken.suffix(4)))",
            category: .apiClient
        )
        
        if let bodyData = request.httpBody,
           let bodyString = String(data: bodyData, encoding: .utf8) {
            LoggingService.debug("Request Body: \(bodyString)", category: .apiClient)
        }
    }
}

// MARK: - Test Support

extension CursorAPIClient {
    /// Creates a test instance with custom dependencies
    static func testInstance(
        session: URLSessionProtocol = URLSession.shared,
        settingsManager: SettingsManagerProtocol
    ) -> CursorAPIClient {
        return CursorAPIClient(session: session, settingsManager: settingsManager)
    }
}

// MARK: - Private Types

private struct EmptyRequestBody: Codable {}

// MARK: - API Response Types

private struct TeamInfoResponse: Codable {
    let teams: [Team]
    
    struct Team: Codable {
        let id: Int
        let name: String
    }
}

private struct UserInfoResponse: Codable {
    let email: String
    let teamId: Int?
}

private struct MonthlyInvoiceResponse: Codable {
    let items: [InvoiceItem]?
    let pricingDescription: PricingDescription?
}

private struct MonthlyInvoiceRequest: Codable {
    let teamId: Int
    let month: Int
    let year: Int
    let includeUsageEvents: Bool
}