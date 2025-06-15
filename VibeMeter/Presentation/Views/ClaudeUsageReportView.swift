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

    @State var animationTrigger = false

    // MARK: - View

    var body: some View {
        Group {
            if let error = dataLoader.errorMessage {
                errorView(error: error)
            } else {
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
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onChange(of: dataLoader.filesProcessed) { _, newValue in
            debouncedFilesProcessed = newValue
        }
        .onChange(of: dataLoader.loadingMessage) { _, newValue in
            debouncedLoadingMessage = newValue
        }
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
        refreshData()

        // Start animation
        animationTrigger = true

        // Initialize debounced values with current dataLoader values
        debouncedFilesProcessed = dataLoader.filesProcessed
        debouncedLoadingMessage = dataLoader.loadingMessage
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