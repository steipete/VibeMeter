import Foundation

// MARK: - Collection Extensions

public extension Sequence {
    /// Groups elements by a key function, similar to JavaScript's Object.groupBy
    /// - Parameter keyFn: Function that extracts the grouping key from each element
    /// - Returns: Dictionary mapping keys to arrays of elements
    func groupBy<Key: Hashable>(_ keyFn: (Element) throws -> Key) rethrows -> [Key: [Element]] {
        try reduce(into: [:]) { result, element in
            let key = try keyFn(element)
            result[key, default: []].append(element)
        }
    }

    /// Groups elements by a key function with transformation
    /// - Parameters:
    ///   - keyFn: Function that extracts the grouping key from each element
    ///   - transform: Function that transforms each element before grouping
    /// - Returns: Dictionary mapping keys to arrays of transformed elements
    func groupBy<Key: Hashable, Value>(
        _ keyFn: (Element) throws -> Key,
        transform: (Element) throws -> Value) rethrows -> [Key: [Value]] {
        try reduce(into: [:]) { result, element in
            let key = try keyFn(element)
            let value = try transform(element)
            result[key, default: []].append(value)
        }
    }

    /// Groups and aggregates elements by a key function
    /// - Parameters:
    ///   - keyFn: Function that extracts the grouping key from each element
    ///   - initialValue: Initial value for aggregation
    ///   - reduce: Function that aggregates values for each group
    /// - Returns: Dictionary mapping keys to aggregated values
    func groupByAndReduce<Key: Hashable, Value>(
        _ keyFn: (Element) throws -> Key,
        initialValue: Value,
        reduce: (Value, Element) throws -> Value) rethrows -> [Key: Value] {
        try self.reduce(into: [:]) { result, element in
            let key = try keyFn(element)
            let currentValue = result[key] ?? initialValue
            result[key] = try reduce(currentValue, element)
        }
    }
}

// MARK: - Array Extensions

public extension Array {
    /// Split array into chunks of specified size
    /// - Parameter size: Size of each chunk
    /// - Returns: Array of chunks
    func chunked(into size: Int) -> [[Element]] {
        guard size > 0 else { return [] }
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0 ..< Swift.min($0 + size, count)])
        }
    }

    /// Process array elements in batches with async support
    /// - Parameters:
    ///   - batchSize: Size of each batch
    ///   - transform: Async function to process each batch
    /// - Returns: Array of results from each batch
    func processInBatches<T: Sendable>(
        batchSize: Int,
        transform: @escaping @Sendable ([Element]) async throws -> T) async throws -> [T] where Element: Sendable {
        let batches = chunked(into: batchSize)

        return try await withThrowingTaskGroup(of: (Int, T).self) { group in
            for (index, batch) in batches.enumerated() {
                group.addTask {
                    let result = try await transform(batch)
                    return (index, result)
                }
            }

            // Collect results in order
            var results = [(Int, T)]()
            for try await result in group {
                results.append(result)
            }

            return results
                .sorted { $0.0 < $1.0 }
                .map(\.1)
        }
    }
}

// MARK: - Dictionary Extensions

public extension Dictionary {
    /// Merge another dictionary into this one, with custom conflict resolution
    /// - Parameters:
    ///   - other: Dictionary to merge
    ///   - uniquingKeysWith: Function to resolve conflicts
    mutating func merge(
        _ other: some Sequence<(Key, Value)>,
        uniquingKeysWith combine: (Value, Value) throws -> Value) rethrows {
        for (key, value) in other {
            if let existing = self[key] {
                self[key] = try combine(existing, value)
            } else {
                self[key] = value
            }
        }
    }
}

// MARK: - Date Extensions for Grouping

public extension Date {
    /// Returns the start of the day for grouping purposes
    var startOfDay: Date {
        Calendar.current.startOfDay(for: self)
    }

    /// Returns the start of the month for grouping purposes
    var startOfMonth: Date {
        let components = Calendar.current.dateComponents([.year, .month], from: self)
        return Calendar.current.date(from: components) ?? self
    }

    /// Returns a string key for daily grouping (YYYY-MM-DD)
    var dailyGroupingKey: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: self)
    }

    /// Returns a string key for monthly grouping (YYYY-MM)
    var monthlyGroupingKey: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        return formatter.string(from: self)
    }
}
