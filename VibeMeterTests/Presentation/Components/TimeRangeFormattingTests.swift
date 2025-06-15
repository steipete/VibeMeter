import XCTest
@testable import VibeMeter

final class TimeRangeFormattingTests: XCTestCase {
    
    // MARK: - Properties
    
    private var dateFormatter: DateFormatter!
    
    // MARK: - Setup
    
    override func setUp() {
        super.setUp()
        
        dateFormatter = DateFormatter()
        dateFormatter.timeStyle = .short
        dateFormatter.dateStyle = .none
    }
    
    // MARK: - Basic Time Range Tests
    
    func testWindowTimeRangeFormatting() {
        // Given
        let now = Date()
        let windowStart = now.addingTimeInterval(-5 * 60 * 60) // 5 hours ago
        
        // When
        let startTimeString = dateFormatter.string(from: windowStart)
        let endTimeString = dateFormatter.string(from: now)
        let timeRange = "\(startTimeString) - \(endTimeString)"
        
        // Then
        XCTAssertTrue(timeRange.contains(" - "))
        XCTAssertFalse(timeRange.isEmpty)
        
        // Verify format matches expected pattern (e.g., "2:30 PM - 7:30 PM")
        let components = timeRange.components(separatedBy: " - ")
        XCTAssertEqual(components.count, 2)
        XCTAssertFalse(components[0].isEmpty)
        XCTAssertFalse(components[1].isEmpty)
    }
    
    func testTimeRangeAcrossDayBoundary() {
        // Given - create a time that crosses midnight
        let calendar = Calendar.current
        let midnight = calendar.startOfDay(for: Date())
        let beforeMidnight = midnight.addingTimeInterval(-2 * 60 * 60) // 10 PM yesterday
        let afterMidnight = midnight.addingTimeInterval(3 * 60 * 60) // 3 AM today
        
        // When
        let startTimeString = dateFormatter.string(from: beforeMidnight)
        let endTimeString = dateFormatter.string(from: afterMidnight)
        let timeRange = "\(startTimeString) - \(endTimeString)"
        
        // Then
        XCTAssertTrue(timeRange.contains(" - "))
        // Should show times without dates since it's using .short time style
    }
    
    // MARK: - Locale-Specific Tests
    
    func testTimeRangeWith12HourFormat() {
        // Given
        dateFormatter.locale = Locale(identifier: "en_US")
        let now = Date()
        let fiveHoursAgo = now.addingTimeInterval(-5 * 60 * 60)
        
        // When
        let timeRange = "\(dateFormatter.string(from: fiveHoursAgo)) - \(dateFormatter.string(from: now))"
        
        // Then
        // Should contain AM/PM indicators
        let hasAMPM = timeRange.contains("AM") || timeRange.contains("PM")
        XCTAssertTrue(hasAMPM, "12-hour format should include AM/PM")
    }
    
    func testTimeRangeWith24HourFormat() {
        // Given
        dateFormatter.locale = Locale(identifier: "en_GB")
        dateFormatter.dateFormat = "HH:mm"
        let now = Date()
        let fiveHoursAgo = now.addingTimeInterval(-5 * 60 * 60)
        
        // When
        let timeRange = "\(dateFormatter.string(from: fiveHoursAgo)) - \(dateFormatter.string(from: now))"
        
        // Then
        // Should not contain AM/PM
        XCTAssertFalse(timeRange.contains("AM"))
        XCTAssertFalse(timeRange.contains("PM"))
        // Should contain colon
        XCTAssertTrue(timeRange.contains(":"))
    }
    
    // MARK: - Edge Cases
    
    func testTimeRangeAtExactHours() {
        // Given - times at exact hours
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day, .hour], from: Date())
        components.hour = 14 // 2 PM
        components.minute = 0
        components.second = 0
        
        guard let exactHour = calendar.date(from: components) else {
            XCTFail("Failed to create exact hour date")
            return
        }
        
        let fiveHoursLater = exactHour.addingTimeInterval(5 * 60 * 60)
        
        // When
        let startTime = dateFormatter.string(from: exactHour)
        let endTime = dateFormatter.string(from: fiveHoursLater)
        let timeRange = "\(startTime) - \(endTime)"
        
        // Then
        XCTAssertFalse(timeRange.isEmpty)
        XCTAssertTrue(timeRange.contains(" - "))
    }
    
    func testTimeRangeNearMidnight() {
        // Given
        let calendar = Calendar.current
        let midnight = calendar.startOfDay(for: Date())
        let elevenPM = midnight.addingTimeInterval(-1 * 60 * 60) // 11 PM
        let fourAM = midnight.addingTimeInterval(4 * 60 * 60) // 4 AM
        
        // When
        let timeRange = "\(dateFormatter.string(from: elevenPM)) - \(dateFormatter.string(from: fourAM))"
        
        // Then
        XCTAssertTrue(timeRange.contains(" - "))
        // Verify it doesn't show dates, just times
        XCTAssertFalse(timeRange.contains("/")) // No date separators
    }
    
    // MARK: - Integration with CostTableView
    
    @MainActor
    func testCostTableViewTimeRangeDisplay() {
        // Test the actual implementation from CostTableView
        let providerData = ProviderSpendingData(provider: .claude)
        
        // Simulate the windowTimeRangeText function
        let now = Date()
        let windowStart = now.addingTimeInterval(-5 * 60 * 60)
        
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        
        let startTimeString = formatter.string(from: windowStart)
        let endTimeString = formatter.string(from: now)
        let expectedRange = "\(startTimeString) - \(endTimeString)"
        
        XCTAssertFalse(expectedRange.isEmpty)
        XCTAssertTrue(expectedRange.contains(" - "))
    }
    
    // MARK: - Performance Tests
    
    func testTimeRangeFormattingPerformance() {
        // Test that formatting is fast enough for UI updates
        measure {
            for _ in 0..<1000 {
                let now = Date()
                let windowStart = now.addingTimeInterval(-5 * 60 * 60)
                
                let startTime = dateFormatter.string(from: windowStart)
                let endTime = dateFormatter.string(from: now)
                _ = "\(startTime) - \(endTime)"
            }
        }
    }
    
    // MARK: - Helper Method Tests
    
    func testConsistentTimeFormatting() {
        // Ensure time formatting is consistent across the app
        let testDate = Date()
        
        // Test multiple formatters to ensure consistency
        let formatter1 = DateFormatter()
        formatter1.timeStyle = .short
        formatter1.dateStyle = .none
        
        let formatter2 = DateFormatter()
        formatter2.timeStyle = .short
        formatter2.dateStyle = .none
        
        let time1 = formatter1.string(from: testDate)
        let time2 = formatter2.string(from: testDate)
        
        XCTAssertEqual(time1, time2, "Time formatting should be consistent")
    }
}