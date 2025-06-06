import SwiftUI

/// Custom button styles for the VibeMeter application interface.
///
/// This file contains reusable button styles that provide consistent visual design
/// across the application, including glass effects, prominent styles, and icon buttons
/// with proper hover states and animations.

/// Glass-effect button style with subtle transparency and optional destructive styling.
/// Glass-styled button with translucent background and subtle hover effects.
///
/// This button style provides a modern glass-morphism appearance with a blurred
/// background material and smooth hover animations. It's the standard button
/// style used throughout the application for secondary actions.
struct GlassButtonStyle: ButtonStyle {
    let isDestructive: Bool
    @Environment(\.colorScheme)
    private var colorScheme

    init(isDestructive: Bool = false) {
        self.isDestructive = isDestructive
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(configuration.isPressed ?
                            Color.selectionBackground(for: colorScheme) :
                            Color.hoverBackground(for: colorScheme)))
            .foregroundStyle(isDestructive ? .red : .primary)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

/// Prominent button style with gradient background for primary actions.
/// Prominent glass-styled button with stronger visual emphasis.
///
/// A variant of the glass button style with increased opacity and stronger
/// hover effects, used for primary actions that need to stand out in the UI.
/// Features enhanced hover states and more prominent visual feedback.
struct ProminentGlassButtonStyle: ButtonStyle {
    @Environment(\.colorScheme)
    private var colorScheme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(LinearGradient(
                            colors: [
                                Color.vibeMeterAccent.opacity(configuration.isPressed ? 0.6 : 0.8),
                                Color.vibeMeterAccent.opacity(configuration.isPressed ? 0.4 : 0.6),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing)))
            .foregroundStyle(Color.menuBarContent(for: colorScheme))
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

/// Icon button style with circular hover effect and optional destructive styling.
/// Minimalist icon button style with subtle interaction states.
///
/// Designed for icon-only buttons, this style provides a clean appearance
/// with minimal visual weight. Features subtle opacity changes on hover
/// and press states for clear interaction feedback without overwhelming the UI.
struct IconButtonStyle: ButtonStyle {
    let isDestructive: Bool
    @State
    private var isHovering = false
    @Environment(\.colorScheme)
    private var colorScheme

    init(isDestructive: Bool = false) {
        self.isDestructive = isDestructive
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(8)
            .background(
                Circle()
                    .fill((isHovering || configuration.isPressed) ?
                            Color.hoverBackground(for: colorScheme) :
                            Color.clear))
            .foregroundStyle(isDestructive ?
                                (isHovering ? .red : .red.opacity(0.8)) :
                                (isHovering ? .primary : .secondary))
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
            .animation(.easeInOut(duration: 0.15), value: isHovering)
            .onHover { hovering in
                isHovering = hovering
            }
    }
}
