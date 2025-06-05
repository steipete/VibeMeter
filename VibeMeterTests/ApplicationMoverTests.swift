@testable import VibeMeter
import Testing

/// Tests for the ApplicationMover service
@Suite("ApplicationMover Service Tests")
@MainActor
struct ApplicationMoverTests {
    // Using lazy initialization instead of setUp/tearDown to avoid concurrency issues
    let applicationMover = ApplicationMover()

    // MARK: - Path Detection Tests

    @Test("Detects Applications folder")
    @MainActor
    func detectsApplicationsFolder() {
        // Test Applications folder detection
        let applicationsPath = "/Applications/VibeMeter.app"
        let result = applicationMover.isInApplicationsFolder(applicationsPath)
        #expect(result == true)
        
        let userAppsPath = NSHomeDirectory() + "/Applications/VibeMeter.app"
        let userResult = applicationMover.isInApplicationsFolder(userAppsPath)
        #expect(userResult == true)
    }

    @Test("detects dmg path")
    @MainActor
    func detectsDMGPath() {
        // Test DMG path detection
        let dmgPath = "/Volumes/VibeMeter/VibeMeter.app"
        let result = applicationMover.isRunningFromDMG(dmgPath)
        #expect(result == true)
        
        let normalPath = "/Applications/VibeMeter.app"
        let normalResult = applicationMover.isRunningFromDMG(normalPath)
        #expect(normalResult == false)
    }

    @Test("detects temporary location")
    @MainActor
    func detectsTemporaryLocation() {
        let homeDirectory = NSHomeDirectory()

        // Test Downloads
        let downloadsPath = homeDirectory + "/Downloads/VibeMeter.app"
        let downloadsResult = applicationMover.isRunningFromTemporaryLocation(downloadsPath)
        #expect(downloadsResult == true)
        
        // Test Desktop
        let desktopPath = homeDirectory + "/Desktop/VibeMeter.app"
        let desktopResult = applicationMover.isRunningFromTemporaryLocation(desktopPath)
        #expect(desktopResult == true)
        
        // Test Documents
        let documentsPath = homeDirectory + "/Documents/VibeMeter.app"
        let documentsResult = applicationMover.isRunningFromTemporaryLocation(documentsPath)
        #expect(documentsResult == true)
        
        // Test Applications (should not be temporary)
        let appsPath = "/Applications/VibeMeter.app"
        let appsResult = applicationMover.isRunningFromTemporaryLocation(appsPath)
        #expect(appsResult == false)
    }

    @Test("should offer to move logic")
    @MainActor
    func shouldOfferToMoveLogic() {
        // Test that we don't offer to move when already in Applications
        let applicationsPath = "/Applications/VibeMeter.app"
        let applicationsResult = applicationMover.shouldOfferToMove(for: applicationsPath)
        #expect(applicationsResult == false)
        
        // Test that we do offer to move from Downloads
        let downloadsPath = NSHomeDirectory() + "/Downloads/VibeMeter.app"
        let downloadsResult = applicationMover.shouldOfferToMove(for: downloadsPath)
        #expect(downloadsResult == true)
        
        // Test that we do offer to move from DMG
        let dmgPath = "/Volumes/VibeMeter/VibeMeter.app"
        let dmgResult = applicationMover.shouldOfferToMove(for: dmgPath)
        #expect(dmgResult == true)
    }
}