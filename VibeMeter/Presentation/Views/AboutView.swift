import SwiftUI
import AppKit

struct AboutView: View {
    var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
        return "\(version) (\(build))"
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                appInfoSection
                descriptionSection
                linksSection

                Spacer(minLength: 40)

                copyrightSection
            }
            .frame(maxWidth: .infinity)
            .padding()
        }
        .scrollContentBackground(.hidden)
    }

    private var appInfoSection: some View {
        VStack(spacing: 16) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 128, height: 128)

            Text("VibeMeter")
                .font(.largeTitle)
                .fontWeight(.medium)

            Text("Version \(appVersion)")
                .foregroundStyle(.secondary)
        }
        .padding(.top, 20)
    }

    private var descriptionSection: some View {
        Text("Monitor your monthly Cursor AI spending")
            .foregroundStyle(.secondary)
    }

    private var linksSection: some View {
        VStack(spacing: 12) {
            Link(destination: URL(string: "https://github.com/steipete/VibeMeter")!) {
                Label("View on GitHub", systemImage: "link")
            }
            .buttonStyle(.link)

            Link(destination: URL(string: "https://github.com/steipete/VibeMeter/issues")!) {
                Label("Report an Issue", systemImage: "exclamationmark.bubble")
            }
            .buttonStyle(.link)
        }
    }

    private var copyrightSection: some View {
        Text("© 2025 Peter Steinberger • MIT Licensed")
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.bottom, 32)
    }
}