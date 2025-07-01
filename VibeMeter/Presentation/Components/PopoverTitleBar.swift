import SwiftUI
import AppKit

/// Title bar for the popover with settings and close buttons
struct PopoverTitleBar: View {
    var body: some View {
        HStack(spacing: 8) {
            // Settings button
            Button(action: openSettings) {
                Image(systemName: "gearshape")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .frame(width: 16, height: 16)
            }
            .buttonStyle(.plain)
            .help("Settings (⌘,)")
            .keyboardShortcut(",", modifiers: .command)
            
            Spacer()
            
            // Title (optional - could add "VibeMeter" text here)
            
            Spacer()
            
            // Close button
            Button(action: closePopover) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .frame(width: 16, height: 16)
            }
            .buttonStyle(.plain)
            .help("Close (Esc)")
            .keyboardShortcut(.escape, modifiers: [])
        }
        .frame(height: 24)
    }
    
    private func openSettings() {
        NSApp.openSettings()
    }
    
    private func closePopover() {
        // Find and close the custom menu window
        for window in NSApp.windows {
            if window.styleMask.contains(.borderless), 
               window.isVisible,
               window.level == .popUpMenu {
                window.orderOut(nil)
                break
            }
        }
    }
}

// MARK: - Preview

#Preview {
    PopoverTitleBar()
        .padding()
        .frame(width: 320)
        .background(Color(NSColor.windowBackgroundColor))
}