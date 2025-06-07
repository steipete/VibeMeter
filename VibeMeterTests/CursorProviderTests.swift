import Foundation
import Testing
@testable import VibeMeter

// MARK: - Test Case Data Structures

struct TeamInfoTestCase: Sendable {
    let jsonResponse: String
    let expectedId: Int
    let expectedName: String?
    let description: String

    init(json: String, id: Int, name: String? = nil, _ description: String) {
        self.jsonResponse = json
        self.expectedId = id
        self.expectedName = name
        self.description = description
    }
}

struct MonthlySpendingTestCase: Sendable {
    let jsonResponse: String
    let expectedSpending: Double
    let description: String

    init(json: String, spending: Double, _ description: String) {
        self.jsonResponse = json
        self.expectedSpending = spending
        self.description = description
    }
}

struct UsageDataTestCase: Sendable {
    let jsonResponse: String
    let expectedUsage: Double
    let description: String

    init(json: String, usage: Double, _ description: String) {
        self.jsonResponse = json
        self.expectedUsage = usage
        self.description = description
    }
}

struct UserInfoTestCase: Sendable {
    let jsonResponse: String
    let expectedEmail: String
    let hasTeamId: Bool
    let description: String

    init(json: String, email: String, hasTeamId: Bool = true, _ description: String) {
        self.jsonResponse = json
        self.expectedEmail = email
        self.hasTeamId = hasTeamId
        self.description = description
    }
}

struct TokenExtractionTestCase: @unchecked Sendable {
    let callbackData: [String: Any]
    let expectedToken: String?
    let description: String

    init(data: [String: Any], expectedToken: String?, _ description: String) {
        self.callbackData = data
        self.expectedToken = expectedToken
        self.description = description
    }
}

@Suite("CursorProvider Tests", .tags(.provider))
struct CursorProviderTests {
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

    // MARK: - Basic Functionality Tests
    
    @Suite("Basic Functionality", .tags(.unit, .fast))
    struct BasicFunctionality {
        let provider: CursorProvider
        let mockSession: MockURLSession
        let mockSettings: MockSettingsManager

        init() async {
            self.mockSession = MockURLSession()
            self.mockSettings = await MockSettingsManager()
            self.provider = CursorProvider(settingsManager: mockSettings, urlSession: mockSession)
        }

        // MARK: Team Info Tests
        
        @Suite("Team Information")
        struct TeamInformation {
            let provider: CursorProvider
            let mockSession: MockURLSession

            init() async {
                self.mockSession = MockURLSession()
                let mockSettings = await MockSettingsManager()
                self.provider = CursorProvider(settingsManager: mockSettings, urlSession: mockSession)
            }

            static let teamInfoTestCases: [TeamInfoTestCase] = [
                TeamInfoTestCase(
                    json: """
                    {
                        "teams": [
                            {
                                "id": 123,
                                "name": "Development Team"
                            }
                        ]
                    }
                    """,
                    id: 123,
                    name: "Development Team",
                    "successful team fetch with name"),
                TeamInfoTestCase(
                    json: """
                    {
                        "teams": [
                            {
                                "id": 456,
                                "name": "Production Team"
                            }
                        ]
                    }
                    """,
                    id: 456,
                    name: "Production Team",
                    "successful team fetch with different team"),
                TeamInfoTestCase(
                    json: "{}",
                    id: -1,
                    "fallback team when no teams found"),
            ]

            @Test("Team info fetching scenarios", arguments: teamInfoTestCases)
            func teamInfoFetchingScenarios(testCase: TeamInfoTestCase) async throws {
                // Given
                let mockData = Data(testCase.jsonResponse.utf8)
                let mockResponse = HTTPURLResponse(
                    url: URL(string: CursorAPIConstants.URLs.teams.absoluteString)!,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: nil)!

                mockSession.nextData = mockData
                mockSession.nextResponse = mockResponse

                // When
                let teamInfo = try await provider.fetchTeamInfo(authToken: "test-token")

                // Then
                #expect(teamInfo.id == testCase.expectedId)
                #expect(teamInfo.provider == .cursor)
                #expect(mockSession.lastRequest?.value(forHTTPHeaderField: "Cookie") != nil)
            }

            @Test("Unauthorized team info request")
            func unauthorizedTeamInfoRequest() async {
                // Given
                let mockResponse = HTTPURLResponse(
                    url: URL(string: CursorAPIConstants.URLs.teams.absoluteString)!,
                    statusCode: 401,
                    httpVersion: nil,
                    headerFields: nil)!
                mockSession.nextData = Data()
                mockSession.nextResponse = mockResponse

                // When/Then
                do {
                    _ = try await provider.fetchTeamInfo(authToken: "invalid-token")
                    Issue.record("Expected condition not met")
                } catch let error as ProviderError {
                    #expect(error == .unauthorized)
                } catch {
                    Issue.record("Expected condition not met")
                }
            }
        }

        // MARK: User Info Tests
        
        @Suite("User Information")
        struct UserInformation {
            let provider: CursorProvider
            let mockSession: MockURLSession

            init() async {
                self.mockSession = MockURLSession()
                let mockSettings = await MockSettingsManager()
                self.provider = CursorProvider(settingsManager: mockSettings, urlSession: mockSession)
            }

            static let userInfoTestCases: [UserInfoTestCase] = [
                UserInfoTestCase(
                    json: """
                    {
                        "email": "developer@example.com",
                        "teamId": 456
                    }
                    """,
                    email: "developer@example.com",
                    "user with team ID"),
                UserInfoTestCase(
                    json: """
                    {
                        "email": "freelancer@example.com"
                    }
                    """,
                    email: "freelancer@example.com",
                    hasTeamId: false,
                    "user without team ID"),
                UserInfoTestCase(
                    json: """
                    {
                        "email": "admin@company.com",
                        "teamId": 789
                    }
                    """,
                    email: "admin@company.com",
                    "admin user with different team"),
            ]

            @Test("User info fetching scenarios", arguments: userInfoTestCases)
            func userInfoFetchingScenarios(testCase: UserInfoTestCase) async throws {
                // Given
                let mockData = Data(testCase.jsonResponse.utf8)
                let mockResponse = HTTPURLResponse(
                    url: URL(string: CursorAPIConstants.URLs.userInfo.absoluteString)!,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: nil)!

                mockSession.nextData = mockData
                mockSession.nextResponse = mockResponse

                // When
                let userInfo = try await provider.fetchUserInfo(authToken: "test-token")

                // Then
                #expect(userInfo.email == testCase.expectedEmail)
                #expect(userInfo.provider == .cursor)
                #expect(mockSession.lastRequest?.httpMethod == "GET")

                let cookieHeader = mockSession.lastRequest?.value(forHTTPHeaderField: "Cookie")
                #expect(cookieHeader?.contains("WorkosCursorSessionToken=test-token") == true)
                #expect(mockSession.lastRequest?.value(forHTTPHeaderField: "Accept") != nil)
            }
        }

        // MARK: Authentication Tests
        
        @Suite("Authentication")
        struct Authentication {
            let provider: CursorProvider

            init() async {
                let mockSession = MockURLSession()
                let mockSettings = await MockSettingsManager()
                self.provider = CursorProvider(settingsManager: mockSettings, urlSession: mockSession)
            }

            @Test("Authentication URL generation")
            func authenticationURLGeneration() {
                // When
                let authURL = provider.getAuthenticationURL()

                // Then
                #expect(authURL == CursorAPIConstants.authenticationURL)
            }

            static let tokenExtractionTestCases: [TokenExtractionTestCase] = [
                TokenExtractionTestCase(
                    data: [
                        "cookies": [
                            HTTPCookie(properties: [
                                .name: CursorAPIConstants.Headers.sessionCookieName,
                                .value: "valid-token-123",
                                .domain: ".cursor.com",
                                .path: "/",
                            ])!,
                        ],
                    ],
                    expectedToken: "valid-token-123",
                    "valid session cookie extraction"),
                TokenExtractionTestCase(
                    data: [:],
                    expectedToken: nil,
                    "no cookies in callback data"),
                TokenExtractionTestCase(
                    data: [
                        "cookies": [
                            HTTPCookie(properties: [
                                .name: "SomeOtherCookie",
                                .value: "irrelevant-value",
                                .domain: ".cursor.com",
                                .path: "/",
                            ])!,
                        ],
                    ],
                    expectedToken: nil,
                    "wrong cookie name"),
                TokenExtractionTestCase(
                    data: [
                        "cookies": [
                            HTTPCookie(properties: [
                                .name: CursorAPIConstants.Headers.sessionCookieName,
                                .value: "another-token-456",
                                .domain: ".cursor.com",
                                .path: "/",
                            ])!,
                            HTTPCookie(properties: [
                                .name: "OtherCookie",
                                .value: "other-value",
                                .domain: ".cursor.com",
                                .path: "/",
                            ])!,
                        ],
                    ],
                    expectedToken: "another-token-456",
                    "multiple cookies with correct one present"),
            ]

            @Test("Auth token extraction scenarios", arguments: tokenExtractionTestCases)
            func authTokenExtractionScenarios(testCase: TokenExtractionTestCase) {
                // When
                let extractedToken = provider.extractAuthToken(from: testCase.callbackData)

                // Then
                #expect(extractedToken == testCase.expectedToken)
            }
        }

        // MARK: Performance Tests
        
        @Test("Provider initialization performance", .timeLimit(.minutes(1)))
        func providerInitializationPerformance() async {
            // When/Then - Should initialize quickly
            for _ in 0 ..< 100 {
                let mockSession = MockURLSession()
                let mockSettings = await MockSettingsManager()
                _ = CursorProvider(settingsManager: mockSettings, urlSession: mockSession)
            }
        }

        @Test("Concurrent authentication operations")
        func concurrentAuthenticationOperations() async {
            // Given
            let iterations = 10

            // When - Perform concurrent operations
            await withTaskGroup(of: Void.self) { group in
                for i in 0 ..< iterations {
                    group.addTask {
                        _ = self.provider.getAuthenticationURL()

                        let callbackData: [String: Any] = [
                            "cookies": [
                                HTTPCookie(properties: [
                                    .name: CursorAPIConstants.Headers.sessionCookieName,
                                    .value: "concurrent-token-\(i)",
                                    .domain: ".cursor.com",
                                    .path: "/",
                                ])!,
                            ],
                        ]
                        _ = self.provider.extractAuthToken(from: callbackData)
                    }
                }
            }

            // Then - Operations should complete without issues
            #expect(Bool(true))
        }
    }

    // MARK: - Data Fetching Tests
    
    @Suite("Data Fetching", .tags(.integration, .network))
    struct DataFetching {
        let provider: CursorProvider
        let mockSession: MockURLSession
        let mockSettings: MockSettingsManager

        init() async {
            self.mockSession = MockURLSession()
            self.mockSettings = await MockSettingsManager()
            self.provider = CursorProvider(
                settingsManager: mockSettings,
                urlSession: mockSession)
        }

        // MARK: - Test Data Constants

        private static let mockPricingDescription = """
        1. Chat, Cmd-K, Terminal Cmd-K, and Context Chat with claude-3-opus: \
        10 requests per day included in Pro/Business, 10 cents per request after that.
        2. Chat, Cmd-K, Terminal Cmd-K, and Context Chat with o1: 40 cents per request.
        3. Chat, Cmd-K, Terminal Cmd-K, and Context Chat with o1-mini: \
        10 requests per day included in Pro/Business, 10 cents per request after that.
        4. Chat, Cmd-K, Terminal Cmd-K, and Context Chat with o3: 30 cents per request.
        5. Chat, Cmd-K, Terminal Cmd-K, and Context Chat with gpt-4.5-preview: 200 cents per request.
        6. Chat, Cmd-K, Terminal Cmd-K, and Context Chat with our MAX versions of \
        claude-3-7-sonnet and gemini-2-5-pro-exp-max: 5 cents per request, plus 5 cents per tool call.
        7. Long context chat with claude-3-haiku-200k: \
        10 requests per day included in Pro/Business, 10 cents per request after that.
        8. Long context chat with claude-3-sonnet-200k: \
        10 requests per day included in Pro/Business, 20 cents per request after that.
        9. Long context chat with claude-3-5-sonnet-200k: \
        10 requests per day included in Pro/Business, 20 cents per request after that.
        10. Long context chat with gemini-1.5-flash-500k: \
        10 requests per day included in Pro/Business, 10 cents per request after that.
        11. Long context chat with gpt-4o-128k: \
        10 requests per day included in Pro/Business, 10 cents per request after that.
        12. Bug finder: priced upfront based on the size of the diff. \
        Currently experimental; expect the price to go down in the future.
        13. Fast premium models: \
        As many fast premium requests as are included in your plan, 4 cents per request after that.
        14. Fast premium models (Haiku): \
        As many fast premium requests as are included in your plan, 1 cent per request after that.
        """


        // MARK: Monthly Invoice Tests
        
        @Suite("Monthly Invoice")
        struct MonthlyInvoice {
            let provider: CursorProvider
            let mockSession: MockURLSession
            let mockSettings: MockSettingsManager

            init() async {
                self.mockSession = MockURLSession()
                self.mockSettings = await MockSettingsManager()
                self.provider = CursorProvider(
                    settingsManager: mockSettings,
                    urlSession: mockSession)
            }

            @Test("fetch monthly invoice with provided team id")
            func fetchMonthlyInvoice_WithProvidedTeamId() async throws {
                // Given
                let mockInvoiceData = Data("""
                    {
                        "items": [
                            {
                                "description": "112 discounted claude-4-sonnet-thinking requests",
                                "cents": 336
                            },
                            {
                                "description": "97 extra fast premium requests beyond 500/month * 4 cents per such request",
                                "cents": 388
                            },
                            {
                                "description": "59 token-based usage calls to claude-4-sonnet-thinking, totalling: $4.65",
                                "cents": 465
                            },
                            {
                                "description": "12 token-based usage calls to o3, totalling: $2.10",
                                "cents": 210
                            }
                        ],
                        "pricingDescription": {
                            "description": "\(DataFetching.mockPricingDescription)",
                            "id": "392eabec215b2d0381fb87ead3be48765ced78e4acfbac7b12e862e8c426875f"
                        }
                    }
                """.utf8)

                let mockResponse = HTTPURLResponse(
                    url: CursorAPIConstants.URLs.monthlyInvoice,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: nil)!

                mockSession.nextData = mockInvoiceData
                mockSession.nextResponse = mockResponse

                // When
                let invoice = try await provider.fetchMonthlyInvoice(
                    authToken: "test-token",
                    month: 11,
                    year: 2023,
                    teamId: 789)

                // Then
                #expect(invoice.items.count == 4)
                #expect(invoice.items[0].description == "112 discounted claude-4-sonnet-thinking requests")
                #expect(invoice.items[1].description ==
                    "97 extra fast premium requests beyond 500/month * 4 cents per such request")
                #expect(invoice.month == 11)
                #expect(invoice.provider == .cursor)

                // Verify request body
                let requestBody = mockSession.lastRequest?.httpBody
                #expect(requestBody != nil)
                let bodyJSON = try JSONSerialization.jsonObject(with: requestBody!) as? [String: Any]
                #expect(bodyJSON?["month"] as? Int == 11)
                #expect(bodyJSON?["teamId"] as? Int == 789)
            }

            @Test("fetch monthly invoice with stored team id")
            func fetchMonthlyInvoice_WithStoredTeamId() async throws {
                // Given
                await mockSettings.updateSession(for: .cursor, session: ProviderSession(
                    provider: .cursor,
                    teamId: 999,
                    teamName: "Test Team",
                    userEmail: "test@example.com",
                    isActive: true))

                let mockInvoiceData = Data("""
                    {
                        "items": [
                            {
                                "description": "112 discounted claude-4-sonnet-thinking requests",
                                "cents": 336
                            },
                            {
                                "description": "97 extra fast premium requests beyond 500/month * 4 cents per such request",
                                "cents": 388
                            },
                            {
                                "description": "59 token-based usage calls to claude-4-sonnet-thinking, totalling: $4.65",
                                "cents": 465
                            },
                            {
                                "description": "12 token-based usage calls to o3, totalling: $2.10",
                                "cents": 210
                            }
                        ],
                        "pricingDescription": {
                            "description": "\(DataFetching.mockPricingDescription)",
                            "id": "392eabec215b2d0381fb87ead3be48765ced78e4acfbac7b12e862e8c426875f"
                        }
                    }
                """.utf8)

                let mockResponse = HTTPURLResponse(
                    url: CursorAPIConstants.URLs.monthlyInvoice,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: nil)!
                mockSession.nextData = mockInvoiceData
                mockSession.nextResponse = mockResponse

                // When
                let invoice = try await provider.fetchMonthlyInvoice(
                    authToken: "test-token",
                    month: 5,
                    year: 2023,
                    teamId: nil)

                // Then
                #expect(invoice.items.count == 4)
                #expect(invoice.pricingDescription == nil)

                // Verify request body
                let requestBody = mockSession.lastRequest?.httpBody
                #expect(requestBody != nil)
                let bodyJSON = try JSONSerialization.jsonObject(with: requestBody!) as? [String: Any]
                #expect(bodyJSON?["month"] as? Int == 5)
                #expect(bodyJSON?["teamId"] as? Int == 999)
            }

            @Test("fetch monthly invoice no team id available")
            func fetchMonthlyInvoice_NoTeamIdAvailable() async throws {
                // Given - no stored team ID and none provided
                let mockInvoiceData = Data("""
                    {
                        "items": [
                            {
                                "description": "112 discounted claude-4-sonnet-thinking requests",
                                "cents": 336
                            },
                            {
                                "description": "97 extra fast premium requests beyond 500/month * 4 cents per such request",
                                "cents": 388
                            },
                            {
                                "description": "59 token-based usage calls to claude-4-sonnet-thinking, totalling: $4.65",
                                "cents": 465
                            },
                            {
                                "description": "12 token-based usage calls to o3, totalling: $2.10",
                                "cents": 210
                            }
                        ],
                        "pricingDescription": {
                            "description": "\(DataFetching.mockPricingDescription)",
                            "id": "392eabec215b2d0381fb87ead3be48765ced78e4acfbac7b12e862e8c426875f"
                        }
                    }
                """.utf8)

                let mockResponse = HTTPURLResponse(
                    url: CursorAPIConstants.URLs.monthlyInvoice,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: nil)!

                mockSession.nextData = mockInvoiceData
                mockSession.nextResponse = mockResponse

                // When
                let invoice = try await provider.fetchMonthlyInvoice(
                    authToken: "test-token",
                    month: 5,
                    year: 2023,
                    teamId: nil)

                // Then
                #expect(invoice.items.count == 4)
                #expect(invoice.pricingDescription == nil)

                // Verify request body
                let requestBody = mockSession.lastRequest?.httpBody
                #expect(requestBody != nil)
                let bodyJSON = try JSONSerialization.jsonObject(with: requestBody!) as? [String: Any]
                #expect(bodyJSON?["month"] as? Int == 5)
                #expect(bodyJSON?["teamId"] == nil)
            }
        }

        // MARK: Usage Data Tests
        
        @Suite("Usage Data")
        struct UsageData {
            let provider: CursorProvider
            let mockSession: MockURLSession

            init() async {
                self.mockSession = MockURLSession()
                let mockSettings = await MockSettingsManager()
                self.provider = CursorProvider(
                    settingsManager: mockSettings,
                    urlSession: mockSession)
            }

            @Test("fetch usage data success")
            func fetchUsageData_Success() async throws {
                // Given
                let mockUsageData = Data("""
                    {
                        "gpt-4": {
                            "numRequests": 518,
                            "numRequestsTotal": 731,
                            "numTokens": 13637151,
                            "maxRequestUsage": 500,
                            "maxTokenUsage": null
                        },
                        "gpt-3.5-turbo": {
                            "numRequests": 0,
                            "numRequestsTotal": 0,
                            "numTokens": 0,
                            "maxRequestUsage": null,
                            "maxTokenUsage": null
                        },
                        "gpt-4-32k": {
                            "numRequests": 0,
                            "numRequestsTotal": 0,
                            "numTokens": 0,
                            "maxRequestUsage": 50,
                            "maxTokenUsage": null
                        },
                        "startOfMonth": "2025-05-28T15:57:12.000Z"
                    }
                """.utf8)

                let mockResponse = HTTPURLResponse(
                    url: URL(string: "\(CursorAPIConstants.URLs.usage)?user=user123")!,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: nil)!

                mockSession.nextData = mockUsageData
                mockSession.nextResponse = mockResponse

                // When
                let usageData = try await provider.fetchUsageData(authToken: "user123::jwt-token")

                // Then
                #expect(usageData.currentRequests == 518)
                #expect(usageData.totalRequests == 731)
                #expect(usageData.provider == .cursor)

                // Verify URL query parameters
                let urlComponents = URLComponents(
                    url: mockSession.lastRequest!.url!,
                    resolvingAgainstBaseURL: false)
                #expect(urlComponents?.queryItems?.first(where: { $0.name == "user" })?.value == "user123")

                // Verify date parsing
                let formatter = ISO8601DateFormatter()
                formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                let expectedDate = formatter.date(from: "2025-05-28T15:57:12.000Z")
                #expect(usageData.startOfMonth == expectedDate)
            }

            @Test("fetch usage data invalid date format")
            func fetchUsageData_InvalidDateFormat() async throws {
                // Given
                let mockUsageData = Data("""
                    {
                        "gpt-4": {
                            "numRequests": 518,
                            "numRequestsTotal": 731,
                            "numTokens": 13637151,
                            "maxRequestUsage": 500,
                            "maxTokenUsage": null
                        },
                        "gpt-3.5-turbo": {
                            "numRequests": 0,
                            "numRequestsTotal": 0,
                            "numTokens": 0,
                            "maxRequestUsage": null,
                            "maxTokenUsage": null
                        },
                        "gpt-4-32k": {
                            "numRequests": 0,
                            "numRequestsTotal": 0,
                            "numTokens": 0,
                            "maxRequestUsage": 50,
                            "maxTokenUsage": null
                        },
                        "startOfMonth": "invalid-date"
                    }
                """.utf8)

                let mockResponse = HTTPURLResponse(
                    url: URL(string: "\(CursorAPIConstants.URLs.usage)?user=user123")!,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: nil)!

                mockSession.nextData = mockUsageData
                mockSession.nextResponse = mockResponse

                // When
                let usageData = try await provider.fetchUsageData(authToken: "user456::jwt-token")

                // Then - should use current date as fallback
                let timeDifference = abs(usageData.startOfMonth.timeIntervalSinceNow)
                #expect(timeDifference < 60)

                // Verify URL query parameters
                let urlComponents = URLComponents(
                    url: mockSession.lastRequest!.url!,
                    resolvingAgainstBaseURL: false)
                #expect(urlComponents?.queryItems?.first(where: { $0.name == "user" })?.value == "user456")
            }
        }
    }

    // MARK: - Individual User Tests
    
    @Suite("Individual User Scenarios", .tags(.edgeCase))
    struct IndividualUser {
        let provider: CursorProvider
        let mockSession: MockURLSession
        let mockSettings: MockSettingsManager

        init() async {
            self.mockSession = MockURLSession()
            self.mockSettings = await MockSettingsManager()
            self.provider = CursorProvider(
                settingsManager: mockSettings,
                urlSession: mockSession)
        }

        @Test("fetch user info individual user no team id")
        func fetchUserInfo_IndividualUser_NoTeamId() async throws {
            // Given - API returns user without teamId
            let mockUserData = Data("""
            {
                "email": "individual@example.com"
            }
            """.utf8)

            let mockResponse = HTTPURLResponse(
                url: CursorAPIConstants.URLs.userInfo,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil)!

            mockSession.nextData = mockUserData
            mockSession.nextResponse = mockResponse

            // When
            let userInfo = try await provider.fetchUserInfo(authToken: "individual-token")

            // Then
            #expect(userInfo.email == "individual@example.com")
            #expect(userInfo.provider == .cursor)
        }

        @Test("fetch team info individual user empty teams")
        func fetchTeamInfo_IndividualUser_EmptyTeams() async throws {
            // Given - API returns empty teams array for individual users
            let mockEmptyTeamsData = Data("""
            {
                "teams": []
            }
            """.utf8)

            let mockResponse = HTTPURLResponse(
                url: CursorAPIConstants.URLs.teams,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil)!

            mockSession.nextData = mockEmptyTeamsData
            mockSession.nextResponse = mockResponse

            // When
            let teamInfo = try await provider.fetchTeamInfo(authToken: "individual-token")

            // Then - Should return fallback team info for individual users
            #expect(teamInfo.id == CursorAPIConstants.ResponseConstants.individualUserTeamId)
            #expect(teamInfo.provider == .cursor)
        }

        @Test("fetch monthly invoice individual user no team id")
        func fetchMonthlyInvoice_IndividualUser_NoTeamId() async throws {
            // Given - No stored team ID and none provided (individual user)
            let mockInvoiceData = Data("""
            {
                "items": [
                    {
                        "cents": 2000,
                        "description": "Individual Pro Usage"
                    }
                ],
                "pricing_description": {
                    "description": "Individual Pro Plan",
                    "id": "individual-pro"
                }
            }
            """.utf8)

            let mockResponse = HTTPURLResponse(
                url: CursorAPIConstants.URLs.monthlyInvoice,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil)!

            mockSession.nextData = mockInvoiceData
            mockSession.nextResponse = mockResponse

            // When
            let invoice = try await provider.fetchMonthlyInvoice(
                authToken: "individual-token",
                month: 12,
                year: 2023,
                teamId: nil)

            // Then
            #expect(invoice.items.count == 1)
            #expect(invoice.items[0].description == "Individual Pro Usage")
            #expect(invoice.pricingDescription?.description == "Individual Pro Plan")
            let requestBody = try #require(mockSession.lastRequest?.httpBody)
            let bodyJSON = try JSONSerialization.jsonObject(with: requestBody) as? [String: Any]
            #expect(bodyJSON?["month"] as? Int == 12)
            #expect(bodyJSON?["teamId"] == nil)
        }

        @Test("fetch monthly invoice individual user empty invoice")
        func fetchMonthlyInvoice_IndividualUser_EmptyInvoice() async throws {
            // Given - Individual user with no spending
            let mockEmptyInvoiceData = Data("""
            {
                "items": [],
                "pricing_description": null
            }
            """.utf8)

            let mockResponse = HTTPURLResponse(
                url: CursorAPIConstants.URLs.monthlyInvoice,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil)!

            mockSession.nextData = mockEmptyInvoiceData
            mockSession.nextResponse = mockResponse

            // When
            let invoice = try await provider.fetchMonthlyInvoice(
                authToken: "individual-token",
                month: 1,
                year: 2024,
                teamId: nil)

            // Then
            #expect(invoice.items.isEmpty)
            #expect(invoice.pricingDescription == nil)
            let requestBody = try #require(mockSession.lastRequest?.httpBody)
            let bodyJSON = try JSONSerialization.jsonObject(with: requestBody) as? [String: Any]
            #expect(bodyJSON?["teamId"] == nil)
        }

        @Test("api request body without team id")
        func aPIRequestBody_WithoutTeamId() async throws {
            // Given
            let mockInvoiceData = Data("""
            {"items": [], "pricing_description": null}
            """.utf8)

            let mockResponse = HTTPURLResponse(
                url: CursorAPIConstants.URLs.monthlyInvoice,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil)!

            mockSession.nextData = mockInvoiceData
            mockSession.nextResponse = mockResponse

            // When - No teamId provided and no stored session
            _ = try await provider.fetchMonthlyInvoice(
                authToken: "token",
                month: 8,
                year: 2024,
                teamId: nil)

            // Then - Verify request body excludes teamId
            let requestBody = try #require(mockSession.lastRequest?.httpBody)
            let bodyJSON = try JSONSerialization.jsonObject(with: requestBody) as? [String: Any]
            #expect(bodyJSON?.count == 3)
            #expect(bodyJSON?["year"] as? Int == 2024)
            #expect(bodyJSON?["month"] as? Int == 8)
            #expect(bodyJSON?.keys.contains("teamId") == false)
        }

        @Test("api request body team id zero")
        func aPIRequestBody_TeamIdZero() async throws {
            // Given - Test edge case where teamId is 0
            let mockInvoiceData = Data("""
            {"items": [], "pricing_description": null}
            """.utf8)

            let mockResponse = HTTPURLResponse(
                url: CursorAPIConstants.URLs.monthlyInvoice,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil)!

            mockSession.nextData = mockInvoiceData
            mockSession.nextResponse = mockResponse

            // When - teamId is 0 (edge case)
            _ = try await provider.fetchMonthlyInvoice(
                authToken: "token",
                month: 9,
                year: 2024,
                teamId: 0)

            // Then - Verify request body excludes teamId since 0 is now filtered as invalid
            let requestBody = try #require(mockSession.lastRequest?.httpBody)
            let bodyJSON = try JSONSerialization.jsonObject(with: requestBody) as? [String: Any]
            #expect(bodyJSON?["teamId"] == nil)
        }
    }

    // MARK: - State Transition Tests
    
    @Suite("State Transitions", .tags(.integration))
    struct StateTransitions {
        let provider: CursorProvider
        let mockSession: MockURLSession
        let mockSettings: MockSettingsManager

        init() async {
            self.mockSession = MockURLSession()
            self.mockSettings = await MockSettingsManager()
            self.provider = CursorProvider(
                settingsManager: mockSettings,
                urlSession: mockSession)
        }

        @Test("user transition from individual to team")
        func userTransition_FromIndividualToTeam() async throws {
            // Given - Start as individual user (no session)
            let session = await mockSettings.getSession(for: .cursor)
            #expect(session == nil)

            let individualInvoiceData = Data("""
            {
                "items": [{"cents": 1000, "description": "Individual Usage"}],
                "pricing_description": {"description": "Individual Plan", "id": "individual"}
            }
            """.utf8)

            mockSession.nextData = individualInvoiceData
            mockSession.nextResponse = HTTPURLResponse(
                url: CursorAPIConstants.URLs.monthlyInvoice,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil)!

            let individualInvoice = try await provider.fetchMonthlyInvoice(
                authToken: "token",
                month: 1,
                year: 2024,
                teamId: nil)

            #expect(individualInvoice.totalSpendingCents == 1000)
            let firstRequestBody = try #require(mockSession.lastRequest?.httpBody)
            let firstBodyJSON = try JSONSerialization.jsonObject(with: firstRequestBody) as? [String: Any]
            #expect(firstBodyJSON?["teamId"] == nil)

            // When - User joins a team, update session with teamId
            await mockSettings.updateSession(for: .cursor, session: ProviderSession(
                provider: .cursor,
                teamId: 4567,
                teamName: "Development Team",
                userEmail: "dev@team.com",
                isActive: true))

            // Fetch invoice as team member
            let teamInvoiceData = Data("""
            {
                "items": [{"cents": 5000, "description": "Team Usage"}],
                "pricing_description": {"description": "Team Plan", "id": "team-pro"}
            }
            """.utf8)

            mockSession.nextData = teamInvoiceData
            mockSession.nextResponse = HTTPURLResponse(
                url: CursorAPIConstants.URLs.monthlyInvoice,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil)!

            let teamInvoice = try await provider.fetchMonthlyInvoice(
                authToken: "token",
                month: 2,
                year: 2024,
                teamId: nil) // Not providing teamId, should use stored value

            // Then
            #expect(teamInvoice.totalSpendingCents == 5000)

            // Verify stored teamId was used
            let secondRequestBody = try #require(mockSession.lastRequest?.httpBody)
            let secondBodyJSON = try JSONSerialization.jsonObject(with: secondRequestBody) as? [String: Any]
            #expect(secondBodyJSON?["teamId"] as? Int == 4567)
        }

        @Test("user transition team member leaves team")
        func userTransition_TeamMemberLeavesTeam() async throws {
            // Given - User starts in a team
            await mockSettings.updateSession(for: .cursor, session: ProviderSession(
                provider: .cursor,
                teamId: 3000,
                teamName: "Current Team",
                userEmail: "member@team.com",
                isActive: true))

            // When - User leaves team (session cleared)
            await mockSettings.clearUserSessionData(for: .cursor)

            // Fetch invoice as individual
            let mockInvoiceData = Data("""
            {"items": [], "pricing_description": null}
            """.utf8)

            mockSession.nextData = mockInvoiceData
            mockSession.nextResponse = HTTPURLResponse(
                url: CursorAPIConstants.URLs.monthlyInvoice,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil)!

            _ = try await provider.fetchMonthlyInvoice(
                authToken: "token",
                month: 3,
                year: 2024,
                teamId: nil)

            // Then - Verify no teamId in request
            let requestBody = try #require(mockSession.lastRequest?.httpBody)
            let bodyJSON = try JSONSerialization.jsonObject(with: requestBody) as? [String: Any]
            #expect(bodyJSON?["teamId"] == nil)
        }

        @Test("explicit team id overrides stored value")
        func explicitTeamIdOverridesStoredValue() async throws {
            // Given - User has a stored team
            await mockSettings.updateSession(for: .cursor, session: ProviderSession(
                provider: .cursor,
                teamId: 1111,
                teamName: "Stored Team",
                userEmail: "user@example.com",
                isActive: true))

            let mockInvoiceData = Data("""
            {"items": [{"cents": 2500, "description": "Override Team Usage"}], "pricing_description": null}
            """.utf8)

            mockSession.nextData = mockInvoiceData
            mockSession.nextResponse = HTTPURLResponse(
                url: CursorAPIConstants.URLs.monthlyInvoice,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil)!

            // When - Explicitly provide different teamId
            _ = try await provider.fetchMonthlyInvoice(
                authToken: "token",
                month: 4,
                year: 2024,
                teamId: 9999) // Override with different team

            // Then - Verify override teamId was used
            let requestBody = try #require(mockSession.lastRequest?.httpBody)
            let bodyJSON = try JSONSerialization.jsonObject(with: requestBody) as? [String: Any]
            #expect(bodyJSON?["teamId"] as? Int == 9999)
        }

        @Test("multiple requests with changing session state")
        func multipleRequestsWithChangingSessionState() async throws {
            // Test 1: No session (individual)
            var mockData = Data("""
            {"items": [{"cents": 500, "description": "Individual"}], "pricing_description": null}
            """.utf8)
            mockSession.nextData = mockData
            mockSession.nextResponse = HTTPURLResponse(
                url: CursorAPIConstants.URLs.monthlyInvoice,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil)!

            _ = try await provider.fetchMonthlyInvoice(authToken: "token", month: 1, year: 2024, teamId: nil)

            var requestBody = try #require(mockSession.lastRequest?.httpBody)
            var bodyJSON = try JSONSerialization.jsonObject(with: requestBody) as? [String: Any]
            #expect(bodyJSON?["teamId"] == nil)
            await mockSettings.updateSession(for: .cursor, session: ProviderSession(
                provider: .cursor,
                teamId: 4444,
                teamName: "New Team",
                userEmail: "user@team.com",
                isActive: true))

            mockData = Data("""
            {"items": [{"cents": 1500, "description": "Team"}], "pricing_description": null}
            """.utf8)
            mockSession.nextData = mockData
            mockSession.nextResponse = HTTPURLResponse(
                url: CursorAPIConstants.URLs.monthlyInvoice,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil)!

            _ = try await provider.fetchMonthlyInvoice(authToken: "token", month: 2, year: 2024, teamId: nil)

            requestBody = try #require(mockSession.lastRequest?.httpBody)
            bodyJSON = try JSONSerialization.jsonObject(with: requestBody) as? [String: Any]
            #expect(bodyJSON?["teamId"] as? Int == 4444)
            await mockSettings.clearUserSessionData(for: .cursor)

            mockData = Data("""
            {"items": [{"cents": 750, "description": "Individual Again"}], "pricing_description": null}
            """.utf8)
            mockSession.nextData = mockData
            mockSession.nextResponse = HTTPURLResponse(
                url: CursorAPIConstants.URLs.monthlyInvoice,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil)!

            _ = try await provider.fetchMonthlyInvoice(authToken: "token", month: 3, year: 2024, teamId: nil)

            requestBody = try #require(mockSession.lastRequest?.httpBody)
            bodyJSON = try JSONSerialization.jsonObject(with: requestBody) as? [String: Any]
            #expect(bodyJSON?["teamId"] == nil)
        }
    }

    // MARK: - Validation and Error Handling Tests
    
    @Suite("Validation and Error Handling", .tags(.unit))
    struct ValidationErrorHandling {
        let provider: CursorProvider
        let mockSession: MockURLSession
        let mockSettings: MockSettingsManager

        init() async {
            self.mockSession = MockURLSession()
            self.mockSettings = await MockSettingsManager()
            self.provider = CursorProvider(
                settingsManager: mockSettings,
                urlSession: mockSession)
        }

        // MARK: Token Validation
        
        @Suite("Token Validation")
        struct TokenValidation {
            let provider: CursorProvider
            let mockSession: MockURLSession

            init() async {
                self.mockSession = MockURLSession()
                let mockSettings = await MockSettingsManager()
                self.provider = CursorProvider(
                    settingsManager: mockSettings,
                    urlSession: mockSession)
            }

            @Test("validate token valid token")
            func validateToken_ValidToken() async {
                // Given
                let mockUserData = Data("""
                {
                    "email": "test@example.com",
                    "teamId": 456
                }
                """.utf8)

                let mockResponse = HTTPURLResponse(
                    url: CursorAPIConstants.URLs.userInfo,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: nil)!

                mockSession.nextData = mockUserData
                mockSession.nextResponse = mockResponse

                // When
                let isValid = await provider.validateToken(authToken: "valid-token")

                // Then
                #expect(isValid == true)
            }

            @Test("validate token invalid token")
            func validateToken_InvalidToken() async {
                // Given
                let mockResponse = HTTPURLResponse(
                    url: URL(string: "https://www.cursor.com/api/auth/me")!,
                    statusCode: 401,
                    httpVersion: nil,
                    headerFields: nil)!

                mockSession.nextData = Data()
                mockSession.nextResponse = mockResponse

                // When
                let isValid = await provider.validateToken(authToken: "invalid-token")

                // Then
                #expect(isValid == false)
            }

            @Test("validate token network error")
            func validateToken_NetworkError() async {
                // Given
                mockSession.nextError = NSError(domain: "NetworkError", code: -1009, userInfo: nil)

                // When
                let isValid = await provider.validateToken(authToken: "test-token")

                // Then
                #expect(isValid == false)
            }
        }

        // MARK: Network Errors
        
        @Suite("Network Errors")
        struct NetworkErrors {
            let provider: CursorProvider
            let mockSession: MockURLSession

            init() async {
                self.mockSession = MockURLSession()
                let mockSettings = await MockSettingsManager()
                self.provider = CursorProvider(
                    settingsManager: mockSettings,
                    urlSession: mockSession)
            }

            @Test("network error rate limit exceeded")
            func networkError_RateLimitExceeded() async {
                // Given
                let mockResponse = HTTPURLResponse(
                    url: URL(string: "https://www.cursor.com/api/auth/me")!,
                    statusCode: 429,
                    httpVersion: nil,
                    headerFields: nil)!

                mockSession.nextData = Data()
                mockSession.nextResponse = mockResponse

                // When/Then
                do {
                    _ = try await provider.fetchUserInfo(authToken: "test-token")
                    Issue.record("Expected condition not met")
                } catch let error as ProviderError {
                    #expect(error == .rateLimitExceeded)
                } catch {
                    Issue.record("Expected condition not met")
                }
            }

            @Test("network error service unavailable")
            func networkError_ServiceUnavailable() async {
                // Given
                let mockResponse = HTTPURLResponse(
                    url: URL(string: "https://www.cursor.com/api/auth/me")!,
                    statusCode: 503,
                    httpVersion: nil,
                    headerFields: nil)!

                mockSession.nextData = Data()
                mockSession.nextResponse = mockResponse

                // When/Then
                do {
                    _ = try await provider.fetchUserInfo(authToken: "test-token")
                    Issue.record("Expected condition not met")
                } catch let error as ProviderError {
                    #expect(error == .serviceUnavailable)
                } catch {
                    Issue.record("Expected condition not met")
                }
            }

            @Test("network error decoding error")
            func networkError_DecodingError() async {
                // Given - invalid JSON
                let invalidJSON = Data("{ invalid json }".utf8)

                let mockResponse = HTTPURLResponse(
                    url: CursorAPIConstants.URLs.userInfo,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: nil)!

                mockSession.nextData = invalidJSON
                mockSession.nextResponse = mockResponse

                // When/Then
                do {
                    _ = try await provider.fetchUserInfo(authToken: "test-token")
                    Issue.record("Expected condition not met")
                } catch let error as ProviderError {
                    if case .decodingError = error {
                        // Expected
                    } else {
                        Issue.record("Expected condition not met")
                    }
                } catch {
                    Issue.record("Expected condition not met")
                }
            }

            @Test("network error specific error response")
            func networkError_SpecificErrorResponse() async {
                // Given
                let errorResponse = Data("""
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
                """.utf8)

                let mockResponse = HTTPURLResponse(
                    url: CursorAPIConstants.URLs.teams,
                    statusCode: 400,
                    httpVersion: nil,
                    headerFields: nil)!

                mockSession.nextData = errorResponse
                mockSession.nextResponse = mockResponse

                // When/Then
                do {
                    _ = try await provider.fetchTeamInfo(authToken: "test-token")
                    Issue.record("Expected condition not met")
                } catch let error as ProviderError {
                    #expect(error == .noTeamFound)
                } catch {
                    Issue.record("Expected condition not met")
                }
            }

            @Test("network error 500 with team not found")
            func networkError_500WithTeamNotFound() async {
                // Given
                let errorMessage = Data("Team not found in database".utf8)

                let mockResponse = HTTPURLResponse(
                    url: CursorAPIConstants.URLs.teams,
                    statusCode: 500,
                    httpVersion: nil,
                    headerFields: nil)!

                mockSession.nextData = errorMessage
                mockSession.nextResponse = mockResponse

                // When/Then
                do {
                    _ = try await provider.fetchTeamInfo(authToken: "test-token")
                    Issue.record("Expected condition not met")
                } catch let error as ProviderError {
                    #expect(error == .noTeamFound)
                } catch {
                    Issue.record("Expected condition not met")
                }
            }

            @Test("network error generic network failure")
            func networkError_GenericNetworkFailure() async {
                // Given
                mockSession.nextError = NSError(
                    domain: NSURLErrorDomain,
                    code: NSURLErrorTimedOut,
                    userInfo: [NSLocalizedDescriptionKey: "Request timed out"])

                // When/Then
                do {
                    _ = try await provider.fetchUserInfo(authToken: "test-token")
                    Issue.record("Expected condition not met")
                } catch let error as ProviderError {
                    if case let .networkError(message, _) = error {
                        #expect(message.contains("timed out"))
                    } else {
                        Issue.record("Expected condition not met")
                    }
                } catch {
                    Issue.record("Expected condition not met")
                }
            }

            @Test("individual user handles team specific errors")
            func individualUser_HandlesTeamSpecificErrors() async throws {
                // Given - Individual user (no team) getting team-specific error
                let errorResponse = Data("""
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
                """.utf8)

                mockSession.nextData = errorResponse
                mockSession.nextResponse = HTTPURLResponse(
                    url: URL(string: "https://www.cursor.com/api/dashboard/get-monthly-invoice")!,
                    statusCode: 400,
                    httpVersion: nil,
                    headerFields: nil)!

                // When/Then
                do {
                    _ = try await provider.fetchMonthlyInvoice(
                        authToken: "token",
                        month: 6,
                        year: 2024,
                        teamId: nil)
                    Issue.record("Expected condition not met")
                } catch let error as ProviderError {
                    #expect(error == .noTeamFound)
                }
            }
        }

        // MARK: Request Configuration
        
        @Test("request configuration")
        func requestConfiguration() async throws {
            // Given
            let mockUserData = Data("""
            {
                "email": "test@example.com"
            }
            """.utf8)

            let mockResponse = HTTPURLResponse(
                url: CursorAPIConstants.URLs.userInfo,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil)!

            mockSession.nextData = mockUserData
            mockSession.nextResponse = mockResponse

            // When
            _ = try await provider.fetchUserInfo(authToken: "test-auth-token")

            // Then
            let request = try #require(mockSession.lastRequest)

            // Verify headers
            #expect(request.value(forHTTPHeaderField: "Cookie") != nil)
            #expect(request.value(forHTTPHeaderField: "Accept") != nil)

            // Verify timeout
            #expect(request.timeoutInterval == 30)
        }
    }
}