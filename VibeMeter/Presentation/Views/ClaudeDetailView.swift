// VibeMeter/Presentation/Views/ClaudeDetailView.swift
import SwiftUI

struct ClaudeDetailView: View {
    @State private var dailyUsage: [Date: [ClaudeLogEntry]] = [:]

    var body: some View {
        VStack {
            Text("Claude Daily Usage")
                .font(.title2)
            List {
                ForEach(dailyUsage.keys.sorted(by: >), id: \ .self) { day in
                    Section(header: Text(day, style: .date)) {
                        let totalInput = dailyUsage[day]?.reduce(0) { $0 + $1.inputTokens } ?? 0
                        let totalOutput = dailyUsage[day]?.reduce(0) { $0 + $1.outputTokens } ?? 0
                        Text("Input: \(totalInput) tokens")
                        Text("Output: \(totalOutput) tokens")
                    }
                }
            }
        }
        .task {
            dailyUsage = await ClaudeLogManager.shared.getDailyUsage()
        }
        .frame(minWidth: 300, minHeight: 400)
    }
}

#if DEBUG
#Preview {
    ClaudeDetailView()
}
#endif

