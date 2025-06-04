import SwiftUI

// MARK: - Shimmer Effect Modifier

/// Applies a shimmer effect compatible with drawingGroup() for loading states.
struct ShimmerEffectModifier: ViewModifier {
    @State
    private var animationPhase: CGFloat = 0
    @Environment(\.colorScheme)
    private var colorScheme

    func body(content: Content) -> some View {
        content
            .redacted(reason: .placeholder)
            .overlay(
                Canvas { context, size in
                    let shimmerWidth = size.width * 0.3
                    let startX = (animationPhase - 0.15) * size.width
                    let endX = startX + shimmerWidth

                    let gradient = Gradient(colors: [
                        Color.clear,
                        shimmerColor.opacity(0.6),
                        shimmerColor.opacity(0.8),
                        shimmerColor.opacity(0.6),
                        Color.clear,
                    ])

                    let shimmerRect = CGRect(
                        x: startX,
                        y: 0,
                        width: shimmerWidth,
                        height: size.height)

                    context.fill(
                        Path(shimmerRect),
                        with: .linearGradient(
                            gradient,
                            startPoint: CGPoint(x: startX, y: 0),
                            endPoint: CGPoint(x: endX, y: 0)))
                })
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .onAppear {
                withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    animationPhase = 1.15
                }
            }
    }

    /// Shimmer color that adapts to the current color scheme
    private var shimmerColor: Color {
        colorScheme == .dark ? .white : .black
    }
}

// MARK: - View Extension

public extension View {
    /// Applies a shimmer effect for loading states, compatible with drawingGroup().
    ///
    /// This modifier combines `.redacted(reason: .placeholder)` with a custom Canvas-based
    /// shimmer animation that works smoothly with `drawingGroup()` optimization.
    ///
    /// Usage:
    /// ```swift
    /// Text("Loading...")
    ///     .shimmer()
    ///
    /// RoundedRectangle(cornerRadius: 4)
    ///     .fill(Color.secondary.opacity(0.2))
    ///     .frame(width: 100, height: 20)
    ///     .shimmer()
    /// ```
    func shimmer() -> some View {
        modifier(ShimmerEffectModifier())
    }
}

// MARK: - Shimmer Shape Components

/// Pre-built shimmer shapes for common loading states
public enum ShimmerShapes {
    /// Shimmer rectangle for text placeholders
    /// - Parameters:
    ///   - width: Width of the shimmer rectangle
    ///   - height: Height of the shimmer rectangle
    ///   - cornerRadius: Corner radius for the rectangle
    @MainActor
    public static func text(width: CGFloat, height: CGFloat, cornerRadius: CGFloat = 4) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(Color.secondary.opacity(0.2))
            .frame(width: width, height: height)
            .shimmer()
    }

    /// Shimmer circle for avatar placeholders
    /// - Parameter diameter: Diameter of the shimmer circle
    @MainActor
    public static func circle(diameter: CGFloat) -> some View {
        Circle()
            .fill(Color.secondary.opacity(0.2))
            .frame(width: diameter, height: diameter)
            .shimmer()
    }

    /// Shimmer rectangle for spending amount placeholders
    @MainActor
    public static var spendingAmount: some View {
        text(width: 60, height: 20, cornerRadius: 4)
            .accessibilityLabel("Loading spending data")
    }

    /// Shimmer rectangle for usage text placeholders
    @MainActor
    public static var usageText: some View {
        text(width: 45, height: 12, cornerRadius: 3)
            .accessibilityLabel("Loading usage data")
    }

    /// Shimmer rectangle for progress bar placeholders
    /// - Parameter width: Width of the progress bar
    @MainActor
    public static func progressBar(width: CGFloat) -> some View {
        text(width: width, height: 3, cornerRadius: 1.5)
            .accessibilityLabel("Loading progress data")
    }

    /// Shimmer rectangle for total spending display
    @MainActor
    public static var totalSpending: some View {
        text(width: 100, height: 28, cornerRadius: 6)
            .accessibilityLabel("Loading total spending")
    }
}

// MARK: - Preview

#Preview("Shimmer Effects") {
    VStack(spacing: 20) {
        VStack(alignment: .leading, spacing: 8) {
            Text("Text Shimmer")
                .font(.headline)

            VStack(alignment: .leading, spacing: 4) {
                Text("Normal text")
                Text("Loading text placeholder...")
                    .shimmer()
            }
        }

        VStack(alignment: .leading, spacing: 8) {
            Text("Shape Shimmers")
                .font(.headline)

            HStack(spacing: 12) {
                VStack(spacing: 4) {
                    Text("Spending")
                        .font(.caption)
                    ShimmerShapes.spendingAmount
                }

                VStack(spacing: 4) {
                    Text("Usage")
                        .font(.caption)
                    ShimmerShapes.usageText
                }

                VStack(spacing: 4) {
                    Text("Progress")
                        .font(.caption)
                    ShimmerShapes.progressBar(width: 60)
                }

                VStack(spacing: 4) {
                    Text("Avatar")
                        .font(.caption)
                    ShimmerShapes.circle(diameter: 24)
                }
            }
        }

        VStack(alignment: .leading, spacing: 8) {
            Text("Total Spending")
                .font(.headline)

            HStack {
                Text("Total Spending")
                    .font(.body.weight(.medium))
                    .foregroundStyle(.secondary)

                Spacer()

                ShimmerShapes.totalSpending
            }
            .padding()
            .background(Color.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
        }
    }
    .padding()
    .frame(width: 350)
    .background(Color(NSColor.windowBackgroundColor))
}
