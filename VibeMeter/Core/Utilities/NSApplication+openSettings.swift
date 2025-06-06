import SwiftUI

private let kAppMenuInternalIdentifier = "app"
private let kSettingsLocalizedStringKey = "Settings\\U2026"

extension NSApplication {
    /// Open the application settings/preferences window.
    ///
    /// This method uses SwiftUI's native Settings scene for macOS 15+.
    /// The Settings scene is automatically managed by SwiftUI and integrates
    /// with the standard macOS settings menu item.
    func openSettings() {
        // Ensure the app is active and comes to foreground
        NSApp.activate(ignoringOtherApps: true)

        // For macOS 15+ with SwiftUI Settings scene
        if let internalItemAction = NSApp.mainMenu?.item(
            withInternalIdentifier: kAppMenuInternalIdentifier)?.submenu?.item(
                withLocalizedTitle: kSettingsLocalizedStringKey)?.internalItemAction {
            internalItemAction()

            // Additional step to ensure the settings window comes to front
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(100))

                // Find and bring the settings window to front
                for window in NSApp.windows {
                    if window.title.contains("Settings") || window.title.contains("Preferences") {
                        window.makeKeyAndOrderFront(nil)
                        window.orderFrontRegardless()
                        break
                    }
                }

                // Ensure app stays active
                NSApp.activate(ignoringOtherApps: true)
            }
        }
    }
}

// MARK: - NSMenuItem (Private)

/// NSMenuItem extension for accessing internal properties.
///
/// This private extension provides access to internal menu item properties
/// needed for reliably opening the settings window.
extension NSMenuItem {
    /// An internal SwiftUI menu item identifier that should be a public property on `NSMenuItem`.
    var internalIdentifier: String? {
        guard let id = Mirror.firstChild(
                withLabel: "id", in: self)?.value
        else {
            return nil
        }

        return "\(id)"
    }

    /// A callback which is associated directly with this `NSMenuItem`.
    var internalItemAction: (() -> Void)? {
        guard
            let platformItemAction = Mirror.firstChild(
                withLabel: "platformItemAction", in: self)?.value,
            let typeErasedCallback = Mirror.firstChild(
                in: platformItemAction)?.value
        else {
            return nil
        }

        return Mirror.firstChild(
            in: typeErasedCallback)?.value as? () -> Void
    }
}

// MARK: - NSMenu (Private)

/// NSMenu extension for finding menu items by internal identifier.
///
/// This private extension allows searching for menu items using their
/// internal identifiers, which is more reliable than using titles.
extension NSMenu {
    /// Get the first `NSMenuItem` whose internal identifier string matches the given value.
    func item(withInternalIdentifier identifier: String) -> NSMenuItem? {
        items.first(where: {
            $0.internalIdentifier?.elementsEqual(identifier) ?? false
        })
    }

    /// Get the first `NSMenuItem` whose title is equivalent to the localized string referenced
    /// by the given localized string key in the localization table identified by the given table name
    /// from the bundle located at the given bundle path.
    func item(
        withLocalizedTitle localizedTitleKey: String,
        inTable tableName: String = "MenuCommands",
        fromBundle bundlePath: String = "/System/Library/Frameworks/AppKit.framework") -> NSMenuItem? {
        guard let localizationResource = Bundle(path: bundlePath) else {
            return nil
        }

        return item(withTitle: NSLocalizedString(
                        localizedTitleKey,
                        tableName: tableName,
                        bundle: localizationResource,
                        comment: ""))
    }
}

// MARK: - Mirror (Helper)

/// Mirror extension for safe property access via reflection.
///
/// This private extension provides a safe way to access object properties
/// through reflection, used for accessing internal AppKit properties.
private extension Mirror {
    /// The unconditional first child of the reflection subject.
    var firstChild: Child? { children.first }

    /// The first child of the reflection subject whose label matches the given string.
    func firstChild(withLabel label: String) -> Child? {
        children.first(where: {
            $0.label?.elementsEqual(label) ?? false
        })
    }

    /// The unconditional first child of the given subject.
    static func firstChild(in subject: Any) -> Child? {
        Mirror(reflecting: subject).firstChild
    }

    /// The first child of the given subject whose label matches the given string.
    static func firstChild(
        withLabel label: String, in subject: Any) -> Child? {
        Mirror(reflecting: subject).firstChild(withLabel: label)
    }
}
