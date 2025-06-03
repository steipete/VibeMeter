import Foundation
import os.log

// MARK: - Modern Swift 6 API Client using Actor for thread safety

/// Thread-safe API client for Cursor service using Swift 6 actor model
public actor CursorAPIClient: CursorAPIClientProtocol {
    // MARK: - Properties

    private let urlSession: URLSessionProtocol
    private let settingsManager: any SettingsManagerProtocol
    private let logger = Logger(subsystem: "com.vibemeter", category: "CursorAPI")

    private let baseURL = URL(string: "https://www.cursor.com/api")!
    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }()

    // MARK: - Initialization

    public init(
        urlSession: URLSessionProtocol = URLSession.shared,
        settingsManager: any SettingsManagerProtocol) {
        self.urlSession = urlSession
        self.settingsManager = settingsManager
    }

    // MARK: - Public API

    public func fetchTeamInfo(authToken: String) async throws -> TeamInfo {
        logger.debug("Fetching team info")

        let endpoint = baseURL.appendingPathComponent("teams")
        let request = createRequest(for: endpoint, authToken: authToken)

        let response: TeamsResponse = try await performRequest(request)

        guard let firstTeam = response.teams.first else {
            logger.error("No teams found in response")
            throw CursorAPIError.noTeamFound
        }

        logger.info("Successfully fetched team: \(firstTeam.name, privacy: .public)")
        return TeamInfo(id: firstTeam.id, name: firstTeam.name)
    }

    public func fetchUserInfo(authToken: String) async throws -> UserInfo {
        logger.debug("Fetching user info")

        let endpoint = baseURL.appendingPathComponent("me")
        let request = createRequest(for: endpoint, authToken: authToken)

        let response: UserResponse = try await performRequest(request)

        logger.info("Successfully fetched user: \(response.email, privacy: .public)")
        return UserInfo(email: response.email, teamId: response.teamId)
    }

    public func fetchMonthlyInvoice(authToken: String, month: Int, year: Int) async throws -> MonthlyInvoice {
        guard let teamId = await settingsManager.teamId else {
            logger.error("Team ID not set")
            throw CursorAPIError.teamIdNotSet
        }

        logger.debug("Fetching invoice for \(month)/\(year) for team \(teamId)")

        let endpoint = baseURL
            .appendingPathComponent("usage-by-model/get-team-month")
            .appendingQueryItems([
                URLQueryItem(name: "month", value: String(month)),
                URLQueryItem(name: "teamId", value: String(teamId)),
                URLQueryItem(name: "year", value: String(year)),
            ])

        let request = createRequest(for: endpoint, authToken: authToken)
        let response: InvoiceResponse = try await performRequest(request)

        logger.info("Successfully fetched invoice with \(response.items?.count ?? 0) items")

        return MonthlyInvoice(
            items: response.items ?? [],
            pricingDescription: response.pricingDescription)
    }

    // MARK: - Private Helpers

    private func createRequest(for url: URL, authToken: String) -> URLRequest {
        var request = URLRequest(url: url)
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 30
        return request
    }

    private func performRequest<T: Decodable>(_ request: URLRequest) async throws -> T {
        do {
            let (data, response) = try await urlSession.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw CursorAPIError.networkError(message: "Invalid response type", statusCode: nil)
            }

            switch httpResponse.statusCode {
            case 200 ... 299:
                do {
                    return try decoder.decode(T.self, from: data)
                } catch {
                    logger.error("Decoding error: \(error.localizedDescription)")
                    throw CursorAPIError.decodingError(
                        message: error.localizedDescription,
                        statusCode: httpResponse.statusCode)
                }

            case 401:
                logger.warning("Unauthorized request")
                throw CursorAPIError.unauthorized

            default:
                let message = String(data: data, encoding: .utf8) ?? "Unknown error"
                logger.error("API error \(httpResponse.statusCode): \(message)")
                throw CursorAPIError.networkError(
                    message: message,
                    statusCode: httpResponse.statusCode)
            }
        } catch let error as CursorAPIError {
            throw error
        } catch {
            logger.error("Network error: \(error.localizedDescription)")
            throw CursorAPIError.networkError(message: error.localizedDescription, statusCode: nil)
        }
    }
}

// MARK: - Response Models

private struct TeamsResponse: Decodable {
    let teams: [Team]

    struct Team: Decodable {
        let id: Int
        let name: String
    }
}

private struct UserResponse: Decodable {
    let email: String
    let teamId: Int?
}

private struct InvoiceResponse: Decodable {
    let items: [InvoiceItem]?
    let pricingDescription: PricingDescription?
}

// MARK: - URL Extension for Query Items

private extension URL {
    func appendingQueryItems(_ items: [URLQueryItem]) -> URL {
        guard var components = URLComponents(url: self, resolvingAgainstBaseURL: false) else {
            return self
        }
        components.queryItems = (components.queryItems ?? []) + items
        return components.url ?? self
    }
}
