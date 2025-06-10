// VibeMeter/Core/Providers/ClaudeProvider.swift
// Created by Codegen – minimal initial provider

import Foundation
import os.log

public actor ClaudeProvider: ProviderProtocol {
    public let provider: ServiceProvider = .claude
    private let logger = Logger(subsystem: "com.steipete.vibemeter", category: "ClaudeProvider")
    private let logManager = ClaudeLogManager.shared

    public init() {}

    // MARK: - ProviderProtocol Conformance

    public func fetchTeamInfo(authToken _: String) async throws -> ProviderTeamInfo {
        throw ProviderError.unsupportedProvider(.claude)
    }

    public func fetchUserInfo(authToken _: String) async throws -> ProviderUserInfo {
        let user = FileManager.default.homeDirectoryForCurrentUser.lastPathComponent
        return ProviderUserInfo(email: "\(user) (Local)", provider: .claude)
    }

    public func fetchMonthlyInvoice(authToken _: String, month: Int, year: Int, teamId _: Int?) async throws -> ProviderMonthlyInvoice {
        let daily = await logManager.getDailyUsage()
        let calendar = Calendar.current
        var items: [ProviderInvoiceItem] = []
        for (_, entries) in daily {
            for entry in entries where calendar.component(.month, from: entry.timestamp) == month + 1 && calendar.component(.year, from: entry.timestamp) == year {
                let cents = Int(calculateCost(input: entry.inputTokens, output: entry.outputTokens) * 100)
                items.append(ProviderInvoiceItem(cents: cents, description: "Claude Usage", provider: .claude))
            }
        }
        return ProviderMonthlyInvoice(items: items, provider: .claude, month: month, year: year)
    }

    public func fetchUsageData(authToken _: String) async throws -> ProviderUsageData {
        ProviderUsageData(currentRequests: 0, totalRequests: 0, maxRequests: 100, startOfMonth: Date(), provider: .claude)
    }

    public func validateToken(authToken _: String) async -> Bool {
        await logManager.hasAccess()
    }

    public nonisolated func getAuthenticationURL() -> URL {
        URL(string: "file://localhost")!
    }

    public nonisolated func extractAuthToken(from _: [String: Any]) -> String? {
        "local_claude_token"
    }

    // MARK: - Helpers

    private func calculateCost(input: Int, output: Int) -> Double {
        let inputCostPM = 3.0
        let outputCostPM = 15.0
        return (Double(input) / 1_000_000.0 * inputCostPM) + (Double(output) / 1_000_000.0 * outputCostPM)
    }
}

