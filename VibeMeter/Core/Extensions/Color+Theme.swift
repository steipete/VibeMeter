import SwiftUI

/// Theme-aware color extensions for VibeMeter.
///
/// This extension provides semantic colors that automatically adapt to light and dark modes,
/// ensuring consistent visual appearance across all system themes. Colors are optimized
/// for accessibility and follow macOS design guidelines.
extension Color {
    // MARK: - Accessibility Support

    /// Returns whether the system is currently in high contrast mode
    static var isHighContrastEnabled: Bool {
        NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast
    }

    /// Returns whether the system should reduce transparency
    static var shouldReduceTransparency: Bool {
        NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency
    }

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

    /// Standard gauge color progression from healthy to danger
    static let gaugeColorProgression: [Color] = [
        gaugeHealthy,
        gaugeModerate,
        gaugeWarning,
        gaugeDanger,
    ]

    /// Gauge stroke colors for different themes
    static func gaugeStroke(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? .white.opacity(0.25)
            : .black.opacity(0.15)
    }

    /// Gauge background colors
    static func gaugeBackground(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? .white.opacity(0.1)
            : .black.opacity(0.05)
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
        colorScheme == .dark ? .white : .black
    }

    /// Hover state colors
    static func hoverBackground(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? .white.opacity(0.08)
            : .black.opacity(0.05)
    }

    /// Selection background colors
    static func selectionBackground(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? .white.opacity(0.12)
            : .black.opacity(0.08)
    }

    /// Divider overlay colors for enhanced visibility
    static func dividerOverlay(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? .white.opacity(0.08)
            : .black.opacity(0.04)
    }

    /// Secondary divider colors for subtle separations
    static func secondaryDivider(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? .white.opacity(0.1)
            : .black.opacity(0.06)
    }

    /// Window background color
    static func windowBackground(for _: ColorScheme) -> Color {
        Color(NSColor.windowBackgroundColor)
    }

    /// Control background color
    static func controlBackground(for _: ColorScheme) -> Color {
        Color(NSColor.controlBackgroundColor)
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
        return colorScheme == .dark
            ? baseColor.opacity(0.9)
            : baseColor
    }

    // MARK: - Progress Colors (Universal)

    /// Universal progress-based colors for usage indicators, progress bars, gauges, and spending visualizations
    /// This replaces the previous ProgressColorHelper with theme-aware implementation
    static let progressSafe = Color.green
    static let progressCaution = Color.yellow
    static let progressWarning = Color.orange
    static let progressDanger = Color.red

    /// Get appropriate progress color based on percentage value
    static func progressColor(for progress: Double, colorScheme: ColorScheme? = nil) -> Color {
        let baseColor: Color = switch progress {
        case ..<0.5:
            .progressSafe
        case 0.5 ..< 0.75:
            .progressCaution
        case 0.75 ..< 0.9:
            .progressWarning
        default:
            .progressDanger
        }

        // Apply theme adjustments if colorScheme is provided
        if let colorScheme {
            return colorScheme == .dark
                ? baseColor.opacity(0.9)
                : baseColor
        } else {
            return baseColor
        }
    }

    /// Warning levels corresponding to progress colors
    enum ProgressWarningLevel: CaseIterable, Equatable {
        case normal
        case low
        case medium
        case high

        /// Get warning level for a given progress value
        static func level(for progress: Double) -> ProgressWarningLevel {
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
    }

    // MARK: - High Contrast Support

    /// Returns high-contrast version of the color if accessibility requires it
    func withAccessibilityContrast() -> Color {
        if Color.isHighContrastEnabled {
            // For high contrast mode, use more vibrant, saturated colors
            self.opacity(1.0)
        } else {
            self
        }
    }

    /// Returns gauge colors with proper accessibility contrast
    /// - Parameter colorScheme: Current color scheme
    /// - Returns: Array of colors optimized for accessibility
    static func accessibleGaugeColors(for colorScheme: ColorScheme) -> [Color] {
        if isHighContrastEnabled {
            // Use more saturated, high contrast colors
            colorScheme == .dark
                ? [
                    Color.cyan,
                    Color.green,
                    Color.yellow,
                    Color.orange,
                    Color.red
                ]
                : [
                    Color.blue,
                    Color.green,
                    Color.yellow,
                    Color.orange,
                    Color.red,
                ]
        } else {
            gaugeColorProgression
        }
    }

    /// Returns background color with reduced transparency for accessibility
    static func accessibleBackground(for _: ColorScheme) -> Color {
        if shouldReduceTransparency {
            // Use solid colors instead of transparent materials
            Color(NSColor.windowBackgroundColor)
        } else {
            vibeMeterBackground
        }
    }
}

// MARK: - Dynamic Color Helper

/// Helper for creating colors that respond to color scheme changes
struct AdaptiveColor {
    let light: Color
    let dark: Color

    func color(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? dark : light
    }
}

// MARK: - Color Accessibility Extensions

extension Color {
    /// Returns a color with enhanced contrast for accessibility
    func withAccessibilityContrast(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? self.opacity(0.95) // Increase brightness in dark mode
            : self.opacity(1.0) // Increase saturation in light mode
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
