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

    private let urlSession: URLSessionProtocol
    private let settingsManager: any SettingsManagerProtocol
    private let logger = Logger(subsystem: "com.vibemeter", category: "CursorProvider")
    private let retryHandler = NetworkRetryHandler.forProvider(.cursor)

    private let baseURL = URL(string: "https://www.cursor.com/api")!
    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }()

    // MARK: - Initialization

    public init(
        settingsManager: any SettingsManagerProtocol,
        urlSession: URLSessionProtocol = URLSession.shared) {
        self.settingsManager = settingsManager
        self.urlSession = urlSession
    }

    // MARK: - ProviderProtocol Implementation

    public func fetchTeamInfo(authToken: String) async throws -> ProviderTeamInfo {
        logger.debug("Fetching Cursor team info")

        let endpoint = baseURL.appendingPathComponent("dashboard/teams")
        var request = createRequest(for: endpoint, authToken: authToken)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: [String: Any]())

        let response: CursorTeamsResponse = try await performRequest(request)

        guard let firstTeam = response.teams.first else {
            logger.error("No teams found in Cursor response")
            throw ProviderError.noTeamFound
        }

        logger.info("Successfully fetched Cursor team: \(firstTeam.name, privacy: .public)")
        return ProviderTeamInfo(id: firstTeam.id, name: firstTeam.name, provider: .cursor)
    }

    public func fetchUserInfo(authToken: String) async throws -> ProviderUserInfo {
        logger.debug("Fetching Cursor user info")

        let endpoint = baseURL.appendingPathComponent("auth/me")
        logger.debug("User info endpoint: \(endpoint.absoluteString)")

        let request = createRequest(for: endpoint, authToken: authToken)
        logger.debug("Request URL: \(request.url?.absoluteString ?? "nil")")
        logger.debug("Request Headers: \(request.allHTTPHeaderFields ?? [:])")

        // GET request (default)

        let response: CursorUserResponse = try await performRequest(request)

        logger.info("Successfully fetched Cursor user: \(response.email, privacy: .public)")
        return ProviderUserInfo(email: response.email, teamId: response.teamId, provider: .cursor)
    }

    public func fetchMonthlyInvoice(authToken: String, month: Int, year: Int,
                                    teamId: Int?) async throws -> ProviderMonthlyInvoice {
        // Use provided team ID, or fall back to stored team ID if not provided
        let resolvedTeamId: Int
        if let teamId {
            resolvedTeamId = teamId
        } else if let storedTeamId = await getTeamId() {
            resolvedTeamId = storedTeamId
        } else {
            logger.error("Cursor team ID not set and not provided")
            throw ProviderError.teamIdNotSet
        }

        logger.debug("Fetching Cursor invoice for \(month)/\(year) for team \(resolvedTeamId)")

        let endpoint = baseURL.appendingPathComponent("dashboard/get-monthly-invoice")

        var request = createRequest(for: endpoint, authToken: authToken)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = [
            "month": month,
            "teamId": resolvedTeamId,
            "year": year,
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        let response: CursorInvoiceResponse = try await performRequest(request)

        logger.info("Successfully fetched Cursor invoice with \(response.items?.count ?? 0) items")

        let genericItems = (response.items ?? []).map { item in
            ProviderInvoiceItem(cents: item.cents, description: item.description, provider: .cursor)
        }

        let genericPricing = response.pricingDescription.map { pricing in
            ProviderPricingDescription(description: pricing.description, id: pricing.id, provider: .cursor)
        }

        return ProviderMonthlyInvoice(
            items: genericItems,
            pricingDescription: genericPricing,
            provider: .cursor,
            month: month,
            year: year)
    }

    public func fetchUsageData(authToken: String) async throws -> ProviderUsageData {
        logger.debug("Fetching Cursor usage data")

        let endpoint = baseURL.appendingPathComponent("usage")
        let request = createRequest(for: endpoint, authToken: authToken)

        let response: CursorUsageResponse = try await performRequest(request)

        // Use GPT-4 usage as the primary metric since it has the largest quota
        let primaryUsage = response.gpt4

        // Parse the start of month date
        let dateFormatter = ISO8601DateFormatter()
        let startOfMonth = dateFormatter.date(from: response.startOfMonth) ?? Date()

        logger
            .info(
                "Successfully fetched Cursor usage: \(primaryUsage.numRequests)/\(primaryUsage.maxRequestUsage ?? 0) requests")

        return ProviderUsageData(
            currentRequests: primaryUsage.numRequests,
            totalRequests: primaryUsage.numRequestsTotal,
            maxRequests: primaryUsage.maxRequestUsage,
            startOfMonth: startOfMonth,
            provider: .cursor)
    }

    public func validateToken(authToken: String) async -> Bool {
        do {
            _ = try await fetchUserInfo(authToken: authToken)
            return true
        } catch {
            logger.debug("Cursor token validation failed: \(error.localizedDescription)")
            return false
        }
    }

    public nonisolated func getAuthenticationURL() -> URL {
        URL(string: "https://authenticator.cursor.sh/")!
    }

    public nonisolated func extractAuthToken(from callbackData: [String: Any]) -> String? {
        // For Cursor, we extract the token from cookies
        if let cookies = callbackData["cookies"] as? [HTTPCookie] {
            return cookies.first { $0.name == "WorkosCursorSessionToken" }?.value
        }
        return nil
    }

    // MARK: - Private Helpers

    private func createRequest(for url: URL, authToken: String) -> URLRequest {
        var request = URLRequest(url: url)
        request.setValue("WorkosCursorSessionToken=\(authToken)", forHTTPHeaderField: "Cookie")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 30
        return request
    }

    private func performRequest<T: Decodable>(_ request: URLRequest) async throws -> T {
        // Use retry handler for network resilience
        try await retryHandler.execute(
            operation: { [self] in
                logger.debug("Performing request to: \(request.url?.absoluteString ?? "nil")")
                let (data, response) = try await urlSession.data(for: request)

                guard let httpResponse = response as? HTTPURLResponse else {
                    throw ProviderError.networkError(message: "Invalid response type", statusCode: nil)
                }

                switch httpResponse.statusCode {
                case 200 ... 299:
                    do {
                        return try decoder.decode(T.self, from: data)
                    } catch {
                        logger.error("Cursor API decoding error: \(error.localizedDescription)")
                        throw ProviderError.decodingError(
                            message: error.localizedDescription,
                            statusCode: httpResponse.statusCode)
                    }

                case 401:
                    logger.warning("Unauthorized Cursor request")
                    throw ProviderError.unauthorized

                case 429:
                    logger.warning("Cursor rate limit exceeded")
                    // Extract retry-after header if available
                    let retryAfter = httpResponse.value(forHTTPHeaderField: "Retry-After")
                        .flatMap { TimeInterval($0) }
                    throw NetworkRetryHandler.RetryableError.rateLimited(retryAfter: retryAfter)

                case 503:
                    logger.warning("Cursor service unavailable")
                    throw NetworkRetryHandler.RetryableError.serverError(statusCode: 503)

                default:
                    let message = String(data: data, encoding: .utf8) ?? "Unknown error"
                    logger.error("Cursor API error \(httpResponse.statusCode): \(message)")

                    // Parse specific error types from response body
                    if let errorData = data.isEmpty ? nil : data,
                       let json = try? JSONSerialization.jsonObject(with: errorData) as? [String: Any],
                       let error = json["error"] as? [String: Any],
                       let details = error["details"] as? [[String: Any]] {
                        for detail in details {
                            if let errorCode = detail["error"] as? String,
                               let errorDetails = detail["details"] as? [String: Any] {
                                // Check for unauthorized/team not found errors
                                if errorCode == "ERROR_UNAUTHORIZED" {
                                    if let errorDetail = errorDetails["detail"] as? String,
                                       errorDetail.contains("Team not found") {
                                        logger.warning("Team not found error detected")
                                        throw ProviderError.noTeamFound
                                    } else {
                                        logger.warning("Unauthorized error detected")
                                        throw ProviderError.unauthorized
                                    }
                                }
                            }
                        }
                    }

                    // Handle status code specific errors
                    if httpResponse.statusCode == 500, message.contains("Team not found") {
                        logger.warning("Team not found error detected from 500 response")
                        throw ProviderError.noTeamFound
                    }

                    // Check if it's a server error that should be retried
                    if httpResponse.statusCode >= 500 {
                        throw NetworkRetryHandler.RetryableError.serverError(statusCode: httpResponse.statusCode)
                    }

                    throw ProviderError.networkError(
                        message: message,
                        statusCode: httpResponse.statusCode)
                }
            },
            shouldRetry: { [self] error in
                // Don't retry authentication or team not found errors
                switch error {
                case ProviderError.unauthorized, ProviderError.noTeamFound:
                    return false
                case let providerError as ProviderError:
                    // Don't retry client errors (4xx)
                    if case .networkError(_, let statusCode) = providerError,
                       let code = statusCode,
                       code >= 400 && code < 500 {
                        return false
                    }
                    return true
                default:
                    // Let the retry handler decide for other errors
                    return true
                }
            }
        )
    }

    private func getTeamId() async -> Int? {
        // Access team ID from provider-specific settings
        await settingsManager.getSession(for: .cursor)?.teamId
    }
}
