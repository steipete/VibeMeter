import Foundation
import Testing
@testable import VibeMeter

// MARK: - Common Test Expectations

extension Double {
    /// Verifies that two doubles are approximately equal within a tolerance
    @discardableResult
    func isApproximatelyEqual(
        to other: Double,
        tolerance: Double = 0.01,
        sourceLocation: SourceLocation = #_sourceLocation) -> Bool {
        let difference = abs(self - other)
        let result = difference < tolerance
        #expect(
            result,
            """
            Expected \(self) to be approximately equal to \(other) within tolerance \(tolerance), \
            but difference was \(difference)
            """,
            sourceLocation: sourceLocation)
        return result
    }
}

extension Double? {
    /// Verifies that an optional double is approximately equal to an expected value
    @discardableResult
    func isApproximatelyEqual(
        to expected: Double,
        tolerance: Double = 0.01,
        sourceLocation: SourceLocation = #_sourceLocation) -> Bool {
        guard let value = self else {
            #expect(
                Bool(false),
                "Expected value to be approximately \(expected), but was nil",
                sourceLocation: sourceLocation)
            return false
        }
        return value.isApproximatelyEqual(to: expected, tolerance: tolerance, sourceLocation: sourceLocation)
    }
}

// MARK: - Async Test Helpers

extension Confirmation {
    /// Expects the confirmation to be confirmed exactly once
    func expectOnce(sourceLocation _: SourceLocation = #_sourceLocation) async {
        self.confirm()
    }
}

// MARK: - Collection Test Helpers

extension Collection {
    /// Verifies that a collection is not empty
    @discardableResult
    func isNotEmpty(sourceLocation: SourceLocation = #_sourceLocation) -> Bool {
        let result = !isEmpty
        #expect(result, "Expected collection to not be empty", sourceLocation: sourceLocation)
        return result
    }

    /// Verifies that a collection has a specific count
    @discardableResult
    func hasCount(_ expectedCount: Int, sourceLocation: SourceLocation = #_sourceLocation) -> Bool {
        let result = count == expectedCount
        #expect(
            result,
            "Expected collection to have count \(expectedCount), but was \(count)",
            sourceLocation: sourceLocation)
        return result
    }
}

// MARK: - String Test Helpers

extension String {
    /// Verifies that a string contains a substring
    @discardableResult
    func containsSubstring(_ substring: String, sourceLocation: SourceLocation = #_sourceLocation) -> Bool {
        let result = contains(substring)
        #expect(result, "Expected '\(self)' to contain '\(substring)'", sourceLocation: sourceLocation)
        return result
    }

    /// Verifies that a string has a specific prefix
    @discardableResult
    func hasPrefix(_ prefix: String, sourceLocation: SourceLocation = #_sourceLocation) -> Bool {
        let result = hasPrefix(prefix)
        #expect(result, "Expected '\(self)' to have prefix '\(prefix)'", sourceLocation: sourceLocation)
        return result
    }
}

// MARK: - Provider Test Helpers

extension ProviderConnectionStatus {
    /// Verifies that the connection status is in a specific state
    @discardableResult
    func isState(_ expectedState: ProviderConnectionStatus, sourceLocation: SourceLocation = #_sourceLocation) -> Bool {
        let result = self == expectedState
        #expect(
            result,
            "Expected connection status to be \(expectedState), but was \(self)",
            sourceLocation: sourceLocation)
        return result
    }

    /// Verifies that the connection status indicates an error
    @discardableResult
    func isErrorState(sourceLocation: SourceLocation = #_sourceLocation) -> Bool {
        #expect(
            isError,
            "Expected connection status to be an error state, but was \(self)",
            sourceLocation: sourceLocation)
        return isError
    }
}

// MARK: - Date Test Helpers

extension Date {
    /// Verifies that a date is within a time interval from now
    @discardableResult
    func isWithin(seconds: TimeInterval, of otherDate: Date = Date(),
                  sourceLocation: SourceLocation = #_sourceLocation) -> Bool {
        let difference = abs(timeIntervalSince(otherDate))
        let result = difference <= seconds
        #expect(
            result,
            "Expected date to be within \(seconds) seconds of \(otherDate), but difference was \(difference) seconds",
            sourceLocation: sourceLocation)
        return result
    }
}

// MARK: - Error Test Helpers

/// Expects that an async expression throws a specific error type
func expectThrows<E: Error & Equatable>(
    _ expectedError: E,
    _ expression: () async throws -> some Any,
    sourceLocation: SourceLocation = #_sourceLocation) async {
    do {
        _ = try await expression()
        #expect(
            Bool(false),
            "Expected to throw \(expectedError), but no error was thrown",
            sourceLocation: sourceLocation)
    } catch let error as E {
        #expect(error == expectedError, sourceLocation: sourceLocation)
    } catch {
        #expect(Bool(false), "Expected to throw \(expectedError), but threw \(error)", sourceLocation: sourceLocation)
    }
}

/// Expects that a non-async expression throws a specific error type
func expectThrows<E: Error & Equatable>(
    _ expectedError: E,
    _ expression: () throws -> some Any,
    sourceLocation: SourceLocation = #_sourceLocation) {
    do {
        _ = try expression()
        #expect(
            Bool(false),
            "Expected to throw \(expectedError), but no error was thrown",
            sourceLocation: sourceLocation)
    } catch let error as E {
        #expect(error == expectedError, sourceLocation: sourceLocation)
    } catch {
        #expect(Bool(false), "Expected to throw \(expectedError), but threw \(error)", sourceLocation: sourceLocation)
    }
}
