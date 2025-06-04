import Foundation

// MARK: - Cursor API Response Models

/// Data models for parsing responses from the Cursor AI service API.
///
/// These structures define the JSON response formats from various Cursor API endpoints
/// including teams, user information, billing data, and usage statistics. All models
/// conform to Decodable for automatic JSON parsing.

/// Response model for the teams endpoint containing available team information.
struct CursorTeamsResponse: Decodable, Sendable {
    let teams: [Team]?

    // Handle case where API returns empty object {}
    init(from decoder: Decoder) throws {
        let container = try? decoder.container(keyedBy: CodingKeys.self)
        self.teams = try container?.decodeIfPresent([Team].self, forKey: .teams)
    }

    private enum CodingKeys: String, CodingKey {
        case teams
    }

    struct Team: Decodable, Sendable {
        let id: Int
        let name: String
    }
}

/// Response model for user information endpoint.
struct CursorUserResponse: Decodable, Sendable {
    let email: String
    let teamId: Int?
}

/// Response model for monthly invoice data containing billing items and pricing details.
struct CursorInvoiceResponse: Decodable, Sendable {
    let items: [CursorInvoiceItem]?
    let pricingDescription: CursorPricingDescription?
    
    private enum CodingKeys: String, CodingKey {
        case items
        case pricingDescription = "pricing_description"
    }
}

/// Individual line item within an invoice containing cost and description.
struct CursorInvoiceItem: Decodable, Sendable {
    let cents: Int
    let description: String
}

/// Pricing plan description containing plan details and identifier.
struct CursorPricingDescription: Decodable, Sendable {
    let description: String
    let id: String
}

/// Response model for usage statistics across different AI models and request types.
struct CursorUsageResponse: Decodable, Sendable {
    let gpt35Turbo: ModelUsage
    let gpt4: ModelUsage
    let gpt432K: ModelUsage
    let startOfMonth: String

    private enum CodingKeys: String, CodingKey {
        case gpt35Turbo = "gpt-3.5-turbo"
        case gpt4 = "gpt-4"
        case gpt432K = "gpt-4-32k"
        case startOfMonth
        case start_of_month // snake_case fallback
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        self.gpt35Turbo = try container.decode(ModelUsage.self, forKey: .gpt35Turbo)
        self.gpt4 = try container.decode(ModelUsage.self, forKey: .gpt4)
        self.gpt432K = try container.decode(ModelUsage.self, forKey: .gpt432K)
        
        // Try camelCase first, then snake_case as fallback
        self.startOfMonth = try container.decodeIfPresent(String.self, forKey: .startOfMonth)
            ?? container.decode(String.self, forKey: .start_of_month)
    }
}

/// Usage statistics for a specific AI model including request and token consumption.
struct ModelUsage: Decodable, Sendable {
    let numRequests: Int
    let numRequestsTotal: Int
    let maxTokenUsage: Int?
    let numTokens: Int
    let maxRequestUsage: Int?
    
    // Custom decoder to handle both camelCase and snake_case from API
    private enum CodingKeys: String, CodingKey {
        case numRequests
        case num_requests // snake_case fallback
        case numRequestsTotal
        case num_requests_total // snake_case fallback
        case maxTokenUsage
        case max_token_usage // snake_case fallback
        case numTokens
        case num_tokens // snake_case fallback
        case maxRequestUsage
        case max_request_usage // snake_case fallback
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Try camelCase first, then snake_case as fallback
        self.numRequests = try container.decodeIfPresent(Int.self, forKey: .numRequests) 
            ?? container.decode(Int.self, forKey: .num_requests)
        
        self.numRequestsTotal = try container.decodeIfPresent(Int.self, forKey: .numRequestsTotal)
            ?? container.decode(Int.self, forKey: .num_requests_total)
        
        self.numTokens = try container.decodeIfPresent(Int.self, forKey: .numTokens)
            ?? container.decode(Int.self, forKey: .num_tokens)
        
        self.maxTokenUsage = try container.decodeIfPresent(Int?.self, forKey: .maxTokenUsage)
            ?? container.decodeIfPresent(Int?.self, forKey: .max_token_usage) ?? nil
        
        self.maxRequestUsage = try container.decodeIfPresent(Int?.self, forKey: .maxRequestUsage)
            ?? container.decodeIfPresent(Int?.self, forKey: .max_request_usage) ?? nil
    }
}
