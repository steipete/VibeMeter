import Foundation
@testable import VibeMeter
import XCTest

final class CursorProviderDataTests: XCTestCase {
    private var cursorProvider: CursorProvider!
    private var mockURLSession: MockURLSession!
    private var mockSettingsManager: MockSettingsManager!

    override func setUp() {
        super.setUp()
        mockURLSession = MockURLSession()
        mockSettingsManager = MainActor.assumeIsolated { MockSettingsManager() }
        cursorProvider = CursorProvider(
            settingsManager: mockSettingsManager,
            urlSession: mockURLSession)
    }

    override func tearDown() {
        cursorProvider = nil
        mockURLSession = nil
        mockSettingsManager = nil
        super.tearDown()
    }

    // MARK: - Monthly Invoice Tests

    func testFetchMonthlyInvoice_WithProvidedTeamId() async throws {
        // Given
        let mockInvoiceData = Data("""
        {
            "items": [
                {
                    "cents": 2500,
                    "description": "GPT-4 Usage"
                },
                {
                    "cents": 1000,
                    "description": "GPT-3.5 Usage"
                }
            ],
            "pricing_description": {
                "description": "Pro Plan",
                "id": "pro-plan-123"
            }
        }
        """.utf8)

        let mockResponse = HTTPURLResponse(
            url: URL(string: "https://www.cursor.com/api/dashboard/get-monthly-invoice")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil)!

        mockURLSession.nextData = mockInvoiceData
        mockURLSession.nextResponse = mockResponse

        // When
        let invoice = try await cursorProvider.fetchMonthlyInvoice(
            authToken: "test-token",
            month: 11,
            year: 2023,
            teamId: 789)

        // Then
        XCTAssertEqual(invoice.items.count, 2)
        XCTAssertEqual(invoice.items[0].cents, 2500)
        XCTAssertEqual(invoice.items[0].description, "GPT-4 Usage")
        XCTAssertEqual(invoice.items[1].cents, 1000)
        XCTAssertEqual(invoice.items[1].description, "GPT-3.5 Usage")
        XCTAssertEqual(invoice.totalSpendingCents, 3500)
        XCTAssertEqual(invoice.month, 11)
        XCTAssertEqual(invoice.year, 2023)
        XCTAssertEqual(invoice.provider, .cursor)

        XCTAssertNotNil(invoice.pricingDescription)
        XCTAssertEqual(invoice.pricingDescription?.description, "Pro Plan")
        XCTAssertEqual(invoice.pricingDescription?.id, "pro-plan-123")

        // Verify request body
        let requestBody = try XCTUnwrap(mockURLSession.lastRequest?.httpBody)
        let bodyJSON = try JSONSerialization.jsonObject(with: requestBody) as? [String: Any]
        XCTAssertEqual(bodyJSON?["month"] as? Int, 11)
        XCTAssertEqual(bodyJSON?["year"] as? Int, 2023)
        XCTAssertEqual(bodyJSON?["teamId"] as? Int, 789)
        XCTAssertEqual(bodyJSON?["includeUsageEvents"] as? Bool, false)
    }

    func testFetchMonthlyInvoice_WithStoredTeamId() async throws {
        // Given
        await mockSettingsManager.updateSession(for: .cursor, session: ProviderSession(
            provider: .cursor,
            teamId: 999,
            teamName: "Test Team",
            userEmail: "test@example.com",
            isActive: true))

        let mockInvoiceData = Data("""
        {
            "items": [],
            "pricing_description": null
        }
        """.utf8)

        let mockResponse = HTTPURLResponse(
            url: URL(string: "https://www.cursor.com/api/dashboard/get-monthly-invoice")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil)!

        mockURLSession.nextData = mockInvoiceData
        mockURLSession.nextResponse = mockResponse

        // When
        let invoice = try await cursorProvider.fetchMonthlyInvoice(
            authToken: "test-token",
            month: 5,
            year: 2023,
            teamId: nil)

        // Then
        XCTAssertEqual(invoice.items.count, 0)
        XCTAssertEqual(invoice.totalSpendingCents, 0)
        XCTAssertNil(invoice.pricingDescription)

        // Verify stored team ID was used
        let requestBody = try XCTUnwrap(mockURLSession.lastRequest?.httpBody)
        let bodyJSON = try JSONSerialization.jsonObject(with: requestBody) as? [String: Any]
        XCTAssertEqual(bodyJSON?["month"] as? Int, 5)
        XCTAssertEqual(bodyJSON?["year"] as? Int, 2023)
        XCTAssertEqual(bodyJSON?["teamId"] as? Int, 999)
        XCTAssertEqual(bodyJSON?["includeUsageEvents"] as? Bool, false)
    }

    func testFetchMonthlyInvoice_NoTeamIdAvailable() async {
        // Given - no stored team ID and none provided

        // When/Then
        do {
            _ = try await cursorProvider.fetchMonthlyInvoice(
                authToken: "test-token",
                month: 5,
                year: 2023,
                teamId: nil)
            XCTFail("Should have thrown teamIdNotSet error")
        } catch let error as ProviderError {
            XCTAssertEqual(error, .teamIdNotSet)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    // MARK: - Usage Data Tests

    func testFetchUsageData_Success() async throws {
        // Given
        let mockUsageData = Data("""
        {
            "gpt-3.5-turbo": {
                "num_requests": 50,
                "num_requests_total": 100,
                "max_token_usage": 1000,
                "num_tokens": 500,
                "max_request_usage": 200
            },
            "gpt-4": {
                "num_requests": 25,
                "num_requests_total": 50,
                "max_token_usage": 2000,
                "num_tokens": 750,
                "max_request_usage": 100
            },
            "gpt-4-32k": {
                "num_requests": 5,
                "num_requests_total": 10,
                "max_token_usage": 5000,
                "num_tokens": 1000,
                "max_request_usage": 20
            },
            "start_of_month": "2023-12-01T00:00:00Z"
        }
        """.utf8)

        let mockResponse = HTTPURLResponse(
            url: URL(string: "https://www.cursor.com/api/usage?user=user123")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil)!

        mockURLSession.nextData = mockUsageData
        mockURLSession.nextResponse = mockResponse

        // When
        let usageData = try await cursorProvider.fetchUsageData(authToken: "user123::jwt-token")

        // Then
        XCTAssertEqual(usageData.currentRequests, 25) // Uses GPT-4 as primary

        // Verify the user parameter was extracted and used
        XCTAssertNotNil(mockURLSession.lastRequest?.url)
        let urlComponents = URLComponents(url: mockURLSession.lastRequest!.url!, resolvingAgainstBaseURL: false)
        XCTAssertEqual(urlComponents?.queryItems?.first(where: { $0.name == "user" })?.value, "user123")
        XCTAssertEqual(usageData.totalRequests, 50)
        XCTAssertEqual(usageData.maxRequests, 100)
        XCTAssertEqual(usageData.provider, .cursor)

        // Verify date parsing
        let expectedDate = ISO8601DateFormatter().date(from: "2023-12-01T00:00:00Z")!
        XCTAssertEqual(usageData.startOfMonth, expectedDate)
    }

    func testFetchUsageData_InvalidDateFormat() async throws {
        // Given
        let mockUsageData = Data("""
        {
            "gpt-3.5-turbo": {
                "num_requests": 50,
                "num_requests_total": 100,
                "max_token_usage": 1000,
                "num_tokens": 500,
                "max_request_usage": 200
            },
            "gpt-4": {
                "num_requests": 25,
                "num_requests_total": 50,
                "max_token_usage": 2000,
                "num_tokens": 750,
                "max_request_usage": 100
            },
            "gpt-4-32k": {
                "num_requests": 5,
                "num_requests_total": 10,
                "max_token_usage": 5000,
                "num_tokens": 1000,
                "max_request_usage": 20
            },
            "start_of_month": "invalid-date"
        }
        """.utf8)

        let mockResponse = HTTPURLResponse(
            url: URL(string: "https://www.cursor.com/api/usage?user=user123")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil)!

        mockURLSession.nextData = mockUsageData
        mockURLSession.nextResponse = mockResponse

        // When
        let usageData = try await cursorProvider.fetchUsageData(authToken: "user456::jwt-token")

        // Then - should use current date as fallback
        let timeDifference = abs(usageData.startOfMonth.timeIntervalSinceNow)
        XCTAssertLessThan(timeDifference, 60) // Within 1 minute of now

        // Verify the user parameter was extracted and used
        XCTAssertNotNil(mockURLSession.lastRequest?.url)
        let urlComponents = URLComponents(url: mockURLSession.lastRequest!.url!, resolvingAgainstBaseURL: false)
        XCTAssertEqual(urlComponents?.queryItems?.first(where: { $0.name == "user" })?.value, "user456")
    }
}

// MARK: - Mock Settings Manager

private class MockSettingsManager: SettingsManagerProtocol {
    var providerSessions: [ServiceProvider: ProviderSession] = [:]
    var selectedCurrencyCode: String = "USD"
    var warningLimitUSD: Double = 200
    var upperLimitUSD: Double = 500
    var refreshIntervalMinutes: Int = 5
    var launchAtLoginEnabled: Bool = false
    var menuBarDisplayMode: MenuBarDisplayMode = .both
    var showInDock: Bool = false
    var enabledProviders: Set<ServiceProvider> = [.cursor]
    var updateChannel: UpdateChannel = .stable

    func clearUserSessionData() {
        providerSessions.removeAll()
    }

    func clearUserSessionData(for provider: ServiceProvider) {
        providerSessions.removeValue(forKey: provider)
    }

    func getSession(for provider: ServiceProvider) -> ProviderSession? {
        providerSessions[provider]
    }

    func updateSession(for provider: ServiceProvider, session: ProviderSession) {
        providerSessions[provider] = session
    }
}
