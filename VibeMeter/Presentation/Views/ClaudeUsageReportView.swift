import SwiftUI

/// Displays a detailed daily token usage report for Claude
struct ClaudeUsageReportView: View {
    // MARK: - Environment

    @Environment(SettingsManager.self) private var settingsManager

    // MARK: - State

    @State var dataLoader = ClaudeUsageDataLoader()
    @State var sortOrder: [KeyPathComparator<DailyUsageSummary>] = [
        .init(\.date, order: .reverse),
    ]
    @State var projectSortOrder: [KeyPathComparator<ProjectUsageSummary>] = [
        .init(\.cost, order: .reverse),
    ]
    @State var selectedProject = "All Projects"
    @State var viewMode: ClaudeUsageViewMode = .daily
    @State var dateRangeStart = Date().addingTimeInterval(-30 * 24 * 60 * 60) // 30 days ago
    @State var dateRangeEnd = Date()
    @State var selectedCostStrategy: CostCalculationStrategy = .auto

    // Debounced state for progress updates
    @DebouncedState(duration: .milliseconds(300)) private var debouncedFilesProcessed = 0
    @DebouncedState(duration: .milliseconds(300)) private var debouncedLoadingMessage = ""
    
    // Debounced state for table data to prevent excessive updates
    @DebouncedState(duration: .milliseconds(500)) private var debouncedDailyUsage: [Date: [ClaudeLogEntry]] = [:]
    @DebouncedState(duration: .milliseconds(500)) private var debouncedDataVersion = 0
    @State var cachedSummaries: [DailyUsageSummary] = []
    @State var cachedProjectSummaries: [ProjectUsageSummary] = []
    @State var availableProjects: [String] = []

    @State var animationTrigger = false

    // MARK: - View

    var body: some View {
        mainContent
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onAppear {
                handleOnAppear()
            }
            .toolbar {
                ToolbarItemGroup(placement: .automatic) {
                    toolbarAutomaticItems
                }
                ToolbarItemGroup(placement: .primaryAction) {
                    toolbarPrimaryItems
                }
            }
    }
    
    @ViewBuilder
    private var mainContent: some View {
        baseContent
            .onChange(of: dataLoader.filesProcessed) { _, newValue in
                debouncedFilesProcessed = newValue
            }
            .onChange(of: dataLoader.loadingMessage) { _, newValue in
                debouncedLoadingMessage = newValue
            }
            .onChange(of: dataLoader.dailyUsage.count) { _, _ in
                // When data changes, update debounced data and increment version
                debouncedDailyUsage = dataLoader.dailyUsage
                debouncedDataVersion += 1
            }
            .onChange(of: debouncedDataVersion) { _, _ in
                updateCachedSummaries()
            }
            .onChange(of: sortOrder) { _, _ in
                cachedSummaries = cachedSummaries.sorted(using: sortOrder)
            }
            .onChange(of: projectSortOrder) { _, _ in
                cachedProjectSummaries = cachedProjectSummaries.sorted(using: projectSortOrder)
            }
            .onChange(of: selectedProject) { _, _ in
                updateCachedSummaries()
            }
            .onChange(of: dateRangeStart) { _, _ in
                if viewMode == .project {
                    cachedProjectSummaries = computeProjectSummaries()
                }
            }
            .onChange(of: dateRangeEnd) { _, _ in
                if viewMode == .project {
                    cachedProjectSummaries = computeProjectSummaries()
                }
            }
            .onChange(of: selectedCostStrategy) { _, _ in
                updateCachedSummaries()
            }
            .onChange(of: viewMode) { _, _ in
                updateCachedSummaries()
            }
    }
    
    @ViewBuilder
    private var baseContent: some View {
        Group {
            if let error = dataLoader.errorMessage {
                errorView(error: error)
            } else {
                dataContentView
            }
        }
    }
    
    
    @ViewBuilder
    private var dataContentView: some View {
        VStack(spacing: 0) {
            if dataLoader.isLoading, dataLoader.dailyUsage.isEmpty {
                // Initial loading state
                initialLoadingView
            } else {
                headerSection
                Divider()
                if dataLoader.isLoading {
                    progressSection
                    Divider()
                }
                contentSection
            }
        }
    }

    // MARK: - Header Section

    private var headerView: some View {
        HStack {
            Text("Claude Usage Report")
                .font(.title2)
                .fontWeight(.semibold)
            Spacer()
        }
        .padding()
    }

    // MARK: - Progress Section

    private var progressSection: some View {
        HStack {
            ProgressView()
                .progressViewStyle(.circular)
                .scaleEffect(0.8)
            Text(debouncedLoadingMessage)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.regularMaterial)
    }

    // MARK: - View Sections

    private var headerSection: some View {
        headerView
            .transition(.move(edge: .top).combined(with: .opacity))
    }

    private var contentSection: some View {
        Group {
            if dataLoader.dailyUsage.isEmpty, !dataLoader.isLoading {
                emptyStateView
            } else {
                tableContentView
            }
        }
    }

    private var tableContentView: some View {
        VStack(spacing: 0) {
            if viewMode == .daily {
                dailyTableView
            } else {
                projectTableView
            }
            summaryFooterView
        }
    }

    // MARK: - Actions

    func refreshData() {
        dataLoader.loadData(forceRefresh: true)
    }

    private func handleOnAppear() {
        // Initialize cost strategy from settings
        selectedCostStrategy = settingsManager.displaySettingsManager.costCalculationStrategy
        
        // Load data WITHOUT forcing refresh - use cache if available
        dataLoader.loadData(forceRefresh: false)

        // Start animation
        animationTrigger = true

        // Initialize debounced values with current dataLoader values
        debouncedFilesProcessed = dataLoader.filesProcessed
        debouncedLoadingMessage = dataLoader.loadingMessage
        debouncedDailyUsage = dataLoader.dailyUsage
        debouncedDataVersion = 1 // Trigger initial update
        
        // Initialize cached summaries
        updateCachedSummaries()
    }
    
    private func updateCachedSummaries() {
        // Update daily summaries
        cachedSummaries = computeSummaries()
        
        // Update project summaries
        cachedProjectSummaries = computeProjectSummaries()
        
        // Update available projects from debounced data
        let projects = debouncedDailyUsage.values
            .flatMap(\.self)
            .compactMap(\.projectName)
        availableProjects = Array(Set(projects)).sorted()
    }
    
    private func computeSummaries() -> [DailyUsageSummary] {
        let filtered = getFilteredDailyUsage()
        let sortedDays = filtered.keys.sorted(by: >)
        
        let summaries: [DailyUsageSummary] = sortedDays.compactMap { date -> DailyUsageSummary? in
            guard let entries = filtered[date] else { return nil }
            return DailyUsageSummary(date: date, entries: entries, costStrategy: selectedCostStrategy)
        }
        
        return summaries.sorted(using: sortOrder)
    }
    
    private func computeProjectSummaries() -> [ProjectUsageSummary] {
        // Filter entries by date range
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: dateRangeStart)
        let endOfDay = calendar.startOfDay(for: dateRangeEnd).addingTimeInterval(24 * 60 * 60)

        let filteredEntries = debouncedDailyUsage.flatMap { date, entries -> [ClaudeLogEntry] in
            guard date >= startOfDay, date < endOfDay else { return [] }
            return entries
        }

        // Group by project
        let entriesByProject = Dictionary(grouping: filteredEntries) { entry in
            entry.projectName ?? "Unknown"
        }

        // Create summaries
        let summaries = entriesByProject.map { projectName, entries in
            ProjectUsageSummary(projectName: projectName, entries: entries, costStrategy: selectedCostStrategy)
        }
        
        return summaries.sorted(using: projectSortOrder)
    }
    
    private func getFilteredDailyUsage() -> [Date: [ClaudeLogEntry]] {
        guard selectedProject != "All Projects" else {
            return debouncedDailyUsage
        }

        var filtered: [Date: [ClaudeLogEntry]] = [:]
        for (date, entries) in debouncedDailyUsage {
            let projectEntries = entries.filter { $0.projectName == selectedProject }
            if !projectEntries.isEmpty {
                filtered[date] = projectEntries
            }
        }
        return filtered
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