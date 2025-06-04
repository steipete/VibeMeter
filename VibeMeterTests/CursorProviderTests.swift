import Foundation
@testable import VibeMeter
import XCTest

final class CursorProviderTests: XCTestCase {
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

    // MARK: - Team Info Tests

    func testFetchTeamInfo_Success() async throws {
        // Given
        let mockTeamsData = """
        {
            "teams": [
                {
                    "id": 123,
                    "name": "Test Team"
                }
            ]
        }
        """.data(using: .utf8)!

        let mockResponse = HTTPURLResponse(
            url: URL(string: "https://www.cursor.com/api/dashboard/teams")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil)!

        mockURLSession.nextData = mockTeamsData
        mockURLSession.nextResponse = mockResponse

        // When
        let teamInfo = try await cursorProvider.fetchTeamInfo(authToken: "test-token")

        // Then
        XCTAssertEqual(teamInfo.id, 123)
        XCTAssertEqual(teamInfo.name, "Test Team")
        XCTAssertEqual(teamInfo.provider, .cursor)

        // Verify request was correctly formed
        XCTAssertEqual(mockURLSession.lastRequest?.httpMethod, "POST")
        XCTAssertEqual(
            mockURLSession.lastRequest?.value(forHTTPHeaderField: "Cookie"),
            "WorkosCursorSessionToken=test-token")
        XCTAssertEqual(mockURLSession.lastRequest?.value(forHTTPHeaderField: "Content-Type"), "application/json")
    }

    func testFetchTeamInfo_NoTeamsFound() async {
        // Given
        let mockEmptyTeamsData = """
        {
            "teams": []
        }
        """.data(using: .utf8)!

        let mockResponse = HTTPURLResponse(
            url: URL(string: "https://www.cursor.com/api/dashboard/teams")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil)!

        mockURLSession.nextData = mockEmptyTeamsData
        mockURLSession.nextResponse = mockResponse

        // When/Then
        do {
            _ = try await cursorProvider.fetchTeamInfo(authToken: "test-token")
            XCTFail("Should have thrown noTeamFound error")
        } catch let error as ProviderError {
            XCTAssertEqual(error, .noTeamFound)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testFetchTeamInfo_UnauthorizedError() async {
        // Given
        let mockResponse = HTTPURLResponse(
            url: URL(string: "https://www.cursor.com/api/dashboard/teams")!,
            statusCode: 401,
            httpVersion: nil,
            headerFields: nil)!

        mockURLSession.nextData = Data()
        mockURLSession.nextResponse = mockResponse

        // When/Then
        do {
            _ = try await cursorProvider.fetchTeamInfo(authToken: "invalid-token")
            XCTFail("Should have thrown unauthorized error")
        } catch let error as ProviderError {
            XCTAssertEqual(error, .unauthorized)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    // MARK: - User Info Tests

    func testFetchUserInfo_Success() async throws {
        // Given
        let mockUserData = """
        {
            "email": "test@example.com",
            "teamId": 456
        }
        """.data(using: .utf8)!

        let mockResponse = HTTPURLResponse(
            url: URL(string: "https://www.cursor.com/api/auth/me")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil)!

        mockURLSession.nextData = mockUserData
        mockURLSession.nextResponse = mockResponse

        // When
        let userInfo = try await cursorProvider.fetchUserInfo(authToken: "test-token")

        // Then
        XCTAssertEqual(userInfo.email, "test@example.com")
        XCTAssertEqual(userInfo.teamId, 456)
        XCTAssertEqual(userInfo.provider, .cursor)

        // Verify request was correctly formed (GET request)
        XCTAssertEqual(mockURLSession.lastRequest?.httpMethod, "GET")
        XCTAssertEqual(
            mockURLSession.lastRequest?.value(forHTTPHeaderField: "Cookie"),
            "WorkosCursorSessionToken=test-token")
        XCTAssertEqual(mockURLSession.lastRequest?.value(forHTTPHeaderField: "Accept"), "application/json")
    }

    func testFetchUserInfo_WithoutTeamId() async throws {
        // Given
        let mockUserData = """
        {
            "email": "test@example.com"
        }
        """.data(using: .utf8)!

        let mockResponse = HTTPURLResponse(
            url: URL(string: "https://www.cursor.com/api/auth/me")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil)!

        mockURLSession.nextData = mockUserData
        mockURLSession.nextResponse = mockResponse

        // When
        let userInfo = try await cursorProvider.fetchUserInfo(authToken: "test-token")

        // Then
        XCTAssertEqual(userInfo.email, "test@example.com")
        XCTAssertNil(userInfo.teamId)
        XCTAssertEqual(userInfo.provider, .cursor)
    }

    // MARK: - Monthly Invoice Tests

    func testFetchMonthlyInvoice_WithProvidedTeamId() async throws {
        // Given
        let mockInvoiceData = """
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
        """.data(using: .utf8)!

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
    }

    func testFetchMonthlyInvoice_WithStoredTeamId() async throws {
        // Given
        await mockSettingsManager.updateSession(for: .cursor, session: ProviderSession(
            provider: .cursor,
            teamId: 999,
            teamName: "Test Team",
            userEmail: "test@example.com",
            isActive: true))

        let mockInvoiceData = """
        {
            "items": [],
            "pricing_description": null
        }
        """.data(using: .utf8)!

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
        XCTAssertEqual(bodyJSON?["teamId"] as? Int, 999)
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
        let mockUsageData = """
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
        """.data(using: .utf8)!

        let mockResponse = HTTPURLResponse(
            url: URL(string: "https://www.cursor.com/api/usage")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil)!

        mockURLSession.nextData = mockUsageData
        mockURLSession.nextResponse = mockResponse

        // When
        let usageData = try await cursorProvider.fetchUsageData(authToken: "test-token")

        // Then
        XCTAssertEqual(usageData.currentRequests, 25) // Uses GPT-4 as primary
        XCTAssertEqual(usageData.totalRequests, 50)
        XCTAssertEqual(usageData.maxRequests, 100)
        XCTAssertEqual(usageData.provider, .cursor)

        // Verify date parsing
        let expectedDate = ISO8601DateFormatter().date(from: "2023-12-01T00:00:00Z")!
        XCTAssertEqual(usageData.startOfMonth, expectedDate)
    }

    func testFetchUsageData_InvalidDateFormat() async throws {
        // Given
        let mockUsageData = """
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
        """.data(using: .utf8)!

        let mockResponse = HTTPURLResponse(
            url: URL(string: "https://www.cursor.com/api/usage")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil)!

        mockURLSession.nextData = mockUsageData
        mockURLSession.nextResponse = mockResponse

        // When
        let usageData = try await cursorProvider.fetchUsageData(authToken: "test-token")

        // Then - should use current date as fallback
        let timeDifference = abs(usageData.startOfMonth.timeIntervalSinceNow)
        XCTAssertLessThan(timeDifference, 60) // Within 1 minute of now
    }

    // MARK: - Token Validation Tests

    func testValidateToken_ValidToken() async {
        // Given
        let mockUserData = """
        {
            "email": "test@example.com",
            "teamId": 456
        }
        """.data(using: .utf8)!

        let mockResponse = HTTPURLResponse(
            url: URL(string: "https://www.cursor.com/api/auth/me")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil)!

        mockURLSession.nextData = mockUserData
        mockURLSession.nextResponse = mockResponse

        // When
        let isValid = await cursorProvider.validateToken(authToken: "valid-token")

        // Then
        XCTAssertTrue(isValid)
    }

    func testValidateToken_InvalidToken() async {
        // Given
        let mockResponse = HTTPURLResponse(
            url: URL(string: "https://www.cursor.com/api/auth/me")!,
            statusCode: 401,
            httpVersion: nil,
            headerFields: nil)!

        mockURLSession.nextData = Data()
        mockURLSession.nextResponse = mockResponse

        // When
        let isValid = await cursorProvider.validateToken(authToken: "invalid-token")

        // Then
        XCTAssertFalse(isValid)
    }

    func testValidateToken_NetworkError() async {
        // Given
        mockURLSession.nextError = NSError(domain: "NetworkError", code: -1009, userInfo: nil)

        // When
        let isValid = await cursorProvider.validateToken(authToken: "test-token")

        // Then
        XCTAssertFalse(isValid)
    }

    // MARK: - Authentication URL Tests

    func testGetAuthenticationURL() async {
        // When
        let authURL = cursorProvider.getAuthenticationURL()

        // Then
        XCTAssertEqual(authURL.absoluteString, "https://authenticator.cursor.sh/")
    }

    // MARK: - Token Extraction Tests

    func testExtractAuthToken_FromCookies() async {
        // Given
        let cookie = HTTPCookie(properties: [
            .name: "WorkosCursorSessionToken",
            .value: "extracted-token-123",
            .domain: ".cursor.com",
            .path: "/",
        ])!

        let callbackData: [String: Any] = [
            "cookies": [cookie],
        ]

        // When
        let extractedToken = cursorProvider.extractAuthToken(from: callbackData)

        // Then
        XCTAssertEqual(extractedToken, "extracted-token-123")
    }

    func testExtractAuthToken_NoCookies() async {
        // Given
        let callbackData: [String: Any] = [:]

        // When
        let extractedToken = cursorProvider.extractAuthToken(from: callbackData)

        // Then
        XCTAssertNil(extractedToken)
    }

    func testExtractAuthToken_WrongCookieName() async {
        // Given
        let cookie = HTTPCookie(properties: [
            .name: "SomeOtherCookie",
            .value: "some-value",
            .domain: ".cursor.com",
            .path: "/",
        ])!

        let callbackData: [String: Any] = [
            "cookies": [cookie],
        ]

        // When
        let extractedToken = cursorProvider.extractAuthToken(from: callbackData)

        // Then
        XCTAssertNil(extractedToken)
    }

    // MARK: - Error Handling Tests

    func testNetworkError_RateLimitExceeded() async {
        // Given
        let mockResponse = HTTPURLResponse(
            url: URL(string: "https://www.cursor.com/api/auth/me")!,
            statusCode: 429,
            httpVersion: nil,
            headerFields: nil)!

        mockURLSession.nextData = Data()
        mockURLSession.nextResponse = mockResponse

        // When/Then
        do {
            _ = try await cursorProvider.fetchUserInfo(authToken: "test-token")
            XCTFail("Should have thrown rate limit error")
        } catch let error as ProviderError {
            XCTAssertEqual(error, .rateLimitExceeded)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testNetworkError_ServiceUnavailable() async {
        // Given
        let mockResponse = HTTPURLResponse(
            url: URL(string: "https://www.cursor.com/api/auth/me")!,
            statusCode: 503,
            httpVersion: nil,
            headerFields: nil)!

        mockURLSession.nextData = Data()
        mockURLSession.nextResponse = mockResponse

        // When/Then
        do {
            _ = try await cursorProvider.fetchUserInfo(authToken: "test-token")
            XCTFail("Should have thrown service unavailable error")
        } catch let error as ProviderError {
            XCTAssertEqual(error, .serviceUnavailable)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testNetworkError_DecodingError() async {
        // Given - invalid JSON
        let invalidJSON = "{ invalid json }".data(using: .utf8)!

        let mockResponse = HTTPURLResponse(
            url: URL(string: "https://www.cursor.com/api/auth/me")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil)!

        mockURLSession.nextData = invalidJSON
        mockURLSession.nextResponse = mockResponse

        // When/Then
        do {
            _ = try await cursorProvider.fetchUserInfo(authToken: "test-token")
            XCTFail("Should have thrown decoding error")
        } catch let error as ProviderError {
            if case .decodingError = error {
                // Expected
            } else {
                XCTFail("Expected decoding error, got \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testNetworkError_SpecificErrorResponse() async {
        // Given
        let errorResponse = """
        {
            "error": {
                "details": [
                    {
                        "error": "ERROR_UNAUTHORIZED",
                        "details": {
                            "detail": "Team not found"
                        }
                    }
                ]
            }
        }
        """.data(using: .utf8)!

        let mockResponse = HTTPURLResponse(
            url: URL(string: "https://www.cursor.com/api/dashboard/teams")!,
            statusCode: 400,
            httpVersion: nil,
            headerFields: nil)!

        mockURLSession.nextData = errorResponse
        mockURLSession.nextResponse = mockResponse

        // When/Then
        do {
            _ = try await cursorProvider.fetchTeamInfo(authToken: "test-token")
            XCTFail("Should have thrown no team found error")
        } catch let error as ProviderError {
            XCTAssertEqual(error, .noTeamFound)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testNetworkError_500WithTeamNotFound() async {
        // Given
        let errorMessage = "Team not found in database".data(using: .utf8)!

        let mockResponse = HTTPURLResponse(
            url: URL(string: "https://www.cursor.com/api/dashboard/teams")!,
            statusCode: 500,
            httpVersion: nil,
            headerFields: nil)!

        mockURLSession.nextData = errorMessage
        mockURLSession.nextResponse = mockResponse

        // When/Then
        do {
            _ = try await cursorProvider.fetchTeamInfo(authToken: "test-token")
            XCTFail("Should have thrown no team found error")
        } catch let error as ProviderError {
            XCTAssertEqual(error, .noTeamFound)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testNetworkError_GenericNetworkFailure() async {
        // Given
        mockURLSession.nextError = NSError(
            domain: NSURLErrorDomain,
            code: NSURLErrorTimedOut,
            userInfo: [NSLocalizedDescriptionKey: "Request timed out"])

        // When/Then
        do {
            _ = try await cursorProvider.fetchUserInfo(authToken: "test-token")
            XCTFail("Should have thrown network error")
        } catch let error as ProviderError {
            if case let .networkError(message, statusCode) = error {
                XCTAssertTrue(message.contains("timed out"))
                XCTAssertNil(statusCode)
            } else {
                XCTFail("Expected network error, got \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    // MARK: - Request Configuration Tests

    func testRequestConfiguration() async throws {
        // Given
        let mockUserData = """
        {
            "email": "test@example.com"
        }
        """.data(using: .utf8)!

        let mockResponse = HTTPURLResponse(
            url: URL(string: "https://www.cursor.com/api/auth/me")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil)!

        mockURLSession.nextData = mockUserData
        mockURLSession.nextResponse = mockResponse

        // When
        _ = try await cursorProvider.fetchUserInfo(authToken: "test-auth-token")

        // Then
        let request = try XCTUnwrap(mockURLSession.lastRequest)

        // Verify headers
        XCTAssertEqual(request.value(forHTTPHeaderField: "Cookie"), "WorkosCursorSessionToken=test-auth-token")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Accept"), "application/json")

        // Verify timeout
        XCTAssertEqual(request.timeoutInterval, 30)

        // Verify URL
        XCTAssertEqual(request.url?.absoluteString, "https://www.cursor.com/api/auth/me")
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
