import AppKit
import Foundation
import os.log

// MARK: - Main Manager


/// Manages access to Claude log files and parses usage data
@MainActor
@Observable
public final class ClaudeLogManager: ClaudeLogManagerProtocol, @unchecked Sendable {
    // MARK: - Singleton (for backward compatibility)

    private static let _shared = MainActor.assumeIsolated {
        ClaudeLogManager()
    }

    public nonisolated static var shared: ClaudeLogManager {
        MainActor.assumeIsolated {
            _shared
        }
    }

    // MARK: - Properties

    private let logger = Logger.vibeMeter(category: "ClaudeLogManager")
    private let fileManager: FileManager
    private let userDefaults: UserDefaults
    private let authTokenManager = AuthenticationTokenManager()
    private let logProcessor = ClaudeLogProcessor()

    // New components
    private let bookmarkManager: ClaudeLogBookmarkManager
    private let fileScanner: ClaudeLogFileScanner
    private let windowCalculator: ClaudeFiveHourWindowCalculator
    private let cacheManager: ClaudeLogCacheManager
    private let sessionTracker = ClaudeSessionTracker()

    public private(set) var hasAccess = false
    public private(set) var isProcessing = false
    public private(set) var lastError: Error?

    private var _tiktoken: Tiktoken?
    private var tiktoken: Tiktoken? {
        if _tiktoken == nil {
            do {
                _tiktoken = try Tiktoken(encoding: .o200k_base)
            } catch {
                logger.error("Failed to initialize Tiktoken: \(error.localizedDescription)")
            }
        }
        return _tiktoken
    }

    // MARK: - Initialization

    public init(fileManager: FileManager = .default,
                userDefaults: UserDefaults = .standard) {
        self.fileManager = fileManager
        self.userDefaults = userDefaults
        self.bookmarkManager = ClaudeLogBookmarkManager()
        self.fileScanner = ClaudeLogFileScanner()
        self.windowCalculator = ClaudeFiveHourWindowCalculator()
        self.cacheManager = ClaudeLogCacheManager(userDefaults: userDefaults)

        // Set up access state
        self.hasAccess = bookmarkManager.hasAccess

        // If we have access, ensure we have a token saved and provider is enabled
        if hasAccess {
            _ = authTokenManager.saveToken("claude_local_access", for: .claude)
            // Enable Claude provider if not already enabled
            if !ProviderRegistry.shared.isEnabled(.claude) {
                ProviderRegistry.shared.enableProvider(.claude)
            }

            // Clear any error messages since we have valid access
            Task { @MainActor in
                if let orchestrator = (NSApp.delegate as? AppDelegate)?.multiProviderOrchestrator {
                    orchestrator.userSessionData.clearError(for: .claude)
                }
            }
        }
    }

    // Convenience init for singleton
    private convenience init() {
        self.init(fileManager: .default, userDefaults: .standard)
    }

    // MARK: - Public Methods

    /// Request access to the Claude logs directory
    public func requestLogAccess() async -> Bool {
        let success = await bookmarkManager.requestLogAccess()

        if success {
            hasAccess = true

            // Save a dummy token to indicate Claude is "logged in"
            _ = authTokenManager.saveToken("claude_local_access", for: .claude)

            // Enable Claude provider if not already enabled
            if !ProviderRegistry.shared.isEnabled(.claude) {
                ProviderRegistry.shared.enableProvider(.claude)
            }
        }

        return success
    }

    /// Revoke access to Claude logs
    public func revokeAccess() {
        bookmarkManager.revokeAccess()
        hasAccess = false

        // Remove the dummy token to indicate Claude is "logged out"
        _ = authTokenManager.deleteToken(for: .claude)
    }

    /// Get daily usage data from Claude logs
    public func getDailyUsage() async -> [Date: [ClaudeLogEntry]] {
        await getDailyUsageWithProgress(delegate: nil)
    }

    /// Get daily usage data from Claude logs with progress updates
    public func getDailyUsageWithProgress(delegate: ClaudeLogProgressDelegate?) async -> [Date: [ClaudeLogEntry]] {
        // Check cache first
        let startDate = Date().addingTimeInterval(-90 * 24 * 60 * 60) // 90 days back
        let endDate = Date()
        if let cachedData = await cacheManager.getCachedDailyUsage(from: startDate, to: endDate),
           cacheManager.isCacheValid {
            logger.info("ClaudeLogManager: Returning cached data")
            delegate?.logProcessingDidComplete(dailyUsage: cachedData)
            return cachedData
        }

        isProcessing = true
        defer {
            isProcessing = false
        }

        logger.info("ClaudeLogManager: getDailyUsage started (cache miss)")

        guard let accessURL = bookmarkManager.resolveBookmark() else {
            logger.warning("ClaudeLogManager: No access to Claude logs - bookmark resolution failed")
            let error = ClaudeLogManagerError.noAccess
            delegate?.logProcessingDidFail(error: error)
            return [:]
        }
        defer { accessURL.stopAccessingSecurityScopedResource() }

        guard let claudeURL = bookmarkManager.getClaudeLogsURL() else {
            logger.warning("ClaudeLogManager: Could not get Claude logs URL")
            let error = ClaudeLogManagerError.noAccess
            delegate?.logProcessingDidFail(error: error)
            return [:]
        }

        logger.info("ClaudeLogManager: Looking for Claude logs at: \(claudeURL.path)")

        guard fileScanner.claudeLogsExist(at: accessURL) else {
            logger.warning("ClaudeLogManager: Claude directory not found")
            let error = ClaudeLogManagerError.fileSystemError(
                NSError(domain: "ClaudeLogManager", code: 404, userInfo: [
                    NSLocalizedDescriptionKey: "Claude logs directory not found",
                ]))
            delegate?.logProcessingDidFail(error: error)
            return [:]
        }

        // Get all JSONL files in the directory and subdirectories
        let jsonlFiles = fileScanner.findJSONLFiles(in: claudeURL)
        logger.info("ClaudeLogManager: Found \(jsonlFiles.count) JSONL files to process")

        // Log sample of files for debugging
        if !jsonlFiles.isEmpty {
            let firstFiles = jsonlFiles.prefix(3).map(\.lastPathComponent).joined(separator: ", ")
            logger.info("ClaudeLogManager: First few files: \(firstFiles)")
        }

        // Notify delegate of start
        delegate?.logProcessingDidStart(totalFiles: jsonlFiles.count)

        // Create a progress handler that properly captures the delegate
        let progressHandler: (@Sendable (Int, [Date: [ClaudeLogEntry]]) async -> Void)? = if let delegate {
            { filesProcessed, currentDailyUsage in
                await MainActor.run {
                    delegate.logProcessingDidUpdate(
                        filesProcessed: filesProcessed,
                        dailyUsage: currentDailyUsage)
                }
            }
        } else {
            nil
        }

        // Process files using the background actor with parallel processing
        // Process files using the background actor with parallel processing
        let (dailyUsage, updatedHashCache) = await logProcessor.processLogFiles(
            jsonlFiles,
            usingCache: [:], // File hash cache now in database
            cacheManager: cacheManager,
            progressHandler: progressHandler)

        let totalEntries = dailyUsage.values.flatMap(\.self).count
        logger.info("ClaudeLogManager: Parsed \(totalEntries) total log entries from \(dailyUsage.count) days")

        // Log the dates we found for debugging
        if !dailyUsage.isEmpty {
            let dates = dailyUsage.keys.sorted().map { DateFormatter.localizedString(
                from: $0,
                dateStyle: .short,
                timeStyle: .none) }
            logger.info("ClaudeLogManager: Found data for dates: \(dates.joined(separator: ", "))")
        }

        // Update caches
        await cacheManager.updateDailyUsageCache(dailyUsage, fileHashCache: updatedHashCache)
        
        // Update session tracker with all entries
        let allEntries = dailyUsage.values.flatMap { $0 }
        sessionTracker.updateSessions(from: allEntries)

        // Notify delegate of completion
        delegate?.logProcessingDidComplete(dailyUsage: dailyUsage)

        return dailyUsage
    }

    /// Invalidate the cache to force a refresh on next access
    public func invalidateCache() {
        cacheManager.invalidateAll()
    }

    /// Calculate the current 5-hour window usage
    public func calculateFiveHourWindow(from dailyUsage: [Date: [ClaudeLogEntry]]) -> FiveHourWindow {
        windowCalculator.calculateFiveHourWindow(from: dailyUsage)
    }

    /// Count tokens in text using Tiktoken
    public func countTokens(in text: String) -> Int {
        tiktoken?.countTokens(in: text) ?? 0
    }

    /// Get real-time usage for the current 5-hour window (optimized for frequent updates)
    public func getCurrentWindowUsage() async -> FiveHourWindow {
        // Check if we have a valid cached result
        if let cachedWindow = cacheManager.getCachedCurrentWindow() {
            return cachedWindow
        }

        guard let accessURL = bookmarkManager.resolveBookmark() else {
            logger.warning("No access to Claude logs for real-time updates")
            return FiveHourWindow(
                used: 0,
                total: 100,
                resetDate: Date().addingTimeInterval(5 * 60 * 60),
                tokensUsed: 0,
                estimatedTokenLimit: 0)
        }
        defer { accessURL.stopAccessingSecurityScopedResource() }

        guard let claudeURL = bookmarkManager.getClaudeLogsURL() else {
            return FiveHourWindow(
                used: 0,
                total: 100,
                resetDate: Date().addingTimeInterval(5 * 60 * 60),
                tokensUsed: 0,
                estimatedTokenLimit: 0)
        }

        // Get entries from the last 5 hours
        let fiveHoursAgo = Date().addingTimeInterval(-5 * 60 * 60)
        var recentEntries: [ClaudeLogEntry] = []

        // First check today's log file for recent entries
        if let todaysLogFile = fileScanner.findTodaysLogFile(in: claudeURL) {
            logger.debug("Processing today's log file for real-time updates")

            // Check if we can use cached data
            var entries: [ClaudeLogEntry] = []

            if let cachedEntries = cacheManager.getCachedTodaysLog(for: todaysLogFile, fileManager: fileManager) {
                entries = cachedEntries
            } else {
                // No cache or file was modified, process it
                logger.debug("Processing today's log file")
                let (dailyUsage, _) = await logProcessor.processLogFiles([todaysLogFile], usingCache: [:], cacheManager: nil)
                entries = dailyUsage.values.flatMap(\.self)

                // Cache the results
                cacheManager.cacheTodaysLog(entries, for: todaysLogFile, fileManager: fileManager)
                
                // Also update the daily usage cache with today's data
                let todayDate = Calendar.current.startOfDay(for: Date())
                if var cachedDaily = cacheManager.cachedDailyUsage {
                    cachedDaily[todayDate] = entries
                    cacheManager.cachedDailyUsage = cachedDaily
                } else {
                    cacheManager.cachedDailyUsage = [todayDate: entries]
                }
                
                logger.info("Cached \(entries.count) entries for today in daily usage cache")
            }

            let recentFromToday = entries.filter { $0.timestamp >= fiveHoursAgo }
            recentEntries.append(contentsOf: recentFromToday)
            logger.debug("Found \(recentFromToday.count) recent entries in today's log")
        }

        // If we need more data (crossing day boundary), check cached data
        if Calendar.current.startOfDay(for: Date()) > fiveHoursAgo {
            // We need data from yesterday too
            if let cachedData = cacheManager.cachedDailyUsage {
                let yesterdayEntries = cachedData.values.flatMap(\.self)
                    .filter { $0.timestamp >= fiveHoursAgo && $0.timestamp < Calendar.current.startOfDay(for: Date()) }
                recentEntries.append(contentsOf: yesterdayEntries)
                logger.debug("Added \(yesterdayEntries.count) entries from cache")
            }
        }

        // Build daily usage map for window calculation
        // Include all of today's data for proper calculation, not just 5-hour window
        var windowDailyUsage: [Date: [ClaudeLogEntry]] = [:]
        
        // Add all recent entries (5-hour window)
        for entry in recentEntries {
            let day = Calendar.current.startOfDay(for: entry.timestamp)
            windowDailyUsage[day, default: []].append(entry)
        }
        
        // Also include all of today's entries for accurate token counting
        let todayDate = Calendar.current.startOfDay(for: Date())
        if let todaysCachedData = cacheManager.cachedDailyUsage?[todayDate] {
            // Merge today's full data with what we already have
            windowDailyUsage[todayDate] = todaysCachedData
        }

        // Update session tracker with recent entries
        let allCurrentEntries = windowDailyUsage.values.flatMap { $0 }
        sessionTracker.updateSessions(from: allCurrentEntries)
        
        // Use session-aware calculation if we have an active session
        let window: FiveHourWindow
        if sessionTracker.getActiveSession() != nil {
            window = sessionTracker.calculateSessionAwareFiveHourWindow()
        } else {
            // Fall back to traditional calculation
            window = windowCalculator.calculateFiveHourWindow(from: windowDailyUsage)
        }

        // Cache the result
        cacheManager.cacheCurrentWindow(window)

        return window
    }

    /// Get session tracker for burn rate calculations
    public func getSessionTracker() -> ClaudeSessionTracker {
        sessionTracker
    }
    
    // MARK: - Private Methods
}

// End of ClaudeLogManager
