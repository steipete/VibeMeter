import Foundation
@testable import VibeMeter
import XCTest

final class CursorProviderValidationTests: XCTestCase {
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

    // MARK: - Token Validation Tests

    func testValidateToken_ValidToken() async {
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
            XCTFail("Should have thrown no team found error")
        } catch let error as ProviderError {
            XCTAssertEqual(error, .noTeamFound)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testNetworkError_500WithTeamNotFound() async {
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
        let request = try XCTUnwrap(mockURLSession.lastRequest)

        // Verify headers
        XCTAssertEqual(request.value(forHTTPHeaderField: "Cookie"), CursorAPIConstants.cookieHeader(for: "test-auth-token"))
        XCTAssertEqual(request.value(forHTTPHeaderField: "Accept"), "application/json")

        // Verify timeout
        XCTAssertEqual(request.timeoutInterval, 30)

        // Verify URL
        XCTAssertEqual(request.url, CursorAPIConstants.URLs.userInfo)
    }
}
