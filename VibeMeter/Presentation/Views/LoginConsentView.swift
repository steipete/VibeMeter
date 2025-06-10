import SwiftUI

/// View showing consent information before Cursor login
struct LoginConsentView: View {
    let provider: ServiceProvider
    let onAccept: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 12) {
                Image(systemName: "lock.shield")
                    .font(.system(size: 48))
                    .foregroundStyle(.blue)
                
                Text("Secure Login Information")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("How we handle your \(provider.displayName) credentials")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            // Info sections
            VStack(alignment: .leading, spacing: 20) {
                InfoRow(
                    icon: "key.fill",
                    title: "Credential Storage",
                    description: "Your login credentials will be captured during the login process and stored securely in your macOS Keychain.")
                
                InfoRow(
                    icon: "arrow.clockwise",
                    title: "Automatic Re-authentication",
                    description: "When your session expires, we'll automatically log you back in using the stored credentials to ensure uninterrupted service.")
                
                InfoRow(
                    icon: "exclamationmark.triangle",
                    title: "CAPTCHA Requirements",
                    description: "Occasionally, \(provider.displayName) may require you to solve a CAPTCHA. When this happens, we'll send you a notification to complete the login manually.")
                
                InfoRow(
                    icon: "info.circle",
                    title: "Why We Need This",
                    description: "Since there's no official API for cost data yet, this allows us to maintain your session and continue tracking your spending.")
            }
            .padding(.horizontal)
            
            // Privacy note
            HStack(spacing: 8) {
                Image(systemName: "lock.fill")
                    .font(.caption)
                Text("Your credentials never leave your device and are only used for \(provider.displayName) authentication.")
                    .font(.caption)
            }
            .foregroundStyle(.secondary)
            .padding(.horizontal)
            
            // Action buttons
            HStack(spacing: 12) {
                Button("Cancel") {
                    onCancel()
                }
                .buttonStyle(.bordered)
                .keyboardShortcut(.cancelAction)
                
                Button("Accept & Continue") {
                    onAccept()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
            .padding(.top)
        }
        .padding(32)
        .frame(width: 520)
        .fixedSize()
    }
}

struct InfoRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.blue)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// MARK: - Preview

#Preview("Login Consent") {
    LoginConsentView(
        provider: .cursor,
        onAccept: { print("Accepted") },
        onCancel: { print("Cancelled") }
    )
    .background(Color(NSColor.windowBackgroundColor))
}
