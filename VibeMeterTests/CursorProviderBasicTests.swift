import Foundation
@testable import VibeMeter
import Testing

@Suite("CursorProvider Basic Tests")
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

    @Test("fetch team info success")

    func fetchTeamInfoSuccess() async throws {
        // Given
        let mockTeamsData = Data("""
        {
            "teams": [
                {
                    "id": 123,
                    "name": "Test Team"
                }
            ]
        }
        """.utf8)

        let mockResponse = HTTPURLResponse(
            url: CursorAPIConstants.URLs.teams,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil)!

        mockURLSession.nextData = mockTeamsData
        mockURLSession.nextResponse = mockResponse

        // When
        let teamInfo = try await cursorProvider.fetchTeamInfo(authToken: "test-token")

        // Then
        #expect(teamInfo.id == 123)
        #expect(teamInfo.provider == .cursor)
        #expect(
            mockURLSession.lastRequest?.value(forHTTPHeaderField: "Cookie" == true)
        #expect(mockURLSession.lastRequest?.value(forHTTPHeaderField: "Content-Type" == true)
    }

    @Test("fetch team info no teams found uses fallback")

    func fetchTeamInfoNoTeamsFoundUsesFallback() async {
        // Given
        let mockEmptyTeamsData = Data("""
        {}
        """.utf8)

        let mockResponse = HTTPURLResponse(
            url: CursorAPIConstants.URLs.teams,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil)!

        mockURLSession.nextData = mockEmptyTeamsData
        mockURLSession.nextResponse = mockResponse

        // When
        do {
            let teamInfo = try await cursorProvider.fetchTeamInfo(authToken: "test-token")

            // Then - Should return fallback team info instead of throwing
            #expect(teamInfo.id == -1, "Should use fallback team ID")
            #expect(teamInfo.provider == .cursor, "Should maintain correct provider")
        }
    }

    @Test("fetch team info unauthorized error")

    func fetchTeamInfoUnauthorizedError() async {
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
            Issue.record("Should have thrown unauthorized error")
        } catch let error as ProviderError {
            #expect(error == .unauthorized)
        }
    }

    // MARK: - User Info Tests

    @Test("fetch user info  success")

    func testFetchUserInfo_Success() async throws {
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

        mockURLSession.nextData = mockUserData
        mockURLSession.nextResponse = mockResponse

        // When
        let userInfo = try await cursorProvider.fetchUserInfo(authToken: "test-token")

        // Then
        #expect(userInfo.email == "test@example.com")
        #expect(userInfo.provider == .cursor)
        #expect(mockURLSession.lastRequest?.httpMethod == "GET") == "WorkosCursorSessionToken=test-token")
        #expect(mockURLSession.lastRequest?.value(forHTTPHeaderField: "Accept" == true)
    }

    @Test("fetch user info  without team id")

    func testFetchUserInfo_WithoutTeamId() async throws {
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

        mockURLSession.nextData = mockUserData
        mockURLSession.nextResponse = mockResponse

        // When
        let userInfo = try await cursorProvider.fetchUserInfo(authToken: "test-token")

        // Then
        #expect(userInfo.email == "test@example.com")
        #expect(userInfo.provider == .cursor)

    func testGetAuthenticationURL() async {
        // When
        let authURL = cursorProvider.getAuthenticationURL()

        // Then
        #expect(authURL == CursorAPIConstants.authenticationURL)

    func testExtractAuthToken_FromCookies() async {
        // Given
        let cookie = HTTPCookie(properties: [
            .name: CursorAPIConstants.Headers.sessionCookieName,
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
        #expect(extractedToken == "extracted-token-123")

    func testExtractAuthToken_NoCookies() async {
        // Given
        let callbackData: [String: Any] = [:]

        // When
        let extractedToken = cursorProvider.extractAuthToken(from: callbackData)

        // Then
        #expect(extractedToken == nil)

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
        #expect(extractedToken == nil)
    }
}
