import SwiftUI

/// Factory for creating mock services used in SwiftUI previews.
///
/// This factory provides consistent mock service instances across previews,
/// reducing duplication and ensuring standardized behavior for preview scenarios.
public struct MockServices {
    
    /// Shared MockSettingsManager instance for previews.
    ///
    /// Uses default values suitable for most preview scenarios.
    public static var settingsManager: MockSettingsManager {
        MockSettingsManager()
    }
    
    /// MockSettingsManager with custom configuration.
    ///
    /// - Parameters:
    ///   - currency: Selected currency code (default: "USD")
    ///   - warningLimit: Warning limit in USD (default: 200)
    ///   - upperLimit: Upper limit in USD (default: 500)
    /// - Returns: Configured MockSettingsManager
    public static func settingsManager(
        currency: String = "USD",
        warningLimit: Double = 200,
        upperLimit: Double = 500
    ) -> MockSettingsManager {
        MockSettingsManager(
            selectedCurrencyCode: currency,
            warningLimitUSD: warningLimit,
            upperLimitUSD: upperLimit
        )
    }
    
    /// MultiProviderLoginManager with mock settings for previews.
    ///
    /// Uses a MockSettingsManager as the dependency.
    public static var loginManager: MultiProviderLoginManager {
        MultiProviderLoginManager(
            providerFactory: ProviderFactory(settingsManager: MockSettingsManager())
        )
    }
    
    /// MultiProviderLoginManager with custom settings manager.
    ///
    /// - Parameter settingsManager: The settings manager to use
    /// - Returns: Configured MultiProviderLoginManager
    public static func loginManager(with settingsManager: MockSettingsManager) -> MultiProviderLoginManager {
        MultiProviderLoginManager(
            providerFactory: ProviderFactory(settingsManager: settingsManager)
        )
    }
}

// MARK: - Standard Service Combinations

public extension MockServices {
    /// Standard services bundle for most previews.
    ///
    /// - Returns: Tuple containing (settingsManager, loginManager)
    static var standard: (MockSettingsManager, MultiProviderLoginManager) {
        let settings = settingsManager
        let login = loginManager(with: settings)
        return (settings, login)
    }
    
    /// Services bundle with custom currency.
    ///
    /// - Parameter currency: Currency code to use
    /// - Returns: Tuple containing (settingsManager, loginManager)
    static func withCurrency(_ currency: String) -> (MockSettingsManager, MultiProviderLoginManager) {
        let settings = settingsManager(currency: currency)
        let login = loginManager(with: settings)
        return (settings, login)
    }
    
    /// Services bundle with custom spending limits.
    ///
    /// - Parameters:
    ///   - warningLimit: Warning limit in USD
    ///   - upperLimit: Upper limit in USD
    /// - Returns: Tuple containing (settingsManager, loginManager)
    static func withLimits(warning: Double, upper: Double) -> (MockSettingsManager, MultiProviderLoginManager) {
        let settings = settingsManager(warningLimit: warning, upperLimit: upper)
        let login = loginManager(with: settings)
        return (settings, login)
    }
}