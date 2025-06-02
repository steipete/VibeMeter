@testable import VibeMeter
import XCTest

class CursorAPIClientTests: XCTestCase, @unchecked Sendable {
    var apiClient: RealCursorAPIClient!
    var mockURLSession: MockURLSession!
    var testUserDefaults: UserDefaults!
    var settingsManager: SettingsManager!
    let testSuiteName = "com.vibemeter.tests.CursorAPIClientTests"

    override func setUp() {
        super.setUp()
        MainActor.assumeIsolated {
            testUserDefaults = UserDefaults(suiteName: testSuiteName)
            testUserDefaults.removePersistentDomain(forName: testSuiteName)
            // Setup SettingsManager with testUserDefaults
            // Tests for CursorAPIClient might depend on teamId being set in SettingsManager
            SettingsManager._test_setSharedInstance(userDefaults: testUserDefaults)
            settingsManager = SettingsManager.shared
            mockURLSession = MockURLSession()
            apiClient = CursorAPIClient.__init(session: mockURLSession, settingsManager: settingsManager)
        }
    }

    override func tearDown() {
        MainActor.assumeIsolated {
            testUserDefaults.removePersistentDomain(forName: testSuiteName)
            testUserDefaults = nil
            apiClient = nil
            mockURLSession = nil
            settingsManager = nil
            SettingsManager._test_clearSharedInstance()
        }
        super.tearDown()
    }

    // MARK: - Helper to create mock responses

    private func createMockResponse(statusCode: Int, data _: Data?) -> HTTPURLResponse? {
        HTTPURLResponse(
            url: URL(string: "https://example.com")!,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: nil
        )
    }

    // MARK: - Fetch Team Info Tests

    @MainActor
    func testFetchTeamInfoSuccessfully() async throws {
        let mockTeamData = CursorAPIClient.TeamInfoResponse(teams: [CursorAPIClient.Team(id: 123, name: "Test Team")])
        let mockData = try JSONEncoder().encode(mockTeamData)
        mockURLSession.nextData = mockData
        mockURLSession.nextResponse = createMockResponse(statusCode: 200, data: mockData)

        let teamInfo = try await apiClient.fetchTeamInfo(authToken: "testToken")
        XCTAssertEqual(teamInfo.id, 123)
        XCTAssertEqual(teamInfo.name, "Test Team")
        XCTAssertEqual(mockURLSession.lastURL?.absoluteString, "https://www.cursor.com/api/dashboard/teams")
        XCTAssertEqual(
            mockURLSession.lastRequest?.value(forHTTPHeaderField: "Cookie"),
            "WorkosCursorSessionToken=testToken"
        )
        XCTAssertEqual(mockURLSession.lastRequest?.httpMethod, "POST")
    }

    @MainActor
    func testFetchTeamInfoEmptyTeamsArray() async {
        let mockTeamData = CursorAPIClient.TeamInfoResponse(teams: [])
        let mockData = try? JSONEncoder().encode(mockTeamData)
        mockURLSession.nextData = mockData
        mockURLSession.nextResponse = createMockResponse(statusCode: 200, data: mockData)

        do {
            _ = try await apiClient.fetchTeamInfo(authToken: "testToken")
            XCTFail("Should have thrown an error for empty teams array")
        } catch let error as CursorAPIClient.APIError {
            XCTAssertEqual(error, CursorAPIClient.APIError.noTeamFound)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    @MainActor
    func testFetchTeamInfoHttpError() async {
        mockURLSession.nextResponse = createMockResponse(statusCode: 500, data: nil)

        do {
            _ = try await apiClient.fetchTeamInfo(authToken: "testToken")
            XCTFail("Should have thrown an APIError.networkError")
        } catch let error as CursorAPIClient.APIError {
            if case let .networkError(errorDetails) = error {
        XCTAssertEqual(
            errorDetails.statusCode,
            500,
            "Error details should contain the status code"
        )
            } else {
        XCTFail("Incorrect APIError type, expected .networkError")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    @MainActor
    func testFetchTeamInfoDecodingError() async {
        let malformedData = Data("{\"invalid\": \"json\"}".utf8)
        mockURLSession.nextData = malformedData
        mockURLSession.nextResponse = createMockResponse(statusCode: 200, data: malformedData)

        do {
            _ = try await apiClient.fetchTeamInfo(authToken: "testToken")
            XCTFail("Should have thrown APIError.decodingError")
        } catch CursorAPIClient.APIError.decodingError {
            // Correct error caught
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    // MARK: - Fetch User Info Tests

    @MainActor
    func testFetchUserInfoSuccessfully() async throws {
        let mockUserData = CursorAPIClient.UserInfoResponse(email: "test@example.com", teamId: nil)
        let mockData = try JSONEncoder().encode(mockUserData)
        mockURLSession.nextData = mockData
        mockURLSession.nextResponse = createMockResponse(statusCode: 200, data: mockData)

        let userInfo = try await apiClient.fetchUserInfo(authToken: "testToken")
        XCTAssertEqual(userInfo.email, "test@example.com")
        XCTAssertEqual(mockURLSession.lastURL?.absoluteString, "https://www.cursor.com/api/auth/me")
        XCTAssertEqual(
            mockURLSession.lastRequest?.value(forHTTPHeaderField: "Cookie"),
            "WorkosCursorSessionToken=testToken"
        )
        XCTAssertEqual(mockURLSession.lastRequest?.httpMethod, "GET")
    }

    // MARK: - Fetch Monthly Invoice Tests

    @MainActor
    func testFetchMonthlyInvoiceSuccessfully() async throws {
        settingsManager.teamId = 123 // Prerequisite for this call
        let mockInvoiceData = CursorAPIClient.MonthlyInvoiceResponse(items: [
            CursorAPIClient.InvoiceItem(cents: 1000, description: "Usage 1"),
            CursorAPIClient.InvoiceItem(cents: 250, description: "Usage 2"),
        ], pricingDescription: nil)
        let mockData = try JSONEncoder().encode(mockInvoiceData)
        mockURLSession.nextData = mockData
        mockURLSession.nextResponse = createMockResponse(statusCode: 200, data: mockData)

        let invoiceResponse = try await apiClient.fetchMonthlyInvoice(authToken: "testToken", month: 10, year: 2023)
        XCTAssertEqual(invoiceResponse.items?.count, 2)
        XCTAssertEqual(invoiceResponse.items?[0].cents, 1000)
        XCTAssertEqual(invoiceResponse.totalSpendingCents, 1250)
        XCTAssertEqual(
            mockURLSession.lastURL?.absoluteString,
            "https://www.cursor.com/api/dashboard/get-monthly-invoice"
        )
        XCTAssertEqual(mockURLSession.lastRequest?.httpMethod, "POST")

        // Verify request body
        let requestBody = mockURLSession.lastRequest?.httpBody
        XCTAssertNotNil(requestBody)
        let decodedBody = try? JSONDecoder().decode(CursorAPIClient.MonthlyInvoiceRequest.self, from: requestBody!)
        XCTAssertNotNil(decodedBody)
        XCTAssertEqual(decodedBody?.teamId, 123)
        XCTAssertEqual(decodedBody?.month, 10)
        XCTAssertEqual(decodedBody?.year, 2023)
        XCTAssertTrue(decodedBody?.includeUsageEvents ?? false) // Should be true as set in implementation
    }

    @MainActor
    func testFetchMonthlyInvoiceNoTeamId() async {
        settingsManager.teamId = nil // Ensure no teamId
        do {
            _ = try await apiClient.fetchMonthlyInvoice(authToken: "testToken", month: 10, year: 2023)
            XCTFail("Should have thrown APIError.teamIdNotSet")
        } catch CursorAPIClient.APIError.teamIdNotSet {
            // Correct error
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    @MainActor
    func testFetchMonthlyInvoiceEmptyItems() async throws {
        settingsManager.teamId = 123
        let mockInvoiceData = CursorAPIClient.MonthlyInvoiceResponse(items: [], pricingDescription: nil)
        let mockData = try JSONEncoder().encode(mockInvoiceData)
        mockURLSession.nextData = mockData
        mockURLSession.nextResponse = createMockResponse(statusCode: 200, data: mockData)

        let invoiceResponse = try await apiClient.fetchMonthlyInvoice(authToken: "testToken", month: 10, year: 2023)
        XCTAssertTrue(invoiceResponse.items?.isEmpty ?? true)
        XCTAssertEqual(invoiceResponse.totalSpendingCents, 0)
    }

    // MARK: - Unauthorized Error Handling (Applies to all calls)

    @MainActor
    func testApiCallReturnsUnauthorized() async {
        mockURLSession.nextResponse = createMockResponse(statusCode: 401, data: nil)

        do {
            _ = try await apiClient.fetchTeamInfo(authToken: "testToken")
            XCTFail("Should have thrown APIError.unauthorized")
        } catch CursorAPIClient.APIError.unauthorized {
            // Correct error
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
}

// MockURLSession is assumed to be available from ExchangeRateManagerTests or defined globally for tests.
// If not, it should be defined here as well.
// For this example, we assume it's defined elsewhere (e.g. in a shared test utilities file or
// ExchangeRateManagerTests.swift)
// If MockURLSession is in another test file, ensure this target can see it or duplicate/move it.
