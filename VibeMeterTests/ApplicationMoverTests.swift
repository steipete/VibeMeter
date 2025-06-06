import Foundation
import Testing
@testable import VibeMeter

/// Tests for the ApplicationMover service
@Suite("ApplicationMover Service Tests", .tags(.unit, .fast))
@MainActor
struct ApplicationMoverTests {
    // Using lazy initialization instead of setUp/tearDown to avoid concurrency issues
    let applicationMover = ApplicationMover()

    @Test("check and offer to move to applications")
    @MainActor
    func checkAndOfferToMoveToApplications() {
        // Test that the public API exists and doesn't crash
        // Note: This method shows UI dialogs, so we just test it exists
        applicationMover.checkAndOfferToMoveToApplications()

        // Test passes if no exception is thrown
    }
}
