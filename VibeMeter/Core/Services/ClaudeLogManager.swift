import AppKit
import Foundation
import os.log

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
        openPanel.message = "Please select your home directory to grant VibeMeter access to the ~/.claude folder for reading usage data."
        openPanel.prompt = "Grant Access"
        openPanel.canChooseFiles = false
        openPanel.canChooseDirectories = true
        openPanel.canCreateDirectories = false
        openPanel.allowsMultipleSelection = false
        openPanel.directoryURL = fileManager.homeDirectoryForCurrentUser

        let response = await withCheckedContinuation { continuation in
            openPanel.begin { response in
                continuation.resume(returning: response)
            }
        }

        guard response == .OK, let url = openPanel.url else {
            logger.info("User cancelled folder access request")
            return false
        }

        do {
            let bookmark = try url.bookmarkData(
                options: .withSecurityScope,
                includingResourceValuesForKeys: nil,
                relativeTo: nil)
            saveBookmark(data: bookmark)
            logger.info("Successfully created security-scoped bookmark for folder access")
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
        } catch {
            logger.error("Failed to remove bookmark file: \(error.localizedDescription)")
        }
    }

    /// Get daily usage data from Claude logs
    public func getDailyUsage() async -> [Date: [ClaudeLogEntry]] {
        isProcessing = true
        defer { isProcessing = false }

        guard let accessURL = resolveBookmark() else {
            logger.warning("No access to Claude logs")
            return [:]
        }
        defer { accessURL.stopAccessingSecurityScopedResource() }

        let claudeURL = accessURL.appendingPathComponent(logDirectoryName)
        var dailyUsage: [Date: [ClaudeLogEntry]] = [:]

        guard fileManager.fileExists(atPath: claudeURL.path) else {
            logger.warning("Claude directory not found at: \(claudeURL.path)")
            return [:]
        }

        // Get all JSONL files in the directory and subdirectories
        let jsonlFiles = findJSONLFiles(in: claudeURL)

        let decoder = JSONDecoder()

        for fileURL in jsonlFiles {
            do {
                let content = try String(contentsOf: fileURL, encoding: .utf8)
                let lines = content.split(separator: "\n")

                for line in lines {
                    let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmedLine.isEmpty,
                          let data = trimmedLine.data(using: .utf8) else { continue }

                    do {
                        let entry = try decoder.decode(ClaudeLogEntry.self, from: data)
                        let day = Calendar.current.startOfDay(for: entry.timestamp)
                        dailyUsage[day, default: []].append(entry)
                    } catch {
                        // Log individual line parsing errors at debug level
                        logger.debug("Failed to parse log entry: \(error.localizedDescription)")
                    }
                }
            } catch {
                logger.error("Failed to read file \(fileURL.lastPathComponent): \(error.localizedDescription)")
            }
        }

        logger.info("Parsed \(dailyUsage.values.flatMap(\.self).count) log entries from \(dailyUsage.count) days")
        return dailyUsage
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

        // Claude Pro limits (these should be configurable)
        let inputTokenLimit = 100_000_000 // 100M input tokens per 5 hours
        let outputTokenLimit = 20_000_000 // 20M output tokens per 5 hours

        // Calculate percentage used (weighted average of input and output)
        let inputUsageRatio = Double(totalInputTokens) / Double(inputTokenLimit)
        let outputUsageRatio = Double(totalOutputTokens) / Double(outputTokenLimit)
        let overallUsageRatio = max(inputUsageRatio, outputUsageRatio)

        return FiveHourWindow(
            used: overallUsageRatio * 100,
            total: 100,
            resetDate: fiveHoursAgo.addingTimeInterval(5 * 60 * 60))
    }

    /// Count tokens in text using Tiktoken
    public func countTokens(in text: String) -> Int {
        tiktoken?.countTokens(in: text) ?? 0
    }

    // MARK: - Private Methods

    private func findJSONLFiles(in directory: URL) -> [URL] {
        var jsonlFiles: [URL] = []

        if let enumerator = fileManager.enumerator(at: directory,
                                                   includingPropertiesForKeys: [.isRegularFileKey],
                                                   options: [.skipsHiddenFiles, .skipsPackageDescendants]) {
            for case let fileURL as URL in enumerator where fileURL.pathExtension == "jsonl" {
                jsonlFiles.append(fileURL)
            }
        }

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

            let data = try Data(contentsOf: url)
            self.bookmarkData = data
            logger.info("Loaded existing bookmark for Claude logs")
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
