import Foundation
import os.log

/// Manages all caching for Claude log data
@MainActor
public final class ClaudeLogCacheManager: @unchecked Sendable {
    private let logger = Logger.vibeMeter(category: "ClaudeLogCacheManager")
    private let userDefaults: UserDefaults
    
    // Cache keys for UserDefaults
    private let cacheKey = "com.vibemeter.claudeLogCache"
    private let cacheTimestampKey = "com.vibemeter.claudeLogCacheTimestamp"
    private let fileHashCacheKey = "com.vibemeter.claudeFileHashCache"
    private let cacheVersionKey = "com.vibemeter.claudeLogCacheVersion"
    
    // Cache schema version - increment this when parser format changes
    private let currentCacheVersion = 4 // Incremented for progressive loading support
    
    // Cache validity duration
    private let cacheValidityDuration: TimeInterval = 300 // 5 minutes
    private let currentWindowCacheDuration: TimeInterval = 10 // 10 seconds cache for real-time updates
    
    // Current window cache for debouncing
    private var currentWindowCache: FiveHourWindow?
    private var currentWindowCacheTime: Date?
    
    // Today's log file cache
    private var todaysLogCache: [ClaudeLogEntry]?
    private var todaysLogCacheURL: URL?
    private var todaysLogCacheModificationDate: Date?
    
    // MARK: - Initialization
    
    public init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        
        // Check cache version and invalidate if outdated
        let storedVersion = userDefaults.integer(forKey: cacheVersionKey)
        if storedVersion < currentCacheVersion {
            logger.info("Cache version outdated (stored: \(storedVersion), current: \(self.currentCacheVersion)). Clearing cache.")
            invalidateAll()
            userDefaults.set(currentCacheVersion, forKey: cacheVersionKey)
        }
    }
    
    // MARK: - Daily Usage Cache
    
    /// Get cached daily usage data
    public var cachedDailyUsage: [Date: [ClaudeLogEntry]]? {
        get {
            guard let data = userDefaults.data(forKey: cacheKey),
                  let decoded = try? JSONDecoder().decode([Date: [ClaudeLogEntry]].self, from: data) else {
                return nil
            }
            return decoded
        }
        set {
            if let newValue,
               let encoded = try? JSONEncoder().encode(newValue) {
                userDefaults.set(encoded, forKey: cacheKey)
            } else {
                userDefaults.removeObject(forKey: cacheKey)
            }
        }
    }
    
    /// Get cache timestamp
    public var cacheTimestamp: Date? {
        get {
            userDefaults.object(forKey: cacheTimestampKey) as? Date
        }
        set {
            userDefaults.set(newValue, forKey: cacheTimestampKey)
        }
    }
    
    /// Check if cache is valid
    public var isCacheValid: Bool {
        guard let timestamp = cacheTimestamp else { return false }
        return Date().timeIntervalSince(timestamp) < cacheValidityDuration
    }
    
    // MARK: - File Hash Cache
    
    /// File hash cache for detecting changes
    public var fileHashCache: [String: Data] {
        get {
            userDefaults.dictionary(forKey: fileHashCacheKey) as? [String: Data] ?? [:]
        }
        set {
            userDefaults.set(newValue, forKey: fileHashCacheKey)
        }
    }
    
    // MARK: - Window Cache
    
    /// Get cached current window if valid
    public func getCachedCurrentWindow() -> FiveHourWindow? {
        guard let cachedWindow = currentWindowCache,
              let cacheTime = currentWindowCacheTime,
              Date().timeIntervalSince(cacheTime) < currentWindowCacheDuration else {
            return nil
        }
        logger.debug("Returning cached current window usage (age: \(Date().timeIntervalSince(cacheTime))s)")
        return cachedWindow
    }
    
    /// Cache current window
    public func cacheCurrentWindow(_ window: FiveHourWindow) {
        currentWindowCache = window
        currentWindowCacheTime = Date()
    }
    
    // MARK: - Today's Log Cache
    
    /// Get cached today's log entries if valid
    public func getCachedTodaysLog(for fileURL: URL, fileManager: FileManager) -> [ClaudeLogEntry]? {
        guard let cachedURL = todaysLogCacheURL,
              cachedURL == fileURL,
              let cachedEntries = todaysLogCache,
              let cachedModDate = todaysLogCacheModificationDate else {
            return nil
        }
        
        // Check if file hasn't been modified
        guard let attributes = try? fileManager.attributesOfItem(atPath: fileURL.path),
              let currentModDate = attributes[.modificationDate] as? Date,
              currentModDate == cachedModDate else {
            logger.debug("Today's log file was modified, cache invalid")
            return nil
        }
        
        logger.debug("Using cached today's log entries (no file changes)")
        return cachedEntries
    }
    
    /// Cache today's log entries
    public func cacheTodaysLog(_ entries: [ClaudeLogEntry], for fileURL: URL, fileManager: FileManager) {
        todaysLogCache = entries
        todaysLogCacheURL = fileURL
        if let attributes = try? fileManager.attributesOfItem(atPath: fileURL.path) {
            todaysLogCacheModificationDate = attributes[.modificationDate] as? Date
        }
    }
    
    // MARK: - Cache Management
    
    /// Update daily usage cache
    public func updateDailyUsageCache(_ dailyUsage: [Date: [ClaudeLogEntry]], fileHashCache: [String: Data]) {
        self.cachedDailyUsage = dailyUsage
        self.cacheTimestamp = Date()
        self.fileHashCache = fileHashCache
    }
    
    /// Invalidate all caches
    public func invalidateAll() {
        cachedDailyUsage = nil
        cacheTimestamp = nil
        fileHashCache = [:]
        currentWindowCache = nil
        currentWindowCacheTime = nil
        todaysLogCache = nil
        todaysLogCacheURL = nil
        todaysLogCacheModificationDate = nil
    }
}