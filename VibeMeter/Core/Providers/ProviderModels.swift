import Foundation

// MARK: - Generic Data Models

/// Generic team information that works across all providers.
public struct ProviderTeamInfo: Equatable, Sendable, Codable {
    public let id: Int
    public let name: String
    public let provider: ServiceProvider

    public init(id: Int, name: String, provider: ServiceProvider) {
        self.id = id
        self.name = name
        self.provider = provider
    }
}

/// Generic user information that works across all providers.
public struct ProviderUserInfo: Equatable, Sendable, Codable {
    public let email: String
    public let teamId: Int?
    public let provider: ServiceProvider

    public init(email: String, teamId: Int? = nil, provider: ServiceProvider) {
        self.email = email
        self.teamId = teamId
        self.provider = provider
    }
}

/// Generic monthly invoice that works across all providers.
public struct ProviderMonthlyInvoice: Equatable, Sendable, Codable {
    public let items: [ProviderInvoiceItem]
    public let pricingDescription: ProviderPricingDescription?
    public let provider: ServiceProvider
    public let month: Int
    public let year: Int

    public var totalSpendingCents: Int {
        items.reduce(0) { $0 + $1.cents }
    }

    public init(
        items: [ProviderInvoiceItem],
        pricingDescription: ProviderPricingDescription? = nil,
        provider: ServiceProvider,
        month: Int,
        year: Int) {
        self.items = items
        self.pricingDescription = pricingDescription
        self.provider = provider
        self.month = month
        self.year = year
    }
}

/// Generic invoice item that works across all providers.
public struct ProviderInvoiceItem: Codable, Equatable, Sendable {
    public let cents: Int
    public let description: String
    public let provider: ServiceProvider

    public init(cents: Int, description: String, provider: ServiceProvider) {
        self.cents = cents
        self.description = description
        self.provider = provider
    }
}

/// Generic pricing description that works across all providers.
public struct ProviderPricingDescription: Codable, Equatable, Sendable {
    public let description: String
    public let id: String
    public let provider: ServiceProvider

    public init(description: String, id: String, provider: ServiceProvider) {
        self.description = description
        self.id = id
        self.provider = provider
    }
}

/// Generic usage data that works across all providers.
public struct ProviderUsageData: Codable, Equatable, Sendable {
    public let currentRequests: Int
    public let totalRequests: Int
    public let maxRequests: Int?
    public let startOfMonth: Date
    public let provider: ServiceProvider

    public init(
        currentRequests: Int,
        totalRequests: Int,
        maxRequests: Int? = nil,
        startOfMonth: Date,
        provider: ServiceProvider) {
        self.currentRequests = currentRequests
        self.totalRequests = totalRequests
        self.maxRequests = maxRequests
        self.startOfMonth = startOfMonth
        self.provider = provider
    }
}
