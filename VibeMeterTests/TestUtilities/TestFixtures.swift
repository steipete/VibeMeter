import Foundation
@testable import VibeMeter

// MARK: - Test Fixtures

/// Common test fixtures for use across test suites
enum TestFixtures {
    
    // MARK: - Provider Test Data
    
    enum Providers {
        static let testCursorSession = ProviderSession(
            provider: .cursor,
            teamId: 12345,
            teamName: "Test Team",
            userEmail: "test@example.com",
            isActive: true
        )
        
        static let testInvoiceItems = [
            ProviderInvoiceItem(cents: 5000, description: "API Usage", provider: .cursor),
            ProviderInvoiceItem(cents: 3000, description: "Storage", provider: .cursor),
            ProviderInvoiceItem(cents: 2000, description: "Compute", provider: .cursor)
        ]
        
        static let testMonthlyInvoice = ProviderMonthlyInvoice(
            items: testInvoiceItems,
            pricingDescription: ProviderPricingDescription(
                description: "Team Pro Plan",
                id: "team-pro",
                provider: .cursor
            ),
            provider: .cursor,
            month: 1,
            year: 2025
        )
        
        static let testUsageData = ProviderUsageData(
            currentRequests: 150,
            totalRequests: 4387,
            maxRequests: 500,
            startOfMonth: Date(),
            provider: .cursor
        )
    }
    
    // MARK: - Currency Test Data
    
    enum Currency {
        static let standardExchangeRates: [String: Double] = [
            "EUR": 0.92,
            "GBP": 0.82,
            "JPY": 110.0,
            "AUD": 1.35,
            "CAD": 1.25,
            "CHF": 0.98,
            "CNY": 6.45,
            "SEK": 8.5,
            "NZD": 1.4
        ]
        
        static let testAmounts: [Double] = [
            0.0,
            0.01,
            1.0,
            10.0,
            99.99,
            100.0,
            1000.0,
            1234.56,
            9999.99,
            1_000_000.0
        ]
        
        static let currencySymbols: [(code: String, symbol: String)] = [
            ("USD", "$"),
            ("EUR", "€"),
            ("GBP", "£"),
            ("JPY", "¥"),
            ("AUD", "A$"),
            ("CAD", "C$"),
            ("CHF", "CHF"),
            ("CNY", "¥"),
            ("SEK", "kr"),
            ("NZD", "NZ$")
        ]
    }
    
    // MARK: - Network Test Data
    
    enum Network {
        static let successResponse = HTTPURLResponse(
            url: URL(string: "https://api.example.com")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )!
        
        static let unauthorizedResponse = HTTPURLResponse(
            url: URL(string: "https://api.example.com")!,
            statusCode: 401,
            httpVersion: nil,
            headerFields: nil
        )!
        
        static let rateLimitResponse = HTTPURLResponse(
            url: URL(string: "https://api.example.com")!,
            statusCode: 429,
            httpVersion: nil,
            headerFields: ["Retry-After": "60"]
        )!
        
        static let serverErrorResponse = HTTPURLResponse(
            url: URL(string: "https://api.example.com")!,
            statusCode: 500,
            httpVersion: nil,
            headerFields: nil
        )!
    }
    
    // MARK: - Date Test Data
    
    enum Dates {
        static let startOfMonth: Date = {
            let calendar = Calendar.current
            let components = calendar.dateComponents([.year, .month], from: Date())
            return calendar.date(from: components)!
        }()
        
        static let endOfMonth: Date = {
            let calendar = Calendar.current
            let nextMonth = calendar.date(byAdding: .month, value: 1, to: startOfMonth)!
            return calendar.date(byAdding: .day, value: -1, to: nextMonth)!
        }()
        
        static let midMonth: Date = {
            let calendar = Calendar.current
            return calendar.date(byAdding: .day, value: 14, to: startOfMonth)!
        }()
        
        static let futureDate = Date(timeIntervalSinceNow: 3600) // 1 hour from now
        static let pastDate = Date(timeIntervalSinceNow: -3600) // 1 hour ago
    }
    
    // MARK: - String Test Data
    
    enum Strings {
        static let emptyString = ""
        static let whitespaceString = "   "
        static let shortString = "Test"
        static let mediumString = "This is a medium length test string"
        static let longString = String(repeating: "Lorem ipsum dolor sit amet. ", count: 100)
        static let veryLongString = String(repeating: "a", count: 10000)
        
        static let specialCharacters = "Special chars: !@#$%^&*()_+-=[]{}|;':\",./<>?"
        static let unicodeString = "Unicode: 🚀✨🎉 émojis spëcıal chàracters ñ ß ∂ ∑"
        static let multilineString = "Line 1\nLine 2\nLine 3"
        static let tabString = "Tab\tSeparated\tValues"
        
        static let emailAddresses = [
            "test@example.com",
            "user.name@domain.co.uk",
            "first+last@company.org"
        ]
    }
    
    // MARK: - Error Test Data
    
    enum Errors {
        static let networkErrors: [(ProviderError, String)] = [
            (.networkError(message: "Connection failed", statusCode: nil), "Generic network error"),
            (.networkError(message: "Timeout", statusCode: 408), "Timeout error"),
            (.unauthorized, "Authentication error"),
            (.rateLimitExceeded, "Rate limit error"),
            (.serviceUnavailable, "Service unavailable")
        ]
        
        static let decodingErrors: [(ProviderError, String)] = [
            (.decodingError(message: "Invalid JSON", statusCode: 200), "JSON parsing error"),
            (.decodingError(message: "Missing field", statusCode: nil), "Missing field error")
        ]
        
        static let teamErrors: [(ProviderError, String)] = [
            (.noTeamFound, "No team found"),
            (.teamIdNotSet, "Team ID not set")
        ]
    }
}

// MARK: - Test Timeout Constants

enum TestTimeouts {
    static let veryShort: TimeInterval = 0.1  // 100ms
    static let short: TimeInterval = 0.5      // 500ms
    static let medium: TimeInterval = 1.0     // 1 second
    static let long: TimeInterval = 5.0       // 5 seconds
    static let veryLong: TimeInterval = 10.0  // 10 seconds
}

// MARK: - Test Configuration

enum TestConfiguration {
    /// Configuration for network retry tests with minimal delays
    static let fastNetworkRetryConfig = NetworkRetryHandler.Configuration(
        maxRetries: 3,
        initialDelay: 0.001,  // 1ms
        maxDelay: 0.01,       // 10ms
        multiplier: 2.0,
        jitterFactor: 0.1
    )
    
    /// Configuration for realistic network retry behavior
    static let realisticNetworkRetryConfig = NetworkRetryHandler.Configuration(
        maxRetries: 3,
        initialDelay: 1.0,    // 1 second
        maxDelay: 30.0,       // 30 seconds
        multiplier: 2.0,
        jitterFactor: 0.2
    )
}