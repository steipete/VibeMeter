import SwiftUI

/// View mode for the Claude usage report
enum ClaudeUsageViewMode: String, CaseIterable {
    case byDay = "By Day"
    case byProject = "By Project"
}

/// Displays a detailed daily token usage report for Claude
struct ClaudeUsageReportView: View {
    @StateObject
    private var dataLoader = ClaudeUsageDataLoader()

    @State
    private var sortOrder = [KeyPathComparator(\DailyUsageSummary.date, order: .reverse)]
    
    @State
    private var projectSortOrder = [KeyPathComparator(\ProjectUsageSummary.projectName)]

    @State
    private var selectedProject: String = "All Projects"

    @State
    private var selectedCostStrategy: CostCalculationStrategy = .auto
    
    @State
    private var viewMode: ClaudeUsageViewMode = .byDay
    
    @State
    private var dateRangeStart = Date().addingTimeInterval(-30 * 24 * 60 * 60) // 30 days ago
    
    @State
    private var dateRangeEnd = Date()

    @Environment(SettingsManager.self)
    private var settingsManager

    var body: some View {
        VStack(spacing: 0) {
            // Title and description
            VStack(alignment: .leading, spacing: 4) {
                Text("Claude Token Usage Report")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .textSelection(.enabled)

                Text(viewMode == .byDay ? "Daily breakdown of token usage and costs" : "Project breakdown of token usage and costs")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal)
            .padding(.top, 12)
            .padding(.bottom, 8)

            // Progress bar when loading
            if dataLoader.isLoading, dataLoader.totalFiles > 0 {
                VStack(spacing: 6) {
                    ProgressView(
                        value: Double(dataLoader.filesProcessed),
                        total: Double(dataLoader.totalFiles))
                        .progressViewStyle(.linear)
                        .padding(.horizontal)

                    Text(dataLoader.loadingMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.bottom, 12)
            }

            // Content
            VStack(spacing: 0) {
                // Main content area
                if let error = dataLoader.errorMessage {
                    // Error state
                    VStack(spacing: 16) {
                        Spacer()
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundStyle(.orange)

                        Text("Error Loading Data")
                            .font(.headline)

                        Text(error)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 300)

                        Button("Retry") {
                            refreshData()
                        }
                        .buttonStyle(.borderedProminent)
                        Spacer()
                    }
                } else if (viewMode == .byDay ? sortedDays.isEmpty : projectSummaries.isEmpty), !dataLoader.isLoading {
                    // Empty state (only show when not loading)
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)

                        Text("No usage data found")
                            .font(.headline)

                        Text(viewMode == .byDay ? "Start using Claude Code to see your token usage here" : "No projects found in the selected date range")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    Spacer()
                } else if (viewMode == .byDay ? sortedDays.isEmpty : projectSummaries.isEmpty), dataLoader.isLoading, dataLoader.filesProcessed == 0 {
                    // Initial loading state (before any data)
                    VStack(spacing: 16) {
                        Spacer()
                        ProgressView()
                            .progressViewStyle(.circular)
                            .scaleEffect(1.5)

                        Text("Starting scan...")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                } else {
                    // Show table (even if still loading more data)
                    
                    if viewMode == .byDay {
                        // Daily view table
                        Table(of: DailyUsageSummary.self, sortOrder: $sortOrder) {
                        TableColumn("Date", value: \.date) { summary in
                            Text(summary.date, format: .dateTime.year().month().day())
                                .monospacedDigit()
                        }
                        .width(min: 100, ideal: 120)

                        TableColumn("Models") { summary in
                            Text(summary.models.joined(separator: ", "))
                                .font(.system(.body, design: .monospaced))
                        }
                        .width(min: 150, ideal: 200)

                        TableColumn("Input", value: \.inputTokens) { summary in
                            Text(summary.formattedInput)
                                .monospacedDigit()
                        }
                        .width(min: 80, ideal: 100)

                        TableColumn("Output", value: \.outputTokens) { summary in
                            Text(summary.formattedOutput)
                                .monospacedDigit()
                        }
                        .width(min: 80, ideal: 100)

                        TableColumn("Cache Create", value: \.cacheCreationTokens) { summary in
                            Text(summary.formattedCacheCreation)
                                .monospacedDigit()
                                .foregroundStyle(summary.cacheCreationTokens > 0 ? .primary : .secondary)
                        }
                        .width(min: 90, ideal: 110)

                        TableColumn("Cache Read", value: \.cacheReadTokens) { summary in
                            Text(summary.formattedCacheRead)
                                .monospacedDigit()
                                .foregroundStyle(summary.cacheReadTokens > 0 ? .primary : .secondary)
                        }
                        .width(min: 90, ideal: 110)

                        TableColumn("Total Tokens", value: \.totalTokens) { summary in
                            Text(summary.formattedTotal)
                                .monospacedDigit()
                        }
                        .width(min: 100, ideal: 120)

                        TableColumn("Cost (USD)", value: \.cost) { summary in
                            Text(summary.cost, format: .currency(code: "USD"))
                                .monospacedDigit()
                                .foregroundStyle(summary.cost > 10 ? .orange : .primary)
                        }
                        .width(min: 80, ideal: 100)
                        } rows: {
                            ForEach(sortedSummaries) { summary in
                                TableRow(summary)
                            }
                        }
                        .tableStyle(.inset(alternatesRowBackgrounds: true))
                    } else {
                        // Project view table
                        Table(of: ProjectUsageSummary.self, sortOrder: $projectSortOrder) {
                            TableColumn("Session", value: \.projectName) { summary in
                                Text(summary.projectName)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                            .width(min: 150, ideal: 250)
                            
                            TableColumn("Models") { summary in
                                Text(summary.models.joined(separator: ", "))
                                    .font(.system(.body, design: .monospaced))
                            }
                            .width(min: 150, ideal: 200)
                            
                            TableColumn("Input", value: \.inputTokens) { summary in
                                Text(summary.formattedInput)
                                    .monospacedDigit()
                            }
                            .width(min: 80, ideal: 100)
                            
                            TableColumn("Output", value: \.outputTokens) { summary in
                                Text(summary.formattedOutput)
                                    .monospacedDigit()
                            }
                            .width(min: 80, ideal: 100)
                            
                            TableColumn("Cache Create", value: \.cacheCreationTokens) { summary in
                                Text(summary.formattedCacheCreation)
                                    .monospacedDigit()
                                    .foregroundStyle(summary.cacheCreationTokens > 0 ? .primary : .secondary)
                            }
                            .width(min: 90, ideal: 110)
                            
                            TableColumn("Cache Read", value: \.cacheReadTokens) { summary in
                                Text(summary.formattedCacheRead)
                                    .monospacedDigit()
                                    .foregroundStyle(summary.cacheReadTokens > 0 ? .primary : .secondary)
                            }
                            .width(min: 90, ideal: 110)
                            
                            TableColumn("Total Tokens", value: \.totalTokens) { summary in
                                Text(summary.formattedTotal)
                                    .monospacedDigit()
                            }
                            .width(min: 100, ideal: 120)
                            
                            TableColumn("Cost (USD)", value: \.cost) { summary in
                                Text(summary.cost, format: .currency(code: "USD"))
                                    .monospacedDigit()
                                    .foregroundStyle(summary.cost > 10 ? .orange : .primary)
                            }
                            .width(min: 80, ideal: 100)
                            
                            TableColumn("Last Activity", value: \.lastActivity) { summary in
                                Text(summary.lastActivity, format: .dateTime.month().day())
                                    .monospacedDigit()
                            }
                            .width(min: 100, ideal: 120)
                        } rows: {
                            ForEach(sortedProjectSummaries) { summary in
                                TableRow(summary)
                            }
                        }
                        .tableStyle(.inset(alternatesRowBackgrounds: true))
                    }

                    // Summary footer with material background
                    VStack(spacing: 0) {
                        Divider()

                        HStack {
                            Text("Total")
                                .font(.headline)

                            Spacer()

                            HStack(spacing: 24) {
                                VStack(alignment: .trailing) {
                                    Text("Input")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text(totalInputTokens.formatted())
                                        .monospacedDigit()
                                }

                                VStack(alignment: .trailing) {
                                    Text("Output")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text(totalOutputTokens.formatted())
                                        .monospacedDigit()
                                }

                                VStack(alignment: .trailing) {
                                    Text("Total")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text(totalTokens.formatted())
                                        .monospacedDigit()
                                }

                                VStack(alignment: .trailing) {
                                    Text("Cost")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text(totalCost, format: .currency(code: "USD"))
                                        .monospacedDigit()
                                        .fontWeight(.semibold)
                                        .foregroundStyle(totalCost > 50 ? .orange : .primary)
                                }
                            }
                        }
                        .padding()
                        .background(.ultraThinMaterial)
                    }
                }
            }
        }
        .background(.clear)
        .navigationTitle("")
        .onAppear {
            // Initialize cost strategy from settings
            selectedCostStrategy = settingsManager.displaySettingsManager.costCalculationStrategy
            refreshData()
        }
        .toolbar {
            ToolbarItem(placement: .navigation) {
                // View mode picker
                Picker("", selection: $viewMode) {
                    ForEach(ClaudeUsageViewMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 200)
            }
            
            ToolbarItemGroup(placement: .automatic) {
                // Project filter (only in By Day mode)
                if viewMode == .byDay && !dataLoader.availableProjects.isEmpty {
                    Picker("Project", selection: $selectedProject) {
                        Text("All Projects").tag("All Projects")
                        Divider()
                        ForEach(dataLoader.availableProjects, id: \.self) { project in
                            Text(project).tag(project)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(maxWidth: 200)
                }
                
                // Date range selector (only in By Project mode)
                if viewMode == .byProject {
                    HStack(spacing: 8) {
                        Text("Date Range:")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        
                        DatePicker("", selection: $dateRangeStart, displayedComponents: .date)
                            .labelsHidden()
                            .datePickerStyle(.compact)
                        
                        Text("to")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        
                        DatePicker("", selection: $dateRangeEnd, in: dateRangeStart...Date(), displayedComponents: .date)
                            .labelsHidden()
                            .datePickerStyle(.compact)
                    }
                }

                // Cost calculation strategy selector
                Picker("Cost Strategy", selection: $selectedCostStrategy) {
                    ForEach(CostCalculationStrategy.allCases, id: \.self) { strategy in
                        Text(strategy.displayName).tag(strategy)
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: 220)

                // Refresh button
                Button(action: refreshData) {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .disabled(dataLoader.isLoading)
            }
        }
    }

    // MARK: - Data Processing

    private var filteredDailyUsage: [Date: [ClaudeLogEntry]] {
        guard selectedProject != "All Projects" else {
            return dataLoader.dailyUsage
        }

        var filtered: [Date: [ClaudeLogEntry]] = [:]
        for (date, entries) in dataLoader.dailyUsage {
            let projectEntries = entries.filter { $0.projectName == selectedProject }
            if !projectEntries.isEmpty {
                filtered[date] = projectEntries
            }
        }
        return filtered
    }

    private var sortedDays: [Date] {
        filteredDailyUsage.keys.sorted(by: >)
    }

    private var summaries: [DailyUsageSummary] {
        sortedDays.compactMap { date in
            guard let entries = filteredDailyUsage[date] else { return nil }
            return DailyUsageSummary(date: date, entries: entries, costStrategy: selectedCostStrategy)
        }
    }

    private var sortedSummaries: [DailyUsageSummary] {
        summaries.sorted(using: sortOrder)
    }
    
    // Project summaries for "By Project" view
    private var projectSummaries: [ProjectUsageSummary] {
        // Filter entries by date range
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: dateRangeStart)
        let endOfDay = calendar.startOfDay(for: dateRangeEnd).addingTimeInterval(24 * 60 * 60)
        
        let filteredEntries = dataLoader.dailyUsage.flatMap { date, entries -> [ClaudeLogEntry] in
            guard date >= startOfDay && date < endOfDay else { return [] }
            return entries
        }
        
        // Group by project
        let entriesByProject = Dictionary(grouping: filteredEntries) { entry in
            entry.projectName ?? "Unknown"
        }
        
        // Create summaries
        return entriesByProject.map { projectName, entries in
            ProjectUsageSummary(projectName: projectName, entries: entries, costStrategy: selectedCostStrategy)
        }
    }
    
    private var sortedProjectSummaries: [ProjectUsageSummary] {
        projectSummaries.sorted(using: projectSortOrder)
    }

    private var totalInputTokens: Int {
        if viewMode == .byDay {
            return filteredDailyUsage.values.flatMap(\.self).reduce(0) { $0 + $1.inputTokens }
        } else {
            return projectSummaries.reduce(0) { $0 + $1.inputTokens }
        }
    }

    private var totalOutputTokens: Int {
        if viewMode == .byDay {
            return filteredDailyUsage.values.flatMap(\.self).reduce(0) { $0 + $1.outputTokens }
        } else {
            return projectSummaries.reduce(0) { $0 + $1.outputTokens }
        }
    }

    private var totalCacheCreationTokens: Int {
        if viewMode == .byDay {
            return filteredDailyUsage.values.flatMap(\.self).reduce(0) { $0 + ($1.cacheCreationTokens ?? 0) }
        } else {
            return projectSummaries.reduce(0) { $0 + $1.cacheCreationTokens }
        }
    }

    private var totalCacheReadTokens: Int {
        if viewMode == .byDay {
            return filteredDailyUsage.values.flatMap(\.self).reduce(0) { $0 + ($1.cacheReadTokens ?? 0) }
        } else {
            return projectSummaries.reduce(0) { $0 + $1.cacheReadTokens }
        }
    }

    private var totalTokens: Int {
        totalInputTokens + totalOutputTokens + totalCacheCreationTokens + totalCacheReadTokens
    }

    private var totalCost: Double {
        if viewMode == .byDay {
            // Calculate costs based on the selected strategy
            return filteredDailyUsage.values.flatMap(\.self).reduce(0) { $0 + $1.calculateCost(strategy: selectedCostStrategy) }
        } else {
            return projectSummaries.reduce(0) { $0 + $1.cost }
        }
    }

    // MARK: - Actions

    private func refreshData() {
        dataLoader.loadData(forceRefresh: true)
    }
}

// MARK: - Data Models

private struct ProjectUsageSummary: Identifiable {
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
        inputTokens.formatted()
    }
    
    var formattedOutput: String {
        outputTokens.formatted()
    }
    
    var formattedCacheCreation: String {
        cacheCreationTokens > 0 ? cacheCreationTokens.formatted() : "-"
    }
    
    var formattedCacheRead: String {
        cacheReadTokens > 0 ? cacheReadTokens.formatted() : "-"
    }
    
    var formattedTotal: String {
        totalTokens.formatted()
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

private struct DailyUsageSummary: Identifiable {
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
        inputTokens.formatted()
    }

    var formattedOutput: String {
        outputTokens.formatted()
    }

    var formattedCacheCreation: String {
        cacheCreationTokens > 0 ? cacheCreationTokens.formatted() : "-"
    }

    var formattedCacheRead: String {
        cacheReadTokens > 0 ? cacheReadTokens.formatted() : "-"
    }

    var formattedTotal: String {
        totalTokens.formatted()
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
final class ClaudeUsageDataLoader: ObservableObject {
    @Published
    var dailyUsage: [Date: [ClaudeLogEntry]] = [:]
    @Published
    var isLoading = false
    @Published
    var errorMessage: String?
    @Published
    var loadingMessage = "Loading usage data..."
    @Published
    var filesProcessed = 0
    @Published
    var totalFiles = 0
    @Published
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

// MARK: - Preview

#Preview("Claude Usage Report") {
    ZStack {
        Rectangle()
            .fill(.regularMaterial)

        ClaudeUsageReportView()
    }
    .frame(width: 900, height: 650)
    .preferredColorScheme(.dark)
}

#Preview("Claude Usage Report - Light") {
    ZStack {
        Rectangle()
            .fill(.regularMaterial)

        ClaudeUsageReportView()
    }
    .frame(width: 900, height: 650)
    .preferredColorScheme(.light)
}
