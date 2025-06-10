import Foundation
import SwiftUI

/// A gauge icon for the menu bar that displays spending as a percentage of the limit.
///
/// GaugeIcon renders a circular gauge with a colored arc representing the current
/// spending level. It supports both static display and animated loading states,
/// adapts to light/dark mode, and uses a color gradient from teal to red based
/// on the spending percentage. The gauge accepts values between 0 and 1.
struct GaugeIcon: View {
    var value: Double
    var isLoading: Bool = false
    var isDisabled: Bool = false
    var animateOnAppear: Bool = false

    @Environment(\.colorScheme)
    private var colorScheme

    @State
    private var animationProgress: Double = 1.0

    @State
    private var shimmerPhase: Double = 0

    private let lineRatio = 0.18 // stroke thickness vs. frame
    private let startAngle = 180.0 // ° (middle left/9 o'clock)
    private let sweepAngle = 180.0 // clockwise span to middle right/3 o'clock (upper semicircle)

    var body: some View {
        Canvas { ctx, size in
            let line = size.width * lineRatio
            // Add margin by reducing radius further
            let margin = size.width * 0.1 // 10% margin
            let radius = size.width / 2 - line / 2 - margin
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let trackPath = Path { p in
                p.addArc(center: center,
                         radius: radius,
                         startAngle: .degrees(startAngle),
                         endAngle: .degrees(startAngle + sweepAngle * animationProgress),
                         clockwise: false)
            }
            let progPath = Path { p in
                p.addArc(center: center,
                         radius: radius,
                         startAngle: .degrees(startAngle),
                         endAngle: .degrees(startAngle + sweepAngle * value * animationProgress),
                         clockwise: false)
            }

            // Draw track (always visible) - adjust for appearance with better dark mode contrast
            let trackColor = isDisabled
                ? Color.gaugeDisabled(for: colorScheme)
                : Color.gaugeStroke(for: colorScheme)

            if isLoading {
                // Add shimmer effect to track during loading - brighter for dark mode
                let shimmerOpacityRange = colorScheme == .dark
                    ? (min: 0.7, max: 1.0) // Bright shimmer for dark mode
                    : (min: 0.3, max: 0.8) // Subtle shimmer for light mode
                let shimmerOpacityMid = colorScheme == .dark ? 0.9 : 0.6

                let shimmerGradient = Gradient(colors: [
                    trackColor.opacity(shimmerOpacityRange.min),
                    trackColor.opacity(shimmerOpacityRange.max),
                    Color.menuBarContent(for: colorScheme).opacity(shimmerOpacityMid),
                    trackColor.opacity(shimmerOpacityRange.max),
                    trackColor.opacity(shimmerOpacityRange.min),
                ])

                // Calculate shimmer position along the arc for upper half-circle
                // shimmerPhase goes from 0.0 to 1.0, we want shimmer to go from left (180°) to right (0°/360°)
                let shimmerStartAngle = startAngle + (sweepAngle * shimmerPhase * 0.8)

                ctx.stroke(trackPath,
                           with: .conicGradient(
                               shimmerGradient,
                               center: center,
                               angle: Angle(degrees: shimmerStartAngle)),
                           style: StrokeStyle(lineWidth: line, lineCap: .round))
            } else {
                ctx.stroke(trackPath,
                           with: .color(trackColor),
                           style: StrokeStyle(lineWidth: line, lineCap: .round))
            }

            // Only draw progress arc if not disabled
            if !isDisabled {
                // Progress arc with color
                let fillColor = isLoading ? loadingColor(for: value) : color(for: value)
                ctx.stroke(progPath,
                           with: .color(fillColor),
                           style: StrokeStyle(lineWidth: line, lineCap: .round))

                // Add shimmer effect for loading state - brighter for dark mode
                if isLoading {
                    let shimmerPath = progPath
                    let progressShimmerOpacity = colorScheme == .dark ? 0.8 : 0.3
                    ctx.stroke(shimmerPath,
                               with: .linearGradient(
                                   Gradient(colors: [
                                       Color.menuBarContent(for: colorScheme).opacity(progressShimmerOpacity),
                                       Color.menuBarContent(for: colorScheme).opacity(0),
                                   ]),
                                   startPoint: .zero,
                                   endPoint: CGPoint(x: size.width, y: 0)),
                               style: StrokeStyle(lineWidth: line * 0.8, lineCap: .round))
                }

                // optional needle
                let needleLen = radius * 0.82
                let animatedEndAngle = startAngle + sweepAngle * value * animationProgress
                let rad = Double(animatedEndAngle) * .pi / 180
                let tip = CGPoint(x: center.x + needleLen * CGFloat(Foundation.cos(rad)),
                                  y: center.y + needleLen * CGFloat(Foundation.sin(rad)))
                var needle = Path()
                needle.move(to: center)
                needle.addLine(to: tip)
                // Needle color should work for both light and dark mode
                let needleColor = isLoading
                    ? Color.menuBarContent(for: colorScheme).opacity(0.7)
                    : Color.menuBarContent(for: colorScheme)
                ctx.stroke(needle,
                           with: .color(needleColor),
                           style: StrokeStyle(lineWidth: line * 0.5, lineCap: .round))
            }
        }
        .frame(width: 22, height: 22) // menu-bar size (@1×; doubles on Retina)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(accessibilityValue)
        .accessibilityHint("Gauge showing AI service spending level")
        .drawingGroup() // Optimize canvas rendering for macOS 15+
        .onAppear {
            if animateOnAppear {
                animationProgress = 0.0
                withAnimation(.easeOut(duration: 0.6)) {
                    animationProgress = 1.0
                }
            }

            // Start shimmer animation if loading
            if isLoading {
                withAnimation(.linear(duration: 2.0).repeatForever(autoreverses: false)) {
                    shimmerPhase = 1.0
                }
            }
        }
        .onChange(of: isLoading) { _, newValue in
            if newValue {
                // Start shimmer when loading begins
                shimmerPhase = 0.0
                withAnimation(.linear(duration: 2.0).repeatForever(autoreverses: false)) {
                    shimmerPhase = 1.0
                }
            } else {
                // Stop shimmer when loading ends
                shimmerPhase = 0.0
            }
        }
    }

    // MARK: - Accessibility Support

    /// Accessibility label for VoiceOver
    private var accessibilityLabel: String {
        if isDisabled {
            "Spending gauge - disabled"
        } else if isLoading {
            "Spending gauge - loading data"
        } else {
            "Spending gauge"
        }
    }

    /// Accessibility value for VoiceOver
    private var accessibilityValue: String {
        if isDisabled {
            return "No data available"
        } else if isLoading {
            return "Loading spending information"
        } else {
            let percentage = Int((value * 100).rounded())
            let level = switch percentage {
            case 0 ..< 50:
                "Low usage"
            case 50 ..< 80:
                "Moderate usage"
            case 80 ..< 100:
                "High usage, approaching limit"
            default:
                "Over limit"
            }
            return "\(percentage) percent. \(level)"
        }
    }

    /// Progressive gauge colors with greenish tint for low usage
    /// Transitions from green (low) -> blue (medium) -> orange (high) -> red (over limit)
    private func color(for v: Double) -> Color {
        let clampedValue = max(0.0, min(1.0, v))

        switch clampedValue {
        case 0.0 ..< 0.25:
            // Low usage: Green with some blue tint
            let ratio = clampedValue / 0.25
            return Color.green.blend(with: .cyan, ratio: 0.3).opacity(0.7 + ratio * 0.3)
        case 0.25 ..< 0.5:
            // Low-medium: Cyan to blue
            let ratio = (clampedValue - 0.25) / 0.25
            return Color.cyan.blend(with: .blue, ratio: ratio).opacity(0.8)
        case 0.5 ..< 0.8:
            // Medium-high: Blue to orange
            let ratio = (clampedValue - 0.5) / 0.3
            return Color.blue.blend(with: .orange, ratio: ratio).opacity(0.9)
        default:
            // High/over limit: Orange to red
            let ratio = min(1.0, (clampedValue - 0.8) / 0.2)
            return Color.orange.blend(with: .red, ratio: ratio).opacity(1.0)
        }
    }

    /// Loading state with subtle color animation
    /// Uses a gentle color pulse between blue and cyan
    private func loadingColor(for _: Double) -> Color {
        let baseColor = Color.blue
        let pulseColor = Color.cyan
        let pulseAmount = 0.5 + 0.5 * sin(Date().timeIntervalSinceReferenceDate * 2)
        return baseColor.blend(with: pulseColor, ratio: pulseAmount).opacity(0.8)
    }
}

/// Color extension providing color blending functionality.
///
/// This private extension adds the ability to blend two colors together
/// with a specified ratio, useful for creating smooth color gradients
/// in the gauge display.
private extension Color {
    func blend(with other: Color, ratio: Double) -> Color {
        let nsColor1 = NSColor(self).usingColorSpace(.deviceRGB)!
        let r1 = nsColor1.redComponent
        let g1 = nsColor1.greenComponent
        let b1 = nsColor1.blueComponent

        let nsColor2 = NSColor(other).usingColorSpace(.deviceRGB)!
        let r2 = nsColor2.redComponent
        let g2 = nsColor2.greenComponent
        let b2 = nsColor2.blueComponent

        return Color(red: r1 + (r2 - r1) * ratio,
                     green: g1 + (g2 - g1) * ratio,
                     blue: b1 + (b2 - b1) * ratio)
    }
}

// MARK: - Preview

#Preview("Gauge Icon - Various Values") {
    VStack(spacing: 20) {
        HStack(spacing: 30) {
            ForEach([0.0, 0.25, 0.5, 0.75, 1.0], id: \.self) { value in
                VStack {
                    GaugeIcon(value: value)
                        .scaleEffect(2) // Make it easier to see in preview
                    Text("\(Int(value * 100))%")
                        .font(.caption)
                }
            }
        }

        // Animated preview
        TimelineView(.animation) { timeline in
            let progress = (sin(timeline.date.timeIntervalSinceReferenceDate) + 1) / 2
            VStack {
                GaugeIcon(value: progress)
                    .scaleEffect(4)
                Text("\(Int(progress * 100))%")
                    .font(.title3)
            }
        }
    }
    .padding()
    .frame(width: 400, height: 300)
}
