import SwiftUI

/// Displays a detailed daily token usage report for Claude
struct ClaudeUsageReportView: View {
    @StateObject
    private var dataLoader = ClaudeUsageDataLoader()

    // Pricing constants (per million tokens)
    private let inputTokenPrice: Double = 3.00 // $3 per million input tokens
    private let outputTokenPrice: Double = 15.00 // $15 per million output tokens

    var body: some View {
        VStack(spacing: 0) {
            // Header with material background
            VStack(spacing: 0) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Claude Token Usage Report")
                            .font(.title2)
                            .fontWeight(.semibold)

                        Text("Daily breakdown of token usage and costs")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button(action: refreshData) {
                        Image(systemName: "arrow.clockwise")
                            .font(.title3)
                    }
                    .buttonStyle(.plain)
                    .disabled(dataLoader.isLoading)
                }
                .padding()

                Divider()
            }
            .background(.ultraThinMaterial)

            // Content
            Group {
                if dataLoader.isLoading, dataLoader.dailyUsage.isEmpty {
                    VStack(spacing: 16) {
                        Spacer()
                        ProgressView()
                            .progressViewStyle(.circular)
                            .scaleEffect(1.5)

                        Text(dataLoader.loadingMessage)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        if dataLoader.totalFiles > 0 {
                            ProgressView(value: Double(dataLoader.filesProcessed), total: Double(dataLoader.totalFiles))
                                .progressViewStyle(.linear)
                                .frame(width: 200)
                        }
                        Spacer()
                    }
                } else if let error = dataLoader.errorMessage {
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
                } else if sortedDays.isEmpty, !dataLoader.isLoading {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)

                        Text("No usage data found")
                            .font(.headline)

                        Text("Start using Claude Code to see your token usage here")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    Spacer()
                } else {
                    // Show loading indicator at the top if still processing
                    if dataLoader.isLoading, dataLoader.totalFiles > 0 {
                        VStack(spacing: 8) {
                            HStack {
                                ProgressView()
                                    .progressViewStyle(.circular)
                                    .scaleEffect(0.8)

                                Text(dataLoader.loadingMessage)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

                                Spacer()
                            }

                            ProgressView(value: Double(dataLoader.filesProcessed), total: Double(dataLoader.totalFiles))
                                .progressViewStyle(.linear)
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                        .background(.ultraThinMaterial)

                        Divider()
                    }

                    // Table
                    Table(of: DailyUsageSummary.self) {
                        TableColumn("Date") { summary in
                            Text(summary.date, format: .dateTime.year().month().day())
                                .monospacedDigit()
                        }
                        .width(min: 100, ideal: 120)

                        TableColumn("Input", value: \.formattedInput)
                            .width(min: 80, ideal: 100)

                        TableColumn("Output", value: \.formattedOutput)
                            .width(min: 80, ideal: 100)

                        TableColumn("Total Tokens", value: \.formattedTotal)
                            .width(min: 100, ideal: 120)

                        TableColumn("Cost (USD)") { summary in
                            Text(summary.cost, format: .currency(code: "USD"))
                                .monospacedDigit()
                                .foregroundStyle(summary.cost > 10 ? .orange : .primary)
                        }
                        .width(min: 80, ideal: 100)
                    } rows: {
                        ForEach(summaries) { summary in
                            TableRow(summary)
                        }
                    }
                    .tableStyle(.inset(alternatesRowBackgrounds: true))

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
        .onAppear {
            refreshData()
        }
    }

    // MARK: - Data Processing

    private var sortedDays: [Date] {
        dataLoader.dailyUsage.keys.sorted(by: >)
    }

    private var summaries: [DailyUsageSummary] {
        sortedDays.compactMap { date in
            guard let entries = dataLoader.dailyUsage[date] else { return nil }
            return DailyUsageSummary(date: date, entries: entries,
                                     inputPrice: inputTokenPrice,
                                     outputPrice: outputTokenPrice)
        }
    }

    private var totalInputTokens: Int {
        dataLoader.dailyUsage.values.flatMap(\.self).reduce(0) { $0 + $1.inputTokens }
    }

    private var totalOutputTokens: Int {
        dataLoader.dailyUsage.values.flatMap(\.self).reduce(0) { $0 + $1.outputTokens }
    }

    private var totalTokens: Int {
        totalInputTokens + totalOutputTokens
    }

    private var totalCost: Double {
        let inputCost = Double(totalInputTokens) / 1_000_000 * inputTokenPrice
        let outputCost = Double(totalOutputTokens) / 1_000_000 * outputTokenPrice
        return inputCost + outputCost
    }

    // MARK: - Actions

    private func refreshData() {
        dataLoader.loadData(forceRefresh: true)
    }
}

// MARK: - Data Models

private struct DailyUsageSummary: Identifiable {
    let id = UUID()
    let date: Date
    let inputTokens: Int
    let outputTokens: Int
    let totalTokens: Int
    let cost: Double

    var formattedInput: String {
        inputTokens.formatted()
    }

    var formattedOutput: String {
        outputTokens.formatted()
    }

    var formattedTotal: String {
        totalTokens.formatted()
    }

    init(date: Date, entries: [ClaudeLogEntry], inputPrice: Double, outputPrice: Double) {
        self.date = date
        self.inputTokens = entries.reduce(0) { $0 + $1.inputTokens }
        self.outputTokens = entries.reduce(0) { $0 + $1.outputTokens }
        self.totalTokens = inputTokens + outputTokens

        let inputCost = Double(inputTokens) / 1_000_000 * inputPrice
        let outputCost = Double(outputTokens) / 1_000_000 * outputPrice
        self.cost = inputCost + outputCost
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

    private let claudeLogManager = ClaudeLogManager.shared

    func loadData(forceRefresh: Bool = false) {
        guard !isLoading else { return }

        if forceRefresh {
            claudeLogManager.invalidateCache()
        }

        isLoading = true
        errorMessage = nil
        dailyUsage = [:]
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

        // If we have some data, we're no longer in the initial loading state
        if !dailyUsage.isEmpty {
            self.isLoading = false
        }
    }

    func logProcessingDidComplete(dailyUsage: [Date: [ClaudeLogEntry]]) {
        self.dailyUsage = dailyUsage
        self.isLoading = false
        self.loadingMessage = ""
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
