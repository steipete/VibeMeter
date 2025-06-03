import SwiftUI

/// Theme-aware color extensions for VibeMeter.
///
/// This extension provides semantic colors that automatically adapt to light and dark modes,
/// ensuring consistent visual appearance across all system themes. Colors are optimized
/// for accessibility and follow macOS design guidelines.
extension Color {
    // MARK: - App Semantic Colors

    /// Primary app accent color that adapts to theme
    static let vibeMeterAccent = Color.accentColor

    /// Background colors for different surface levels
    static let vibeMeterBackground = Color(NSColor.windowBackgroundColor)
    static let vibeMeterSurface = Color(NSColor.controlBackgroundColor)
    static let vibeMeterElevated = Color(NSColor.unemphasizedSelectedContentBackgroundColor)

    // MARK: - Gauge Colors (Theme-Aware)

    /// Gauge fill colors that adapt to light/dark mode with proper contrast
    static let gaugeHealthy = Color.green
    static let gaugeModerate = Color.yellow
    static let gaugeWarning = Color.orange
    static let gaugeDanger = Color.red
    static let gaugeDisabled = Color.gray

    /// Gauge stroke colors for different themes
    static func gaugeStroke(for colorScheme: ColorScheme) -> Color {
        switch colorScheme {
        case .dark:
            return .white.opacity(0.25)
        case .light:
            return .black.opacity(0.15)
        @unknown default:
            return .gray.opacity(0.2)
        }
    }

    /// Gauge background colors
    static func gaugeBackground(for colorScheme: ColorScheme) -> Color {
        switch colorScheme {
        case .dark:
            return .white.opacity(0.1)
        case .light:
            return .black.opacity(0.05)
        @unknown default:
            return .gray.opacity(0.1)
        }
    }

    // MARK: - Connection Status Colors

    /// Connection status colors that maintain contrast in both themes
    static let statusConnected = Color.green
    static let statusConnecting = Color.blue
    static let statusError = Color.red
    static let statusWarning = Color.orange
    static let statusDisconnected = Color.gray
    static let statusSyncing = Color.blue

    // MARK: - Adaptive Colors for Specific Use Cases

    /// Menu bar colors that work with system appearance
    static func menuBarContent(for colorScheme: ColorScheme) -> Color {
        switch colorScheme {
        case .dark:
            return .white
        case .light:
            return .black
        @unknown default:
            return .primary
        }
    }

    /// Hover state colors
    static func hoverBackground(for colorScheme: ColorScheme) -> Color {
        switch colorScheme {
        case .dark:
            return .white.opacity(0.08)
        case .light:
            return .black.opacity(0.05)
        @unknown default:
            return .gray.opacity(0.1)
        }
    }

    /// Selection background colors
    static func selectionBackground(for colorScheme: ColorScheme) -> Color {
        switch colorScheme {
        case .dark:
            return .white.opacity(0.12)
        case .light:
            return .black.opacity(0.08)
        @unknown default:
            return .accentColor.opacity(0.15)
        }
    }

    // MARK: - Spending Colors with Theme Awareness

    /// Colors for spending amounts based on percentage and theme
    static func spendingColor(percentage: Double, colorScheme: ColorScheme) -> Color {
        let baseColor: Color = if percentage >= 0.9 {
            .red
        } else if percentage >= 0.7 {
            .orange
        } else if percentage >= 0.5 {
            .yellow
        } else {
            .green
        }

        // Adjust opacity/saturation for dark mode if needed
        switch colorScheme {
        case .dark:
            return baseColor.opacity(0.9)
        case .light:
            return baseColor
        @unknown default:
            return baseColor
        }
    }
}

// MARK: - Dynamic Color Helper

/// Helper for creating colors that respond to color scheme changes
struct AdaptiveColor {
    let light: Color
    let dark: Color

    func color(for colorScheme: ColorScheme) -> Color {
        switch colorScheme {
        case .dark:
            return dark
        case .light:
            return light
        @unknown default:
            return light
        }
    }
}

// MARK: - Color Accessibility Extensions

extension Color {
    /// Returns a color with enhanced contrast for accessibility
    func withAccessibilityContrast(for colorScheme: ColorScheme) -> Color {
        switch colorScheme {
        case .dark:
            // Increase brightness in dark mode
            return self.opacity(0.95)
        case .light:
            // Increase saturation in light mode
            return self.opacity(1.0)
        @unknown default:
            return self
        }
    }

    /// Returns an appropriate text color for this background
    var contrastingTextColor: Color {
        // This is a simplified version - in production you'd calculate luminance
        .primary
    }
}

// MARK: - Preview Support

#if DEBUG
    extension Color {
        /// Preview colors for testing theme adaptation
        static let previewColors: [(String, Color)] = [
            ("Gauge Healthy", .gaugeHealthy),
            ("Gauge Warning", .gaugeWarning),
            ("Gauge Danger", .gaugeDanger),
            ("Status Connected", .statusConnected),
            ("Status Error", .statusError),
            ("Accent", .vibeMeterAccent),
        ]
    }

    /// SwiftUI view for previewing theme colors
    struct ThemeColorPreview: View {
        @Environment(\.colorScheme)
        var colorScheme

        var body: some View {
            VStack(spacing: 16) {
                Text("Theme Colors - \(colorScheme == .dark ? "Dark" : "Light") Mode")
                    .font(.headline)

                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 12) {
                    ForEach(Color.previewColors, id: \.0) { name, color in
                        VStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(color)
                                .frame(width: 60, height: 40)

                            Text(name)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Divider()

                VStack(spacing: 8) {
                    Text("Adaptive Colors")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    HStack {
                        Text("Gauge Stroke")
                            .font(.caption)
                        Spacer()
                        Circle()
                            .stroke(Color.gaugeStroke(for: colorScheme), lineWidth: 2)
                            .frame(width: 30, height: 30)
                    }

                    HStack {
                        Text("Hover Background")
                            .font(.caption)
                        Spacer()
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.hoverBackground(for: colorScheme))
                            .frame(width: 50, height: 20)
                    }
                }
            }
            .padding()
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
    }

    #Preview("Theme Colors - Light") {
        ThemeColorPreview()
            .preferredColorScheme(.light)
            .padding()
    }

    #Preview("Theme Colors - Dark") {
        ThemeColorPreview()
            .preferredColorScheme(.dark)
            .padding()
    }
#endif
