import Foundation
@testable import VibeMeter
import XCTest

final class CursorProviderBasicTests: XCTestCase {
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

    func testFetchTeamInfo_NoTeamsFound_UsesFallback() async {
        // Given
        let mockEmptyTeamsData = Data("""
        {}
        """.utf8)

        let mockResponse = HTTPURLResponse(
            url: URL(string: "https://www.cursor.com/api/dashboard/teams")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil)!

        mockURLSession.nextData = mockEmptyTeamsData
        mockURLSession.nextResponse = mockResponse

        // When
        do {
            let teamInfo = try await cursorProvider.fetchTeamInfo(authToken: "test-token")

            // Then - Should return fallback team info instead of throwing
            XCTAssertEqual(teamInfo.id, -1, "Should use fallback team ID")
            XCTAssertEqual(teamInfo.name, "Individual", "Should use fallback team name")
            XCTAssertEqual(teamInfo.provider, .cursor, "Should maintain correct provider")
        } catch {
            XCTFail("Should not throw error when teams are empty, should use fallback. Got: \(error)")
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
        let mockUserData = Data("""
        {
            "email": "test@example.com",
            "teamId": 456
        }
        """.utf8)

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
        let mockUserData = Data("""
        {
            "email": "test@example.com"
        }
        """.utf8)

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
