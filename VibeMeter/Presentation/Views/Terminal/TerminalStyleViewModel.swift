import Foundation
import Combine
import SwiftUI
import AppKit

/// View model for terminal-style interface
@MainActor
final class TerminalStyleViewModel: ObservableObject {
    // MARK: - Types
    
    struct OutputLine: Identifiable {
        let id = UUID()
        let content: String
        let color: Color
        let prefix: String?
        let prefixColor: Color
        let timestamp: Date
        
        init(content: String, color: Color = .white, prefix: String? = nil, prefixColor: Color = .green) {
            self.content = content
            self.color = color
            self.prefix = prefix
            self.prefixColor = prefixColor
            self.timestamp = Date()
        }
    }
    
    enum Command: String, CaseIterable {
        case help = "help"
        case status = "status"
        case usage = "usage"
        case sessions = "sessions"
        case burnrate = "burnrate"
        case predict = "predict"
        case velocity = "velocity"
        case plan = "plan"
        case alerts = "alerts"
        case clear = "clear"
        case monitor = "monitor"
        case exit = "exit"
        
        var description: String {
            switch self {
            case .help: return "Show available commands"
            case .status: return "Show current provider status"
            case .usage: return "Display usage statistics"
            case .sessions: return "List recent sessions"
            case .burnrate: return "Show burn rate analysis"
            case .predict: return "Token depletion prediction"
            case .velocity: return "Usage velocity analysis"
            case .plan: return "Detect subscription plan"
            case .alerts: return "Show active alerts"
            case .clear: return "Clear terminal output"
            case .monitor: return "Start real-time monitoring"
            case .exit: return "Exit terminal mode"
            }
        }
    }
    
    // MARK: - Properties
    
    @Published var outputLines: [OutputLine] = []
    @Published var currentCommand: String = ""
    @Published var isProcessing: Bool = false
    @Published var isMonitoring: Bool = false
    
    private let provider: ServiceProvider
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init(provider: ServiceProvider) {
        self.provider = provider
        
        // Add welcome message
        addLine("VibeMeter Terminal v1.0", color: .cyan)
        addLine("Type 'help' for available commands", color: .gray)
        addLine("")
    }
    
    // MARK: - Public Methods
    
    func executeCommand() {
        guard !currentCommand.isEmpty else { return }
        
        // Add command to output
        addLine("> \(currentCommand)", color: .green, prefix: "$")
        
        let commandText = currentCommand.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        currentCommand = ""
        
        // Parse command
        guard let command = Command(rawValue: commandText) else {
            addLine("Unknown command: '\(commandText)'", color: .red)
            addLine("Type 'help' for available commands", color: .gray)
            return
        }
        
        // Execute command
        Task {
            await processCommand(command)
        }
    }
    
    func stop() {
        isMonitoring = false
        cancellables.removeAll()
    }
    
    // MARK: - Private Methods
    
    private func addLine(_ content: String, color: Color = .white, prefix: String? = nil, prefixColor: Color = .green) {
        let line = OutputLine(
            content: content,
            color: color,
            prefix: prefix,
            prefixColor: prefixColor
        )
        outputLines.append(line)
        
        // Keep only last 100 lines
        if outputLines.count > 100 {
            outputLines.removeFirst()
        }
    }
    
    private func processCommand(_ command: Command) async {
        isProcessing = true
        defer { isProcessing = false }
        
        switch command {
        case .help:
            showHelp()
        case .status:
            await showStatus()
        case .usage:
            await showUsage()
        case .sessions:
            showSessions()
        case .burnrate:
            showBurnRate()
        case .predict:
            showPrediction()
        case .velocity:
            showVelocity()
        case .plan:
            showPlan()
        case .alerts:
            showAlerts()
        case .clear:
            clearTerminal()
        case .monitor:
            toggleMonitoring()
        case .exit:
            // Handled by parent view
            break
        }
    }
    
    private func showHelp() {
        addLine("═══ Available Commands ═══", color: .cyan)
        for cmd in Command.allCases {
            addLine("\(cmd.rawValue.padding(toLength: 10, withPad: " ", startingAt: 0)) - \(cmd.description)",
                   color: .white)
        }
    }
    
    private func showStatus() async {
        addLine("═══ Provider Status ═══", color: .cyan)
        addLine("Provider: \(provider.displayName)")
        addLine("Status: Connected", color: .green)
        // Add more status info as needed
    }
    
    private func showUsage() async {
        addLine("═══ Usage Statistics ═══", color: .cyan)
        addLine("Calculating usage...", color: .gray)
        // Add usage stats implementation
    }
    
    private func showSessions() {
        addLine("═══ Recent Sessions ═══", color: .cyan)
        addLine("No sessions available", color: .gray)
        // Add sessions implementation
    }
    
    private func showBurnRate() {
        addLine("═══ Burn Rate Analysis ═══", color: .cyan)
        addLine("Burn rate data not available", color: .gray)
        // Add burn rate implementation
    }
    
    private func showPrediction() {
        addLine("═══ Token Depletion Prediction ═══", color: .cyan)
        addLine("Prediction not available", color: .gray)
        // Add prediction implementation
    }
    
    private func showVelocity() {
        addLine("═══ Usage Velocity ═══", color: .cyan)
        addLine("Velocity data not available", color: .gray)
        // Add velocity implementation
    }
    
    private func showPlan() {
        addLine("═══ Detected Plan ═══", color: .cyan)
        addLine("Plan detection not available", color: .gray)
        // Add plan detection implementation
    }
    
    private func showAlerts() {
        addLine("═══ Active Alerts ═══", color: .cyan)
        addLine("\nNo active alerts", color: .green)
    }
    
    private func clearTerminal() {
        outputLines.removeAll()
        addLine("Terminal cleared", color: .gray)
    }
    
    private func toggleMonitoring() {
        isMonitoring.toggle()
        if isMonitoring {
            addLine("Real-time monitoring started", color: .green)
            addLine("Press Ctrl+C to stop", color: .gray)
        } else {
            addLine("Real-time monitoring stopped", color: .yellow)
        }
    }
}

// MARK: - Mock Terminal Monitor

@MainActor
final class TerminalMonitor: ObservableObject {
    @Published var isActive: Bool = false
    @Published var statusLines: [String] = []
    @Published var progress: Double = 0
    
    private let provider: ServiceProvider
    
    init(provider: ServiceProvider) {
        self.provider = provider
    }
    
    func startMonitoring() {
        isActive = true
        updateStatus()
    }
    
    func stopMonitoring() {
        isActive = false
    }
    
    private func updateStatus() {
        // Simplified status update
        statusLines = [
            "Provider: \(provider.displayName)",
            "Status: Active",
            "Usage: \(Int(progress * 100))%"
        ]
    }
}