import Foundation
import Testing
@testable import VibeMeter

/// Tests for the ApplicationMover service
@Suite("ApplicationMover Service Tests", .tags(.unit, .fast))
@MainActor
struct ApplicationMoverTests {
    // Note: ApplicationMover tests are disabled because they:
    // 1. Try to run hdiutil which times out in CI environment
    // 2. Show UI dialogs which cannot work in headless environment
    // 3. Require disk image mounting capabilities not available in CI
    //
    // The ApplicationMover service is tested manually during development.
    // To test locally, uncomment the test below and run it on your Mac.
    
    /*
    let applicationMover = ApplicationMover()
    
    @Test("check and offer to move to applications")
    @MainActor
    func checkAndOfferToMoveToApplications() {
        // Test that the public API exists and doesn't crash
        // Note: This method shows UI dialogs, so we just test it exists
        applicationMover.checkAndOfferToMoveToApplications()
        
        // Test passes if no exception is thrown
    }
    */
}