import XCTest
@testable import VibeMeter

final class MultiAccountDetectorTests: XCTestCase {
    
    @MainActor
    func testDetectSingleAccount() async {
        let detector = MultiAccountDetector()
        
        // Create log entries for a single session
        let entries = [
            ClaudeLogEntry(
                timestamp: Date().addingTimeInterval(-3600),
                model: "claude-3-opus",
                inputTokens: 1000,
                outputTokens: 500,
                projectName: "VibeMeter",
                parentUuid: "uuid1",
                conversationType: "assistant"
            ),
            ClaudeLogEntry(
                timestamp: Date().addingTimeInterval(-3000),
                model: "claude-3-opus",
                inputTokens: 2000,
                outputTokens: 1000,
                projectName: "VibeMeter",
                parentUuid: "uuid1",
                conversationType: "assistant"
            )
        ]
        
        let sessions = detector.detectAccountSessions(from: entries)
        
        XCTAssertEqual(sessions.count, 1)
        XCTAssertEqual(sessions.first?.totalTokens, 4500)
    }
    
    @MainActor
    func testDetectMultipleAccountsWithGap() async {
        let detector = MultiAccountDetector()
        
        // Create log entries with a significant gap (indicating account switch)
        let entries = [
            // First account session
            ClaudeLogEntry(
                timestamp: Date().addingTimeInterval(-7200),
                model: "claude-3-sonnet",
                inputTokens: 1000,
                outputTokens: 500,
                projectName: "Project1",
                parentUuid: "uuid1",
                conversationType: "assistant"
            ),
            ClaudeLogEntry(
                timestamp: Date().addingTimeInterval(-6900),
                model: "claude-3-sonnet",
                inputTokens: 2000,
                outputTokens: 1000,
                projectName: "Project1",
                parentUuid: "uuid1",
                conversationType: "assistant"
            ),
            // Gap of >30 minutes indicates potential account switch
            // Second account session
            ClaudeLogEntry(
                timestamp: Date().addingTimeInterval(-3600),
                model: "claude-3-opus",
                inputTokens: 3000,
                outputTokens: 1500,
                projectName: "Project2",
                parentUuid: "",  // Empty parentUuid indicates new conversation
                conversationType: "assistant"
            ),
            ClaudeLogEntry(
                timestamp: Date().addingTimeInterval(-3300),
                model: "claude-3-opus",
                inputTokens: 1500,
                outputTokens: 800,
                projectName: "Project2",
                parentUuid: "uuid2",
                conversationType: "assistant"
            )
        ]
        
        let sessions = detector.detectAccountSessions(from: entries)
        
        XCTAssertEqual(sessions.count, 2)
        XCTAssertEqual(sessions[0].totalTokens, 4500)
        XCTAssertEqual(sessions[1].totalTokens, 6800)
    }
    
    @MainActor
    func testSessionFingerprinting() async {
        let detector = MultiAccountDetector()
        
        // Create entries with distinct patterns
        let heavyOpusUser = Array(repeating: 
            ClaudeLogEntry(
                timestamp: Date(),
                model: "claude-3-opus",
                inputTokens: 10000,
                outputTokens: 5000,
                projectName: "BigProject"
            ), count: 10)
        
        let lightSonnetUser = Array(repeating:
            ClaudeLogEntry(
                timestamp: Date(),
                model: "claude-3-sonnet",
                inputTokens: 500,
                outputTokens: 200,
                projectName: "SmallProject"
            ), count: 10)
        
        let fingerprint1 = detector.generateSessionFingerprint(from: heavyOpusUser)
        let fingerprint2 = detector.generateSessionFingerprint(from: lightSonnetUser)
        
        XCTAssertNotEqual(fingerprint1, fingerprint2)
        XCTAssertTrue(fingerprint1.contains("opus"))
        XCTAssertTrue(fingerprint2.contains("sonnet"))
        XCTAssertTrue(fingerprint1.contains("very_high"))
        XCTAssertTrue(fingerprint2.contains("low"))
    }
    
    @MainActor
    func testAccountNamePersistence() async {
        let detector = MultiAccountDetector()
        
        // Create a session
        let entries = [
            ClaudeLogEntry(
                timestamp: Date(),
                model: "claude-3-opus",
                inputTokens: 1000,
                outputTokens: 500,
                projectName: "Test"
            )
        ]
        
        let sessions = detector.detectAccountSessions(from: entries)
        guard let session = sessions.first else {
            XCTFail("No session detected")
            return
        }
        
        // Set account name
        detector.setAccountName(for: session.id, name: "Work Account")
        
        // Verify name is persisted
        let retrievedName = detector.getAccountName(for: session.id)
        XCTAssertEqual(retrievedName, "Work Account")
    }
    
    @MainActor
    func testDetectNewRootConversation() async {
        let detector = MultiAccountDetector()
        
        // Create entries showing a new root conversation after brief activity
        let entries = [
            ClaudeLogEntry(
                timestamp: Date().addingTimeInterval(-300),
                model: "claude-3-opus",
                inputTokens: 1000,
                outputTokens: 500,
                parentUuid: "uuid1",
                conversationType: "assistant"
            ),
            // New root conversation (empty parentUuid) after 2 minutes
            ClaudeLogEntry(
                timestamp: Date().addingTimeInterval(-180),
                model: "claude-3-opus",
                inputTokens: 2000,
                outputTokens: 1000,
                parentUuid: "",  // Empty indicates root
                conversationType: "assistant"
            )
        ]
        
        let sessions = detector.detectAccountSessions(from: entries)
        
        // Should detect as potential account switch
        XCTAssertEqual(sessions.count, 2)
    }
}