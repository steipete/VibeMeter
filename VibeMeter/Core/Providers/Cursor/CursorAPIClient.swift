import Foundation
import os.log

/// Handles HTTP communication with the Cursor AI API.
///
/// This client manages low-level HTTP operations, authentication headers,
/// request creation, and response handling specific to Cursor AI's API.
actor CursorAPIClient {
    // MARK: - Properties

    private let urlSession: URLSessionProtocol
    private let logger = Logger(subsystem: "com.vibemeter", category: "CursorAPIClient")
    private let baseURL = URL(string: "https://www.cursor.com/api")!

    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .useDefaultKeys
        return decoder
    }()

    // MARK: - Initialization

    init(urlSession: URLSessionProtocol = URLSession.shared) {
        self.urlSession = urlSession
    }

    // MARK: - API Endpoints

    func fetchTeams(authToken: String) async throws -> CursorTeamsResponse {
        logger.debug("Fetching Cursor teams")

        let endpoint = baseURL.appendingPathComponent("dashboard/teams")
        var request = createRequest(for: endpoint, authToken: authToken)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: [String: Any]())

        return try await performRequest(request)
    }

    func fetchUserInfo(authToken: String) async throws -> CursorUserResponse {
        logger.debug("Fetching Cursor user info")

        let endpoint = baseURL.appendingPathComponent("auth/me")
        logger.debug("User info endpoint: \(endpoint.absoluteString)")

        let request = createRequest(for: endpoint, authToken: authToken)
        logger.debug("Request URL: \(request.url?.absoluteString ?? "nil")")
        logger.debug("Request Headers: \(request.allHTTPHeaderFields ?? [:])")

        return try await performRequest(request)
    }

    func fetchInvoice(authToken: String, month: Int, year: Int,
                      teamId: Int) async throws -> CursorInvoiceResponse {
        logger.debug("Fetching Cursor invoice for \(month)/\(year) with team ID \(teamId)")

        let endpoint = baseURL.appendingPathComponent("dashboard/get-monthly-invoice")
        var request = createRequest(for: endpoint, authToken: authToken)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Include team ID in the request body as expected by tests
        let body = [
            "month": month,
            "year": year,
            "teamId": teamId,
            "includeUsageEvents": false,
        ] as [String: Any]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        return try await performRequest(request)
    }

    func fetchUsage(authToken: String) async throws -> CursorUsageResponse {
        logger.debug("Fetching Cursor usage data")

        // Extract user ID from the session token (format: user_id::jwt_token)
        let userId: String = if let colonIndex = authToken.firstIndex(of: ":") {
            String(authToken[..<colonIndex])
        } else {
            // Fallback: if token format is different, use the whole token as user ID
            authToken
        }

        logger.debug("Extracted user ID: \(userId)")

        // Create URL with user query parameter
        var urlComponents = URLComponents(url: baseURL.appendingPathComponent("usage"), resolvingAgainstBaseURL: false)!
        urlComponents.queryItems = [URLQueryItem(name: "user", value: userId)]

        guard let endpoint = urlComponents.url else {
            throw ProviderError.networkError(message: "Failed to construct usage URL", statusCode: nil)
        }

        logger.debug("Usage endpoint URL with user parameter: \(endpoint.absoluteString)")

        let request = createRequest(for: endpoint, authToken: authToken)

        return try await performRequest(request)
    }

    func validateToken(authToken: String) async -> Bool {
        do {
            _ = try await fetchUserInfo(authToken: authToken)
            return true
        } catch {
            logger.debug("Token validation failed: \(error.localizedDescription)")
            return false
        }
    }

    // MARK: - Private Methods

    private func createRequest(for url: URL, authToken: String) -> URLRequest {
        var request = URLRequest(url: url)
        // Set the session cookie instead of Bearer token
        request.setValue("WorkosCursorSessionToken=\(authToken)", forHTTPHeaderField: "Cookie")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("VibeMeter/1.0", forHTTPHeaderField: "User-Agent")
        // Add referer header as some APIs require it
        request.setValue("https://www.cursor.com", forHTTPHeaderField: "Referer")
        request.timeoutInterval = 30.0
        return request
    }

    private func performRequest<T: Decodable & Sendable>(_ request: URLRequest) async throws -> T {
        logger.debug("Performing request to: \(request.url?.absoluteString ?? "nil")")

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await urlSession.data(for: request)
        } catch {
            // Convert URLSession errors to ProviderError
            throw ProviderError.networkError(message: error.localizedDescription, statusCode: nil)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ProviderError.networkError(message: "Invalid response type", statusCode: nil)
        }

        switch httpResponse.statusCode {
        case 200 ... 299:
            // Handle 204 No Content responses
            if httpResponse.statusCode == 204 {
                // 204 from auth endpoints means the session is invalid
                if request.url?.path.contains("/auth/") == true {
                    logger.warning("Received 204 from auth endpoint - session expired or invalid")
                    throw ProviderError.unauthorized
                }
                // For 204 responses, check if we're expecting an optional type
                if T.self == Any?.self {
                    return Any?.none as! T
                }
                // If we're not expecting optional, throw an error
                logger.error("Received 204 No Content but expecting data of type \(T.self)")
                throw ProviderError.decodingError(
                    message: "API returned 204 No Content but response data was expected",
                    statusCode: 204)
            }

            // Handle empty or minimal data for successful responses
            if data.isEmpty {
                logger.error("Received empty data for successful response")
                throw ProviderError.decodingError(
                    message: "Received empty response data",
                    statusCode: httpResponse.statusCode)
            }

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

        case 404:
            let message = String(data: data, encoding: .utf8) ?? "Unknown error"
            logger.error("404 Not Found - API endpoint may have changed. URL: \(request.url?.absoluteString ?? "nil")")
            logger.error("404 Response body: \(message)")
            throw ProviderError.networkError(
                message: "API endpoint not found - the endpoint may have been moved or deprecated",
                statusCode: 404)

        case 429:
            logger.warning("Cursor rate limit exceeded")
            throw ProviderError.rateLimitExceeded

        case 503:
            logger.warning("Cursor service unavailable")
            throw ProviderError.serviceUnavailable

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
    }
}
