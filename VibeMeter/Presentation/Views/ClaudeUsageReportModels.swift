import Foundation
import SwiftUI

// MARK: - View Mode

enum ClaudeUsageViewMode: String, CaseIterable {
    case daily = "By Day"
    case project = "By Project"
}

// MARK: - Project Usage Summary

struct ProjectUsageSummary: Identifiable, Sendable {
    let id = UUID()
    let projectName: String
    let inputTokens: Int
    let outputTokens: Int
    let cacheCreationTokens: Int
    let cacheReadTokens: Int
    let totalTokens: Int
    let cost: Double
    let models: [String]
    let lastActivity: Date

    var formattedInput: String {
        inputTokens.formattedTokens
    }

    var formattedOutput: String {
        outputTokens.formattedTokens
    }

    var formattedCacheCreation: String {
        cacheCreationTokens > 0 ? cacheCreationTokens.formattedTokens : "-"
    }

    var formattedCacheRead: String {
        cacheReadTokens > 0 ? cacheReadTokens.formattedTokens : "-"
    }

    var formattedTotal: String {
        totalTokens.formattedTokens
    }

    init(projectName: String, entries: [ClaudeLogEntry], costStrategy: CostCalculationStrategy = .auto) {
        self.projectName = projectName
        self.inputTokens = entries.reduce(0) { $0 + $1.inputTokens }
        self.outputTokens = entries.reduce(0) { $0 + $1.outputTokens }
        self.cacheCreationTokens = entries.reduce(0) { $0 + ($1.cacheCreationTokens ?? 0) }
        self.cacheReadTokens = entries.reduce(0) { $0 + ($1.cacheReadTokens ?? 0) }
        self.totalTokens = inputTokens + outputTokens + cacheCreationTokens + cacheReadTokens

        // Calculate cost based on the selected strategy
        self.cost = entries.reduce(0) { $0 + $1.calculateCost(strategy: costStrategy) }

        // Get unique models used, sorted, and filter out "synthetic" entries
        let uniqueModels = Set<String>(entries.compactMap { entry in
            guard let model = entry.model else { return nil }
            // Skip synthetic entries completely
            if model == "<synthetic>" {
                return nil
            }
            // Remove "<synthetic>, " prefix if present
            if model.hasPrefix("<synthetic>, ") {
                return String(model.dropFirst("<synthetic>, ".count))
            }
            // Also handle "synthetic, " without angle brackets
            if model.hasPrefix("synthetic, ") {
                return String(model.dropFirst("synthetic, ".count))
            }
            return model
        })
        self.models = Array(uniqueModels).sorted()

        // Get last activity date
        self.lastActivity = entries.map(\.timestamp).max() ?? Date()
    }
}

// MARK: - Daily Usage Summary

struct DailyUsageSummary: Identifiable, Sendable {
    let id = UUID()
    let date: Date
    let inputTokens: Int
    let outputTokens: Int
    let cacheCreationTokens: Int
    let cacheReadTokens: Int
    let totalTokens: Int
    let cost: Double
    let models: [String]

    var formattedInput: String {
        inputTokens.formattedTokens
    }

    var formattedOutput: String {
        outputTokens.formattedTokens
    }

    var formattedCacheCreation: String {
        cacheCreationTokens > 0 ? cacheCreationTokens.formattedTokens : "-"
    }

    var formattedCacheRead: String {
        cacheReadTokens > 0 ? cacheReadTokens.formattedTokens : "-"
    }

    var formattedTotal: String {
        totalTokens.formattedTokens
    }

    init(date: Date, entries: [ClaudeLogEntry], costStrategy: CostCalculationStrategy = .auto) {
        self.date = date
        self.inputTokens = entries.reduce(0) { $0 + $1.inputTokens }
        self.outputTokens = entries.reduce(0) { $0 + $1.outputTokens }
        self.cacheCreationTokens = entries.reduce(0) { $0 + ($1.cacheCreationTokens ?? 0) }
        self.cacheReadTokens = entries.reduce(0) { $0 + ($1.cacheReadTokens ?? 0) }
        self.totalTokens = inputTokens + outputTokens + cacheCreationTokens + cacheReadTokens

        // Calculate cost based on the selected strategy
        self.cost = entries.reduce(0) { $0 + $1.calculateCost(strategy: costStrategy) }

        // Get unique models used, sorted, and filter out "synthetic" entries
        let uniqueModels = Set<String>(entries.compactMap { entry in
            guard let model = entry.model else { return nil }
            // Skip synthetic entries completely
            if model == "<synthetic>" {
                return nil
            }
            // Remove "<synthetic>, " prefix if present
            if model.hasPrefix("<synthetic>, ") {
                return String(model.dropFirst("<synthetic>, ".count))
            }
            // Also handle "synthetic, " without angle brackets
            if model.hasPrefix("synthetic, ") {
                return String(model.dropFirst("synthetic, ".count))
            }
            return model
        })
        self.models = Array(uniqueModels).sorted()
    }
}

// MARK: - Data Loader

/// Observable object that handles loading Claude usage data with progress updates
@MainActor
@Observable
final class ClaudeUsageDataLoader {
    var dailyUsage: [Date: [ClaudeLogEntry]] = [:]
    var isLoading = false
    var errorMessage: String?
    var loadingMessage = "Loading usage data..."
    var filesProcessed = 0
    var totalFiles = 0
    var availableProjects: [String] = []

    private let claudeLogManager = ClaudeLogManager.shared

    func loadData(forceRefresh: Bool = false) {
        guard !isLoading else { return }

        if forceRefresh {
            claudeLogManager.invalidateCache()
            dailyUsage = [:] // Only clear if force refresh
            availableProjects = []
        }

        isLoading = true
        errorMessage = nil
        filesProcessed = 0
        totalFiles = 0

        Task {
            guard claudeLogManager.hasAccess else {
                errorMessage = "No folder access granted. Please grant access in settings."
                isLoading = false
                return
            }

            let usage = await claudeLogManager.getDailyUsageWithProgress(delegate: self)

            // Final update in case delegate methods weren't called
            if dailyUsage.isEmpty, !usage.isEmpty {
                dailyUsage = usage
            }

            isLoading = false
        }
    }

    private func updateAvailableProjects() {
        let projects = dailyUsage.values
            .flatMap(\.self)
            .compactMap(\.projectName)
        availableProjects = Array(Set(projects)).sorted()
    }
}

// MARK: - ClaudeLogProgressDelegate

extension ClaudeUsageDataLoader: ClaudeLogProgressDelegate {
    func logProcessingDidStart(totalFiles: Int) {
        self.totalFiles = totalFiles
        self.loadingMessage = "Scanning \(totalFiles) log files..."
    }

    func logProcessingDidUpdate(filesProcessed: Int, dailyUsage: [Date: [ClaudeLogEntry]]) {
        self.filesProcessed = filesProcessed
        self.dailyUsage = dailyUsage

        let percentage = totalFiles > 0 ? Int((Double(filesProcessed) / Double(totalFiles)) * 100) : 0
        self.loadingMessage = "Processing files... \(percentage)% (\(filesProcessed)/\(totalFiles))"

        // Update available projects
        updateAvailableProjects()

        // Keep isLoading true - it will be set to false in logProcessingDidComplete
    }

    func logProcessingDidComplete(dailyUsage: [Date: [ClaudeLogEntry]]) {
        self.dailyUsage = dailyUsage
        self.isLoading = false
        self.loadingMessage = ""
        updateAvailableProjects()
    }

    func logProcessingDidFail(error: Error) {
        self.errorMessage = error.localizedDescription
        self.isLoading = false
    }
}