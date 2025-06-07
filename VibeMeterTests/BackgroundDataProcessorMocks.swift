import Foundation
@testable import VibeMeter
import XCTest

// MARK: - Mock Provider for Background Processing Tests

class MockBackgroundProvider: ProviderProtocol, @unchecked Sendable {
    let provider: ServiceProvider
    let lock = NSLock()

    // Response data
    private var _userInfoToReturn: ProviderUserInfo?
    private var _teamInfoToReturn: ProviderTeamInfo?
    private var _invoiceToReturn: ProviderMonthlyInvoice?
    private var _usageToReturn: ProviderUsageData?

    // Error simulation
    private var _shouldThrowOnUserInfo = false
    private var _shouldThrowOnTeamInfo = false
    private var _shouldThrowOnInvoice = false
    private var _shouldThrowOnUsage = false
    private var _shouldThrowCustomError = false
    private var _errorToThrow: Error = TestError.networkFailure
    private var _customError: Error = TestError.networkFailure

    // Timing simulation
    private var _userInfoDelay: TimeInterval = 0
    private var _teamInfoDelay: TimeInterval = 0
    private var _invoiceDelay: TimeInterval = 0
    private var _usageDelay: TimeInterval = 0

    // Call tracking
    private var _fetchUserInfoCallCount = 0
    private var _fetchTeamInfoCallCount = 0
    private var _fetchMonthlyInvoiceCallCount = 0
    private var _fetchUsageDataCallCount = 0
    private var _lastInvoiceMonth: Int?
    private var _lastInvoiceYear: Int?
    private var _lastTeamId: Int?

    // Thread-safe property accessors
    var userInfoToReturn: ProviderUserInfo? {
        get { lock.withLock { _userInfoToReturn } }
        set { lock.withLock { _userInfoToReturn = newValue } }
    }

    var teamInfoToReturn: ProviderTeamInfo? {
        get { lock.withLock { _teamInfoToReturn } }
        set { lock.withLock { _teamInfoToReturn = newValue } }
    }

    var invoiceToReturn: ProviderMonthlyInvoice? {
        get { lock.withLock { _invoiceToReturn } }
        set { lock.withLock { _invoiceToReturn = newValue } }
    }

    var usageToReturn: ProviderUsageData? {
        get { lock.withLock { _usageToReturn } }
        set { lock.withLock { _usageToReturn = newValue } }
    }

    var shouldThrowOnUserInfo: Bool {
        get { lock.withLock { _shouldThrowOnUserInfo } }
        set { lock.withLock { _shouldThrowOnUserInfo = newValue } }
    }

    var shouldThrowOnTeamInfo: Bool {
        get { lock.withLock { _shouldThrowOnTeamInfo } }
        set { lock.withLock { _shouldThrowOnTeamInfo = newValue } }
    }

    var shouldThrowOnInvoice: Bool {
        get { lock.withLock { _shouldThrowOnInvoice } }
        set { lock.withLock { _shouldThrowOnInvoice = newValue } }
    }

    var shouldThrowOnUsage: Bool {
        get { lock.withLock { _shouldThrowOnUsage } }
        set { lock.withLock { _shouldThrowOnUsage = newValue } }
    }

    var errorToThrow: Error {
        get { lock.withLock { _errorToThrow } }
        set { lock.withLock { _errorToThrow = newValue } }
    }

    var shouldThrowCustomError: Bool {
        get { lock.withLock { _shouldThrowCustomError } }
        set { lock.withLock { _shouldThrowCustomError = newValue } }
    }

    var customError: Error {
        get { lock.withLock { _customError } }
        set { lock.withLock { _customError = newValue } }
    }

    // Aliases for compatibility with tests
    var shouldThrowUserInfoError: Bool {
        get { shouldThrowOnUserInfo }
        set { shouldThrowOnUserInfo = newValue }
    }

    var shouldThrowTeamInfoError: Bool {
        get { shouldThrowOnTeamInfo }
        set { shouldThrowOnTeamInfo = newValue }
    }

    var shouldThrowInvoiceError: Bool {
        get { shouldThrowOnInvoice }
        set { shouldThrowOnInvoice = newValue }
    }

    var shouldThrowUsageError: Bool {
        get { shouldThrowOnUsage }
        set { shouldThrowOnUsage = newValue }
    }

    var userInfoDelay: TimeInterval {
        get { lock.withLock { _userInfoDelay } }
        set { lock.withLock { _userInfoDelay = newValue } }
    }

    var teamInfoDelay: TimeInterval {
        get { lock.withLock { _teamInfoDelay } }
        set { lock.withLock { _teamInfoDelay = newValue } }
    }

    var invoiceDelay: TimeInterval {
        get { lock.withLock { _invoiceDelay } }
        set { lock.withLock { _invoiceDelay = newValue } }
    }

    var usageDelay: TimeInterval {
        get { lock.withLock { _usageDelay } }
        set { lock.withLock { _usageDelay = newValue } }
    }

    var fetchUserInfoCallCount: Int {
        lock.withLock { _fetchUserInfoCallCount }
    }

    var fetchTeamInfoCallCount: Int {
        lock.withLock { _fetchTeamInfoCallCount }
    }

    var fetchMonthlyInvoiceCallCount: Int {
        lock.withLock { _fetchMonthlyInvoiceCallCount }
    }

    var fetchUsageDataCallCount: Int {
        lock.withLock { _fetchUsageDataCallCount }
    }

    var lastInvoiceMonth: Int? {
        lock.withLock { _lastInvoiceMonth }
    }

    var lastInvoiceYear: Int? {
        lock.withLock { _lastInvoiceYear }
    }

    var lastTeamId: Int? {
        lock.withLock { _lastTeamId }
    }

    init(provider: ServiceProvider = .cursor) {
        self.provider = provider
    }

    func fetchUserInfo(authToken _: String) async throws -> ProviderUserInfo {
        lock.withLock { _fetchUserInfoCallCount += 1 }

        if userInfoDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(userInfoDelay * 1_000_000_000))
        }

        if shouldThrowCustomError {
            throw customError
        }

        if shouldThrowOnUserInfo {
            throw errorToThrow
        }

        guard let userInfo = userInfoToReturn else {
            throw TestError.unexpectedNil
        }

        return userInfo
    }

    func fetchTeamInfo(authToken _: String) async throws -> ProviderTeamInfo {
        lock.withLock { _fetchTeamInfoCallCount += 1 }

        if teamInfoDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(teamInfoDelay * 1_000_000_000))
        }

        if shouldThrowOnTeamInfo {
            throw errorToThrow
        }

        guard let teamInfo = teamInfoToReturn else {
            throw TestError.unexpectedNil
        }

        return teamInfo
    }

    func fetchMonthlyInvoice(
        authToken _: String,
        month: Int,
        year: Int,
        teamId: Int?) async throws -> ProviderMonthlyInvoice {
        lock.withLock {
            _fetchMonthlyInvoiceCallCount += 1
            _lastInvoiceMonth = month
            _lastInvoiceYear = year
            _lastTeamId = teamId
        }

        if invoiceDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(invoiceDelay * 1_000_000_000))
        }

        if shouldThrowOnInvoice {
            throw errorToThrow
        }

        guard let invoice = invoiceToReturn else {
            throw TestError.unexpectedNil
        }

        return invoice
    }

    func fetchUsageData(authToken _: String) async throws -> ProviderUsageData {
        lock.withLock { _fetchUsageDataCallCount += 1 }

        if usageDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(usageDelay * 1_000_000_000))
        }

        if shouldThrowOnUsage {
            throw errorToThrow
        }

        guard let usage = usageToReturn else {
            throw TestError.unexpectedNil
        }

        return usage
    }

    func validateToken(authToken: String) async -> Bool {
        do {
            _ = try await fetchUserInfo(authToken: authToken)
            return true
        } catch {
            return false
        }
    }

    func getAuthenticationURL() -> URL {
        URL(string: "https://test-auth.example.com")!
    }

    func extractAuthToken(from callbackData: [String: Any]) -> String? {
        callbackData["test_token"] as? String
    }

    func reset() {
        lock.withLock {
            _fetchUserInfoCallCount = 0
            _fetchTeamInfoCallCount = 0
            _fetchMonthlyInvoiceCallCount = 0
            _fetchUsageDataCallCount = 0
            _lastInvoiceMonth = nil
            _lastInvoiceYear = nil
            _lastTeamId = nil
        }
    }
}

// MARK: - Thread Capturing Mock Provider

class ThreadCapturingProvider: MockBackgroundProvider, @unchecked Sendable {
    private var _executionThread: Thread?

    var executionThread: Thread? {
        lock.withLock { _executionThread }
    }

    override func fetchUserInfo(authToken: String) async throws -> ProviderUserInfo {
        lock.withLock { _executionThread = Thread.current }
        return try await super.fetchUserInfo(authToken: authToken)
    }
}

// MARK: - Test Errors

enum TestError: LocalizedError {
    case networkFailure
    case unexpectedNil
    case authenticationFailed
    case teamInfoUnavailable
    case invoiceUnavailable
    case usageDataUnavailable

    var errorDescription: String? {
        switch self {
        case .networkFailure: "Network request failed"
        case .unexpectedNil: "Unexpected nil value"
        case .authenticationFailed: "Authentication failed"
        case .teamInfoUnavailable: "Team info is unavailable"
        case .invoiceUnavailable: "Invoice data is unavailable"
        case .usageDataUnavailable: "Usage data is unavailable"
        }
    }
}
