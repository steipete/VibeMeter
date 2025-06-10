import Foundation
import Testing
@testable import VibeMeter

// MARK: - Collection Extensions Tests

@Suite("Collection Extensions Tests", .tags(.unit))
struct CollectionExtensionsTests {
    // MARK: - GroupBy Tests

    @Test("Group elements by key")
    func groupElementsByKey() {
        struct Person {
            let name: String
            let age: Int
            let department: String
        }

        let people = [
            Person(name: "Alice", age: 30, department: "Engineering"),
            Person(name: "Bob", age: 25, department: "Marketing"),
            Person(name: "Charlie", age: 35, department: "Engineering"),
            Person(name: "Diana", age: 28, department: "Marketing"),
            Person(name: "Eve", age: 32, department: "Sales"),
        ]

        let grouped = people.groupBy { $0.department }

        #expect(grouped.count == 3)
        #expect(grouped["Engineering"]?.count == 2)
        #expect(grouped["Marketing"]?.count == 2)
        #expect(grouped["Sales"]?.count == 1)

        // Verify specific groupings
        let engineering = grouped["Engineering"] ?? []
        #expect(engineering.contains { $0.name == "Alice" })
        #expect(engineering.contains { $0.name == "Charlie" })
    }

    @Test("Group with transformation")
    func groupWithTransformation() {
        let numbers = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]

        // Group by even/odd and transform to strings
        let grouped = numbers.groupBy(
            { $0 % 2 == 0 ? "even" : "odd" },
            transform: { "\($0)" })

        #expect(grouped["even"]?.count == 5)
        #expect(grouped["odd"]?.count == 5)
        #expect(grouped["even"]?.contains("2") == true)
        #expect(grouped["odd"]?.contains("3") == true)
    }

    @Test("Group empty collection")
    func groupEmptyCollection() {
        let empty: [Int] = []
        let grouped = empty.groupBy { $0 % 2 }

        #expect(grouped.isEmpty)
    }

    @Test("Group and reduce")
    func groupAndReduce() {
        struct Sale {
            let product: String
            let amount: Double
        }

        let sales = [
            Sale(product: "Widget", amount: 100.0),
            Sale(product: "Gadget", amount: 150.0),
            Sale(product: "Widget", amount: 200.0),
            Sale(product: "Gadget", amount: 75.0),
            Sale(product: "Widget", amount: 50.0),
        ]

        // Calculate total sales by product
        let totalsByProduct = sales.groupByAndReduce(
            { $0.product },
            initialValue: 0.0,
            reduce: { total, sale in total + sale.amount })

        #expect(totalsByProduct["Widget"] == 350.0)
        #expect(totalsByProduct["Gadget"] == 225.0)
    }

    // MARK: - Array Chunking Tests

    @Test("Chunk array into equal parts")
    func chunkArrayEqualParts() {
        let numbers = Array(1 ... 10)
        let chunks = numbers.chunked(into: 3)

        #expect(chunks.count == 4) // 3, 3, 3, 1
        #expect(chunks[0] == [1, 2, 3])
        #expect(chunks[1] == [4, 5, 6])
        #expect(chunks[2] == [7, 8, 9])
        #expect(chunks[3] == [10])
    }

    @Test("Chunk with size larger than array")
    func chunkWithLargeSize() {
        let numbers = [1, 2, 3]
        let chunks = numbers.chunked(into: 10)

        #expect(chunks.count == 1)
        #expect(chunks[0] == [1, 2, 3])
    }

    @Test("Chunk empty array")
    func chunkEmptyArray() {
        let empty: [Int] = []
        let chunks = empty.chunked(into: 5)

        #expect(chunks.isEmpty)
    }

    @Test("Chunk with invalid size")
    func chunkWithInvalidSize() {
        let numbers = [1, 2, 3]
        let chunks = numbers.chunked(into: 0)

        #expect(chunks.isEmpty)
    }

    // MARK: - Batch Processing Tests

    @Test("Process array in batches")
    func processInBatches() async throws {
        let numbers = Array(1 ... 100)

        // Process in batches of 25, calculating sum of each batch
        let batchSums = try await numbers.processInBatches(batchSize: 25) { batch in
            batch.reduce(0, +)
        }

        #expect(batchSums.count == 4)
        #expect(batchSums[0] == 325) // 1+2+...+25
        #expect(batchSums[1] == 950) // 26+27+...+50
        #expect(batchSums[2] == 1575) // 51+52+...+75
        #expect(batchSums[3] == 2275) // 76+77+...+100

        // Verify total
        let total = batchSums.reduce(0, +)
        #expect(total == 5050) // Sum of 1 to 100
    }

    @Test("Process maintains order")
    func processMaintainsOrder() async throws {
        let items = ["a", "b", "c", "d", "e", "f", "g", "h", "i", "j"]

        // Process with async delay to test ordering
        let results = try await items.processInBatches(batchSize: 3) { batch in
            // Simulate async work
            try await Task.sleep(for: .milliseconds(10))
            return batch.joined()
        }

        #expect(results == ["abc", "def", "ghi", "j"])
    }

    // MARK: - Dictionary Merge Tests

    @Test("Merge dictionaries with conflict resolution")
    func mergeDictionaries() {
        var dict1 = ["a": 1, "b": 2, "c": 3]
        let dict2 = ["b": 20, "d": 4, "e": 5]

        // Merge keeping the maximum value for conflicts
        dict1.merge(dict2) { old, new in max(old, new) }

        #expect(dict1["a"] == 1)
        #expect(dict1["b"] == 20) // max(2, 20)
        #expect(dict1["c"] == 3)
        #expect(dict1["d"] == 4)
        #expect(dict1["e"] == 5)
    }

    @Test("Merge empty dictionaries")
    func mergeEmptyDictionaries() {
        var dict1: [String: Int] = [:]
        let dict2 = ["a": 1, "b": 2]

        dict1.merge(dict2) { old, new in old + new }

        #expect(dict1 == ["a": 1, "b": 2])
    }

    // MARK: - Date Grouping Tests

    @Test("Date start of day")
    func dateStartOfDay() {
        let calendar = Calendar.current
        let date = calendar.date(from: DateComponents(
            year: 2025,
            month: 1,
            day: 15,
            hour: 14,
            minute: 30,
            second: 45))!

        let startOfDay = date.startOfDay

        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: startOfDay)
        #expect(components.year == 2025)
        #expect(components.month == 1)
        #expect(components.day == 15)
        #expect(components.hour == 0)
        #expect(components.minute == 0)
        #expect(components.second == 0)
    }

    @Test("Date start of month")
    func dateStartOfMonth() {
        let calendar = Calendar.current
        let date = calendar.date(from: DateComponents(
            year: 2025,
            month: 3,
            day: 15))!

        let startOfMonth = date.startOfMonth

        let components = calendar.dateComponents([.year, .month, .day], from: startOfMonth)
        #expect(components.year == 2025)
        #expect(components.month == 3)
        #expect(components.day == 1)
    }

    @Test("Date grouping keys")
    func dateGroupingKeys() {
        let calendar = Calendar.current
        let date = calendar.date(from: DateComponents(
            year: 2025,
            month: 1,
            day: 15,
            hour: 14,
            minute: 30))!

        #expect(date.dailyGroupingKey == "2025-01-15")
        #expect(date.monthlyGroupingKey == "2025-01")
    }

    // MARK: - Performance Tests

    @Test("Group large dataset efficiently")
    func groupLargeDataset() {
        // Create 10,000 items
        let items = (0 ..< 10000).map { i in
            (id: i, category: "Category\(i % 100)")
        }

        let startTime = Date()
        let grouped = items.groupBy { $0.category }
        let duration = Date().timeIntervalSince(startTime)

        #expect(grouped.count == 100)
        #expect(grouped["Category0"]?.count == 100)

        // Should complete in reasonable time (less than 100ms)
        #expect(duration < 0.1)
    }

    @Test("Process large array in batches efficiently")
    func processLargeArrayInBatches() async throws {
        let largeArray = Array(1 ... 1000)

        let startTime = Date()
        let results = try await largeArray.processInBatches(batchSize: 100) { batch in
            // Simulate some work
            batch.reduce(0, +)
        }
        let duration = Date().timeIntervalSince(startTime)

        #expect(results.count == 10)

        // Should complete quickly due to parallel processing
        #expect(duration < 0.5)
    }
}
