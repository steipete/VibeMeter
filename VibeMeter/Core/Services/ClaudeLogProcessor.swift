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
        cacheManager: ClaudeLogCacheManager? = nil,
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
                group.addTask(priority: .background) { [self] in
                    // Process file without actor isolation to allow true parallelism
                    return await self.processFileParallel(fileURL, existingCache: cache, cacheManager: cacheManager)
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
    private nonisolated func processFileParallel(_ fileURL: URL,
                                                 existingCache: [String: Data],
                                                 cacheManager: ClaudeLogCacheManager?) async
        -> ([ClaudeLogEntry], String, Data)? {
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

            // Check temporary cache first
            if let cachedHash = existingCache[fileKey], cachedHash == hashData {
                return nil
            }

            // Check permanent cache if available
            if let cacheManager = cacheManager {
                // Need to call this on MainActor since ClaudeLogCacheManager is @MainActor
                let cachedEntries = await cacheManager.getPermanentlyCachedEntries(for: fileKey, fileHash: hashData)
                
                if let entries = cachedEntries {
                    // Return cached entries with metadata
                    return (entries, fileKey, hashData)
                }
            }

            // Parse the file data in parallel
            let entries = parseFileDataParallel(fileData, projectName: projectName)
            
            // Store in permanent cache if eligible
            if let cacheManager = cacheManager, !entries.isEmpty {
                await cacheManager.permanentlyCacheEntries(entries, for: fileKey, fileHash: hashData)
            }

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
    private nonisolated func extractProjectNameParallel(from fileURL: URL) -> String {
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
    private nonisolated func parseFileDataParallel(_ data: Data, projectName: String? = nil) -> [ClaudeLogEntry] {
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