import SwiftUI

/// Helper for calculating progress-based colors
enum ProgressColorHelper {
    static func color(for progress: Double) -> Color {
        switch progress {
        case ..<0.5:
            .green
        case 0.5 ..< 0.75:
            .yellow
        case 0.75 ..< 0.9:
            .orange
        default:
            .red
        }
    }

    static func warningLevel(for progress: Double) -> WarningLevel {
        switch progress {
        case ..<0.5:
            .normal
        case 0.5 ..< 0.75:
            .low
        case 0.75 ..< 0.9:
            .medium
        default:
            .high
        }
    }

    enum WarningLevel {
        case normal
        case low
        case medium
        case high
    }
}
