import AppKit
import Combine
import SwiftUI

@MainActor
class MenuBarController {
    private var statusItem: NSStatusItem
    private var menu: NSMenu
    private var dataCoordinator: RealDataCoordinator
    private var cancellables = Set<AnyCancellable>()
    private var menuBuilder: MenuBarMenuBuilder?

    // DataCoordinator provides all the state we need

    // Settings window
    private var settingsWindow: NSWindow?

    init(dataCoordinator: RealDataCoordinator = DataCoordinator.shared as! RealDataCoordinator) {
        self.dataCoordinator = dataCoordinator
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        menu = NSMenu()
        menuBuilder = MenuBarMenuBuilder(controller: self, dataCoordinator: dataCoordinator)

        setupStatusBarButton()
        setupBindings()
        updateMenu()
        updateMenuButtonText(newText: dataCoordinator.menuBarDisplayText)
    }

    private func setupStatusBarButton() {
        // Set icon and ensure it's always visible
        if let button = statusItem.button {
            if let iconImage = NSImage(named: "menubar-icon") {
                iconImage.isTemplate = true // Allows macOS to style it (dark/light mode)

                // Optimize icon size for menu bar
                iconImage.size = NSSize(width: 18, height: 18)

                button.image = iconImage
                button.imagePosition = .imageOnly // Start with icon only
                LoggingService.info("Menu bar icon loaded successfully.", category: .ui)
            } else {
                LoggingService.error("menubar-icon.png not found. Using default text title.", category: .ui)
                button.title = "VM"
                button.image = nil
            }

            // Ensure button is always visible
            button.isEnabled = true
        }
    }

    private func setupBindings() {
        // Observe changes from DataCoordinator
        dataCoordinator.$menuBarDisplayText
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newText in
                self?.updateMenuButtonText(newText: newText)
            }
            .store(in: &cancellables)

        // Observe other properties as needed to rebuild the menu dynamically
        dataCoordinator.objectWillChange // A more general way to catch any change
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateMenu()
            }
            .store(in: &cancellables)
    }

    private func updateMenuButtonText(newText: String?) {
        if let button = statusItem.button {
            let text = newText ?? ""

            // When not logged in, show only icon (no text)
            if !dataCoordinator.isLoggedIn {
                button.title = ""
                button.imagePosition = .imageOnly
                return
            }

            // When logged in, show both icon and text if text is available
            button.title = text
            if !text.isEmpty, button.image != nil {
                button.imagePosition = .imageLeading
            } else if button.image != nil {
                button.imagePosition = .imageOnly
            }
        }
    }

    func updateMenu() { // Changed to public if DataCoordinator needs to trigger it, though binding is preferred
        guard let menuBuilder else { return }
        let newMenu = menuBuilder.buildMenu()
        statusItem.menu = newMenu
        menu = newMenu
    }

    // MARK: - Actions

    @objc func loginClicked() {
        LoggingService.info("Login clicked.", category: .ui)
        dataCoordinator.initiateLoginFlow()
    }

    @objc func logOutClicked() {
        LoggingService.info("Log Out clicked.", category: .ui)
        dataCoordinator.userDidRequestLogout() // Correctly call the protocol method
    }

    @objc func refreshNowClicked() {
        LoggingService.info("Refresh Now action triggered from menu.", category: .ui)
        // Only refresh if logged in, don't trigger login automatically
        if dataCoordinator.isLoggedIn {
            Task {
                await dataCoordinator.forceRefreshData(showSyncedMessage: true)
            }
        } else {
            LoggingService.info("Not logged in, skipping refresh.", category: .ui)
        }
    }

    @objc func settingsClicked() {
        LoggingService.info("Open Settings action triggered from menu.", category: .ui)

        // Use the new openSettings extension method
        NSApp.openSettings()
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc func toggleLaunchAtLogin() {
        let newState = !dataCoordinator.settingsManager.launchAtLoginEnabled
        LoggingService.info("Toggle Launch at Login action triggered from menu. New state: \(newState)", category: .ui)
        dataCoordinator.settingsManager.launchAtLoginEnabled = newState
        // Menu will be rebuilt by MenuBarMenuBuilder with the new state
    }

    @objc func checkForUpdates() {
        LoggingService.info("Check for Updates action triggered from menu.", category: .ui)
        // Get the Sparkle updater from the app delegate
        if let appDelegate = NSApplication.shared.delegate as? AppDelegate,
           let sparkleManager = appDelegate.sparkleUpdaterManager
        {
            sparkleManager.updaterController.checkForUpdates(nil)
        }
    }

    // State updates are handled automatically through DataCoordinator's @Published properties
    // The setupBindings() method observes these changes and updates the UI accordingly
}
