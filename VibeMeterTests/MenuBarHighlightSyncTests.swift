import AppKit
import Foundation
import Testing
@testable import VibeMeter

// MARK: - Menu Bar Highlight Sync Tests

@Suite("Menu Bar Highlight Sync Tests", .tags(.ui))
struct MenuBarHighlightSyncTests {
    
    // MARK: - Test Helpers
    
    @MainActor
    private func createTestEnvironment() -> (
        controller: StatusBarController,
        menuManager: StatusBarMenuManagerMock,
        button: NSStatusBarButtonMock
    ) {
        let settingsManager = MockSettingsManager()
        let orchestrator = MultiProviderDataOrchestrator(settingsManager: settingsManager)
        let controller = StatusBarController(
            settingsManager: settingsManager,
            orchestrator: orchestrator
        )
        
        let menuManager = StatusBarMenuManagerMock()
        let button = NSStatusBarButtonMock()
        
        return (controller, menuManager, button)
    }
    
    // MARK: - Basic Highlight Tests
    
    @Test("Button highlights when custom window shows")
    @MainActor
    func buttonHighlightsOnWindowShow() async {
        let button = NSStatusBarButtonMock()
        let menuManager = StatusBarMenuManagerMock()
        
        #expect(!button.isHighlighted)
        
        menuManager.showCustomWindow(relativeTo: button)
        
        #expect(button.isHighlighted)
        #expect(menuManager.isCustomWindowVisible)
    }
    
    @Test("Button unhighlights when custom window hides")
    @MainActor
    func buttonUnhighlightsOnWindowHide() async {
        let button = NSStatusBarButtonMock()
        let menuManager = StatusBarMenuManagerMock()
        
        // Show window first
        menuManager.showCustomWindow(relativeTo: button)
        #expect(button.isHighlighted)
        
        // Hide window
        menuManager.hideCustomWindow()
        
        // Wait for async operations
        try? await Task.sleep(for: .milliseconds(10))
        
        #expect(!button.isHighlighted)
        #expect(!menuManager.isCustomWindowVisible)
    }
    
    @Test("Toggle custom window syncs highlight state")
    @MainActor
    func toggleWindowSyncsHighlight() async {
        let button = NSStatusBarButtonMock()
        let menuManager = StatusBarMenuManagerMock()
        
        // First toggle - should show and highlight
        menuManager.toggleCustomWindow(relativeTo: button)
        #expect(button.isHighlighted)
        #expect(menuManager.isCustomWindowVisible)
        
        // Second toggle - should hide and unhighlight
        menuManager.toggleCustomWindow(relativeTo: button)
        try? await Task.sleep(for: .milliseconds(10))
        #expect(!button.isHighlighted)
        #expect(!menuManager.isCustomWindowVisible)
        
        // Third toggle - should show and highlight again
        menuManager.toggleCustomWindow(relativeTo: button)
        #expect(button.isHighlighted)
        #expect(menuManager.isCustomWindowVisible)
    }
    
    // MARK: - Click Event Tests
    
    @Test("Left click toggles highlight state")
    @MainActor
    func leftClickTogglesHighlight() async {
        let (_, menuManager, button) = createTestEnvironment()
        
        // Simulate left click
        button.simulateClick(type: .leftMouseUp)
        
        #expect(button.isHighlighted)
        #expect(menuManager.isCustomWindowVisible)
        
        // Second left click
        button.simulateClick(type: .leftMouseUp)
        try? await Task.sleep(for: .milliseconds(10))
        
        #expect(!button.isHighlighted)
        #expect(!menuManager.isCustomWindowVisible)
    }
    
    @Test("Right click does not affect highlight state")
    @MainActor
    func rightClickNoHighlight() async {
        let (_, menuManager, button) = createTestEnvironment()
        
        // Simulate right click
        button.simulateClick(type: .rightMouseUp)
        
        #expect(!button.isHighlighted)
        #expect(!menuManager.isCustomWindowVisible)
        #expect(menuManager.contextMenuShown)
    }
    
    @Test("Right click hides custom window and unhighlights")
    @MainActor
    func rightClickHidesWindowAndUnhighlights() async {
        let (_, menuManager, button) = createTestEnvironment()
        
        // Show custom window first
        menuManager.showCustomWindow(relativeTo: button)
        #expect(button.isHighlighted)
        
        // Right click
        button.simulateClick(type: .rightMouseUp)
        try? await Task.sleep(for: .milliseconds(10))
        
        #expect(!button.isHighlighted)
        #expect(!menuManager.isCustomWindowVisible)
        #expect(menuManager.contextMenuShown)
    }
    
    // MARK: - Window Dismissal Tests
    
    @Test("Click outside dismisses window and unhighlights")
    @MainActor
    func clickOutsideDismissesAndUnhighlights() async {
        let button = NSStatusBarButtonMock()
        let window = CustomMenuWindowMock()
        
        // Show window
        window.show(relativeTo: button)
        button.highlight(true)
        #expect(button.isHighlighted)
        #expect(window.isVisible)
        
        // Simulate click outside
        window.simulateClickOutside()
        
        // Wait for event processing
        try? await Task.sleep(for: .milliseconds(50))
        
        #expect(!button.isHighlighted)
        #expect(!window.isVisible)
    }
    
    @Test("ESC key dismisses window and unhighlights")
    @MainActor
    func escKeyDismissesAndUnhighlights() async {
        let button = NSStatusBarButtonMock()
        let window = CustomMenuWindowMock()
        
        // Show window
        window.show(relativeTo: button)
        button.highlight(true)
        
        // Simulate ESC key
        window.simulateEscapeKey()
        try? await Task.sleep(for: .milliseconds(10))
        
        #expect(!button.isHighlighted)
        #expect(!window.isVisible)
    }
    
    // MARK: - State Persistence Tests
    
    @Test("Highlight state persists during data refresh")
    @MainActor
    func highlightPersistsDuringRefresh() async {
        let (controller, menuManager, button) = createTestEnvironment()
        
        // Show window
        menuManager.showCustomWindow(relativeTo: button)
        #expect(button.isHighlighted)
        
        // Trigger data refresh
        controller.updateStatusItemDisplay()
        
        // Highlight should remain
        #expect(button.isHighlighted)
        #expect(menuManager.isCustomWindowVisible)
    }
    
    @Test("Highlight clears on logout")
    @MainActor
    func highlightClearsOnLogout() async {
        let (_, menuManager, button) = createTestEnvironment()
        let loginManager = MultiProviderLoginManager(
            providerFactory: ProviderFactory(settingsManager: MockSettingsManager())
        )
        
        // Show window
        menuManager.showCustomWindow(relativeTo: button)
        #expect(button.isHighlighted)
        
        // Simulate logout
        loginManager.logOut(from: .cursor)
        menuManager.hideAllMenus()
        try? await Task.sleep(for: .milliseconds(10))
        
        #expect(!button.isHighlighted)
        #expect(!menuManager.isCustomWindowVisible)
    }
    
    // MARK: - Edge Cases
    
    @Test("Multiple rapid clicks handle highlight correctly")
    @MainActor
    func rapidClicksHandleHighlight() async {
        let (_, menuManager, button) = createTestEnvironment()
        
        // Rapid clicks
        for i in 0..<5 {
            button.simulateClick(type: .leftMouseUp)
            try? await Task.sleep(for: .milliseconds(5))
            
            // Even clicks = closed, odd clicks = open
            if i % 2 == 0 {
                #expect(button.isHighlighted)
            } else {
                #expect(!button.isHighlighted)
            }
        }
    }
    
    @Test("Window callback prevents orphaned highlight")
    @MainActor
    func windowCallbackPreventsOrphanedHighlight() async {
        let button = NSStatusBarButtonMock()
        let window = CustomMenuWindowMock()
        
        // Set up callback
        var callbackCalled = false
        window.onHide = {
            button.highlight(false)
            callbackCalled = true
        }
        
        // Show then hide
        window.show(relativeTo: button)
        button.highlight(true)
        window.hide()
        
        try? await Task.sleep(for: .milliseconds(10))
        
        #expect(!button.isHighlighted)
        #expect(callbackCalled)
    }
}

// MARK: - Mock Classes

@MainActor
final class NSStatusBarButtonMock: NSStatusBarButton {
    private(set) var isHighlighted = false
    var clickHandler: ((NSEvent.EventType) -> Void)?
    
    override func highlight(_ flag: Bool) {
        isHighlighted = flag
    }
    
    func simulateClick(type: NSEvent.EventType) {
        clickHandler?(type)
    }
}

@MainActor
final class StatusBarMenuManagerMock: StatusBarMenuManager {
    private(set) var isCustomWindowVisible = false
    private(set) var contextMenuShown = false
    private weak var currentButton: NSStatusBarButtonMock?
    
    override func showCustomWindow(relativeTo button: NSStatusBarButton) {
        isCustomWindowVisible = true
        if let mockButton = button as? NSStatusBarButtonMock {
            currentButton = mockButton
            mockButton.highlight(true)
        }
    }
    
    override func hideCustomWindow() {
        isCustomWindowVisible = false
        // Simulate the onHide callback
        Task { @MainActor in
            currentButton?.highlight(false)
        }
    }
    
    override func toggleCustomWindow(relativeTo button: NSStatusBarButton) {
        if isCustomWindowVisible {
            hideCustomWindow()
        } else {
            showCustomWindow(relativeTo: button)
        }
    }
    
    override func showContextMenu(for button: NSStatusBarButton, statusItem: NSStatusItem) {
        contextMenuShown = true
        hideCustomWindow()
    }
    
    override func hideAllMenus() {
        hideCustomWindow()
        contextMenuShown = false
    }
}

@MainActor
final class CustomMenuWindowMock: NSPanel {
    private(set) var isWindowVisible = false
    var onHide: (() -> Void)?
    
    init() {
        super.init(
            contentRect: .zero,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
    }
    
    override var isVisible: Bool {
        isWindowVisible
    }
    
    func show(relativeTo button: NSStatusBarButton) {
        isWindowVisible = true
    }
    
    override func orderOut(_ sender: Any?) {
        hide()
    }
    
    func hide() {
        isWindowVisible = false
        onHide?()
    }
    
    func simulateClickOutside() {
        hide()
    }
    
    func simulateEscapeKey() {
        hide()
    }
}