import Foundation

// Protocol for SettingsManager
@MainActor
protocol SettingsManagerProtocol: ObservableObject {
    var selectedCurrencyCode: String { get set }
    var warningLimitUSD: Double { get set }
    var upperLimitUSD: Double { get set }
    var refreshIntervalMinutes: Int { get set }
    var teamId: Int? { get set }
    var teamName: String? { get set }
    var userEmail: String? { get set }
    var launchAtLoginEnabled: Bool { get set }
    
    func clearUserSessionData()
}

// Note: The SettingsManager class already exists and should be made to conform to this protocol
