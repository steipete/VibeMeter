import Foundation
import SwiftUI

/// An async sequence that emits values at regular intervals
@available(macOS 15.0, *)
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

// MARK: - For older macOS versions

/// A compatibility wrapper for Timer-based async sequences
@available(macOS, deprecated: 15.0, message: "Use AsyncTimerSequence on macOS 15+")
struct LegacyAsyncTimerSequence: AsyncSequence {
    typealias Element = Date

    let interval: TimeInterval

    init(interval: TimeInterval) {
        self.interval = interval
    }

    func makeAsyncIterator() -> AsyncIterator {
        AsyncIterator(interval: interval)
    }

    class AsyncIterator: AsyncIteratorProtocol {
        private let interval: TimeInterval
        private let stream: AsyncStream<Date>
        private var iterator: AsyncStream<Date>.Iterator

        init(interval: TimeInterval) {
            self.interval = interval

            let (stream, continuation) = AsyncStream<Date>.makeStream()
            self.stream = stream
            self.iterator = stream.makeAsyncIterator()

            // Create a weak reference holder to avoid capturing timer
            final class TimerHolder: @unchecked Sendable {
                weak var timer: Timer?
            }
            let holder = TimerHolder()

            // Start the timer on main thread
            DispatchQueue.main.async {
                let timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
                    continuation.yield(Date())
                }
                holder.timer = timer
            }

            continuation.onTermination = { @Sendable _ in
                DispatchQueue.main.async {
                    holder.timer?.invalidate()
                }
            }
        }

        func next() async -> Date? {
            await iterator.next()
        }
    }
}

// MARK: - Convenience Extensions

extension AsyncTimerSequence {
    /// Creates a timer that fires every specified number of seconds
    @available(macOS 15.0, *)
    static func seconds(_ seconds: Int) -> AsyncTimerSequence {
        AsyncTimerSequence(interval: .seconds(seconds))
    }

    /// Creates a timer that fires every specified number of milliseconds
    @available(macOS 15.0, *)
    static func milliseconds(_ milliseconds: Int) -> AsyncTimerSequence {
        AsyncTimerSequence(interval: .milliseconds(milliseconds))
    }
}

// View extensions removed - they should be in a separate SwiftUI-specific file

// MARK: - Usage Examples

/*
 Example usage:

 ```swift
 // In a view
 struct MyView: View {
     var body: some View {
         Text("Updated every 30 seconds")
             .onTimer(interval: .seconds(30)) {
                 await refreshData()
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
