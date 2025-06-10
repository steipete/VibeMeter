import AppKit
import Foundation
import os.log
import CryptoKit

// MARK: - Background Actor for Log Processing

/// Actor that handles background processing of Claude log files
actor ClaudeLogProcessor {
    private let logger = Logger(subsystem: "com.vibemeter", category: "ClaudeLogProcessor")
    private let fileManager = FileManager.default
    
    // Pre-compiled regex for efficient matching
    private static let usageEntryPattern = try! NSRegularExpression(
        pattern: #""message".*?"usage".*?"input_tokens":\s*(\d+).*?"output_tokens":\s*(\d+)"#,
        options: []
    )
    
    /// Process all log files and return daily usage
    func processLogFiles(_ fileURLs: [URL], usingCache cache: [String: Data]) async -> (entries: [Date: [ClaudeLogEntry]], updatedCache: [String: Data]) {
        var dailyUsage: [Date: [ClaudeLogEntry]] = [:]
        var updatedCache = cache
        
        await withTaskGroup(of: ([ClaudeLogEntry], String, Data)?.self) { group in
            for fileURL in fileURLs {
                group.addTask(priority: .utility) {
                    await self.processFile(fileURL, existingCache: cache)
                }
            }
            
            // Collect results
            for await result in group {
                if let (entries, fileKey, fileHash) = result {
                    // Update cache
                    updatedCache[fileKey] = fileHash
                    
                    // Group by day
                    for entry in entries {
                        let day = Calendar.current.startOfDay(for: entry.timestamp)
                        dailyUsage[day, default: []].append(entry)
                    }
                }
            }
        }
        
        return (dailyUsage, updatedCache)
    }
    
    private func processFile(_ fileURL: URL, existingCache: [String: Data]) async -> ([ClaudeLogEntry], String, Data)? {
        let fileKey = fileURL.lastPathComponent
        
        do {
            // Read file data
            let fileData = try Data(contentsOf: fileURL)
            
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
        var buffer = Data()
        
        // Process data in chunks
        let chunkSize = 65536 // 64KB
        var offset = 0
        
        while offset < data.count {
            let end = min(offset + chunkSize, data.count)
            let chunk = data.subdata(in: offset..<end)
            buffer.append(chunk)
            offset = end
            
            // Process complete lines
            while let newlineRange = buffer.range(of: Data("\n".utf8)) {
                let lineData = buffer.subdata(in: 0..<newlineRange.lowerBound)
                buffer.removeSubrange(0...newlineRange.lowerBound)
                
                if let entry = parseLogLine(lineData) {
                    entries.append(entry)
                }
            }
        }
        
        // Process any remaining data
        if !buffer.isEmpty, let entry = parseLogLine(buffer) {
            entries.append(entry)
        }
        
        return entries
    }
    
    private func parseLogLine(_ data: Data) -> ClaudeLogEntry? {
        guard let line = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !line.isEmpty else { return nil }
        
        // Quick check with regex for efficiency
        let range = NSRange(location: 0, length: line.utf16.count)
        guard let match = Self.usageEntryPattern.firstMatch(in: line, options: [], range: range) else {
            return nil
        }
        
        // Skip summary and other non-usage entries
        if line.contains("\"type\":\"summary\"") || 
           line.contains("\"type\":\"user\"") ||
           line.contains("\"leafUuid\"") ||
           line.contains("\"sessionId\"") ||
           line.contains("\"parentUuid\"") {
            return nil
        }
        
        // Extract tokens from regex match for quick validation
        if let inputRange = Range(match.range(at: 1), in: line),
           let outputRange = Range(match.range(at: 2), in: line),
           let _ = Int(line[inputRange]),
           let _ = Int(line[outputRange]) {
            
            // Now do full JSON decode since we know it's valid
            if let jsonData = line.data(using: .utf8) {
                do {
                    return try JSONDecoder().decode(ClaudeLogEntry.self, from: jsonData)
                } catch {
                    // Silently skip malformed entries
                }
            }
        }
        
        return nil
    }
}

// MARK: - Protocols

/// Protocol for managing Claude log file access and parsing
@MainActor
public protocol ClaudeLogManagerProtocol: AnyObject, Sendable {
    var hasAccess: Bool { get }
    var isProcessing: Bool { get }
    var lastError: Error? { get }

    func requestLogAccess() async -> Bool
    func revokeAccess()
    func getDailyUsage() async -> [Date: [ClaudeLogEntry]]
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

    private let logger = Logger(subsystem: "com.vibemeter", category: "ClaudeLogManager")
    private let fileManager: FileManager
    private let userDefaults: UserDefaults
    private let logDirectoryName = ".claude/projects"
    private let authTokenManager = AuthenticationTokenManager()
    private let logProcessor = ClaudeLogProcessor()

    @Published
    public private(set) var hasAccess = false
    @Published
    public private(set) var isProcessing = false
    @Published
    public private(set) var lastError: Error?

    private var bookmarkData: Data? {
        didSet {
            hasAccess = bookmarkData != nil
        }
    }
    
    // Cache keys for UserDefaults
    private let cacheKey = "com.vibemeter.claudeLogCache"
    private let cacheTimestampKey = "com.vibemeter.claudeLogCacheTimestamp"
    private let fileHashCacheKey = "com.vibemeter.claudeFileHashCache"
    
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
        loadBookmark()

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
        let openPanel = NSOpenPanel()
        openPanel.title = "Grant Access to Claude Logs"
        openPanel.message =
            "Please select your home directory to grant VibeMeter access to the ~/.claude folder for reading usage data."
        openPanel.prompt = "Grant Access"
        openPanel.canChooseFiles = false
        openPanel.canChooseDirectories = true
        openPanel.canCreateDirectories = false
        openPanel.allowsMultipleSelection = false
        // Get the actual user home directory (not the sandboxed one)
        // In a sandboxed app, NSHomeDirectory() returns the container, so we construct the path manually
        let actualHomeDir = URL(fileURLWithPath: "/Users/\(NSUserName())")
        openPanel.directoryURL = actualHomeDir
        openPanel.showsHiddenFiles = true  // Show hidden files like .claude

        let response = await withCheckedContinuation { continuation in
            openPanel.begin { response in
                continuation.resume(returning: response)
            }
        }

        guard response == .OK, let url = openPanel.url else {
            logger.info("User cancelled folder access request")
            return false
        }

        // Validate that the selected directory can access Claude logs
        logger.info("Validating selected directory: \(url.path)")
        logger.info("Expected home directory: \(actualHomeDir.path)")
        logger.info("NSUserName: \(NSUserName())")
        
        // Check if Claude logs directory exists at the expected location
        let claudeLogsPath = url.appendingPathComponent(logDirectoryName)
        let canAccessClaudeLogs = fileManager.fileExists(atPath: claudeLogsPath.path) ||
                                 url.path == actualHomeDir.path // Accept home directory even if .claude doesn't exist yet
        
        guard canAccessClaudeLogs else {
            logger.warning("Selected directory doesn't contain Claude logs: \(url.path)")
            logger.warning("Expected to find logs at: \(claudeLogsPath.path)")
            // Show alert to user
            await MainActor.run {
                let alert = NSAlert()
                alert.messageText = "Claude Logs Not Found"
                alert.informativeText = "Please select your home directory (\(actualHomeDir.path)) to grant access to Claude logs located in ~/.claude/projects"
                alert.alertStyle = .warning
                alert.addButton(withTitle: "OK")
                alert.runModal()
            }
            return false
        }

        do {
            let bookmark = try url.bookmarkData(
                options: .withSecurityScope,
                includingResourceValuesForKeys: nil,
                relativeTo: nil)
            saveBookmark(data: bookmark)
            logger.info("Successfully created security-scoped bookmark for folder access")

            // Save a dummy token to indicate Claude is "logged in"
            _ = authTokenManager.saveToken("claude_local_access", for: .claude)
            
            // Enable Claude provider if not already enabled
            if !ProviderRegistry.shared.isEnabled(.claude) {
                ProviderRegistry.shared.enableProvider(.claude)
            }

            return true
        } catch {
            logger.error("Failed to create bookmark: \(error.localizedDescription)")
            lastError = error
            return false
        }
    }

    /// Revoke access to Claude logs
    public func revokeAccess() {
        bookmarkData = nil
        do {
            try fileManager.removeItem(at: bookmarkFileURL())
            logger.info("Successfully revoked Claude log access")

            // Remove the dummy token to indicate Claude is "logged out"
            _ = authTokenManager.deleteToken(for: .claude)
        } catch {
            logger.error("Failed to remove bookmark file: \(error.localizedDescription)")
        }
    }

    /// Get daily usage data from Claude logs
    public func getDailyUsage() async -> [Date: [ClaudeLogEntry]] {
        // Check cache first
        if let cachedData = cachedDailyUsage,
           let timestamp = cacheTimestamp,
           Date().timeIntervalSince(timestamp) < cacheValidityDuration {
            logger.info("ClaudeLogManager: Returning cached data")
            return cachedData
        }
        
        isProcessing = true
        defer {
            isProcessing = false
        }

        logger.info("ClaudeLogManager: getDailyUsage started (cache miss)")

        guard let accessURL = resolveBookmark() else {
            logger.warning("ClaudeLogManager: No access to Claude logs - bookmark resolution failed")
            return [:]
        }
        defer { accessURL.stopAccessingSecurityScopedResource() }

        let claudeURL = accessURL.appendingPathComponent(logDirectoryName)
        logger.info("ClaudeLogManager: Looking for Claude logs at: \(claudeURL.path)")

        guard fileManager.fileExists(atPath: claudeURL.path) else {
            logger.warning("ClaudeLogManager: Claude directory not found at: \(claudeURL.path)")
            logger.warning("ClaudeLogManager: Home directory is: \(accessURL.path)")
            return [:]
        }

        // Get all JSONL files in the directory and subdirectories
        let jsonlFiles = findJSONLFiles(in: claudeURL)
        logger.info("ClaudeLogManager: Found \(jsonlFiles.count) JSONL files to process")

        // Process files using the background actor
        let (dailyUsage, updatedHashCache) = await logProcessor.processLogFiles(jsonlFiles, usingCache: fileHashCache)
        
        let totalEntries = dailyUsage.values.flatMap(\.self).count
        logger.info("ClaudeLogManager: Parsed \(totalEntries) total log entries from \(dailyUsage.count) days")
        
        // Update caches
        self.cachedDailyUsage = dailyUsage
        self.cacheTimestamp = Date()
        self.fileHashCache = updatedHashCache
        
        return dailyUsage
    }
    
    /// Invalidate the cache to force a refresh on next access
    public func invalidateCache() {
        cachedDailyUsage = nil
        cacheTimestamp = nil
        fileHashCache = [:]
    }

    /// Calculate the current 5-hour window usage
    public func calculateFiveHourWindow(from dailyUsage: [Date: [ClaudeLogEntry]]) -> FiveHourWindow {
        let now = Date()
        let fiveHoursAgo = now.addingTimeInterval(-5 * 60 * 60)

        // Filter entries within the last 5 hours
        let recentEntries = dailyUsage.values
            .flatMap(\.self)
            .filter { $0.timestamp >= fiveHoursAgo }

        // Calculate total tokens used
        let totalInputTokens = recentEntries.reduce(0) { $0 + $1.inputTokens }
        let totalOutputTokens = recentEntries.reduce(0) { $0 + $1.outputTokens }

        // Get account type from settings
        let accountType = SettingsManager.shared.sessionSettingsManager.claudeAccountType
        
        // For Pro/Team accounts, calculate based on message count approximation
        // Since we don't have exact token limits, we'll estimate based on messages
        if accountType.usesFiveHourWindow, let messagesPerWindow = accountType.messagesPerFiveHours {
            // Estimate average tokens per message (input + output)
            // Average message might be ~2000 tokens input + ~1000 tokens output
            let avgTokensPerMessage = 3000
            let estimatedTokenLimit = messagesPerWindow * avgTokensPerMessage
            
            let totalTokensUsed = totalInputTokens + totalOutputTokens
            let usageRatio = Double(totalTokensUsed) / Double(estimatedTokenLimit)
            
            return FiveHourWindow(
                used: min(usageRatio * 100, 100),
                total: 100,
                resetDate: fiveHoursAgo.addingTimeInterval(5 * 60 * 60))
        } else {
            // Free tier - daily limit
            // Calculate usage for the whole day
            let calendar = Calendar.current
            let startOfDay = calendar.startOfDay(for: now)
            let todayEntries = dailyUsage.values
                .flatMap(\.self)
                .filter { $0.timestamp >= startOfDay }
            
            let messageCount = todayEntries.count
            let dailyLimit = accountType.dailyMessageLimit ?? 50
            let usageRatio = Double(messageCount) / Double(dailyLimit)
            
            // Reset at midnight PT
            var nextResetComponents = calendar.dateComponents([.year, .month, .day], from: now)
            nextResetComponents.day! += 1
            nextResetComponents.hour = 0
            nextResetComponents.minute = 0
            nextResetComponents.timeZone = TimeZone(identifier: "America/Los_Angeles")
            let resetDate = calendar.date(from: nextResetComponents) ?? now
            
            return FiveHourWindow(
                used: min(usageRatio * 100, 100),
                total: 100,
                resetDate: resetDate)
        }
    }

    /// Count tokens in text using Tiktoken
    public func countTokens(in text: String) -> Int {
        tiktoken?.countTokens(in: text) ?? 0
    }

    // MARK: - Private Methods

    private func findJSONLFiles(in directory: URL) -> [URL] {
        var jsonlFiles: [URL] = []
        let cutoffDate = Date().addingTimeInterval(-30 * 24 * 60 * 60) // 30 days ago

        logger.debug("ClaudeLogManager: Searching for JSONL files in: \(directory.path)")

        if let enumerator = fileManager.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey, .contentModificationDateKey, .fileSizeKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) {
            for case let fileURL as URL in enumerator where fileURL.pathExtension == "jsonl" {
                // Skip very old files for performance
                if let attributes = try? fileManager.attributesOfItem(atPath: fileURL.path),
                   let modificationDate = attributes[.modificationDate] as? Date,
                   modificationDate < cutoffDate {
                    logger.trace("Skipping old file: \(fileURL.lastPathComponent)")
                    continue
                }
                
                jsonlFiles.append(fileURL)
                logger.debug("ClaudeLogManager: Found JSONL file: \(fileURL.path)")
            }
        } else {
            logger.error("ClaudeLogManager: Failed to create file enumerator for directory: \(directory.path)")
        }

        // Sort by modification date (newest first) for better cache hits
        jsonlFiles.sort { url1, url2 in
            let date1 = (try? fileManager.attributesOfItem(atPath: url1.path)[.modificationDate] as? Date) ?? Date.distantPast
            let date2 = (try? fileManager.attributesOfItem(atPath: url2.path)[.modificationDate] as? Date) ?? Date.distantPast
            return date1 > date2
        }

        logger.info("ClaudeLogManager: Found \(jsonlFiles.count) JSONL files (excluding old files)")
        return jsonlFiles
    }

    private func saveBookmark(data: Data) {
        do {
            let url = bookmarkFileURL()
            let directory = url.deletingLastPathComponent()

            // Create directory if needed
            if !fileManager.fileExists(atPath: directory.path) {
                try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            }

            try data.write(to: url)
            self.bookmarkData = data
            logger.debug("Saved bookmark to: \(url.path)")
        } catch {
            logger.error("Failed to save bookmark data: \(error.localizedDescription)")
            lastError = error
        }
    }

    private func loadBookmark() {
        do {
            let url = bookmarkFileURL()
            guard fileManager.fileExists(atPath: url.path) else {
                logger.debug("No existing bookmark found")
                return
            }

            logger.info("Loading bookmark from: \(url.path)")
            logger.info("Current NSHomeDirectory: \(NSHomeDirectory())")
            logger.info("Current NSUserName: \(NSUserName())")
            logger.info("Expected home directory: /Users/\(NSUserName())")

            let data = try Data(contentsOf: url)
            
            // Validate the bookmark points to the home directory
            if let validatedURL = validateBookmark(data) {
                self.bookmarkData = data
                logger.info("Loaded existing bookmark for Claude logs at: \(validatedURL.path)")
            } else {
                logger.warning("Existing bookmark is invalid (wrong directory), removing it")
                try? fileManager.removeItem(at: url)
                // Remove the token as well since the bookmark is invalid
                _ = authTokenManager.deleteToken(for: .claude)
                // Disable Claude provider
                if ProviderRegistry.shared.isEnabled(.claude) {
                    ProviderRegistry.shared.disableProvider(.claude)
                }
                
                // Log the issue prominently
                logger.error("IMPORTANT: Claude bookmark was pointing to wrong directory and has been invalidated. User needs to grant access again.")
            }
        } catch {
            logger.error("Failed to load bookmark: \(error.localizedDescription)")
        }
    }

    private func resolveBookmark() -> URL? {
        guard let bookmarkData else {
            logger.debug("No bookmark data available")
            return nil
        }

        do {
            var isStale = false
            let url = try URL(
                resolvingBookmarkData: bookmarkData,
                options: .withSecurityScope,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale)

            logger.debug("Resolved bookmark URL: \(url.path)")
            
            // Check if Claude logs exist at this location
            let claudeLogsPath = url.appendingPathComponent(logDirectoryName)
            logger.debug("Checking for Claude logs at: \(claudeLogsPath.path)")
            
            // Accept the bookmark if it's either:
            // 1. The user's home directory (/Users/username)
            // 2. A directory that contains .claude/projects
            let actualHomeDir = URL(fileURLWithPath: "/Users/\(NSUserName())")
            let isValidLocation = url.path == actualHomeDir.path || 
                                fileManager.fileExists(atPath: claudeLogsPath.path)
            
            guard isValidLocation else {
                logger.error("Bookmark points to invalid directory: \(url.path)")
                logger.error("Expected home directory: \(actualHomeDir.path)")
                logger.error("Claude logs path would be: \(claudeLogsPath.path)")
                // Invalidate the bookmark
                self.bookmarkData = nil
                revokeAccess()
                return nil
            }

            if isStale {
                logger.warning("Bookmark is stale, attempting to refresh")
                let newBookmark = try url.bookmarkData(
                    options: .withSecurityScope,
                    includingResourceValuesForKeys: nil,
                    relativeTo: nil)
                saveBookmark(data: newBookmark)
            }

            guard url.startAccessingSecurityScopedResource() else {
                logger.error("Failed to start accessing security-scoped resource")
                return nil
            }

            return url
        } catch {
            logger.error("Failed to resolve bookmark: \(error.localizedDescription)")
            self.bookmarkData = nil // Invalidate bookmark if it fails
            lastError = error
            return nil
        }
    }

    private func validateBookmark(_ bookmarkData: Data) -> URL? {
        do {
            var isStale = false
            let url = try URL(
                resolvingBookmarkData: bookmarkData,
                options: .withSecurityScope,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale)
            
            logger.debug("Validating bookmark URL: \(url.path)")
            
            // Check if Claude logs exist at this location
            let claudeLogsPath = url.appendingPathComponent(logDirectoryName)
            
            // Accept the bookmark if it's either:
            // 1. The user's home directory (/Users/username)
            // 2. A directory that contains .claude/projects
            let actualHomeDir = URL(fileURLWithPath: "/Users/\(NSUserName())")
            let isValidLocation = url.path == actualHomeDir.path || 
                                fileManager.fileExists(atPath: claudeLogsPath.path)
            
            guard isValidLocation else {
                logger.warning("Bookmark points to invalid directory: \(url.path)")
                logger.warning("Expected home directory: \(actualHomeDir.path) or directory containing .claude/projects")
                return nil
            }
            
            // Try to access it to ensure it's valid
            guard url.startAccessingSecurityScopedResource() else {
                logger.error("Failed to access security-scoped resource for validation")
                return nil
            }
            url.stopAccessingSecurityScopedResource()
            
            return url
        } catch {
            logger.error("Failed to validate bookmark: \(error.localizedDescription)")
            return nil
        }
    }

    private func bookmarkFileURL() -> URL {
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
            // Use temporary directory for tests
            let testDir = fileManager.temporaryDirectory
                .appendingPathComponent("VibeMeterTests")
                .appendingPathComponent("Claude")
            try? fileManager.createDirectory(at: testDir, withIntermediateDirectories: true)
            return testDir.appendingPathComponent("claude_folder_bookmark.data")
        }

        let applicationSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return applicationSupport
            .appendingPathComponent("VibeMeter")
            .appendingPathComponent("claude_folder_bookmark.data")
    }
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
