import Foundation
import AppKit
import os.log

/// Manages security-scoped bookmarks for accessing Claude log files
@MainActor
final class ClaudeLogBookmarkManager: @unchecked Sendable {
    private let logger = Logger.vibeMeter(category: "ClaudeLogBookmarkManager")
    private let fileManager = FileManager.default
    private let logDirectoryName = ".claude/projects"
    private var bookmarkData: Data?
    
    var hasAccess: Bool {
        bookmarkData != nil
    }
    
    init() {
        loadBookmark()
    }
    
    /// Request access to the Claude logs directory
    func requestLogAccess() async -> Bool {
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
        let actualHomeDir = URL(fileURLWithPath: NSHomeDirectory())
        openPanel.directoryURL = actualHomeDir
        openPanel.showsHiddenFiles = true // Show hidden files like .claude
        
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
                alert.informativeText =
                    "Please select your home directory (\(NSHomeDirectory())) to grant access to Claude logs located in ~/.claude/projects"
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
            logger.info("Successfully created security-scoped bookmark for folder access.")
            return true
        } catch {
            logger.error("Failed to create bookmark: \(error.localizedDescription)")
            return false
        }
    }
    
    /// Revoke access to Claude logs
    func revokeAccess() {
        bookmarkData = nil
        do {
            try fileManager.removeItem(at: bookmarkFileURL())
            logger.info("Successfully revoked Claude log access")
        } catch {
            logger.error("Failed to remove bookmark file: \(error.localizedDescription)")
        }
    }
    
    /// Resolve the bookmark and return the access URL
    func resolveBookmark() -> URL? {
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
            let actualHomeDir = URL(fileURLWithPath: NSHomeDirectory())
            let isValidLocation = url.path == actualHomeDir.path ||
                fileManager.fileExists(atPath: claudeLogsPath.path)
            
            guard isValidLocation else {
                logger.error("Bookmark points to invalid directory: \(url.path)")
                logger.error("Expected home directory: \(NSHomeDirectory())")
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
            return nil
        }
    }
    
    /// Get the Claude logs directory URL
    func getClaudeLogsURL() -> URL? {
        guard let accessURL = resolveBookmark() else { return nil }
        return accessURL.appendingPathComponent(logDirectoryName)
    }
    
    // MARK: - Private Methods
    
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
            
            let data = try Data(contentsOf: url)
            
            // Validate the bookmark points to the home directory
            if let validatedURL = validateBookmark(data) {
                self.bookmarkData = data
                logger.info("Loaded existing bookmark for Claude logs at: \(validatedURL.path)")
            } else {
                logger.warning("Existing bookmark is invalid (wrong directory), removing it")
                try? fileManager.removeItem(at: url)
            }
        } catch {
            logger.error("Failed to load bookmark: \(error.localizedDescription)")
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
            let actualHomeDir = URL(fileURLWithPath: NSHomeDirectory())
            let isValidLocation = url.path == actualHomeDir.path ||
                fileManager.fileExists(atPath: claudeLogsPath.path)
            
            guard isValidLocation else {
                logger.warning("Bookmark points to invalid directory: \(url.path)")
                logger.warning("Expected home directory: \(NSHomeDirectory()) or directory containing .claude/projects")
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