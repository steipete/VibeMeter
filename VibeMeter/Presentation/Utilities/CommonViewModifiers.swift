import SwiftUI

/// Common view modifiers to eliminate UI styling duplication across the app.
///
/// These modifiers provide consistent styling patterns for material backgrounds,
/// standard padding, and other frequently used UI configurations.

// MARK: - Material Background Modifier

/// Applies a rounded rectangle background with material fill.
struct MaterialBackgroundModifier: ViewModifier {
    let cornerRadius: CGFloat
    let material: Material

    init(cornerRadius: CGFloat = 10, material: Material = .thickMaterial) {
        self.cornerRadius = cornerRadius
        self.material = material
    }

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(material))
    }
}

// MARK: - Standard Padding Modifier

/// Applies standard horizontal and vertical padding used throughout the app.
struct StandardPaddingModifier: ViewModifier {
    let horizontal: CGFloat
    let vertical: CGFloat

    init(horizontal: CGFloat = 16, vertical: CGFloat = 14) {
        self.horizontal = horizontal
        self.vertical = vertical
    }

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, horizontal)
            .padding(.vertical, vertical)
    }
}

// MARK: - Card Style Modifier

/// Combines material background with standard padding for card-like components.
struct CardStyleModifier: ViewModifier {
    let cornerRadius: CGFloat
    let horizontalPadding: CGFloat
    let verticalPadding: CGFloat

    init(
        cornerRadius: CGFloat = 10,
        horizontalPadding: CGFloat = 14,
        verticalPadding: CGFloat = 10) {
        self.cornerRadius = cornerRadius
        self.horizontalPadding = horizontalPadding
        self.verticalPadding = verticalPadding
    }

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .materialBackground(cornerRadius: cornerRadius)
    }
}

// MARK: - View Extensions

public extension View {
    /// Applies a material background with rounded corners.
    ///
    /// - Parameters:
    ///   - cornerRadius: Corner radius for the rounded rectangle (default: 10)
    ///   - material: Material type to use (default: .thickMaterial)
    func materialBackground(
        cornerRadius: CGFloat = 10,
        material: Material = .thickMaterial) -> some View {
        modifier(MaterialBackgroundModifier(cornerRadius: cornerRadius, material: material))
    }

    /// Applies standard padding used throughout the app.
    ///
    /// - Parameters:
    ///   - horizontal: Horizontal padding (default: 16)
    ///   - vertical: Vertical padding (default: 14)
    func standardPadding(
        horizontal: CGFloat = 16,
        vertical: CGFloat = 14) -> some View {
        modifier(StandardPaddingModifier(horizontal: horizontal, vertical: vertical))
    }

    /// Applies card styling with material background and padding.
    ///
    /// - Parameters:
    ///   - cornerRadius: Corner radius for the card (default: 10)
    ///   - horizontalPadding: Horizontal padding (default: 14)
    ///   - verticalPadding: Vertical padding (default: 10)
    func cardStyle(
        cornerRadius: CGFloat = 10,
        horizontalPadding: CGFloat = 14,
        verticalPadding: CGFloat = 10) -> some View {
        modifier(CardStyleModifier(
            cornerRadius: cornerRadius,
            horizontalPadding: horizontalPadding,
            verticalPadding: verticalPadding))
    }
}

// MARK: - Previews

#Preview("Material Backgrounds") {
    VStack(spacing: 20) {
        Text("Thick Material")
            .standardPadding()
            .materialBackground(material: .thickMaterial)

        Text("Regular Material")
            .standardPadding()
            .materialBackground(material: .regular)

        Text("Thin Material")
            .standardPadding()
            .materialBackground(material: .thin)

        Text("Ultra Thin Material")
            .standardPadding()
            .materialBackground(material: .ultraThin)
    }
    .padding()
    .frame(width: 300)
    .background(Color(NSColor.windowBackgroundColor))
}

#Preview("Card Styles") {
    VStack(spacing: 16) {
        VStack(alignment: .leading, spacing: 8) {
            Text("Default Card Style")
                .font(.headline)
            Text("With standard padding and corner radius")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()

        VStack(alignment: .leading, spacing: 8) {
            Text("Custom Card Style")
                .font(.headline)
            Text("With larger padding and corner radius")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle(cornerRadius: 16, horizontalPadding: 20, verticalPadding: 16)
    }
    .padding()
    .frame(width: 350)
    .background(Color(NSColor.windowBackgroundColor))
}

#Preview("Standard Padding") {
    VStack(spacing: 16) {
        HStack {
            Text("Default Padding")
            Spacer()
            Text("16pt H, 14pt V")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .standardPadding()
        .background(Color.blue.opacity(0.1))

        HStack {
            Text("Custom Padding")
            Spacer()
            Text("24pt H, 20pt V")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .standardPadding(horizontal: 24, vertical: 20)
        .background(Color.green.opacity(0.1))
    }
    .padding()
    .frame(width: 400)
    .background(Color(NSColor.windowBackgroundColor))
}
