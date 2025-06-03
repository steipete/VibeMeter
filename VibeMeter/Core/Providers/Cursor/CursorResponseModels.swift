import Foundation

// MARK: - Cursor API Response Models

struct CursorTeamsResponse: Decodable {
    let teams: [Team]

    struct Team: Decodable {
        let id: Int
        let name: String
    }
}

struct CursorUserResponse: Decodable {
    let email: String
    let teamId: Int?
}

struct CursorInvoiceResponse: Decodable {
    let items: [CursorInvoiceItem]?
    let pricingDescription: CursorPricingDescription?
}

struct CursorInvoiceItem: Decodable {
    let cents: Int
    let description: String
}

struct CursorPricingDescription: Decodable {
    let description: String
    let id: String
}

struct CursorUsageResponse: Decodable {
    let gpt35Turbo: ModelUsage
    let gpt4: ModelUsage
    let gpt432K: ModelUsage
    let startOfMonth: String

    private enum CodingKeys: String, CodingKey {
        case gpt35Turbo = "gpt-3.5-turbo"
        case gpt4 = "gpt-4"
        case gpt432K = "gpt-4-32k"
        case startOfMonth
    }
}

struct ModelUsage: Decodable {
    let numRequests: Int
    let numRequestsTotal: Int
    let maxTokenUsage: Int?
    let numTokens: Int
    let maxRequestUsage: Int?
}
