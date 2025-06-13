import Foundation

extension AsyncTimerSequence {
    /// Creates a timer that fires every specified number of seconds
    static func seconds(_ seconds: Int) -> AsyncTimerSequence {
        AsyncTimerSequence(interval: .seconds(seconds))
    }

    /// Creates a timer that fires every specified number of milliseconds
    static func milliseconds(_ milliseconds: Int) -> AsyncTimerSequence {
        AsyncTimerSequence(interval: .milliseconds(milliseconds))
    }
}
