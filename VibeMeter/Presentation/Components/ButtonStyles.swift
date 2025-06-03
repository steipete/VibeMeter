import SwiftUI

struct GlassButtonStyle: ButtonStyle {
    let isDestructive: Bool

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
                        Color.white.opacity(0.2) :
                        Color.white.opacity(0.1)))
            .foregroundStyle(isDestructive ? .red : .primary)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct ProminentGlassButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(LinearGradient(
                        colors: [
                            Color.blue.opacity(configuration.isPressed ? 0.6 : 0.8),
                            Color.purple.opacity(configuration.isPressed ? 0.6 : 0.8),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing)))
            .foregroundStyle(.white)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct IconButtonStyle: ButtonStyle {
    let isDestructive: Bool
    @State
    private var isHovering = false

    init(isDestructive: Bool = false) {
        self.isDestructive = isDestructive
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(8)
            .background(
                Circle()
                    .fill((isHovering || configuration.isPressed) ?
                        Color.white.opacity(0.15) :
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
