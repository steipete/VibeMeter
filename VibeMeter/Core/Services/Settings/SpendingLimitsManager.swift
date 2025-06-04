import Foundation
import os.log

/// Manages spending limit settings and thresholds.
///
/// This manager handles warning and upper spending limits stored in USD,
/// with validation and persistence functionality.
@Observable
@MainActor
public final class SpendingLimitsManager {
    
    // MARK: - Properties
    
    private let userDefaults: UserDefaults
    private let logger = Logger(subsystem: "com.vibemeter", category: "SpendingLimits")
    
    // MARK: - Keys
    
    private enum Keys {
        static let warningLimitUSD = "warningLimitUSD"
        static let upperLimitUSD = "upperLimitUSD"
    }
    
    // MARK: - Spending Limits (stored in USD)
    
    /// Warning threshold for spending notifications
    public var warningLimitUSD: Double {
        didSet {
            userDefaults.set(warningLimitUSD, forKey: Keys.warningLimitUSD)
            logger.debug("Warning limit updated: $\(self.warningLimitUSD)")
        }
    }
    
    /// Upper threshold for spending notifications
    public var upperLimitUSD: Double {
        didSet {
            userDefaults.set(upperLimitUSD, forKey: Keys.upperLimitUSD)
            logger.debug("Upper limit updated: $\(self.upperLimitUSD)")
        }
    }
    
    // MARK: - Initialization
    
    public init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        
        // Load spending limits with defaults
        warningLimitUSD = userDefaults.object(forKey: Keys.warningLimitUSD) as? Double ?? 200.0
        upperLimitUSD = userDefaults.object(forKey: Keys.upperLimitUSD) as? Double ?? 1000.0
        
        logger.info("SpendingLimitsManager initialized - warning: $\(self.warningLimitUSD), upper: $\(self.upperLimitUSD)")
    }
    
    // MARK: - Public Methods
    
    /// Updates the warning limit with validation
    public func updateWarningLimit(to amount: Double) {
        guard amount >= 0 else {
            logger.warning("Invalid warning limit: \(amount), must be >= 0")
            return
        }
        
        warningLimitUSD = amount
        
        // Ensure warning limit doesn't exceed upper limit
        if warningLimitUSD > upperLimitUSD {
            logger.info("Warning limit exceeded upper limit, adjusting upper limit to \(self.warningLimitUSD)")
            upperLimitUSD = warningLimitUSD
        }
    }
    
    /// Updates the upper limit with validation
    public func updateUpperLimit(to amount: Double) {
        guard amount >= 0 else {
            logger.warning("Invalid upper limit: \(amount), must be >= 0")
            return
        }
        
        upperLimitUSD = amount
        
        // Ensure upper limit doesn't fall below warning limit
        if upperLimitUSD < warningLimitUSD {
            logger.info("Upper limit set below warning limit, adjusting warning limit to \(self.upperLimitUSD)")
            warningLimitUSD = upperLimitUSD
        }
    }
    
    /// Updates both limits simultaneously with cross-validation
    public func updateLimits(warning: Double, upper: Double) {
        guard warning >= 0, upper >= 0 else {
            logger.warning("Invalid limits: warning=\(warning), upper=\(upper), both must be >= 0")
            return
        }
        
        guard warning <= upper else {
            logger.warning("Invalid limits: warning (\(warning)) must be <= upper (\(upper))")
            return
        }
        
        warningLimitUSD = warning
        upperLimitUSD = upper
        
        logger.info("Both limits updated - warning: $\(warning), upper: $\(upper)")
    }
    
    /// Validates current limit settings
    public func validateLimits() -> Bool {
        let isValid = warningLimitUSD >= 0 && upperLimitUSD >= 0 && warningLimitUSD <= upperLimitUSD
        
        if !isValid {
            logger.error("Invalid limit configuration detected - warning: $\(self.warningLimitUSD), upper: $\(self.upperLimitUSD)")
        }
        
        return isValid
    }
    
    /// Resets limits to default values
    public func resetToDefaults() {
        logger.info("Resetting spending limits to defaults")
        warningLimitUSD = 200.0
        upperLimitUSD = 1000.0
    }
}