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
             {"items":[{"description":"112 discounted claude-4-sonnet-thinking requests","cents":336},{"description":"97 extra fast premium requests beyond 500/month * 4 cents per such request","cents":388},{"description":"59 token-based usage calls to claude-4-sonnet-thinking, totalling: $4.65","cents":465},{"description":"12 token-based usage calls to o3, totalling: $2.10","cents":210}],"pricingDescription":{"description":"1. Chat, Cmd-K, Terminal Cmd-K, and Context Chat with claude-3-opus: 10 requests per day included in Pro/Business, 10 cents per request after that.\n2. Chat, Cmd-K, Terminal Cmd-K, and Context Chat with o1: 40 cents per request.\n3. Chat, Cmd-K, Terminal Cmd-K, and Context Chat with o1-mini: 10 requests per day included in Pro/Business, 10 cents per request after that.\n4. Chat, Cmd-K, Terminal Cmd-K, and Context Chat with o3: 30 cents per request.\n5. Chat, Cmd-K, Terminal Cmd-K, and Context Chat with gpt-4.5-preview: 200 cents per request.\n6. Chat, Cmd-K, Terminal Cmd-K, and Context Chat with our MAX versions of claude-3-7-sonnet and gemini-2-5-pro-exp-max: 5 cents per request, plus 5 cents per tool call.\n7. Long context chat with claude-3-haiku-200k: 10 requests per day included in Pro/Business, 10 cents per request after that.\n8. Long context chat with claude-3-sonnet-200k: 10 requests per day included in Pro/Business, 20 cents per request after that.\n9. Long context chat with claude-3-5-sonnet-200k: 10 requests per day included in Pro/Business, 20 cents per request after that.\n10. Long context chat with gemini-1.5-flash-500k: 10 requests per day included in Pro/Business, 10 cents per request after that.\n11. Long context chat with gpt-4o-128k: 10 requests per day included in Pro/Business, 10 cents per request after that.\n12. Bug finder: priced upfront based on the size of the diff. Currently experimental; expect the price to go down in the future.\n13. Fast premium models: As many fast premium requests as are included in your plan, 4 cents per request after that.\n14. Fast premium models (Haiku): As many fast premium requests as are included in your plan, 1 cent per request after that.","id":"392eabec215b2d0381fb87ead3be48765ced78e4acfbac7b12e862e8c426875f"}}
        """.utf8)

        let mockResponse = HTTPURLResponse(
            url: CursorAPIConstants.URLs.monthlyInvoice,
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
        XCTAssertEqual(invoice.items.count, 4)
        XCTAssertEqual(invoice.items[0].cents, 336)
        XCTAssertEqual(invoice.items[0].description, "112 discounted claude-4-sonnet-thinking requests")
        XCTAssertEqual(invoice.items[1].cents, 388)
        XCTAssertEqual(invoice.items[1].description, "97 extra fast premium requests beyond 500/month * 4 cents per such request")
        XCTAssertEqual(invoice.totalSpendingCents, 1399)
        XCTAssertEqual(invoice.month, 11)
        XCTAssertEqual(invoice.year, 2023)
        XCTAssertEqual(invoice.provider, .cursor)

        XCTAssertNil(invoice.pricingDescription)

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
             {"items":[{"description":"112 discounted claude-4-sonnet-thinking requests","cents":336},{"description":"97 extra fast premium requests beyond 500/month * 4 cents per such request","cents":388},{"description":"59 token-based usage calls to claude-4-sonnet-thinking, totalling: $4.65","cents":465},{"description":"12 token-based usage calls to o3, totalling: $2.10","cents":210}],"pricingDescription":{"description":"1. Chat, Cmd-K, Terminal Cmd-K, and Context Chat with claude-3-opus: 10 requests per day included in Pro/Business, 10 cents per request after that.\n2. Chat, Cmd-K, Terminal Cmd-K, and Context Chat with o1: 40 cents per request.\n3. Chat, Cmd-K, Terminal Cmd-K, and Context Chat with o1-mini: 10 requests per day included in Pro/Business, 10 cents per request after that.\n4. Chat, Cmd-K, Terminal Cmd-K, and Context Chat with o3: 30 cents per request.\n5. Chat, Cmd-K, Terminal Cmd-K, and Context Chat with gpt-4.5-preview: 200 cents per request.\n6. Chat, Cmd-K, Terminal Cmd-K, and Context Chat with our MAX versions of claude-3-7-sonnet and gemini-2-5-pro-exp-max: 5 cents per request, plus 5 cents per tool call.\n7. Long context chat with claude-3-haiku-200k: 10 requests per day included in Pro/Business, 10 cents per request after that.\n8. Long context chat with claude-3-sonnet-200k: 10 requests per day included in Pro/Business, 20 cents per request after that.\n9. Long context chat with claude-3-5-sonnet-200k: 10 requests per day included in Pro/Business, 20 cents per request after that.\n10. Long context chat with gemini-1.5-flash-500k: 10 requests per day included in Pro/Business, 10 cents per request after that.\n11. Long context chat with gpt-4o-128k: 10 requests per day included in Pro/Business, 10 cents per request after that.\n12. Bug finder: priced upfront based on the size of the diff. Currently experimental; expect the price to go down in the future.\n13. Fast premium models: As many fast premium requests as are included in your plan, 4 cents per request after that.\n14. Fast premium models (Haiku): As many fast premium requests as are included in your plan, 1 cent per request after that.","id":"392eabec215b2d0381fb87ead3be48765ced78e4acfbac7b12e862e8c426875f"}}
        """.utf8)

        let mockResponse = HTTPURLResponse(
            url: CursorAPIConstants.URLs.monthlyInvoice,
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
        XCTAssertEqual(invoice.items.count, 4)
        XCTAssertEqual(invoice.totalSpendingCents, 1399)
        XCTAssertNil(invoice.pricingDescription)

        // Verify stored team ID was used
        let requestBody = try XCTUnwrap(mockURLSession.lastRequest?.httpBody)
        let bodyJSON = try JSONSerialization.jsonObject(with: requestBody) as? [String: Any]
        XCTAssertEqual(bodyJSON?["month"] as? Int, 5)
        XCTAssertEqual(bodyJSON?["year"] as? Int, 2023)
        XCTAssertEqual(bodyJSON?["teamId"] as? Int, 999)
        XCTAssertEqual(bodyJSON?["includeUsageEvents"] as? Bool, false)
    }

    func testFetchMonthlyInvoice_NoTeamIdAvailable() async throws {
        // Given - no stored team ID and none provided
        let mockInvoiceData = Data("""
             {"items":[{"description":"112 discounted claude-4-sonnet-thinking requests","cents":336},{"description":"97 extra fast premium requests beyond 500/month * 4 cents per such request","cents":388},{"description":"59 token-based usage calls to claude-4-sonnet-thinking, totalling: $4.65","cents":465},{"description":"12 token-based usage calls to o3, totalling: $2.10","cents":210}],"pricingDescription":{"description":"1. Chat, Cmd-K, Terminal Cmd-K, and Context Chat with claude-3-opus: 10 requests per day included in Pro/Business, 10 cents per request after that.\n2. Chat, Cmd-K, Terminal Cmd-K, and Context Chat with o1: 40 cents per request.\n3. Chat, Cmd-K, Terminal Cmd-K, and Context Chat with o1-mini: 10 requests per day included in Pro/Business, 10 cents per request after that.\n4. Chat, Cmd-K, Terminal Cmd-K, and Context Chat with o3: 30 cents per request.\n5. Chat, Cmd-K, Terminal Cmd-K, and Context Chat with gpt-4.5-preview: 200 cents per request.\n6. Chat, Cmd-K, Terminal Cmd-K, and Context Chat with our MAX versions of claude-3-7-sonnet and gemini-2-5-pro-exp-max: 5 cents per request, plus 5 cents per tool call.\n7. Long context chat with claude-3-haiku-200k: 10 requests per day included in Pro/Business, 10 cents per request after that.\n8. Long context chat with claude-3-sonnet-200k: 10 requests per day included in Pro/Business, 20 cents per request after that.\n9. Long context chat with claude-3-5-sonnet-200k: 10 requests per day included in Pro/Business, 20 cents per request after that.\n10. Long context chat with gemini-1.5-flash-500k: 10 requests per day included in Pro/Business, 10 cents per request after that.\n11. Long context chat with gpt-4o-128k: 10 requests per day included in Pro/Business, 10 cents per request after that.\n12. Bug finder: priced upfront based on the size of the diff. Currently experimental; expect the price to go down in the future.\n13. Fast premium models: As many fast premium requests as are included in your plan, 4 cents per request after that.\n14. Fast premium models (Haiku): As many fast premium requests as are included in your plan, 1 cent per request after that.","id":"392eabec215b2d0381fb87ead3be48765ced78e4acfbac7b12e862e8c426875f"}}
        """.utf8)

        let mockResponse = HTTPURLResponse(
            url: CursorAPIConstants.URLs.monthlyInvoice,
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
        XCTAssertEqual(invoice.items.count, 4)
        XCTAssertEqual(invoice.totalSpendingCents, 1399)
        XCTAssertNil(invoice.pricingDescription)

        // Verify no team ID was sent in the request body
        let requestBody = try XCTUnwrap(mockURLSession.lastRequest?.httpBody)
        let bodyJSON = try JSONSerialization.jsonObject(with: requestBody) as? [String: Any]
        XCTAssertEqual(bodyJSON?["month"] as? Int, 5)
        XCTAssertEqual(bodyJSON?["year"] as? Int, 2023)
        XCTAssertNil(bodyJSON?["teamId"]) // teamId should not be present when nil
        XCTAssertEqual(bodyJSON?["includeUsageEvents"] as? Bool, false)
    }

    // MARK: - Usage Data Tests

    func testFetchUsageData_Success() async throws {
        // Given
        let mockUsageData = Data("""
        {"gpt-4":{"numRequests":518,"numRequestsTotal":731,"numTokens":13637151,"maxRequestUsage":500,"maxTokenUsage":null},"gpt-3.5-turbo":{"numRequests":0,"numRequestsTotal":0,"numTokens":0,"maxRequestUsage":null,"maxTokenUsage":null},"gpt-4-32k":{"numRequests":0,"numRequestsTotal":0,"numTokens":0,"maxRequestUsage":50,"maxTokenUsage":null},"startOfMonth":"2025-05-28T15:57:12.000Z"}
        """.utf8)

        let mockResponse = HTTPURLResponse(
            url: URL(string: "\(CursorAPIConstants.URLs.usage)?user=user123")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil)!

        mockURLSession.nextData = mockUsageData
        mockURLSession.nextResponse = mockResponse

        // When
        let usageData = try await cursorProvider.fetchUsageData(authToken: "user123::jwt-token")
        
        // Then
        XCTAssertEqual(usageData.currentRequests, 518) // Uses GPT-4 as primary

        // Verify the user parameter was extracted and used
        XCTAssertNotNil(mockURLSession.lastRequest?.url)
        let urlComponents = URLComponents(url: mockURLSession.lastRequest!.url!, resolvingAgainstBaseURL: false)
        XCTAssertEqual(urlComponents?.queryItems?.first(where: { $0.name == "user" })?.value, "user123")
        XCTAssertEqual(usageData.totalRequests, 731)
        XCTAssertEqual(usageData.maxRequests, 500)
        XCTAssertEqual(usageData.provider, .cursor)

        // Verify date parsing
        let expectedDate = ISO8601DateFormatter().date(from: "2025-05-28T15:57:12Z")
        XCTAssertEqual(usageData.startOfMonth, expectedDate)
    }

    func testFetchUsageData_InvalidDateFormat() async throws {
        // Given
        let mockUsageData = Data("""
                {"gpt-4":{"numRequests":518,"numRequestsTotal":731,"numTokens":13637151,"maxRequestUsage":500,"maxTokenUsage":null},"gpt-3.5-turbo":{"numRequests":0,"numRequestsTotal":0,"numTokens":0,"maxRequestUsage":null,"maxTokenUsage":null},"gpt-4-32k":{"numRequests":0,"numRequestsTotal":0,"numTokens":0,"maxRequestUsage":50,"maxTokenUsage":null},"startOfMonth":"invalid-date"}
        """.utf8)

        let mockResponse = HTTPURLResponse(
            url: URL(string: "\(CursorAPIConstants.URLs.usage)?user=user123")!,
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
