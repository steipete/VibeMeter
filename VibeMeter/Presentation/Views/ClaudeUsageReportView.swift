import SwiftUI

/// Displays a detailed daily token usage report for Claude
struct ClaudeUsageReportView: View {
    @StateObject private var claudeLogManager = ClaudeLogManager.shared
    @State private var dailyUsage: [Date: [ClaudeLogEntry]] = [:]
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var loadingMessage = "Loading usage data..."
    
    // Pricing constants (per million tokens)
    private let inputTokenPrice: Double = 3.00   // $3 per million input tokens
    private let outputTokenPrice: Double = 15.00 // $15 per million output tokens
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
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
                .disabled(isLoading)
            }
            .padding()
            
            Divider()
            
            // Content
            if isLoading {
                Spacer()
                VStack(spacing: 16) {
                    ProgressView()
                        .controlSize(.large)
                        .scaleEffect(1.5)
                    
                    Text(loadingMessage)
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    
                    if claudeLogManager.isProcessing {
                        Text("Processing log files...")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
                .padding()
                Spacer()
            } else if let error = errorMessage {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundStyle(.orange)
                    
                    Text("Error loading data")
                        .font(.headline)
                    
                    Text(error)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    
                    Button("Retry") {
                        refreshData()
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
                Spacer()
            } else if sortedDays.isEmpty {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    
                    Text("No usage data found")
                        .font(.headline)
                    
                    Text("Start using Claude to see your token usage here")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding()
                Spacer()
            } else {
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
                
                // Summary footer
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
                    .background(Color(NSColor.controlBackgroundColor))
                }
            }
        }
        .frame(minWidth: 700, idealWidth: 800, minHeight: 500, idealHeight: 600)
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear {
            refreshData()
        }
    }
    
    // MARK: - Data Processing
    
    private var sortedDays: [Date] {
        dailyUsage.keys.sorted(by: >)
    }
    
    private var summaries: [DailyUsageSummary] {
        sortedDays.compactMap { date in
            guard let entries = dailyUsage[date] else { return nil }
            return DailyUsageSummary(date: date, entries: entries, 
                                   inputPrice: inputTokenPrice, 
                                   outputPrice: outputTokenPrice)
        }
    }
    
    private var totalInputTokens: Int {
        dailyUsage.values.flatMap { $0 }.reduce(0) { $0 + $1.inputTokens }
    }
    
    private var totalOutputTokens: Int {
        dailyUsage.values.flatMap { $0 }.reduce(0) { $0 + $1.outputTokens }
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
        isLoading = true
        errorMessage = nil
        loadingMessage = "Loading usage data..."
        
        // Force cache invalidation on manual refresh
        claudeLogManager.invalidateCache()
        
        Task {
            do {
                guard claudeLogManager.hasAccess else {
                    await MainActor.run {
                        errorMessage = "No folder access granted. Please grant access in settings."
                        isLoading = false
                    }
                    return
                }
                
                await MainActor.run {
                    loadingMessage = "Scanning log files..."
                }
                
                let usage = await claudeLogManager.getDailyUsage()
                
                await MainActor.run {
                    loadingMessage = "Processing data..."
                    self.dailyUsage = usage
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
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

// MARK: - Preview

#Preview("Claude Usage Report") {
    ClaudeUsageReportView()
        .frame(width: 800, height: 600)
}
