import AppKit
import Combine
import os.log
import SwiftUI

// MARK: - App Entry Point

@main
struct VibeMeterApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // Settings window using modern SwiftUI
        Settings {
            // We need to ensure we're on MainActor when accessing these singletons
            // Use a lazy initialization to defer singleton access
            SettingsView(
                settingsManager: appDelegate.settingsManager,
                dataCoordinator: appDelegate.dataCoordinator
            )
        }
    }
}

// MARK: - App Delegate

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    // MARK: - Properties

    private(set) var menuBarController: MenuBarController?
    private(set) var sparkleUpdaterManager: SparkleUpdaterManager?

    // Expose for SwiftUI Scene
    private(set) lazy var settingsManager = SettingsManager.shared
    private(set) lazy var dataCoordinator: DataCoordinator = {
        // Ensure we're accessing the shared instance safely
        guard let coordinator = DataCoordinator.shared as? DataCoordinator else {
            fatalError("DataCoordinator.shared must be of type DataCoordinator")
        }
        return coordinator
    }()

    private let logger = Logger(subsystem: "com.vibemeter", category: "AppLifecycle")

    // MARK: - App Lifecycle

    func applicationDidFinishLaunching(_: Notification) {
        logger.info("VibeMeter launching...")

        // Initialize core services
        _ = DataCoordinator.shared

        // Setup menu bar
        menuBarController = MenuBarController()

        // Initialize auto-updater
        #if !DEBUG
            sparkleUpdaterManager = SparkleUpdaterManager()
        #endif

        // Initial data refresh
        Task {
            await DataCoordinator.shared.forceRefreshData(showSyncedMessage: false)
        }

        logger.info("VibeMeter launched successfully")
    }

    func applicationWillTerminate(_: Notification) {
        logger.info("VibeMeter terminating...")

        // Cleanup
        DataCoordinator.shared.cleanup()

        logger.info("VibeMeter terminated")
    }

    func applicationSupportsSecureRestorableState(_: NSApplication) -> Bool {
        return true
    }
}

// MARK: - Menu Bar Controller

@MainActor
public final class MenuBarController: NSObject {
    // MARK: - Properties

    private var statusItem: NSStatusItem?
    private var menuBuilder: MenuBarMenuBuilder?
    private let dataCoordinator: DataCoordinatorProtocol
    private let logger = Logger(subsystem: "com.vibemeter", category: "MenuBar")

    // MARK: - Initialization

    public init(dataCoordinator: DataCoordinatorProtocol = DataCoordinator.shared) {
        self.dataCoordinator = dataCoordinator
        super.init()

        setupStatusItem()
        menuBuilder = MenuBarMenuBuilder(controller: self, dataCoordinator: dataCoordinator)
        observeDataChanges()

        logger.info("MenuBarController initialized")
    }

    // MARK: - Setup

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        guard let button = statusItem?.button else {
            logger.error("Failed to create status bar button")
            return
        }

        button.image = NSImage(named: "menubar-icon")
        button.image?.isTemplate = true
        button.imagePosition = .imageLeading
        button.target = self
        button.action = #selector(statusItemClicked)
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])

        updateDisplay()
    }

    private func observeDataChanges() {
        if let coordinator = dataCoordinator as? DataCoordinator {
            coordinator.$menuBarDisplayText
                .receive(on: DispatchQueue.main)
                .sink { [weak self] _ in
                    self?.updateDisplay()
                }
                .store(in: &cancellables)
        }
    }

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Display Updates

    private func updateDisplay() {
        statusItem?.button?.title = dataCoordinator.menuBarDisplayText
        logger.debug("Menu bar updated: \(dataCoordinator.menuBarDisplayText)")
    }

    // MARK: - Actions

    @objc private func statusItemClicked(_: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }

        if event.type == .rightMouseUp {
            showMenu()
        } else {
            showMenu()
        }
    }

    private func showMenu() {
        guard let menu = menuBuilder?.buildMenu() else { return }
        statusItem?.menu = menu
        statusItem?.button?.performClick(nil)
        statusItem?.menu = nil // Clear to allow rebuilding on next click
    }

    // MARK: - Menu Actions

    @objc func refreshNowClicked() {
        logger.info("Manual refresh requested")
        Task {
            await dataCoordinator.forceRefreshData(showSyncedMessage: true)
        }
    }

    @objc func settingsClicked() {
        logger.info("Settings requested")
        if #available(macOS 14, *) {
            NSApp.activate(ignoringOtherApps: true)
            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        } else {
            NSApp.activate(ignoringOtherApps: true)
            NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
        }
    }

    @objc func loginClicked() {
        logger.info("Login requested")
        dataCoordinator.initiateLoginFlow()
    }

    @objc func logOutClicked() {
        logger.info("Logout requested")
        dataCoordinator.userDidRequestLogout()
    }
}
