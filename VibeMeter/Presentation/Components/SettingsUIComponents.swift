import AppKit
import SwiftUI

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

// MARK: - Previews

#Preview("Settings Section") {
    VStack(spacing: 16) {
        SettingsSection(title: "General Settings") {
            SettingsRow {
                Text("Setting 1")
                Spacer()
                Toggle("", isOn: .constant(true))
                    .toggleStyle(.switch)
            }
            
            Divider()
                .padding(.horizontal, 16)
            
            SettingsRow {
                Text("Setting 2")
                Spacer()
                Text("Value")
                    .foregroundStyle(.secondary)
            }
        }
        
        SettingsSection(title: "Advanced Options") {
            SettingsRow {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Complex Setting")
                    Text("Description of the setting")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Configure") {}
                    .buttonStyle(.bordered)
            }
        }
    }
    .padding()
    .frame(width: 400)
    .background(Color(NSColor.windowBackgroundColor))
}

#Preview("Settings Row Variations") {
    VStack(spacing: 1) {
        SettingsRow {
            Label("Toggle Setting", systemImage: "togglepower")
            Spacer()
            Toggle("", isOn: .constant(true))
                .toggleStyle(.switch)
        }
        
        Divider()
            .padding(.horizontal, 16)
        
        SettingsRow {
            Label("Picker Setting", systemImage: "paintbrush")
            Spacer()
            Picker("", selection: .constant("Blue")) {
                Text("Red").tag("Red")
                Text("Blue").tag("Blue")
                Text("Green").tag("Green")
            }
            .pickerStyle(.menu)
            .fixedSize()
        }
        
        Divider()
            .padding(.horizontal, 16)
        
        SettingsRow {
            Label("Action Setting", systemImage: "gear")
            Spacer()
            Button("Action") {}
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
        }
    }
    .background(.background.secondary)
    .clipShape(RoundedRectangle(cornerRadius: 10))
    .padding()
    .frame(width: 450)
    .background(Color(NSColor.windowBackgroundColor))
}
