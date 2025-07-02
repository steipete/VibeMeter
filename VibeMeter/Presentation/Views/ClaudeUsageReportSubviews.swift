import SwiftUI

// MARK: - Table Views

extension ClaudeUsageReportView {
    var dailyTableView: some View {
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
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .width(min: 80, ideal: 100)

            TableColumn("Output", value: \.outputTokens) { summary in
                Text(summary.formattedOutput)
                    .monospacedDigit()
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .width(min: 80, ideal: 100)

            TableColumn("Cache Create", value: \.cacheCreationTokens) { summary in
                Text(summary.formattedCacheCreation)
                    .monospacedDigit()
                    .foregroundStyle(summary.cacheCreationTokens > 0 ? .primary : .secondary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .width(min: 90, ideal: 110)

            TableColumn("Cache Read", value: \.cacheReadTokens) { summary in
                Text(summary.formattedCacheRead)
                    .monospacedDigit()
                    .foregroundStyle(summary.cacheReadTokens > 0 ? .primary : .secondary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .width(min: 90, ideal: 110)

            TableColumn("Total", value: \.totalTokens) { summary in
                Text(summary.formattedTotal)
                    .monospacedDigit()
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .width(min: 100, ideal: 120)

            TableColumn("Cost", value: \.cost) { summary in
                Text(VibeMeterCurrencyFormatter.format(summary.cost))
                    .monospacedDigit()
                    .foregroundStyle(summary.cost > 10 ? .orange : .primary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .width(min: 80, ideal: 100)
        } rows: {
            ForEach(cachedSummaries) { summary in
                TableRow(summary)
            }
        }
        .tableStyle(.inset(alternatesRowBackgrounds: true))
    }

    var projectTableView: some View {
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
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .width(min: 80, ideal: 100)

            TableColumn("Output", value: \.outputTokens) { summary in
                Text(summary.formattedOutput)
                    .monospacedDigit()
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .width(min: 80, ideal: 100)

            TableColumn("Cache Create", value: \.cacheCreationTokens) { summary in
                Text(summary.formattedCacheCreation)
                    .monospacedDigit()
                    .foregroundStyle(summary.cacheCreationTokens > 0 ? .primary : .secondary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .width(min: 90, ideal: 110)

            TableColumn("Cache Read", value: \.cacheReadTokens) { summary in
                Text(summary.formattedCacheRead)
                    .monospacedDigit()
                    .foregroundStyle(summary.cacheReadTokens > 0 ? .primary : .secondary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .width(min: 90, ideal: 110)

            TableColumn("Total", value: \.totalTokens) { summary in
                Text(summary.formattedTotal)
                    .monospacedDigit()
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .width(min: 100, ideal: 120)

            TableColumn("Cost", value: \.cost) { summary in
                Text(VibeMeterCurrencyFormatter.format(summary.cost))
                    .monospacedDigit()
                    .foregroundStyle(summary.cost > 10 ? .orange : .primary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .width(min: 80, ideal: 100)

            TableColumn("Last Activity", value: \.lastActivity) { summary in
                Text(summary.lastActivity, format: .dateTime.month().day())
                    .monospacedDigit()
            }
            .width(min: 100, ideal: 120)
        } rows: {
            ForEach(cachedProjectSummaries) { summary in
                TableRow(summary)
            }
        }
        .tableStyle(.inset(alternatesRowBackgrounds: true))
    }
}

// MARK: - Footer Views

extension ClaudeUsageReportView {
    @ViewBuilder
    var summaryFooterView: some View {
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
                        Text(TokenFormatter.format(totalInputTokens))
                            .monospacedDigit()
                    }

                    VStack(alignment: .trailing) {
                        Text("Output")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(TokenFormatter.format(totalOutputTokens))
                            .monospacedDigit()
                    }

                    VStack(alignment: .trailing) {
                        Text("Total")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(TokenFormatter.format(totalTokens))
                            .monospacedDigit()
                    }

                    VStack(alignment: .trailing) {
                        Text("Cost")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        HStack(spacing: 4) {
                            Text(VibeMeterCurrencyFormatter.format(totalCost))
                                .monospacedDigit()
                                .fontWeight(.semibold)
                                .foregroundStyle(totalCost > 50 ? .orange : .primary)

                            costEmojiView
                        }
                    }
                }
            }
            .padding()
            .background(.ultraThinMaterial)
        }
    }

    @ViewBuilder
    var costEmojiView: some View {
        // Fun element: Show different emoji based on spending
        if totalCost > 100 {
            Text("🔥")
                .font(.caption)
                .scaleEffect(1.2)
                .animation(
                    .easeInOut(duration: 0.5).repeatForever(autoreverses: true),
                    value: totalCost)
                .help("Your tokens are on fire! 🚒")
        } else if totalCost > 50 {
            Text("💸")
                .font(.caption)
                .help("Money flying away!")
        } else if totalCost > 20 {
            Text("💰")
                .font(.caption)
                .help("Getting pricey")
        } else if totalCost > 0 {
            Text("✨")
                .font(.caption)
                .help("Nice and efficient!")
        }
    }
}

// MARK: - State Views

extension ClaudeUsageReportView {
    func errorView(error: String) -> some View {
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
                dataLoader.loadData(forceRefresh: true)
            }
            .buttonStyle(.borderedProminent)
            Spacer()
        }
    }

    @ViewBuilder
    var emptyStateView: some View {
        Spacer()
        VStack(spacing: 12) {
            ZStack {
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)

                // Fun sparkle animation
                Text("✨")
                    .font(.title3)
                    .offset(x: 25, y: -20)
                    .rotationEffect(.degrees(animationTrigger ? 15 : -15))
                    .scaleEffect(animationTrigger ? 1.2 : 0.8)
                    .animation(
                        .easeInOut(duration: 2).repeatForever(autoreverses: true),
                        value: animationTrigger)
            }

            Text("No usage data found")
                .font(.headline)

            Text(viewMode == .daily ? "Start using Claude Code to see your token usage here 🚀" :
                "No projects found in the selected date range 📅")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
        Spacer()
    }

    @ViewBuilder
    var initialLoadingView: some View {
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
    }
}

// MARK: - Data Processing

extension ClaudeUsageReportView {
    // Note: Data processing has been moved to the main view file
    // to support proper debouncing and caching of computed values

    var totalInputTokens: Int {
        if viewMode == .daily {
            cachedSummaries.reduce(0) { $0 + $1.inputTokens }
        } else {
            cachedProjectSummaries.reduce(0) { $0 + $1.inputTokens }
        }
    }

    var totalOutputTokens: Int {
        if viewMode == .daily {
            cachedSummaries.reduce(0) { $0 + $1.outputTokens }
        } else {
            cachedProjectSummaries.reduce(0) { $0 + $1.outputTokens }
        }
    }

    var totalCacheCreationTokens: Int {
        if viewMode == .daily {
            cachedSummaries.reduce(0) { $0 + $1.cacheCreationTokens }
        } else {
            cachedProjectSummaries.reduce(0) { $0 + $1.cacheCreationTokens }
        }
    }

    var totalCacheReadTokens: Int {
        if viewMode == .daily {
            cachedSummaries.reduce(0) { $0 + $1.cacheReadTokens }
        } else {
            cachedProjectSummaries.reduce(0) { $0 + $1.cacheReadTokens }
        }
    }

    var totalTokens: Int {
        totalInputTokens + totalOutputTokens + totalCacheCreationTokens + totalCacheReadTokens
    }

    var totalCost: Double {
        if viewMode == .daily {
            cachedSummaries.reduce(0) { $0 + $1.cost }
        } else {
            cachedProjectSummaries.reduce(0) { $0 + $1.cost }
        }
    }
}

// MARK: - Toolbar Items

extension ClaudeUsageReportView {
    @ViewBuilder
    var toolbarAutomaticItems: some View {
        // View mode picker
        Picker(selection: $viewMode) {
            ForEach(ClaudeUsageViewMode.allCases, id: \.self) { mode in
                Text(mode.rawValue).tag(mode)
            }
        } label: {
            Label("View Mode", systemImage: "calendar")
        }
        .pickerStyle(.segmented)
        .help("Switch between daily and project views")
        .frame(width: 180)

        // Project filter (only in By Day mode)
        if viewMode == .daily, !availableProjects.isEmpty {
            Picker(selection: $selectedProject) {
                Text("All Projects").tag("All Projects")
                Divider()
                ForEach(availableProjects, id: \.self) { project in
                    Text(project).tag(project)
                }
            } label: {
                Label("Project", systemImage: "folder")
            }
            .pickerStyle(.menu)
            .help("Filter by project")
            .frame(width: 180)
        }

        // Date range selector (only in By Project mode)
        if viewMode == .project {
            HStack(spacing: 6) {
                DatePicker(selection: $dateRangeStart, displayedComponents: .date) {
                    Label("Start Date", systemImage: "calendar")
                }
                .datePickerStyle(.compact)
                .labelsHidden()

                Text("to")
                    .foregroundStyle(.secondary)

                DatePicker(selection: $dateRangeEnd, in: dateRangeStart ... Date(),
                           displayedComponents: .date) {
                    Label("End Date", systemImage: "calendar")
                }
                .datePickerStyle(.compact)
                .labelsHidden()
            }
            .help("Select date range")
        }
    }

    @ViewBuilder
    var toolbarPrimaryItems: some View {
        // Cost calculation strategy selector
        Picker(selection: $selectedCostStrategy) {
            ForEach(CostCalculationStrategy.allCases, id: \.self) { strategy in
                Text(strategy.displayName).tag(strategy)
            }
        } label: {
            Label("Cost Strategy", systemImage: "dollarsign.circle")
        }
        .pickerStyle(.menu)
        .help("Select cost calculation strategy")
        .frame(width: 250)

        // Refresh button
        Button {
            dataLoader.loadData(forceRefresh: true)
        } label: {
            Label("Refresh", systemImage: "arrow.clockwise")
        }
        .help("Refresh usage data")
        .disabled(dataLoader.isLoading)
    }
}