// VibeMeter/Core/Services/ClaudeLogManager.swift
// Created by Codegen – Phase 1 implementation

import Foundation
import os.log
import AppKit

#if canImport(Tiktoken)
import Tiktoken
#endif

/// Service responsible for accessing and parsing local Claude log files.
@MainActor
public final class ClaudeLogManager {
    public static let shared = ClaudeLogManager()

    private let logger = Logger(subsystem: "com.steipete.vibemeter", category: "ClaudeLogManager")
    private let fileManager = FileManager.default
    private let logDirectoryName = ".claude/projects"
    private var bookmarkData: Data?

    private lazy var tiktoken: Tiktoken? = {
        #if canImport(Tiktoken)
        return try? Tiktoken(encoding: .o200k_base)
        #else
        return nil
        #endif
    }()

    private init() {
        loadBookmark()
    }

    // MARK: - Sandbox Bookmark Handling

    /// Prompts user to grant access to their home directory (for ~/.claude).
    public func requestLogAccess() async -> Bool {
        let openPanel = NSOpenPanel()
        openPanel.message = "Please select your home directory to grant VibeMeter access to the ~/.claude folder."
        openPanel.prompt = "Grant Access"
        openPanel.canChooseFiles = false
        openPanel.canChooseDirectories = true
        openPanel.canCreateDirectories = false
        openPanel.directoryURL = fileManager.homeDirectoryForCurrentUser

        let response = await openPanel.begin()
        guard response == .OK, let url = openPanel.url else { return false }

        do {
            let bookmark = try url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
            saveBookmark(data: bookmark)
            logger.info("Successfully created security-scoped bookmark for Claude logs folder access.")
            return true
        } catch {
            logger.error("Failed to create bookmark: \(error.localizedDescription)")
            return false
        }
    }

    public func hasAccess() -> Bool {
        bookmarkData != nil
    }

    // MARK: - Parsing

    /// Reads *.jsonl log files under ~/.claude/projects and groups entries by day.
    public func getDailyUsage() async -> [Date: [ClaudeLogEntry]] {
        guard let accessURL = resolveBookmark() else { return [:] }
        defer { accessURL.stopAccessingSecurityScopedResource() }

        let claudeURL = accessURL.appendingPathComponent(logDirectoryName)
        var dailyUsage: [Date: [ClaudeLogEntry]] = [:]

        guard let enumerator = fileManager.enumerator(at: claudeURL, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles, .skipsPackageDescendants]) else {
            return [:]
        }

        for case let fileURL as URL in enumerator {
            guard fileURL.pathExtension == "jsonl" else { continue }
            parse(fileURL: fileURL, accumulating: &dailyUsage)
        }
        return dailyUsage
    }

    // MARK: - Helpers

    private func parse(fileURL: URL, accumulating dailyUsage: inout [Date: [ClaudeLogEntry]]) {
        do {
            let content = try String(contentsOf: fileURL)
            let lines = content.split(separator: "\n")
            let decoder = JSONDecoder()
            for line in lines {
                guard let data = String(line).data(using: .utf8) else { continue }
                if let entry = try? decoder.decode(ClaudeLogEntry.self, from: data) {
                    let day = Calendar.current.startOfDay(for: entry.timestamp)
                    dailyUsage[day, default: []].append(entry)
                }
            }
        } catch {
            logger.error("Failed to read or parse Claude log file \(fileURL.lastPathComponent): \(error.localizedDescription)")
        }
    }

    private func saveBookmark(data: Data) {
        do {
            try data.write(to: bookmarkFileURL())
            bookmarkData = data
        } catch {
            logger.error("Failed to save bookmark data: \(error.localizedDescription)")
        }
    }

    private func loadBookmark() {
        guard let data = try? Data(contentsOf: bookmarkFileURL()) else { return }
        bookmarkData = data
    }

    private func resolveBookmark() -> URL? {
        guard let bookmarkData else { return nil }
        do {
            var isStale = false
            let url = try URL(resolvingBookmarkData: bookmarkData, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &isStale)
            if isStale {
                logger.warning("Claude log bookmark is stale – refreshing.")
                let refreshed = try url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
                saveBookmark(data: refreshed)
            }
            guard url.startAccessingSecurityScopedResource() else {
                logger.error("Failed to access security-scoped resource for Claude logs.")
                return nil
            }
            return url
        } catch {
            logger.error("Failed to resolve Claude bookmark: \(error.localizedDescription)")
            return nil
        }
    }

    private func bookmarkFileURL() -> URL {
        let support = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return support.appendingPathComponent("VibeMeter/claude_folder_bookmark.data")
    }
}

