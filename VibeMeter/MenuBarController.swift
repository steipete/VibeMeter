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

    // Menu items that need to be updated
    private var loggedInAsMenuItem: NSMenuItem?
    private var currentSpendingMenuItem: NSMenuItem?
    private var warningLimitMenuItem: NSMenuItem?
    private var upperLimitMenuItem: NSMenuItem?
    private var teamMenuItem: NSMenuItem?
    private var launchAtLoginMenuItem: NSMenuItem?
    private var vibeMeterStatusMenuItem: NSMenuItem? // For contextual messages

    init(dataCoordinator: RealDataCoordinator = DataCoordinator.shared as! RealDataCoordinator) {
        self.dataCoordinator = dataCoordinator
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        menu = NSMenu()
        statusItem.menu = menu // Assign menu to statusItem here
        menuBuilder = MenuBarMenuBuilder(controller: self, dataCoordinator: dataCoordinator)

        setupMenu()
        setupBindings()
        updateMenu()
        updateMenuButtonText(newText: dataCoordinator.menuBarDisplayText)

        // Set icon (ensure menubar-icon.png is in your assets)
        if let button = statusItem.button {
            if let iconImage = NSImage(named: "menubar-icon") {
                iconImage.isTemplate = true // Allows macOS to style it (dark/light mode)
                button.image = iconImage
                button.imagePosition = .imageOnly // Show only icon initially, text will be added when logged in
                LoggingService.info("Menu bar icon loaded successfully.", category: .ui)
            } else {
                LoggingService.error("menubar-icon.png not found. Using default text title.", category: .ui)
                button.title = "Vibe"
                button.image = nil
            }
        }
    }

    private func setupMenu() {
        menu.removeAllItems()

        vibeMeterStatusMenuItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        // This item will be hidden if no message, or unhidden and updated if there is one.
        vibeMeterStatusMenuItem?.isHidden = true
        if let item = vibeMeterStatusMenuItem {
            menu.addItem(item)
        }

        loggedInAsMenuItem = NSMenuItem(title: "Not Logged In", action: nil, keyEquivalent: "")
        if let item = loggedInAsMenuItem {
            menu.addItem(item)
        }

        currentSpendingMenuItem = NSMenuItem(title: "Current: N/A", action: nil, keyEquivalent: "")
        if let item = currentSpendingMenuItem {
            menu.addItem(item)
        }

        warningLimitMenuItem = NSMenuItem(title: "Warning at: N/A", action: nil, keyEquivalent: "")
        if let item = warningLimitMenuItem {
            menu.addItem(item)
        }

        upperLimitMenuItem = NSMenuItem(title: "Max: N/A", action: nil, keyEquivalent: "")
        if let item = upperLimitMenuItem {
            menu.addItem(item)
        }

        teamMenuItem = NSMenuItem(title: "Team: N/A", action: nil, keyEquivalent: "")
        if let item = teamMenuItem {
            menu.addItem(item)
        }

        menu.addItem(NSMenuItem.separator())

        let refreshMenuItem = NSMenuItem(title: "Refresh Now", action: #selector(refreshNowClicked), keyEquivalent: "r")
        refreshMenuItem.target = self
        menu.addItem(refreshMenuItem)

        let settingsMenuItem = NSMenuItem(title: "Settings...", action: #selector(settingsClicked), keyEquivalent: ",")
        settingsMenuItem.target = self
        menu.addItem(settingsMenuItem)

        let logOutMenuItem = NSMenuItem(title: "Log Out", action: #selector(logOutClicked), keyEquivalent: "q")
        logOutMenuItem.target = self // Action will be enabled/disabled based on login state
        menu.addItem(logOutMenuItem)

        menu.addItem(NSMenuItem.separator())

        launchAtLoginMenuItem = NSMenuItem(
            title: "Launch at Login",
            action: #selector(toggleLaunchAtLogin),
            keyEquivalent: ""
        )
        launchAtLoginMenuItem?.target = self
        if let item = launchAtLoginMenuItem {
            menu.addItem(item)
        }

        let quitMenuItem = NSMenuItem(
            title: "Quit Vibe Meter",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "Q"
        )
        // Note: Key equivalent for Log Out was 'q', Quit is 'Q' (Shift+q)
        menu.addItem(quitMenuItem)

        statusItem.menu = menu
        updateMenuItems()
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

        // Specific binding for launchAtLogin to update checkbox state directly from SettingsManager
        // DataCoordinator doesn't publish launchAtLoginEnabled itself.
        // SettingsManager is the source of truth for this.
        SettingsManager.shared.$launchAtLoginEnabled
            .receive(on: DispatchQueue.main)
            .sink { [weak self] enabled in
                self?.launchAtLoginMenuItem?.state = enabled ? .on : .off
            }
            .store(in: &cancellables)
    }

    private func updateMenuButtonText(newText: String?) {
        if let button = statusItem.button {
            let text = newText ?? ""
            button.title = text

            // Adjust image position based on whether we have text
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
        if settingsWindow == nil || settingsWindow?.isVisible != true {
            let settingsView = SettingsView(
                settingsManager: dataCoordinator.settingsManager as! SettingsManager,
                dataCoordinator: dataCoordinator
            )
            let hostingController = NSHostingController(rootView: settingsView)

            if settingsWindow == nil {
                settingsWindow = NSWindow(
                    contentRect: NSRect(x: 0, y: 0, width: 520, height: 600), // Larger size for new design
                    styleMask: [.titled, .closable, .fullSizeContentView],
                    // mini & resizable removed for typical settings
                    backing: .buffered,
                    defer: false
                )
                settingsWindow?.center()
                settingsWindow?.setFrameAutosaveName("VibeMeterSettingsWindow")
                settingsWindow?.isReleasedWhenClosed = false // Keep window instance
                settingsWindow?.title = "Vibe Meter Settings"
            }
            settingsWindow?
                .contentView = NSHostingView(rootView: settingsView) // Use NSHostingView for direct SwiftUI content
        }

        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc func toggleLaunchAtLogin() {
        let newState = !dataCoordinator.settingsManager.launchAtLoginEnabled
        LoggingService.info("Toggle Launch at Login action triggered from menu. New state: \(newState)", category: .ui)
        dataCoordinator.settingsManager
            .launchAtLoginEnabled = newState // This will trigger StartupManager via binding in SettingsManager
        launchAtLoginMenuItem?.state = newState ? .on : .off
        // StartupManager.shared.setLaunchAtLogin(enabled: newState) // Direct call if no binding setup
    }

    private func updateMenuItems() {
        let isLoggedIn = dataCoordinator.isLoggedIn
        let ratesAvailable = dataCoordinator.exchangeRatesAvailable
        let symbol = dataCoordinator.selectedCurrencySymbol

        // Logged In As
        if isLoggedIn {
            loggedInAsMenuItem?.title = "Logged In As: \(dataCoordinator.userEmail ?? "Unknown User")"
        } else {
            loggedInAsMenuItem?.title = "Not Logged In"
        }

        // Spending Info
        if isLoggedIn, let spending = dataCoordinator.currentSpendingConverted {
            currentSpendingMenuItem?.title = "Current: \(symbol)\(String(format: "%.2f", spending))"
        } else if isLoggedIn, let spendingUSD = dataCoordinator.currentSpendingUSD, !ratesAvailable {
            currentSpendingMenuItem?.title = "Current: $\(String(format: "%.2f", spendingUSD)) (USD)"
        } else {
            currentSpendingMenuItem?.title = "Current: N/A"
        }

        // Warning Limit
        if isLoggedIn, let limit = dataCoordinator.warningLimitConverted {
            warningLimitMenuItem?.title = "Warning at: \(symbol)\(String(format: "%.2f", limit))"
        } else if isLoggedIn, !ratesAvailable {
            warningLimitMenuItem?
                .title = "Warning at: $\(String(format: "%.2f", dataCoordinator.settingsManager.warningLimitUSD)) (USD)"
        } else {
            warningLimitMenuItem?.title = "Warning at: N/A"
        }

        // Upper Limit
        if isLoggedIn, let limit = dataCoordinator.upperLimitConverted {
            upperLimitMenuItem?.title = "Max: \(symbol)\(String(format: "%.2f", limit))"
        } else if isLoggedIn, !ratesAvailable {
            upperLimitMenuItem?
                .title = "Max: $\(String(format: "%.2f", dataCoordinator.settingsManager.upperLimitUSD)) (USD)"
        } else {
            upperLimitMenuItem?.title = "Max: N/A"
        }

        // Team Name
        if isLoggedIn, let team = dataCoordinator.teamName, !dataCoordinator.teamIdFetchFailed {
            teamMenuItem?.title = "Vibing with: \(team)"
        } else if isLoggedIn, dataCoordinator.teamIdFetchFailed {
            teamMenuItem?.title = "Team: Error fetching"
        } else {
            teamMenuItem?.title = "Team: N/A"
        }

        // Log Out button state
        statusItem.menu?.item(withTitle: "Log Out")?.isEnabled = isLoggedIn

        // Launch at Login checkbox
        launchAtLoginMenuItem?.state = dataCoordinator.settingsManager.launchAtLoginEnabled ? .on : .off

        // Contextual Status/Error Message
        if let message = dataCoordinator.lastErrorMessage, !message.isEmpty {
            vibeMeterStatusMenuItem?.title = message
            vibeMeterStatusMenuItem?.isHidden = false
        } else if dataCoordinator.teamIdFetchFailed, dataCoordinator.isLoggedIn {
            // This specific message is from spec, but DataCoordinator.lastErrorMessage might already cover it.
            // Let's rely on lastErrorMessage for now, or DataCoordinator needs to set a more specific one.
            vibeMeterStatusMenuItem?.title = "Hmm, can't find your team vibe right now. 😕 Try a refresh?"
            vibeMeterStatusMenuItem?.isHidden = false
        } else if !dataCoordinator.exchangeRatesAvailable, dataCoordinator.isLoggedIn, dataCoordinator
            .currentSpendingConverted != nil {
            // This is also handled by lastErrorMessage "Rates MIA!..."
            vibeMeterStatusMenuItem?.title = "Rates MIA! Showing USD for now. ✨"
            vibeMeterStatusMenuItem?.isHidden = false
        } else {
            vibeMeterStatusMenuItem?.isHidden = true
        }
    }

    // State updates are handled automatically through DataCoordinator's @Published properties
    // The setupBindings() method observes these changes and updates the UI accordingly
}
