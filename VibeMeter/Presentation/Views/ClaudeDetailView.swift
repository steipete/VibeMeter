import SwiftUI

/// Displays detailed daily usage breakdown for Claude
struct ClaudeDetailView: View {
    @State
    private var dailyUsage: [ClaudeDailyUsage] = []
    @State
    private var isLoading = true
    @State
    private var error: Error?
    @State
    private var selectedMonth = Date()

    @Environment(\.dismiss)
    private var dismiss

    @State
    private var provider: ClaudeProvider?

    private func getProvider() -> ClaudeProvider {
        if let provider {
            return provider
        }
        let newProvider = ClaudeProvider(settingsManager: SettingsManager.shared)
        self.provider = newProvider
        return newProvider
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Claude Usage Details")
                    .font(.title2)
                    .fontWeight(.semibold)

                Spacer()

                Button("Done") {
                    dismiss()
                }
                .buttonStyle(.bordered)
            }
            .padding()

            Divider()

            // Month selector
            HStack {
                Button(action: previousMonth) {
                    Image(systemName: "chevron.left")
                }
                .buttonStyle(.borderless)

                Text(selectedMonth, format: .dateTime.month(.wide).year())
                    .font(.headline)
                    .frame(minWidth: 150)

                Button(action: nextMonth) {
                    Image(systemName: "chevron.right")
                }
                .buttonStyle(.borderless)
                .disabled(Calendar.current.isDate(selectedMonth, equalTo: Date(), toGranularity: .month))
            }
            .padding()

            Divider()

            // Content
            if isLoading {
                ProgressView("Loading usage data...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error {
                ErrorView(error: error) {
                    Task { await loadData() }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if dailyUsage.isEmpty {
                ContentUnavailableView(
                    "No Usage Data",
                    systemImage: "chart.bar.xaxis",
                    description: Text(
                        "No Claude usage found for \(selectedMonth, format: .dateTime.month(.wide).year())"))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(filteredDailyUsage) { daily in
                            DailyUsageRow(daily: daily)

                            if daily.id != filteredDailyUsage.last?.id {
                                Divider()
                                    .padding(.leading, 20)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
        }
        .frame(width: 600, height: 500)
        .task {
            await loadData()
        }
    }

    // MARK: - Computed Properties

    private var filteredDailyUsage: [ClaudeDailyUsage] {
        let calendar = Calendar.current
        return dailyUsage.filter { daily in
            calendar.isDate(daily.date, equalTo: selectedMonth, toGranularity: .month)
        }
    }

    // MARK: - Actions

    private func loadData() async {
        isLoading = true
        error = nil

        do {
            let usage = try await getProvider().getDailyUsageBreakdown()
            await MainActor.run {
                self.dailyUsage = usage
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.error = error
                self.isLoading = false
            }
        }
    }

    private func previousMonth() {
        selectedMonth = Calendar.current.date(byAdding: .month, value: -1, to: selectedMonth) ?? selectedMonth
    }

    private func nextMonth() {
        let next = Calendar.current.date(byAdding: .month, value: 1, to: selectedMonth) ?? selectedMonth
        if Calendar.current.compare(next, to: Date(), toGranularity: .month) != .orderedDescending {
            selectedMonth = next
        }
    }
}

// MARK: - DailyUsageRow

private struct DailyUsageRow: View {
    let daily: ClaudeDailyUsage

    var body: some View {
        HStack(spacing: 16) {
            // Date
            VStack(alignment: .leading, spacing: 2) {
                Text(daily.date, format: .dateTime.weekday(.abbreviated))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(daily.date, format: .dateTime.day())
                    .font(.title3)
                    .fontWeight(.medium)
            }
            .frame(width: 50)

            // Tokens
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 12) {
                    TokenLabel(label: "Input", value: daily.totalInputTokens, color: .blue)
                    TokenLabel(label: "Output", value: daily.totalOutputTokens, color: .green)
                }

                Text("\(daily.entries.count) conversations")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Cost
            VStack(alignment: .trailing, spacing: 2) {
                Text(daily.calculateCost(), format: .currency(code: "USD"))
                    .font(.body)
                    .fontWeight(.medium)

                Text("\(daily.totalTokens.formatted()) tokens")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        .onHover { _ in
            // Custom hover effect for macOS
        }
    }
}

// MARK: - TokenLabel

private struct TokenLabel: View {
    let label: String
    let value: Int
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)

            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(value.formatted())
                .font(.caption)
                .fontWeight(.medium)
        }
    }
}

// MARK: - ErrorView

private struct ErrorView: View {
    let error: Error
    let retry: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundStyle(.secondary)

            Text("Failed to Load Usage Data")
                .font(.headline)

            Text(error.localizedDescription)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)

            Button("Retry", action: retry)
                .buttonStyle(.bordered)
        }
        .padding()
    }
}

// MARK: - Preview

#Preview {
    ClaudeDetailView()
}
