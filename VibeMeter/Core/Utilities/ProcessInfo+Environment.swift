import Foundation

// MARK: - Environment Detection Helper

extension ProcessInfo {
    /// Detects if the app is running in SwiftUI previews
    var isRunningInPreview: Bool {
        environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }
    
    /// Detects if the app is running in test environment
    var isRunningInTests: Bool {
        environment["XCTestConfigurationFilePath"] != nil || NSClassFromString("XCTestCase") != nil
    }
    
    /// Detects if running in debug mode (using DEBUG compilation condition)
    var isRunningInDebug: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }
}