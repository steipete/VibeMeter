import SwiftUI

/// Helper for calculating progress-based colors
struct ProgressColorHelper {
    static func color(for progress: Double) -> Color {
        switch progress {
        case ..<0.5:
            return .green
        case 0.5..<0.75:
            return .yellow
        case 0.75..<0.9:
            return .orange
        default:
            return .red
        }
    }
    
    static func warningLevel(for progress: Double) -> WarningLevel {
        switch progress {
        case ..<0.5:
            return .normal
        case 0.5..<0.75:
            return .low
        case 0.75..<0.9:
            return .medium
        default:
            return .high
        }
    }
    
    enum WarningLevel {
        case normal
        case low
        case medium
        case high
    }
}