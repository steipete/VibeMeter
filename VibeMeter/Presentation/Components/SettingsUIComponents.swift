import SwiftUI
import AppKit

// MARK: - Settings UI Components

/// A modern macOS-style settings section with proper styling
struct SettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder
    let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)
                .padding(.horizontal, 4)

            VStack(spacing: 1) {
                content
            }
            .background(.background.secondary)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color(NSColor.separatorColor).opacity(0.3), lineWidth: 0.5))
        }
    }
}

/// A modern macOS-style settings row with proper padding and styling
struct SettingsRow<Content: View>: View {
    @ViewBuilder
    let content: Content

    var body: some View {
        HStack {
            content
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background.secondary)
    }
}