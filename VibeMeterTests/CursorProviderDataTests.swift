import Foundation
import Testing
@testable import VibeMeter

@Suite("CursorProviderDataTests")
struct CursorProviderDataTests {
    private let cursorProvider: CursorProvider
    private let mockURLSession: MockURLSession
    private let mockSettingsManager: MockSettingsManager

    init() async {
        self.mockURLSession = MockURLSession()
        self.mockSettingsManager = await MockSettingsManager()
        self.cursorProvider = CursorProvider(
            settingsManager: mockSettingsManager,
            urlSession: mockURLSession)
    }

    // MARK: - Monthly Invoice Tests

    @Test("fetch monthly invoice  with provided team id")

    func fetchMonthlyInvoice_WithProvidedTeamId() async throws {
        // Given
        let mockInvoiceData = Data("""
            {
                "items": [
                    {"description": "112 discounted claude-4-sonnet-thinking requests", "cents": 336},
                    {"description": "97 extra fast premium requests beyond 500/month * 4 cents per such request", "cents": 388},
                    {"description": "59 token-based usage calls to claude-4-sonnet-thinking, totalling: $4.65", "cents": 465},
                    {"description": "12 token-based usage calls to o3, totalling: $2.10", "cents": 210}
                ],
                "pricingDescription": {
                    "description": "1. Chat, Cmd-K, Terminal Cmd-K, and Context Chat with claude-3-opus: 10 requests per day included in Pro/Business, 10 cents per request after that.\\n2. Chat, Cmd-K, Terminal Cmd-K, and Context Chat with o1: 40 cents per request.\\n3. Chat, Cmd-K, Terminal Cmd-K, and Context Chat with o1-mini: 10 requests per day included in Pro/Business, 10 cents per request after that.\\n4. Chat, Cmd-K, Terminal Cmd-K, and Context Chat with o3: 30 cents per request.\\n5. Chat, Cmd-K, Terminal Cmd-K, and Context Chat with gpt-4.5-preview: 200 cents per request.\\n6. Chat, Cmd-K, Terminal Cmd-K, and Context Chat with our MAX versions of claude-3-7-sonnet and gemini-2-5-pro-exp-max: 5 cents per request, plus 5 cents per tool call.\\n7. Long context chat with claude-3-haiku-200k: 10 requests per day included in Pro/Business, 10 cents per request after that.\\n8. Long context chat with claude-3-sonnet-200k: 10 requests per day included in Pro/Business, 20 cents per request after that.\\n9. Long context chat with claude-3-5-sonnet-200k: 10 requests per day included in Pro/Business, 20 cents per request after that.\\n10. Long context chat with gemini-1.5-flash-500k: 10 requests per day included in Pro/Business, 10 cents per request after that.\\n11. Long context chat with gpt-4o-128k: 10 requests per day included in Pro/Business, 10 cents per request after that.\\n12. Bug finder: priced upfront based on the size of the diff. Currently experimental; expect the price to go down in the future.\\n13. Fast premium models: As many fast premium requests as are included in your plan, 4 cents per request after that.\\n14. Fast premium models (Haiku): As many fast premium requests as are included in your plan, 1 cent per request after that.",
                    "id": "392eabec215b2d0381fb87ead3be48765ced78e4acfbac7b12e862e8c426875f"
                }
            }
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
        #expect(invoice.items.count == 4)
        #expect(invoice.items[0].description == "112 discounted claude-4-sonnet-thinking requests")
        #expect(invoice.items[1]
            .description == "97 extra fast premium requests beyond 500/month * 4 cents per such request")
        #expect(invoice.month == 11)
        #expect(invoice.provider == .cursor)

        // Verify request body
        let requestBody = mockURLSession.lastRequest?.httpBody
        #expect(requestBody != nil)
        let bodyJSON = try JSONSerialization.jsonObject(with: requestBody!) as? [String: Any]
        #expect(bodyJSON?["month"] as? Int == 11)
        #expect(bodyJSON?["teamId"] as? Int == 789)
    }

    @Test("fetch monthly invoice  with stored team id")

    func fetchMonthlyInvoice_WithStoredTeamId() async throws {
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
        #expect(invoice.items.count == 4)
        #expect(invoice.pricingDescription == nil)

        // Verify request body
        let requestBody = mockURLSession.lastRequest?.httpBody
        #expect(requestBody != nil)
        let bodyJSON = try JSONSerialization.jsonObject(with: requestBody!) as? [String: Any]
        #expect(bodyJSON?["month"] as? Int == 5)
        #expect(bodyJSON?["teamId"] as? Int == 999)
    }

    @Test("fetch monthly invoice  no team id available")

    func fetchMonthlyInvoice_NoTeamIdAvailable() async throws {
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
        #expect(invoice.items.count == 4)
        #expect(invoice.pricingDescription == nil)

        // Verify request body
        let requestBody = mockURLSession.lastRequest?.httpBody
        #expect(requestBody != nil)
        let bodyJSON = try JSONSerialization.jsonObject(with: requestBody!) as? [String: Any]
        #expect(bodyJSON?["month"] as? Int == 5)
        #expect(bodyJSON?["teamId"] == nil)
    }

    // MARK: - Usage Data Tests

    @Test("fetch usage data  success")

    func fetchUsageData_Success() async throws {
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
        #expect(usageData.currentRequests == 518)
        #expect(usageData.totalRequests == 731)
        #expect(usageData.provider == .cursor)

        // Verify URL query parameters
        let urlComponents = URLComponents(url: mockURLSession.lastRequest!.url!, resolvingAgainstBaseURL: false)
        #expect(urlComponents?.queryItems?.first(where: { $0.name == "user" })?.value == "user123")

        // Verify date parsing
        let formatter = ISO8601DateFormatter()
        let expectedDate = formatter.date(from: "2025-05-28T15:57:12.000Z")
        #expect(usageData.startOfMonth == expectedDate)
    }

    @Test("fetch usage data invalid date format")
    func fetchUsageData_InvalidDateFormat() async throws {
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
        #expect(timeDifference < 60)

        // Verify URL query parameters
        let urlComponents = URLComponents(url: mockURLSession.lastRequest!.url!, resolvingAgainstBaseURL: false)
        #expect(urlComponents?.queryItems?.first(where: { $0.name == "user" })?.value == "user456")
    }
}
