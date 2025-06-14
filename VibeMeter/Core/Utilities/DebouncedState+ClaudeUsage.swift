import SwiftUI

// MARK: - Claude-Specific Debouncing Constants

public extension Duration {
    /// Optimized delay for Claude token window updates (2 seconds)
    static let claudeTokenWindow: Duration = .seconds(2)
    
    /// Optimized delay for Claude progress updates (300ms)
    static let claudeProgress: Duration = .milliseconds(300)
    
    /// Optimized delay for Claude message updates (500ms)
    static let claudeMessage: Duration = .milliseconds(500)
}

// MARK: - Convenience View Extensions

public extension View {
    /// Debounces Claude token window updates to reduce CPU usage
    /// - Parameters:
    ///   - window: The rapidly updating window data
    ///   - destination: Where to store the debounced value
    func debounceTokenWindow(
        _ window: FiveHourWindow?,
        to destination: Binding<FiveHourWindow?>
    ) -> some View {
        self.debounced(window, duration: .seconds(2), to: destination)
    }
    
    /// Debounces Claude progress updates for smooth animations
    /// - Parameters:
    ///   - progress: The rapidly updating progress value
    ///   - destination: Where to store the debounced value
    func debounceClaudeProgress(
        _ progress: Int,
        to destination: Binding<Int>
    ) -> some View {
        self.debounced(progress, duration: .milliseconds(300), to: destination)
    }
}
