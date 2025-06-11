import AppKit
import CryptoKit
import Foundation
import os.log

// MARK: - Background Actor for Log Processing

/// Actor that handles background processing of Claude log files
actor ClaudeLogProcessor {
    private let logger = Logger.vibeMeter(category: "ClaudeLogProcessor")
    private let fileManager = FileManager.default

    /// Process all log files and return daily usage with progress updates
    func processLogFiles(
        _ fileURLs: [URL],
        usingCache cache: [String: Data],
        progressHandler: (@Sendable (Int, [Date: [ClaudeLogEntry]]) async -> Void)? = nil) async -> (entries: [
        Date: [ClaudeLogEntry]
    ], updatedCache: [String: Data]) {
        var dailyUsage: [Date: [ClaudeLogEntry]] = [:]
        var updatedCache = cache
        var filesProcessed = 0

        logger.info("Processing \(fileURLs.count) log files")

        // Process files one by one for streaming updates
        for fileURL in fileURLs {
            if let result = await processFile(fileURL, existingCache: cache) {
                let (entries, fileKey, fileHash) = result

                // Update cache
                updatedCache[fileKey] = fileHash

                // Group by day
                for entry in entries {
                    let day = Calendar.current.startOfDay(for: entry.timestamp)
                    dailyUsage[day, default: []].append(entry)
                }

                filesProcessed += 1

                // Send progress update
                if let progressHandler {
                    await progressHandler(filesProcessed, dailyUsage)
                }
            } else {
                filesProcessed += 1

                // Still send progress update even if no entries found
                if let progressHandler {
                    await progressHandler(filesProcessed, dailyUsage)
                }
            }
        }

        let totalEntries = dailyUsage.values.flatMap(\.self).count
        logger.info("Processed \(totalEntries) total entries across all files")

        return (dailyUsage, updatedCache)
    }

    private func processFile(_ fileURL: URL, existingCache: [String: Data]) async -> ([ClaudeLogEntry], String, Data)? {
        let fileKey = fileURL.lastPathComponent

        do {
            // Skip small files (optimization #6)
            let attributes = try fileManager.attributesOfItem(atPath: fileURL.path)
            let fileSize = attributes[.size] as? Int64 ?? 0
            if fileSize < 100 { // Skip tiny files
                logger.trace("Skipping tiny file: \(fileKey) (\(fileSize) bytes)")
                return nil
            }

            // Use memory-mapped files for better performance (optimization #4)
            let fileData = try Data(contentsOf: fileURL, options: .mappedIfSafe)

            // Calculate SHA-256 hash
            let hash = SHA256.hash(data: fileData)
            let hashData = Data(hash)

            // Check if file hasn't changed
            if let cachedHash = existingCache[fileKey], cachedHash == hashData {
                logger.debug("Skipping unchanged file: \(fileKey)")
                return nil
            }

            // Parse the file
            let entries = parseFileData(fileData)
            logger.debug("Parsed \(entries.count) entries from \(fileKey)")

            return (entries, fileKey, hashData)
        } catch {
            logger.error("Failed to process file \(fileKey): \(error)")
            return nil
        }
    }

    private func parseFileData(_ data: Data) -> [ClaudeLogEntry] {
        var entries: [ClaudeLogEntry] = []
        var linesProcessed = 0
        var linesWithTokens = 0

        // Use autoreleasepool for better memory management with large files
        autoreleasepool {
            var buffer = Data()

            // Process data in chunks for memory efficiency
            let chunkSize = 65536 // 64KB
            var offset = 0

            // Pre-allocate capacity based on estimated entries per chunk
            // Assuming average line size of ~500 bytes
            let estimatedEntriesPerChunk = chunkSize / 500
            entries.reserveCapacity(estimatedEntriesPerChunk * (data.count / chunkSize + 1))

            while offset < data.count {
                // Use autoreleasepool for each chunk to free memory immediately
                autoreleasepool {
                    let end = min(offset + chunkSize, data.count)
                    let chunk = data.subdata(in: offset ..< end)
                    buffer.append(chunk)
                    offset = end

                    // Process complete lines
                    while let newlineRange = buffer.range(of: Data("\n".utf8)) {
                        let lineData = buffer.subdata(in: 0 ..< newlineRange.lowerBound)
                        buffer.removeSubrange(0 ... newlineRange.lowerBound)

                        linesProcessed += 1
                        if let entry = parseLogLine(lineData) {
                            entries.append(entry)
                            linesWithTokens += 1
                        }
                    }
                }
            }

            // Process any remaining data
            if !buffer.isEmpty {
                linesProcessed += 1
                if let entry = parseLogLine(buffer) {
                    entries.append(entry)
                    linesWithTokens += 1
                }
            }
        }

        if linesProcessed > 0 {
            logger.debug("Processed \(linesProcessed) lines, found \(linesWithTokens) with token data")
        }

        return entries
    }

    private func parseLogLine(_ data: Data) -> ClaudeLogEntry? {
        guard let line = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !line.isEmpty else { return nil }

        // Use the flexible ClaudeCodeLogParser
        return ClaudeCodeLogParser.parseLogLine(line)
    }
}

// MARK: - Protocols

/// Protocol for receiving progress updates during log processing
@MainActor
public protocol ClaudeLogProgressDelegate: AnyObject {
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
    private let currentCacheVersion = 2 // Incremented for cache token support

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
            logger.info("Cache version outdated (stored: \(storedVersion), current: \(currentCacheVersion)). Clearing cache.")
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

        // Notify delegate of start
        delegate?.logProcessingDidStart(totalFiles: jsonlFiles.count)

        // Process files using the background actor without progress handler
        // to avoid Sendable issues with delegate capture
        let (dailyUsage, updatedHashCache) = await logProcessor.processLogFiles(
            jsonlFiles,
            usingCache: fileHashCache)

        let totalEntries = dailyUsage.values.flatMap(\.self).count
        logger.info("ClaudeLogManager: Parsed \(totalEntries) total log entries from \(dailyUsage.count) days")

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
