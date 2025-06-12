import AppKit
import CryptoKit
import Foundation
import os.log

// MARK: - Background Actor for Log Processing

/// Actor that handles background processing of Claude log files
actor ClaudeLogProcessor {
    private let logger = Logger.vibeMeter(category: "ClaudeLogProcessor")
    private let fileManager = FileManager.default

    // Ultra-fast parallel processing
    private let processingQueue = DispatchQueue(label: "log.processing", attributes: .concurrent)
    private let processingGroup = DispatchGroup()

    /// Process all log files and return daily usage with progress updates
    func processLogFiles(
        _ fileURLs: [URL],
        usingCache cache: [String: Data],
        progressHandler: (@Sendable (Int, [Date: [ClaudeLogEntry]]) async -> Void)? = nil) async -> (entries: [
        Date: [ClaudeLogEntry]
    ], updatedCache: [String: Data]) {
        // Use actor for thread-safe collection of results
        actor ResultCollector {
            var dailyUsage: [Date: [ClaudeLogEntry]] = [:]
            var updatedCache: [String: Data]
            var filesProcessed = 0

            init(cache: [String: Data]) {
                self.updatedCache = cache
            }

            func addResult(entries: [ClaudeLogEntry], fileKey: String, fileHash: Data) {
                updatedCache[fileKey] = fileHash
                filesProcessed += 1

                // Group by day
                for entry in entries {
                    let day = Calendar.current.startOfDay(for: entry.timestamp)
                    dailyUsage[day, default: []].append(entry)
                }
            }

            func incrementProcessedCount() {
                filesProcessed += 1
            }

            func getResults() -> ([Date: [ClaudeLogEntry]], [String: Data], Int) {
                (dailyUsage, updatedCache, filesProcessed)
            }
        }

        let collector = ResultCollector(cache: cache)

        // Use all available processors for maximum parallelism
        let processorCount = ProcessInfo.processInfo.activeProcessorCount
        logger.info("Processing \(fileURLs.count) log files using \(processorCount) processors")

        // Process all files concurrently with TRUE parallelism
        await withTaskGroup(of: ([ClaudeLogEntry], String, Data)?.self, returning: Void.self) { group in
            // Add all tasks at once - Swift concurrency will manage the actual parallelism
            for fileURL in fileURLs {
                group.addTask(priority: .high) { [self] in
                    // Process file without actor isolation to allow true parallelism
                    return await self.processFileParallel(fileURL, existingCache: cache)
                }
            }

            // Collect results as they complete
            var processedCount = 0
            for await result in group {
                processedCount += 1
                
                if let (entries, fileKey, fileHash) = result {
                    await collector.addResult(entries: entries, fileKey: fileKey, fileHash: fileHash)
                } else {
                    await collector.incrementProcessedCount()
                }

                // Send progress update if handler provided
                if let progressHandler {
                    let (currentDailyUsage, _, currentFilesProcessed) = await collector.getResults()
                    await progressHandler(currentFilesProcessed, currentDailyUsage)
                }
                
                // Log progress periodically
                if processedCount % 10 == 0 {
                    logger.debug("Processed \(processedCount)/\(fileURLs.count) files")
                }
            }
        }

        let (dailyUsage, updatedCache, _) = await collector.getResults()
        let totalEntries = dailyUsage.values.flatMap(\.self).count
        logger.info("Processed \(totalEntries) total entries across all files")

        return (dailyUsage, updatedCache)
    }

    private func processFile(_ fileURL: URL, existingCache: [String: Data]) async -> ([ClaudeLogEntry], String, Data)? {
        let fileKey = fileURL.lastPathComponent
        let projectName = extractProjectName(from: fileURL)

        do {
            // Use memory-mapped files for zero-copy access
            let fileData = try Data(contentsOf: fileURL, options: .alwaysMapped)

            // Skip tiny files
            guard fileData.count > 100 else { return nil }

            // Ultra-fast hash calculation (only first and last 1KB)
            let hashData: Data
            if fileData.count > 2048 {
                var hasher = SHA256()
                fileData.withUnsafeBytes { bytes in
                    hasher.update(bufferPointer: UnsafeRawBufferPointer(start: bytes.baseAddress, count: 1024))
                    hasher.update(bufferPointer: UnsafeRawBufferPointer(
                        start: bytes.baseAddress! + fileData.count - 1024,
                        count: 1024))
                }
                hashData = Data(hasher.finalize())
            } else {
                hashData = Data(SHA256.hash(data: fileData))
            }

            // Check cache
            if let cachedHash = existingCache[fileKey], cachedHash == hashData {
                return nil
            }

            // Parse the file data
            let entries = parseFileData(fileData, projectName: projectName)

            return (entries, fileKey, hashData)
        } catch {
            return nil
        }
    }

    // Non-actor isolated method for true parallel processing
    nonisolated private func processFileParallel(_ fileURL: URL, existingCache: [String: Data]) async -> ([ClaudeLogEntry], String, Data)? {
        let fileKey = fileURL.lastPathComponent
        let projectName = extractProjectNameParallel(from: fileURL)

        do {
            // Use memory-mapped files for zero-copy access
            let fileData = try Data(contentsOf: fileURL, options: .alwaysMapped)

            // Skip tiny files
            guard fileData.count > 100 else { return nil }

            // Ultra-fast hash calculation (only first and last 1KB)
            let hashData: Data
            if fileData.count > 2048 {
                var hasher = SHA256()
                fileData.withUnsafeBytes { bytes in
                    hasher.update(bufferPointer: UnsafeRawBufferPointer(start: bytes.baseAddress, count: 1024))
                    hasher.update(bufferPointer: UnsafeRawBufferPointer(
                        start: bytes.baseAddress! + fileData.count - 1024,
                        count: 1024))
                }
                hashData = Data(hasher.finalize())
            } else {
                hashData = Data(SHA256.hash(data: fileData))
            }

            // Check cache
            if let cachedHash = existingCache[fileKey], cachedHash == hashData {
                return nil
            }

            // Parse the file data in parallel
            let entries = parseFileDataParallel(fileData, projectName: projectName)

            return (entries, fileKey, hashData)
        } catch {
            return nil
        }
    }

    private func extractProjectName(from fileURL: URL) -> String {
        // Get the parent directory name (e.g., "-Users-steipete-Projects-VibeMeter")
        let parentDirectory = fileURL.deletingLastPathComponent().lastPathComponent

        // Convert back to human-readable format
        // Replace leading dash and convert dashes to slashes
        var projectPath = parentDirectory
        if projectPath.hasPrefix("-") {
            projectPath = String(projectPath.dropFirst())
        }
        projectPath = projectPath.replacingOccurrences(of: "-", with: "/")

        // Extract just the project name (last component)
        let pathComponents = projectPath.split(separator: "/")
        if let projectName = pathComponents.last {
            return String(projectName)
        }

        return parentDirectory
    }

    // Non-isolated version for parallel processing
    nonisolated private func extractProjectNameParallel(from fileURL: URL) -> String {
        // Get the parent directory name (e.g., "-Users-steipete-Projects-VibeMeter")
        let parentDirectory = fileURL.deletingLastPathComponent().lastPathComponent

        // Convert back to human-readable format
        // Replace leading dash and convert dashes to slashes
        var projectPath = parentDirectory
        if projectPath.hasPrefix("-") {
            projectPath = String(projectPath.dropFirst())
        }
        projectPath = projectPath.replacingOccurrences(of: "-", with: "/")

        // Extract just the project name (last component)
        let pathComponents = projectPath.split(separator: "/")
        if let projectName = pathComponents.last {
            return String(projectName)
        }

        return parentDirectory
    }

    private func parseFileData(_ data: Data, projectName: String? = nil) -> [ClaudeLogEntry] {
        var entries: [ClaudeLogEntry] = []
        entries.reserveCapacity(1000) // Pre-allocate for typical file sizes

        // Use direct byte processing for better performance
        data.withUnsafeBytes { bytes in
            let buffer = bytes.bindMemory(to: UInt8.self)
            var lineStart = 0

            for i in 0 ..< buffer.count {
                if buffer[i] == 0x0A { // '\n'
                    let lineLength = i - lineStart
                    if lineLength > 0 {
                        // Create string from line bytes
                        let lineData = Data(bytes: buffer.baseAddress! + lineStart, count: lineLength)
                        if let lineString = String(data: lineData, encoding: .utf8),
                           let entry = ClaudeCodeLogParser.parseLogLine(lineString, projectName: projectName) {
                            entries.append(entry)
                        }
                    }
                    lineStart = i + 1
                }
            }

            // Handle last line if no trailing newline
            if lineStart < buffer.count {
                let lineLength = buffer.count - lineStart
                let lineData = Data(bytes: buffer.baseAddress! + lineStart, count: lineLength)
                if let lineString = String(data: lineData, encoding: .utf8),
                   let entry = ClaudeCodeLogParser.parseLogLine(lineString, projectName: projectName) {
                    entries.append(entry)
                }
            }
        }

        return entries
    }

    // Non-isolated version for parallel processing
    nonisolated private func parseFileDataParallel(_ data: Data, projectName: String? = nil) -> [ClaudeLogEntry] {
        var entries: [ClaudeLogEntry] = []
        entries.reserveCapacity(1000) // Pre-allocate for typical file sizes

        // Use direct byte processing for better performance
        data.withUnsafeBytes { bytes in
            let buffer = bytes.bindMemory(to: UInt8.self)
            var lineStart = 0

            for i in 0 ..< buffer.count {
                if buffer[i] == 0x0A { // '\n'
                    let lineLength = i - lineStart
                    if lineLength > 0 {
                        // Create string from line bytes
                        let lineData = Data(bytes: buffer.baseAddress! + lineStart, count: lineLength)
                        if let lineString = String(data: lineData, encoding: .utf8),
                           let entry = ClaudeCodeLogParser.parseLogLine(lineString, projectName: projectName) {
                            entries.append(entry)
                        }
                    }
                    lineStart = i + 1
                }
            }

            // Handle last line if no trailing newline
            if lineStart < buffer.count {
                let lineLength = buffer.count - lineStart
                let lineData = Data(bytes: buffer.baseAddress! + lineStart, count: lineLength)
                if let lineString = String(data: lineData, encoding: .utf8),
                   let entry = ClaudeCodeLogParser.parseLogLine(lineString, projectName: projectName) {
                    entries.append(entry)
                }
            }
        }

        return entries
    }
}

// MARK: - Protocols

/// Protocol for receiving progress updates during log processing
@MainActor
public protocol ClaudeLogProgressDelegate: AnyObject, Sendable {
    func logProcessingDidStart(totalFiles: Int)
    func logProcessingDidUpdate(filesProcessed: Int, dailyUsage: [Date: [ClaudeLogEntry]])
    func logProcessingDidComplete(dailyUsage: [Date: [ClaudeLogEntry]])
    func logProcessingDidFail(error: Error)
}

/// Protocol for managing Claude log file access and parsing
@MainActor
public protocol ClaudeLogManagerProtocol: AnyObject, Sendable {
    var hasAccess: Bool { get }
    var isProcessing: Bool { get }
    var lastError: Error? { get }

    func requestLogAccess() async -> Bool
    func revokeAccess()
    func getDailyUsage() async -> [Date: [ClaudeLogEntry]]
    func getDailyUsageWithProgress(delegate: ClaudeLogProgressDelegate?) async -> [Date: [ClaudeLogEntry]]
    func calculateFiveHourWindow(from dailyUsage: [Date: [ClaudeLogEntry]]) -> FiveHourWindow
    func countTokens(in text: String) -> Int
    func getCurrentWindowUsage() async -> FiveHourWindow
}

/// Manages access to Claude log files and parses usage data
@MainActor
public final class ClaudeLogManager: ObservableObject, ClaudeLogManagerProtocol, @unchecked Sendable {
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

    @Published
    public private(set) var hasAccess = false
    @Published
    public private(set) var isProcessing = false
    @Published
    public private(set) var lastError: Error?

    // Cache keys for UserDefaults
    private let cacheKey = "com.vibemeter.claudeLogCache"
    private let cacheTimestampKey = "com.vibemeter.claudeLogCacheTimestamp"
    private let fileHashCacheKey = "com.vibemeter.claudeFileHashCache"
    private let cacheVersionKey = "com.vibemeter.claudeLogCacheVersion"

    // Cache schema version - increment this when parser format changes
    private let currentCacheVersion = 4 // Incremented for progressive loading support

    // Cache for parsed usage data
    private var cachedDailyUsage: [Date: [ClaudeLogEntry]]? {
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

    private var cacheTimestamp: Date? {
        get {
            userDefaults.object(forKey: cacheTimestampKey) as? Date
        }
        set {
            userDefaults.set(newValue, forKey: cacheTimestampKey)
        }
    }

    // File hash cache for detecting changes
    private var fileHashCache: [String: Data] {
        get {
            userDefaults.dictionary(forKey: fileHashCacheKey) as? [String: Data] ?? [:]
        }
        set {
            userDefaults.set(newValue, forKey: fileHashCacheKey)
        }
    }

    private let cacheValidityDuration: TimeInterval = 300 // 5 minutes

    private lazy var tiktoken: Tiktoken? = {
        do {
            return try Tiktoken(encoding: .o200k_base)
        } catch {
            logger.error("Failed to initialize Tiktoken: \(error.localizedDescription)")
            return nil
        }
    }()

    // MARK: - Initialization

    public init(fileManager: FileManager = .default,
                userDefaults: UserDefaults = .standard) {
        self.fileManager = fileManager
        self.userDefaults = userDefaults
        self.bookmarkManager = ClaudeLogBookmarkManager()
        self.fileScanner = ClaudeLogFileScanner()
        self.windowCalculator = ClaudeFiveHourWindowCalculator()

        // Check cache version and invalidate if outdated
        let storedVersion = userDefaults.integer(forKey: cacheVersionKey)
        if storedVersion < currentCacheVersion {
            logger
                .info(
                    "Cache version outdated (stored: \(storedVersion), current: \(self.currentCacheVersion)). Clearing cache.")
            invalidateCacheInternal()
            userDefaults.set(currentCacheVersion, forKey: cacheVersionKey)
        }

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
        if let cachedData = cachedDailyUsage,
           let timestamp = cacheTimestamp,
           Date().timeIntervalSince(timestamp) < cacheValidityDuration {
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
        let (dailyUsage, updatedHashCache) = await logProcessor.processLogFiles(
            jsonlFiles,
            usingCache: fileHashCache,
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
        self.cachedDailyUsage = dailyUsage
        self.cacheTimestamp = Date()
        self.fileHashCache = updatedHashCache

        // Notify delegate of completion
        delegate?.logProcessingDidComplete(dailyUsage: dailyUsage)

        return dailyUsage
    }

    /// Invalidate the cache to force a refresh on next access
    public func invalidateCache() {
        invalidateCacheInternal()
    }

    private func invalidateCacheInternal() {
        cachedDailyUsage = nil
        cacheTimestamp = nil
        fileHashCache = [:]
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
        guard let accessURL = bookmarkManager.resolveBookmark() else {
            logger.warning("No access to Claude logs for real-time updates")
            return FiveHourWindow(used: 0, total: 100, resetDate: Date().addingTimeInterval(5 * 60 * 60), tokensUsed: 0, estimatedTokenLimit: 0)
        }
        defer { accessURL.stopAccessingSecurityScopedResource() }

        guard let claudeURL = bookmarkManager.getClaudeLogsURL() else {
            return FiveHourWindow(used: 0, total: 100, resetDate: Date().addingTimeInterval(5 * 60 * 60), tokensUsed: 0, estimatedTokenLimit: 0)
        }

        // Get entries from the last 5 hours
        let fiveHoursAgo = Date().addingTimeInterval(-5 * 60 * 60)
        var recentEntries: [ClaudeLogEntry] = []

        // First check today's log file for recent entries
        if let todaysLogFile = fileScanner.findTodaysLogFile(in: claudeURL) {
            logger.debug("Processing today's log file for real-time updates")

            // Process today's file without cache (for real-time accuracy)
            let (dailyUsage, _) = await logProcessor.processLogFiles([todaysLogFile], usingCache: [:])
            let entries = dailyUsage.values.flatMap(\.self)
            let recentFromToday = entries.filter { $0.timestamp >= fiveHoursAgo }
            recentEntries.append(contentsOf: recentFromToday)
            logger.debug("Found \(recentFromToday.count) recent entries in today's log")
        }

        // If we need more data (crossing day boundary), check cached data
        if Calendar.current.startOfDay(for: Date()) > fiveHoursAgo {
            // We need data from yesterday too
            if let cachedData = cachedDailyUsage {
                let yesterdayEntries = cachedData.values.flatMap(\.self)
                    .filter { $0.timestamp >= fiveHoursAgo && $0.timestamp < Calendar.current.startOfDay(for: Date()) }
                recentEntries.append(contentsOf: yesterdayEntries)
                logger.debug("Added \(yesterdayEntries.count) entries from cache")
            }
        }

        // Build daily usage map for window calculation
        var windowDailyUsage: [Date: [ClaudeLogEntry]] = [:]
        for entry in recentEntries {
            let day = Calendar.current.startOfDay(for: entry.timestamp)
            windowDailyUsage[day, default: []].append(entry)
        }

        return windowCalculator.calculateFiveHourWindow(from: windowDailyUsage)
    }

    // MARK: - Private Methods
}

// MARK: - Errors

public enum ClaudeLogManagerError: LocalizedError {
    case noAccess
    case invalidLogFormat
    case fileSystemError(Error)

    public var errorDescription: String? {
        switch self {
        case .noAccess:
            "No access to Claude logs. Please grant folder access in settings."
        case .invalidLogFormat:
            "Invalid Claude log format"
        case let .fileSystemError(error):
            "File system error: \(error.localizedDescription)"
        }
    }
}
