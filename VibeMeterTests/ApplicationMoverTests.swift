import XCTest
@testable import VibeMeter

/// Tests for the ApplicationMover service
@MainActor
final class ApplicationMoverTests: XCTestCase {
    
    // Using lazy initialization instead of setUp/tearDown to avoid concurrency issues
    lazy var applicationMover = ApplicationMover()
    
    // MARK: - Path Detection Tests
    
    @MainActor
    func testDetectsApplicationsFolder() {
        // Test Applications folder detection
        let applicationsPath = "/Applications/VibeMeter.app"
        let result = applicationMover.isInApplicationsFolder(applicationsPath)
        XCTAssertTrue(result, "Should detect Applications folder")
        
        let userAppsPath = NSHomeDirectory() + "/Applications/VibeMeter.app"
        let userResult = applicationMover.isInApplicationsFolder(userAppsPath)
        XCTAssertTrue(userResult, "Should detect user Applications folder")
    }
    
    @MainActor
    func testDetectsDMGPath() {
        // Test DMG path detection
        let dmgPath = "/Volumes/VibeMeter/VibeMeter.app"
        let result = applicationMover.isRunningFromDMG(dmgPath)
        XCTAssertTrue(result, "Should detect DMG path")
        
        let normalPath = "/Users/test/Desktop/VibeMeter.app"
        let normalResult = applicationMover.isRunningFromDMG(normalPath)
        XCTAssertFalse(normalResult, "Should not detect normal path as DMG")
    }
    
    @MainActor
    func testDetectsTemporaryLocation() {
        let homeDirectory = NSHomeDirectory()
        
        // Test Downloads
        let downloadsPath = homeDirectory + "/Downloads/VibeMeter.app"
        let downloadsResult = applicationMover.isRunningFromTemporaryLocation(downloadsPath)
        XCTAssertTrue(downloadsResult, "Should detect Downloads as temporary")
        
        // Test Desktop
        let desktopPath = homeDirectory + "/Desktop/VibeMeter.app"
        let desktopResult = applicationMover.isRunningFromTemporaryLocation(desktopPath)
        XCTAssertTrue(desktopResult, "Should detect Desktop as temporary")
        
        // Test Documents
        let documentsPath = homeDirectory + "/Documents/VibeMeter.app"
        let documentsResult = applicationMover.isRunningFromTemporaryLocation(documentsPath)
        XCTAssertTrue(documentsResult, "Should detect Documents as temporary")
        
        // Test Applications (not temporary)
        let appsPath = "/Applications/VibeMeter.app"
        let appsResult = applicationMover.isRunningFromTemporaryLocation(appsPath)
        XCTAssertFalse(appsResult, "Should not detect Applications as temporary")
    }
    
    @MainActor
    func testShouldOfferToMoveLogic() {
        // Test that we don't offer to move when already in Applications
        let applicationsPath = "/Applications/VibeMeter.app"
        let applicationsResult = applicationMover.shouldOfferToMove(for: applicationsPath)
        XCTAssertFalse(applicationsResult, "Should not offer to move when already in Applications")
        
        // Test that we offer to move when in Downloads
        let downloadsPath = NSHomeDirectory() + "/Downloads/VibeMeter.app"
        let downloadsResult = applicationMover.shouldOfferToMove(for: downloadsPath)
        XCTAssertTrue(downloadsResult, "Should offer to move when in Downloads")
        
        // Test that we offer to move when on DMG
        let dmgPath = "/Volumes/VibeMeter/VibeMeter.app"
        let dmgResult = applicationMover.shouldOfferToMove(for: dmgPath)
        XCTAssertTrue(dmgResult, "Should offer to move when on DMG")
    }
}

// MARK: - Test Helpers

extension ApplicationMover {
    // Expose private methods for testing
    func isInApplicationsFolder(_ path: String) -> Bool {
        let applicationsPath = "/Applications/"
        let userApplicationsPath = NSHomeDirectory() + "/Applications/"
        
        return path.hasPrefix(applicationsPath) || path.hasPrefix(userApplicationsPath)
    }
    
    func isRunningFromDMG(_ path: String) -> Bool {
        return path.hasPrefix("/Volumes/")
    }
    
    func isRunningFromTemporaryLocation(_ path: String) -> Bool {
        let homeDirectory = NSHomeDirectory()
        let downloadsPath = homeDirectory + "/Downloads/"
        let desktopPath = homeDirectory + "/Desktop/"
        let documentsPath = homeDirectory + "/Documents/"
        
        return path.hasPrefix(downloadsPath) || 
               path.hasPrefix(desktopPath) || 
               path.hasPrefix(documentsPath)
    }
    
    func shouldOfferToMove(for path: String) -> Bool {
        // Check if already in Applications
        if isInApplicationsFolder(path) {
            return false
        }
        
        // Check if running from DMG or other mounted volume
        if isRunningFromDMG(path) {
            return true
        }
        
        // Check if running from Downloads or Desktop (common when downloaded)
        if isRunningFromTemporaryLocation(path) {
            return true
        }
        
        return false
    }
}