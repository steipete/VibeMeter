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
    private let permanentCacheKey = "com.vibemeter.claudeLogPermanentCache"
    private let permanentCacheMetadataKey = "com.vibemeter.claudeLogPermanentCacheMetadata"
    
    // Cache schema version - increment this when parser format changes
    private let currentCacheVersion = 5 // Incremented for permanent cache support
    
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
        
        // Perform periodic cleanup of old permanent cache entries
        cleanupOldPermanentCache()
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
    
    // MARK: - Permanent Cache for Old Files
    
    /// Structure to store metadata about permanently cached files
    private struct PermanentCacheMetadata: Codable {
        let fileKey: String
        let fileHash: Data
        let entryCount: Int
        let dateRange: ClosedRange<Date>
        let cachedAt: Date
    }
    
    /// Get permanent cache metadata
    private var permanentCacheMetadata: [String: PermanentCacheMetadata] {
        get {
            guard let data = userDefaults.data(forKey: permanentCacheMetadataKey),
                  let decoded = try? JSONDecoder().decode([String: PermanentCacheMetadata].self, from: data) else {
                return [:]
            }
            return decoded
        }
        set {
            if let encoded = try? JSONEncoder().encode(newValue) {
                userDefaults.set(encoded, forKey: permanentCacheMetadataKey)
            } else {
                userDefaults.removeObject(forKey: permanentCacheMetadataKey)
            }
        }
    }
    
    /// Check if a file is eligible for permanent caching (older than today)
    public func isEligibleForPermanentCache(fileKey: String, entries: [ClaudeLogEntry]) -> Bool {
        guard !entries.isEmpty else { return false }
        
        // Get the latest entry date
        let latestDate = entries.max(by: { $0.timestamp < $1.timestamp })?.timestamp ?? Date()
        let todayStart = Calendar.current.startOfDay(for: Date())
        
        // File is eligible if all entries are from before today
        return latestDate < todayStart
    }
    
    /// Get permanently cached entries for a file
    public func getPermanentlyCachedEntries(for fileKey: String, fileHash: Data) -> [ClaudeLogEntry]? {
        // Check metadata first
        guard let metadata = permanentCacheMetadata[fileKey],
              metadata.fileHash == fileHash else {
            return nil
        }
        
        // Load the actual entries
        let fullKey = "\(permanentCacheKey).\(fileKey)"
        guard let data = userDefaults.data(forKey: fullKey),
              let entries = try? JSONDecoder().decode([ClaudeLogEntry].self, from: data) else {
            // Metadata exists but data is missing - clean up
            var updatedMetadata = permanentCacheMetadata
            updatedMetadata.removeValue(forKey: fileKey)
            permanentCacheMetadata = updatedMetadata
            return nil
        }
        
        logger.debug("Retrieved \(entries.count) entries from permanent cache for \(fileKey)")
        return entries
    }
    
    /// Permanently cache entries for a file
    public func permanentlyCacheEntries(_ entries: [ClaudeLogEntry], for fileKey: String, fileHash: Data) {
        guard !entries.isEmpty,
              isEligibleForPermanentCache(fileKey: fileKey, entries: entries) else {
            return
        }
        
        // Store the entries
        let fullKey = "\(permanentCacheKey).\(fileKey)"
        guard let encoded = try? JSONEncoder().encode(entries) else {
            logger.error("Failed to encode entries for permanent cache")
            return
        }
        
        userDefaults.set(encoded, forKey: fullKey)
        
        // Store metadata
        let minDate = entries.min(by: { $0.timestamp < $1.timestamp })?.timestamp ?? Date()
        let maxDate = entries.max(by: { $0.timestamp < $1.timestamp })?.timestamp ?? Date()
        
        let metadata = PermanentCacheMetadata(
            fileKey: fileKey,
            fileHash: fileHash,
            entryCount: entries.count,
            dateRange: minDate...maxDate,
            cachedAt: Date()
        )
        
        var updatedMetadata = permanentCacheMetadata
        updatedMetadata[fileKey] = metadata
        permanentCacheMetadata = updatedMetadata
        
        logger.info("Permanently cached \(entries.count) entries for \(fileKey) (dates: \(minDate)...\(maxDate))")
    }
    
    /// Clean up permanent cache entries older than a certain age
    public func cleanupOldPermanentCache(olderThan days: Int = 90) {
        let cutoffDate = Date().addingTimeInterval(-Double(days) * 24 * 60 * 60)
        var metadata = permanentCacheMetadata
        var removedCount = 0
        
        for (fileKey, meta) in metadata {
            if meta.cachedAt < cutoffDate {
                // Remove the actual data
                let fullKey = "\(permanentCacheKey).\(fileKey)"
                userDefaults.removeObject(forKey: fullKey)
                
                // Remove metadata
                metadata.removeValue(forKey: fileKey)
                removedCount += 1
            }
        }
        
        if removedCount > 0 {
            permanentCacheMetadata = metadata
            logger.info("Cleaned up \(removedCount) old permanent cache entries")
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
        // Note: We don't clear permanent cache on normal invalidation
    }
    
    /// Clear permanent cache (use with caution)
    public func clearPermanentCache() {
        let metadata = permanentCacheMetadata
        
        // Remove all permanent cache entries
        for fileKey in metadata.keys {
            let fullKey = "\(permanentCacheKey).\(fileKey)"
            userDefaults.removeObject(forKey: fullKey)
        }
        
        // Clear metadata
        userDefaults.removeObject(forKey: permanentCacheMetadataKey)
        
        logger.warning("Cleared all permanent cache entries")
    }
    
    /// Migrate existing daily usage cache to permanent cache
    public func migrateExistingCacheToPermanent(fileHashCache: [String: Data]) {
        guard let dailyUsage = cachedDailyUsage else {
            logger.info("No existing cache to migrate")
            return
        }
        
        logger.info("Starting migration of existing cache to permanent storage")
        
        // Group entries by file
        let todayStart = Calendar.current.startOfDay(for: Date())
        
        for (_, dayEntries) in dailyUsage {
            for entry in dayEntries {
                // Skip today's entries
                if entry.timestamp >= todayStart {
                    continue
                }
                
                // Try to extract file key from entry data (this is a heuristic)
                // In a real implementation, we'd need to track which file each entry came from
                // For now, we'll skip migration and let the cache rebuild naturally
                logger.debug("Skipping migration for entry - file tracking not available")
            }
        }
        
        logger.info("Migration complete - cache will be built incrementally as files are processed")
    }
}