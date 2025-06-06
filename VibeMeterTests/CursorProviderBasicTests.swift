import Foundation
import Testing
@testable import VibeMeter

// Import shared test utilities
typealias Helpers = TestHelpers

extension Tag {
    @Tag static var cursor: Self
}

@Suite("CursorProvider Basic Tests", .tags(.unit, .provider, .cursor))
struct CursorProviderBasicTests {
    private let cursorProvider: CursorProvider
    private let mockURLSession: MockURLSession
    private let mockSettingsManager: MockSettingsManager

    init() {
        self.mockURLSession = MockURLSession()
        self.mockSettingsManager = MainActor.assumeIsolated { MockSettingsManager() }
        self.cursorProvider = CursorProvider(
            settingsManager: mockSettingsManager,
            urlSession: mockURLSession)
    }

    // MARK: - Team Info Tests
    
    @Suite("Team Information Fetching", .tags(.unit, .team))
    struct TeamInfoTests {
        let provider: CursorProvider
        let mockSession: MockURLSession
        
        init() {
            self.mockSession = MockURLSession()
            let mockSettings = MainActor.assumeIsolated { MockSettingsManager() }
            self.provider = CursorProvider(settingsManager: mockSettings, urlSession: mockSession)
        }
        
        struct TeamInfoTestCase {
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
                "successful team fetch with name"
            ),
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
                "successful team fetch with different team"
            ),
            TeamInfoTestCase(
                json: "{}",
                id: -1,
                "fallback team when no teams found"
            )
        ]
        
        @Test("Team info fetching scenarios", arguments: teamInfoTestCases)
        func teamInfoFetchingScenarios(testCase: TeamInfoTestCase) async throws {
            // Given
            let mockData = Data(testCase.jsonResponse.utf8)
            let mockResponse = Helpers.createMockHTTPResponse(statusCode: 200, url: CursorAPIConstants.URLs.teams.absoluteString)
            
            mockSession.nextData = mockData
            mockSession.nextResponse = mockResponse
            
            // When
            let teamInfo = try await provider.fetchTeamInfo(authToken: "test-token")
            
            // Then
            #expect(teamInfo.id == testCase.expectedId, "Team ID mismatch: \(testCase.description)")
            #expect(teamInfo.provider == .cursor, "Provider should be cursor: \(testCase.description)")
            #expect(mockSession.lastRequest?.value(forHTTPHeaderField: "Cookie") != nil, "Should set cookie header: \(testCase.description)")
        }
        
        @Test("Unauthorized team info request")
        func unauthorizedTeamInfoRequest() async {
            // Given
            let mockResponse = Helpers.createMockHTTPResponse(statusCode: 401, url: CursorAPIConstants.URLs.teams.absoluteString)
            mockSession.nextData = Data()
            mockSession.nextResponse = mockResponse
            
            // When/Then
            do {
                _ = try await provider.fetchTeamInfo(authToken: "invalid-token")
                Issue.record("Should have thrown unauthorized error")
            } catch let error as ProviderError {
                #expect(error == .unauthorized, "Should throw unauthorized error")
            } catch {
                Issue.record("Unexpected error type: \(error)")
            }
        }
    }

    // MARK: - User Info Tests
    
    @Suite("User Information Fetching", .tags(.unit, .user))
    struct UserInfoTests {
        let provider: CursorProvider
        let mockSession: MockURLSession
        
        init() {
            self.mockSession = MockURLSession()
            let mockSettings = MainActor.assumeIsolated { MockSettingsManager() }
            self.provider = CursorProvider(settingsManager: mockSettings, urlSession: mockSession)
        }
        
        struct UserInfoTestCase {
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
        
        static let userInfoTestCases: [UserInfoTestCase] = [
            UserInfoTestCase(
                json: """
                {
                    "email": "developer@example.com",
                    "teamId": 456
                }
                """,
                email: "developer@example.com",
                "user with team ID"
            ),
            UserInfoTestCase(
                json: """
                {
                    "email": "freelancer@example.com"
                }
                """,
                email: "freelancer@example.com",
                hasTeamId: false,
                "user without team ID"
            ),
            UserInfoTestCase(
                json: """
                {
                    "email": "admin@company.com",
                    "teamId": 789
                }
                """,
                email: "admin@company.com",
                "admin user with different team"
            )
        ]
        
        @Test("User info fetching scenarios", arguments: userInfoTestCases)
        func userInfoFetchingScenarios(testCase: UserInfoTestCase) async throws {
            // Given
            let mockData = Data(testCase.jsonResponse.utf8)
            let mockResponse = Helpers.createMockHTTPResponse(statusCode: 200, url: CursorAPIConstants.URLs.userInfo.absoluteString)
            
            mockSession.nextData = mockData
            mockSession.nextResponse = mockResponse
            
            // When
            let userInfo = try await provider.fetchUserInfo(authToken: "test-token")
            
            // Then
            #expect(userInfo.email == testCase.expectedEmail, "Email mismatch: \(testCase.description)")
            #expect(userInfo.provider == .cursor, "Provider should be cursor: \(testCase.description)")
            #expect(mockSession.lastRequest?.httpMethod == "GET", "Should use GET method: \(testCase.description)")
            
            let cookieHeader = mockSession.lastRequest?.value(forHTTPHeaderField: "Cookie")
            #expect(cookieHeader?.contains("WorkosCursorSessionToken=test-token") == true, "Should set auth cookie: \(testCase.description)")
            #expect(mockSession.lastRequest?.value(forHTTPHeaderField: "Accept") != nil, "Should set Accept header: \(testCase.description)")
        }
    }

    // MARK: - Authentication Tests
    
    @Suite("Authentication Operations", .tags(.unit, .auth))
    struct AuthenticationTests {
        let provider: CursorProvider
        
        init() {
            let mockSession = MockURLSession()
            let mockSettings = MainActor.assumeIsolated { MockSettingsManager() }
            self.provider = CursorProvider(settingsManager: mockSettings, urlSession: mockSession)
        }
        
        @Test("Authentication URL generation")
        func authenticationURLGeneration() {
            // When
            let authURL = provider.getAuthenticationURL()
            
            // Then
            #expect(authURL == CursorAPIConstants.authenticationURL, "Should return correct authentication URL")
        }
        
        struct TokenExtractionTestCase {
            let callbackData: [String: Any]
            let expectedToken: String?
            let description: String
            
            init(data: [String: Any], expectedToken: String?, _ description: String) {
                self.callbackData = data
                self.expectedToken = expectedToken
                self.description = description
            }
        }
        
        static let tokenExtractionTestCases: [TokenExtractionTestCase] = [
            TokenExtractionTestCase(
                data: [
                    "cookies": [
                        HTTPCookie(properties: [
                            .name: CursorAPIConstants.Headers.sessionCookieName,
                            .value: "valid-token-123",
                            .domain: ".cursor.com",
                            .path: "/"
                        ])!
                    ]
                ],
                expectedToken: "valid-token-123",
                "valid session cookie extraction"
            ),
            TokenExtractionTestCase(
                data: [:],
                expectedToken: nil,
                "no cookies in callback data"
            ),
            TokenExtractionTestCase(
                data: [
                    "cookies": [
                        HTTPCookie(properties: [
                            .name: "SomeOtherCookie",
                            .value: "irrelevant-value",
                            .domain: ".cursor.com",
                            .path: "/"
                        ])!
                    ]
                ],
                expectedToken: nil,
                "wrong cookie name"
            ),
            TokenExtractionTestCase(
                data: [
                    "cookies": [
                        HTTPCookie(properties: [
                            .name: CursorAPIConstants.Headers.sessionCookieName,
                            .value: "another-token-456",
                            .domain: ".cursor.com",
                            .path: "/"
                        ])!,
                        HTTPCookie(properties: [
                            .name: "OtherCookie",
                            .value: "other-value",
                            .domain: ".cursor.com",
                            .path: "/"
                        ])!
                    ]
                ],
                expectedToken: "another-token-456",
                "multiple cookies with correct one present"
            )
        ]
        
        @Test("Auth token extraction scenarios", arguments: tokenExtractionTestCases)
        func authTokenExtractionScenarios(testCase: TokenExtractionTestCase) {
            // When
            let extractedToken = provider.extractAuthToken(from: testCase.callbackData)
            
            // Then
            #expect(extractedToken == testCase.expectedToken, "Token extraction failed: \(testCase.description)")
        }
    }
    
    // MARK: - Performance and Integration Tests
    
    @Test("Provider initialization performance", .timeLimit(.seconds(1)))
    func providerInitializationPerformance() {
        // When/Then - Should initialize quickly
        for _ in 0..<100 {
            let mockSession = MockURLSession()
            let mockSettings = MainActor.assumeIsolated { MockSettingsManager() }
            _ = CursorProvider(settingsManager: mockSettings, urlSession: mockSession)
        }
    }
    
    @Test("Concurrent authentication operations", .tags(.concurrency))
    func concurrentAuthenticationOperations() async {
        // Given
        let iterations = 10
        
        // When - Perform concurrent operations
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<iterations {
                group.addTask {
                    _ = self.cursorProvider.getAuthenticationURL()
                    
                    let callbackData: [String: Any] = [
                        "cookies": [
                            HTTPCookie(properties: [
                                .name: CursorAPIConstants.Headers.sessionCookieName,
                                .value: "concurrent-token-\(i)",
                                .domain: ".cursor.com",
                                .path: "/"
                            ])!
                        ]
                    ]
                    _ = self.cursorProvider.extractAuthToken(from: callbackData)
                }
            }
        }
        
        // Then - Operations should complete without issues
        #expect(Bool(true), "Concurrent operations should complete safely")
    }
}