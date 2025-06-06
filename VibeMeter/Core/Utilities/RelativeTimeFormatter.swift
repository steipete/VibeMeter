import Foundation

/// Utility for formatting relative timestamps in a user-friendly way.
///
/// This formatter provides consistent relative time formatting throughout the app,
/// showing timestamps like "2 minutes ago", "Just now", or "Last updated 5m ago".
public enum RelativeTimeFormatter {
    /// Style for relative time formatting
    public enum Style {
        case short // "2m ago"
        case medium // "2 minutes ago"
        case withPrefix // "Last updated 2m ago"
    }

    private nonisolated(unsafe) static let formatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.dateTimeStyle = .named
        formatter.formattingContext = .standalone
        return formatter
    }()

    private nonisolated(unsafe) static let shortFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        formatter.dateTimeStyle = .named
        formatter.formattingContext = .standalone
        return formatter
    }()

    /// Formats a date relative to now with the specified style
    public static func string(from date: Date, style: Style = .medium) -> String {
        let now = Date()
        let interval = now.timeIntervalSince(date)

        // Handle very recent updates
        if interval < 60 {
            switch style {
            case .short:
                return "now"
            case .medium:
                return "Just now"
            case .withPrefix:
                return "Just updated"
            }
        }

        // Use system formatter for older timestamps
        let relativeString: String
        switch style {
        case .short:
            relativeString = shortFormatter.localizedString(for: date, relativeTo: now)
        case .medium:
            relativeString = formatter.localizedString(for: date, relativeTo: now)
        case .withPrefix:
            let relative = shortFormatter.localizedString(for: date, relativeTo: now)
            relativeString = "Last updated \(relative)"
        }

        return relativeString
    }

    /// Formats a date relative to now for compact displays
    public static func compactString(from date: Date) -> String {
        string(from: date, style: .short)
    }

    /// Formats a date with prefix for status displays
    public static func statusString(from date: Date) -> String {
        string(from: date, style: .withPrefix)
    }

    /// Returns true if the date is considered "fresh" (less than specified minutes old)
    public static func isFresh(_ date: Date, withinMinutes minutes: TimeInterval = 5) -> Bool {
        Date().timeIntervalSince(date) < (minutes * 60)
    }

    /// Returns a color indicating data freshness
    public static func freshnessColor(for date: Date) -> NSColor {
        let interval = Date().timeIntervalSince(date)

        if interval < 300 { // 5 minutes - fresh
            return .systemGreen
        } else if interval < 1800 { // 30 minutes - moderate
            return .systemOrange
        } else { // older - stale
            return .systemRed
        }
    }
}

// MARK: - SwiftUI Extensions

#if canImport(SwiftUI)
import SwiftUI

public extension RelativeTimeFormatter {
    /// SwiftUI color for data freshness
    static func swiftUIFreshnessColor(for date: Date) -> Color {
        Color(freshnessColor(for: date))
    }
}

/// SwiftUI view for displaying relative timestamps with automatic updates
public struct RelativeTimestampView: View {
    let date: Date
    let style: RelativeTimeFormatter.Style
    let showFreshnessColor: Bool

    @State
    private var currentTime = Date()

    public init(
        date: Date,
        style: RelativeTimeFormatter.Style = .medium,
        showFreshnessColor: Bool = false) {
        self.date = date
        self.style = style
        self.showFreshnessColor = showFreshnessColor
    }

    public var body: some View {
        Text(RelativeTimeFormatter.string(from: date, style: style))
            .foregroundStyle(showFreshnessColor ? RelativeTimeFormatter
                                .swiftUIFreshnessColor(for: date) : .secondary)
            .onAppear {
                startTimer()
            }
            .onDisappear {
                stopTimer()
            }
    }

    private func startTimer() {
        Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { _ in
            Task { @MainActor in
                currentTime = Date()
            }
        }
    }

    private func stopTimer() {
        // Timer will be deallocated automatically
    }
}
#endif

// MARK: - Preview Support

#if DEBUG
public extension RelativeTimeFormatter {
    /// Sample dates for testing and previews
    static var sampleDates: [(String, Date)] {
        let now = Date()
        return [
            ("Just now", now.addingTimeInterval(-30)),
            ("2 minutes ago", now.addingTimeInterval(-120)),
            ("15 minutes ago", now.addingTimeInterval(-900)),
            ("1 hour ago", now.addingTimeInterval(-3600)),
            ("Yesterday", now.addingTimeInterval(-86400)),
            ("Last week", now.addingTimeInterval(-604_800)),
        ]
    }
}
#endif
