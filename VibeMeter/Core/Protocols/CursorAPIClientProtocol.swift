import Foundation

// MARK: - API Client Protocol

/// Protocol defining the Cursor API client interface
public protocol CursorAPIClientProtocol: Sendable {
    func fetchTeamInfo(authToken: String) async throws -> TeamInfo
    func fetchUserInfo(authToken: String) async throws -> UserInfo
    func fetchMonthlyInvoice(authToken: String, month: Int, year: Int) async throws -> MonthlyInvoice
}

// MARK: - API Models

/// Team information from Cursor API
public struct TeamInfo: Equatable, Sendable, Codable {
    public let id: Int
    public let name: String

    public init(id: Int, name: String) {
        self.id = id
        self.name = name
    }
}

/// User information from Cursor API
public struct UserInfo: Equatable, Sendable, Codable {
    public let email: String
    public let teamId: Int?

    public init(email: String, teamId: Int? = nil) {
        self.email = email
        self.teamId = teamId
    }
}

/// Monthly invoice data from Cursor API
public struct MonthlyInvoice: Equatable, Sendable, Codable {
    public let items: [InvoiceItem]
    public let pricingDescription: PricingDescription?

    public var totalSpendingCents: Int {
        items.reduce(0) { $0 + $1.cents }
    }

    public init(items: [InvoiceItem], pricingDescription: PricingDescription? = nil) {
        self.items = items
        self.pricingDescription = pricingDescription
    }
}

/// Individual invoice item
public struct InvoiceItem: Codable, Equatable, Sendable {
    public let cents: Int
    public let description: String

    public init(cents: Int, description: String) {
        self.cents = cents
        self.description = description
    }
}

/// Pricing description metadata
public struct PricingDescription: Codable, Equatable, Sendable {
    public let description: String
    public let id: String

    public init(description: String, id: String) {
        self.description = description
        self.id = id
    }
}

// MARK: - API Errors

/// Errors that can occur when interacting with the Cursor API
public enum CursorAPIError: Error, Equatable, LocalizedError {
    case networkError(message: String, statusCode: Int?)
    case decodingError(message: String, statusCode: Int?)
    case noTeamFound
    case teamIdNotSet
    case unauthorized

    public var errorDescription: String? {
        switch self {
        case let .networkError(message, statusCode):
            if let statusCode {
                return "Network error (status \(statusCode)): \(message)"
            }
            return "Network error: \(message)"
        case let .decodingError(message, statusCode):
            if let statusCode {
                return "Decoding error (status \(statusCode)): \(message)"
            }
            return "Decoding error: \(message)"
        case .noTeamFound:
            return "No team found"
        case .teamIdNotSet:
            return "Team ID not set"
        case .unauthorized:
            return "Unauthorized - please log in again"
        }
    }
}
