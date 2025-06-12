import Foundation
import SwiftUI

/// An async sequence that emits values at regular intervals
struct AsyncTimerSequence: AsyncSequence {
    typealias Element = Date

    let interval: Duration
    let tolerance: Duration?

    init(
        interval: Duration,
        tolerance: Duration? = nil) {
        self.interval = interval
        self.tolerance = tolerance
    }

    func makeAsyncIterator() -> AsyncIterator {
        AsyncIterator(
            interval: interval,
            tolerance: tolerance)
    }

    struct AsyncIterator: AsyncIteratorProtocol {
        let interval: Duration
        let tolerance: Duration?
        private var nextDeadline: ContinuousClock.Instant
        private let clock = ContinuousClock()

        init(
            interval: Duration,
            tolerance: Duration?) {
            self.interval = interval
            self.tolerance = tolerance
            self.nextDeadline = ContinuousClock.now + interval
        }

        mutating func next() async -> Date? {
            do {
                try await clock.sleep(until: nextDeadline, tolerance: tolerance)
                nextDeadline += interval
                return Date()
            } catch {
                return nil
            }
        }
    }
}

// MARK: - Usage Examples

/*
 Example usage:

 ```swift
 // In a view
 struct MyView: View {
     var body: some View {
         Text("Updated every 30 seconds")
             .task {
                 for await _ in AsyncTimerSequence.seconds(30) {
                     await refreshData()
                 }
             }
     }
 }

 // In an async context
 func monitorData() async {
     for await date in AsyncTimerSequence.seconds(60) {
         print("Checking at \(date)")
         await checkForUpdates()
     }
 }

 // With cancellation
 func monitorWithCancellation() async {
     let task = Task {
         for await _ in AsyncTimerSequence(interval: .seconds(5)) {
             guard !Task.isCancelled else { break }
             await performWork()
         }
     }

     // Cancel when needed
     task.cancel()
 }
 ```
 */
