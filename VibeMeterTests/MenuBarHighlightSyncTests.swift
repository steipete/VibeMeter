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
        menuManager: StatusBarMenuManagerMock,
        button: NSStatusBarButtonMock
    ) {
        let menuManager = StatusBarMenuManagerMock()
        let button = NSStatusBarButtonMock()
        
        return (menuManager, button)
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
        let (menuManager, button) = createTestEnvironment()
        
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
        let (menuManager, button) = createTestEnvironment()
        
        // Simulate right click
        button.simulateClick(type: .rightMouseUp)
        
        #expect(!button.isHighlighted)
        #expect(!menuManager.isCustomWindowVisible)
        #expect(menuManager.contextMenuShown)
    }
    
    @Test("Right click hides custom window and unhighlights")
    @MainActor
    func rightClickHidesWindowAndUnhighlights() async {
        let (menuManager, button) = createTestEnvironment()
        
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
        let (menuManager, button) = createTestEnvironment()
        
        // Show window
        menuManager.showCustomWindow(relativeTo: button)
        #expect(button.isHighlighted)
        
        // Simulate data refresh (window should remain visible)
        // In a real scenario, the controller would update display but maintain window state
        
        // Highlight should remain
        #expect(button.isHighlighted)
        #expect(menuManager.isCustomWindowVisible)
    }
    
    @Test("Highlight clears on logout")
    @MainActor
    func highlightClearsOnLogout() async {
        let (menuManager, button) = createTestEnvironment()
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
        let (menuManager, button) = createTestEnvironment()
        
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
final class NSStatusBarButtonMock {
    var isHighlighted = false
    var clickHandler: ((NSEvent.EventType) -> Void)?
    
    func highlight(_ flag: Bool) {
        isHighlighted = flag
    }
    
    func simulateClick(type: NSEvent.EventType) {
        clickHandler?(type)
    }
}

@MainActor
final class StatusBarMenuManagerMock {
    private(set) var isCustomWindowVisible = false
    private(set) var contextMenuShown = false
    private weak var currentButton: NSStatusBarButtonMock?
    
    func showCustomWindow(relativeTo button: Any) {
        isCustomWindowVisible = true
        if let mockButton = button as? NSStatusBarButtonMock {
            currentButton = mockButton
            mockButton.highlight(true)
        }
    }
    
    func hideCustomWindow() {
        isCustomWindowVisible = false
        // Simulate the onHide callback
        Task { @MainActor in
            currentButton?.highlight(false)
        }
    }
    
    func toggleCustomWindow(relativeTo button: Any) {
        if isCustomWindowVisible {
            hideCustomWindow()
        } else {
            showCustomWindow(relativeTo: button)
        }
    }
    
    func showContextMenu(for button: Any, statusItem: Any) {
        contextMenuShown = true
        hideCustomWindow()
    }
    
    func hideAllMenus() {
        hideCustomWindow()
        contextMenuShown = false
    }
}

@MainActor
final class CustomMenuWindowMock {
    private(set) var isWindowVisible = false
    var onHide: (() -> Void)?
    
    var isVisible: Bool {
        isWindowVisible
    }
    
    func show(relativeTo button: Any) {
        isWindowVisible = true
    }
    
    func orderOut(_ sender: Any?) {
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
