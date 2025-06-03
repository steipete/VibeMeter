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