import Foundation
import Testing
@testable import VibeMeter

@Suite("CursorProviderValidationTests")
struct CursorProviderValidationTests {
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

    // MARK: - Token Validation Tests

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

        mockURLSession.nextData = mockUserData
        mockURLSession.nextResponse = mockResponse

        // When
        let isValid = await cursorProvider.validateToken(authToken: "valid-token")

        // Then
        #expect(isValid == true)
    }

    func validateToken_InvalidToken() async {
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
        #expect(isValid == false)
    }

    func validateToken_NetworkError() async {
        // Given
        mockURLSession.nextError = NSError(domain: "NetworkError", code: -1009, userInfo: nil)

        // When
        let isValid = await cursorProvider.validateToken(authToken: "test-token")

        // Then
        #expect(isValid == false)
    }

    func networkError_RateLimitExceeded() async {
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

        mockURLSession.nextData = Data()
        mockURLSession.nextResponse = mockResponse

        // When/Then
        do {
            _ = try await cursorProvider.fetchUserInfo(authToken: "test-token")
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

        mockURLSession.nextData = invalidJSON
        mockURLSession.nextResponse = mockResponse

        // When/Then
        do {
            _ = try await cursorProvider.fetchUserInfo(authToken: "test-token")
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

        mockURLSession.nextData = errorResponse
        mockURLSession.nextResponse = mockResponse

        // When/Then
        do {
            _ = try await cursorProvider.fetchTeamInfo(authToken: "test-token")
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

        mockURLSession.nextData = errorMessage
        mockURLSession.nextResponse = mockResponse

        // When/Then
        do {
            _ = try await cursorProvider.fetchTeamInfo(authToken: "test-token")
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
        mockURLSession.nextError = NSError(
            domain: NSURLErrorDomain,
            code: NSURLErrorTimedOut,
            userInfo: [NSLocalizedDescriptionKey: "Request timed out"])

        // When/Then
        do {
            _ = try await cursorProvider.fetchUserInfo(authToken: "test-token")
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

    // MARK: - Request Configuration Tests

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

        mockURLSession.nextData = mockUserData
        mockURLSession.nextResponse = mockResponse

        // When
        _ = try await cursorProvider.fetchUserInfo(authToken: "test-auth-token")

        // Then
        let request = try #require(mockURLSession.lastRequest)

        // Verify headers
        #expect(request.value(forHTTPHeaderField: "Cookie") != nil)
        #expect(request.value(forHTTPHeaderField: "Accept") != nil)

        // Verify timeout
        #expect(request.timeoutInterval == 30)
    }
}
