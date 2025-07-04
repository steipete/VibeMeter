import Foundation
import os.log

/// Manages all caching for Claude log data using SQLite database
@MainActor
public final class ClaudeLogCacheManager: @unchecked Sendable {
    private let logger = Logger.vibeMeter(category: "ClaudeLogCacheManager")
    private let userDefaults: UserDefaults
    private let databaseManager = DatabaseManager.shared
    
    // Cache keys for UserDefaults (only for small metadata)
    private let cacheTimestampKey = "com.vibemeter.claudeLogCacheTimestamp"
    private let cacheVersionKey = "com.vibemeter.claudeLogCacheVersion"
    
    // Cache schema version - increment this when parser format changes
    private let currentCacheVersion = 6 // Incremented for database migration
    
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
            logger.info("Cache version outdated (stored: \(storedVersion), current: \(self.currentCacheVersion)). Migrating to database.")
            Task {
                await migrateToDatabase()
            }
            userDefaults.set(currentCacheVersion, forKey: cacheVersionKey)
        }
        
        // Initialize database if needed
        Task {
            do {
                if !databaseManager.isInitialized {
                    try await databaseManager.initialize()
                }
            } catch {
                logger.error("Failed to initialize database: \(error)")
            }
        }
    }
    
    // MARK: - Daily Usage Cache
    
    /// Get cached daily usage data from database
    public func getCachedDailyUsage(from startDate: Date, to endDate: Date) async -> [Date: [ClaudeLogEntry]]? {
        guard databaseManager.isInitialized else { return nil }
        
        do {
            let dailyUsage = try await databaseManager.fetchClaudeLogs(from: startDate, to: endDate)
            
            // Convert DailyClaudeUsage to ClaudeLogEntry and group by date
            var result: [Date: [ClaudeLogEntry]] = [:]
            for usage in dailyUsage {
                let entry = ClaudeLogEntry(
                    timestamp: usage.timestamp,
                    model: usage.model,
                    inputTokens: usage.inputTokens,
                    outputTokens: usage.outputTokens,
                    cacheCreationTokens: usage.cacheCreationTokens,
                    cacheReadTokens: usage.cacheReadTokens,
                    costUSD: usage.costUSD,
                    projectName: usage.project,
                    parentUuid: usage.conversationId,
                    conversationType: nil
                )
                
                let date = Calendar.current.startOfDay(for: usage.timestamp)
                if result[date] == nil {
                    result[date] = []
                }
                result[date]?.append(entry)
            }
            
            return result.isEmpty ? nil : result
        } catch {
            logger.error("Failed to fetch cached daily usage: \(error)")
            return nil
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
    
    /// Check if file hash exists in database
    public func hasFileHash(_ hash: String) async -> Bool {
        guard databaseManager.isInitialized else { return false }
        
        do {
            return try await databaseManager.hasLogsForFile(hash: hash)
        } catch {
            logger.error("Failed to check file hash: \(error)")
            return false
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
    
    /// Check if a file is eligible for permanent caching (older than today)
    public func isEligibleForPermanentCache(fileKey: String, entries: [ClaudeLogEntry]) -> Bool {
        guard !entries.isEmpty else { return false }
        
        // Get the latest entry date
        let latestDate = entries.max(by: { $0.timestamp < $1.timestamp })?.timestamp ?? Date()
        let todayStart = Calendar.current.startOfDay(for: Date())
        
        // File is eligible if all entries are from before today
        return latestDate < todayStart
    }
    
    /// Get permanently cached entries for a file from database
    public func getPermanentlyCachedEntries(for fileKey: String, fileHash: Data) async -> [ClaudeLogEntry]? {
        guard databaseManager.isInitialized else { return nil }
        
        let hashString = fileHash.base64EncodedString()
        
        do {
            // Check if we have logs for this file hash
            guard try await databaseManager.hasLogsForFile(hash: hashString) else {
                return nil
            }
            
            // Fetch all logs (we'll filter by file hash later if needed)
            let allLogs = try await databaseManager.fetchClaudeLogs()
            
            // Convert to ClaudeLogEntry
            let entries = allLogs.map { usage in
                ClaudeLogEntry(
                    timestamp: usage.timestamp,
                    model: usage.model,
                    inputTokens: usage.inputTokens,
                    outputTokens: usage.outputTokens,
                    cacheCreationTokens: usage.cacheCreationTokens,
                    cacheReadTokens: usage.cacheReadTokens,
                    costUSD: usage.costUSD,
                    projectName: usage.project,
                    parentUuid: usage.conversationId,
                    conversationType: nil
                )
            }
            
            logger.debug("Retrieved \(entries.count) entries from database for \(fileKey)")
            return entries
        } catch {
            logger.error("Failed to get cached entries: \(error)")
            return nil
        }
    }
    
    /// Permanently cache entries for a file in database
    public func permanentlyCacheEntries(_ entries: [ClaudeLogEntry], for fileKey: String, fileHash: Data) async {
        guard !entries.isEmpty,
              isEligibleForPermanentCache(fileKey: fileKey, entries: entries),
              databaseManager.isInitialized else {
            return
        }
        
        let hashString = fileHash.base64EncodedString()
        
        // Convert to DailyClaudeUsage for database storage
        let dailyUsages = entries.map { entry in
            DailyClaudeUsage(
                conversationId: entry.parentUuid ?? UUID().uuidString,
                timestamp: entry.timestamp,
                model: entry.model ?? "unknown",
                inputTokens: entry.inputTokens,
                outputTokens: entry.outputTokens,
                cacheCreationTokens: entry.cacheCreationTokens ?? 0,
                cacheReadTokens: entry.cacheReadTokens ?? 0,
                costUSD: entry.costUSD ?? 0.0,
                project: entry.projectName,
                title: nil
            )
        }
        
        do {
            try await databaseManager.insertClaudeLogs(dailyUsages, filePath: fileKey, fileHash: hashString)
            logger.info("Permanently cached \(entries.count) entries for \(fileKey) in database")
        } catch {
            logger.error("Failed to cache entries in database: \(error)")
        }
    }
    
    /// Clean up old cache entries from database
    public func cleanupOldPermanentCache(olderThan days: Int = 90) async {
        guard databaseManager.isInitialized else { return }
        
        _ = Date().addingTimeInterval(-Double(days) * 24 * 60 * 60)
        
        // For now, we'll keep all data in the database
        // In the future, we might want to implement cleanup based on date
        logger.info("Database cleanup not yet implemented - all data retained")
    }
    
    // MARK: - Cache Management
    
    /// Update daily usage cache in database
    public func updateDailyUsageCache(_ dailyUsage: [Date: [ClaudeLogEntry]], fileHashCache: [String: Data]) async {
        guard databaseManager.isInitialized else {
            logger.warning("Database not initialized, skipping cache update")
            return
        }
        
        // Update timestamp
        self.cacheTimestamp = Date()
        
        // Convert and store in database
        for (_, entries) in dailyUsage {
            let dailyUsages = entries.map { entry in
                DailyClaudeUsage(
                    conversationId: entry.parentUuid ?? UUID().uuidString,
                    timestamp: entry.timestamp,
                    model: entry.model ?? "unknown",
                    inputTokens: entry.inputTokens,
                    outputTokens: entry.outputTokens,
                    cacheCreationTokens: entry.cacheCreationTokens ?? 0,
                    cacheReadTokens: entry.cacheReadTokens ?? 0,
                    costUSD: entry.costUSD ?? 0.0,
                    project: entry.projectName,
                    title: nil
                )
            }
            
            do {
                try await databaseManager.insertClaudeLogs(dailyUsages)
            } catch {
                logger.error("Failed to update database cache: \(error)")
            }
        }
        
        let totalEntries = dailyUsage.values.flatMap { $0 }.count
        logger.info("Processed \(totalEntries) entries, updated database cache")
    }
    
    /// Invalidate all caches
    public func invalidateAll() {
        cacheTimestamp = nil
        currentWindowCache = nil
        currentWindowCacheTime = nil
        todaysLogCache = nil
        todaysLogCacheURL = nil
        todaysLogCacheModificationDate = nil
        // Note: We don't clear database on normal invalidation
    }
    
    /// Clear all database cache (use with caution)
    public func clearPermanentCache() async {
        guard databaseManager.isInitialized else { return }
        
        do {
            try await databaseManager.clearAllData()
            logger.warning("Cleared all database cache entries")
        } catch {
            logger.error("Failed to clear database cache: \(error)")
        }
    }
    
    /// Migrate existing UserDefaults cache to database
    private func migrateToDatabase() async {
        logger.info("Starting migration from UserDefaults to database")
        
        // Clean up old UserDefaults keys
        let oldKeys = [
            "com.vibemeter.claudeLogCache",
            "com.vibemeter.claudeFileHashCache",
            "com.vibemeter.claudeLogPermanentCache",
            "com.vibemeter.claudeLogPermanentCacheMetadata"
        ]
        
        for key in oldKeys {
            if userDefaults.object(forKey: key) != nil {
                userDefaults.removeObject(forKey: key)
                logger.debug("Removed old UserDefaults key: \(key)")
            }
        }
        
        logger.info("Migration complete - old UserDefaults cache cleared")
    }
}