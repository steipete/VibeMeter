import Foundation
import os.log

/// Scans for Claude JSONL log files in the .claude/projects directory
@MainActor
final class ClaudeLogFileScanner: @unchecked Sendable {
    private let logger = Logger.vibeMeter(category: "ClaudeLogFileScanner")
    private let fileManager = FileManager.default
    private let logDirectoryName = ".claude/projects"

    /// Find all JSONL files in the Claude logs directory
    func findJSONLFiles(in directory: URL) -> [URL] {
        var jsonlFiles: [URL] = []
        let cutoffDate = Date().addingTimeInterval(-30 * 24 * 60 * 60) // 30 days ago

        // Date formatter for parsing filenames (optimization #9)
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        logger.debug("Searching for JSONL files in: \(directory.path)")

        if let enumerator = fileManager.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey, .contentModificationDateKey, .fileSizeKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]) {
            for case let fileURL as URL in enumerator where fileURL.pathExtension == "jsonl" {
                let filename = fileURL.lastPathComponent

                // Try to extract date from filename first (optimization #9)
                if let dateRange = filename.range(of: #"\d{4}-\d{2}-\d{2}"#, options: .regularExpression) {
                    let dateString = String(filename[dateRange])
                    if let fileDate = dateFormatter.date(from: dateString),
                       fileDate < cutoffDate {
                        logger.trace("Skipping old file based on filename: \(filename)")
                        continue
                    }
                } else {
                    // Fall back to modification date if no date in filename
                    if let attributes = try? fileManager.attributesOfItem(atPath: fileURL.path),
                       let modificationDate = attributes[.modificationDate] as? Date,
                       modificationDate < cutoffDate {
                        logger.trace("Skipping old file: \(fileURL.lastPathComponent)")
                        continue
                    }
                }

                jsonlFiles.append(fileURL)
                logger.debug("Found JSONL file: \(fileURL.path)")
            }
        } else {
            logger.error("Failed to create file enumerator for directory: \(directory.path)")
        }

        // Sort by modification date (newest first) for better cache hits
        jsonlFiles.sort { url1, url2 in
            let date1 = (try? fileManager.attributesOfItem(atPath: url1.path)[.modificationDate] as? Date) ?? Date
                .distantPast
            let date2 = (try? fileManager.attributesOfItem(atPath: url2.path)[.modificationDate] as? Date) ?? Date
                .distantPast
            return date1 > date2
        }

        logger.info("Found \(jsonlFiles.count) JSONL files (excluding old files)")
        return jsonlFiles
    }

    /// Check if Claude logs directory exists at the given location
    func claudeLogsExist(at baseURL: URL) -> Bool {
        let claudeLogsPath = baseURL.appendingPathComponent(logDirectoryName)
        return fileManager.fileExists(atPath: claudeLogsPath.path)
    }

    /// Get the Claude logs directory URL from a base URL
    func getClaudeLogsURL(from baseURL: URL) -> URL {
        baseURL.appendingPathComponent(logDirectoryName)
    }

    /// Find today's JSONL log file
    func findTodaysLogFile(in directory: URL) -> URL? {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let todayString = dateFormatter.string(from: Date())

        logger.debug("Looking for today's log file with date: \(todayString)")

        if let enumerator = fileManager.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]) {
            for case let fileURL as URL in enumerator where fileURL.pathExtension == "jsonl" {
                let filename = fileURL.lastPathComponent
                if filename.contains(todayString) {
                    logger.info("Found today's log file: \(filename)")
                    return fileURL
                }
            }
        }

        logger.debug("No log file found for today (\(todayString))")
        return nil
    }
}
