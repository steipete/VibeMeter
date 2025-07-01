import Foundation
import os.log

/// Represents a detected account session
public struct AccountSession: Identifiable, Sendable {
    public let id: String
    public let entries: [ClaudeLogEntry]
    public let firstSeen: Date
    public let lastSeen: Date
    public let totalTokens: Int
    public let sessionFingerprint: String
    public let isActive: Bool
    
    public var duration: TimeInterval {
        lastSeen.timeIntervalSince(firstSeen)
    }
}

/// Service responsible for detecting and managing multiple Claude account sessions
@MainActor
public final class MultiAccountDetector: ObservableObject {
    private let logger = Logger.vibeMeter(category: "MultiAccountDetector")
    
    // Configuration
    private let sessionGapThreshold: TimeInterval = 30 * 60 // 30 minutes
    private let activeSessionThreshold: TimeInterval = 15 * 60 // 15 minutes for "active" status
    
    // Published properties
    @Published public private(set) var detectedSessions: [AccountSession] = []
    @Published public private(set) var currentSessionId: String?
    
    // Persistence
    private let persistence = AccountSessionPersistence()
    
    // Session detection
    /// Detect account switches and group entries by session
    public func detectAccountSessions(from entries: [ClaudeLogEntry]) -> [AccountSession] {
        guard !entries.isEmpty else { return [] }
        
        // Sort entries by timestamp
        let sortedEntries = entries.sorted { $0.timestamp < $1.timestamp }
        
        var sessions: [AccountSession] = []
        var currentSessionEntries: [ClaudeLogEntry] = []
        var lastTimestamp: Date?
        
        for entry in sortedEntries {
            // Check for session boundary conditions
            let isNewSession = shouldStartNewSession(
                currentEntry: entry,
                lastTimestamp: lastTimestamp,
                currentSessionEntries: currentSessionEntries
            )
            
            if isNewSession && !currentSessionEntries.isEmpty {
                // Create session from current entries
                if let session = createSession(from: currentSessionEntries) {
                    sessions.append(session)
                }
                currentSessionEntries = []
            }
            
            currentSessionEntries.append(entry)
            lastTimestamp = entry.timestamp
        }
        
        // Don't forget the last session
        if !currentSessionEntries.isEmpty {
            if let session = createSession(from: currentSessionEntries) {
                sessions.append(session)
            }
        }
        
        // Update published properties
        self.detectedSessions = sessions
        self.currentSessionId = sessions.last?.id
        
        // Save metadata for new sessions
        for session in sessions {
            if persistence.getMetadata(for: session.id) == nil {
                persistence.saveMetadata(for: session)
            }
        }
        
        logger.info("Detected \(sessions.count) account sessions from \(entries.count) log entries")
        
        return sessions
    }
    
    /// Group entries by detected account
    public func groupByAccount(_ entries: [ClaudeLogEntry]) -> [String: [ClaudeLogEntry]] {
        let sessions = detectAccountSessions(from: entries)
        
        var accountGroups: [String: [ClaudeLogEntry]] = [:]
        for session in sessions {
            accountGroups[session.id] = session.entries
        }
        
        return accountGroups
    }
    
    /// Generate a session fingerprint based on usage patterns
    public func generateSessionFingerprint(from entries: [ClaudeLogEntry]) -> String {
        guard !entries.isEmpty else { return "empty" }
        
        // Fingerprint components
        let modelPreference = detectModelPreference(entries)
        let avgTokensPerRequest = calculateAverageTokensPerRequest(entries)
        let projectPattern = detectProjectPattern(entries)
        let conversationPattern = detectConversationPattern(entries)
        
        // Create a fingerprint combining multiple signals
        let fingerprint = "\(modelPreference)_\(avgTokensPerRequest)_\(projectPattern)_\(conversationPattern)"
        
        return fingerprint
    }
    
    // MARK: - Account Management
    
    /// Get user-assigned name for a session
    public func getAccountName(for sessionId: String) -> String? {
        persistence.getName(for: sessionId)
    }
    
    /// Set user-assigned name for a session
    public func setAccountName(for sessionId: String, name: String?) {
        persistence.updateName(for: sessionId, name: name)
        objectWillChange.send()
    }
    
    /// Get all saved account metadata
    public func getAllAccountMetadata() -> [AccountSessionPersistence.AccountMetadata] {
        Array(persistence.savedMetadata.values)
    }
    
    /// Find similar accounts based on usage patterns
    public func findSimilarAccounts(to sessionId: String) -> [AccountSession] {
        guard let targetSession = detectedSessions.first(where: { $0.id == sessionId }) else {
            return []
        }
        
        let similarMetadata = persistence.findSimilarSessions(fingerprint: targetSession.sessionFingerprint)
        
        // Return detected sessions that match similar metadata
        return detectedSessions.filter { session in
            similarMetadata.contains { $0.sessionId == session.id }
        }
    }
    
    // MARK: - Private Methods
    
    private func shouldStartNewSession(
        currentEntry: ClaudeLogEntry,
        lastTimestamp: Date?,
        currentSessionEntries: [ClaudeLogEntry]
    ) -> Bool {
        // First entry is never a new session
        guard let lastTimestamp = lastTimestamp else { return false }
        
        // Check time gap
        let timeSinceLastEntry = currentEntry.timestamp.timeIntervalSince(lastTimestamp)
        if timeSinceLastEntry > sessionGapThreshold {
            logger.debug("New session detected: \(timeSinceLastEntry/60) minute gap")
            return true
        }
        
        // Check for conversation root changes (new conversation thread)
        if let parentUuid = currentEntry.parentUuid,
           parentUuid.isEmpty,  // Empty parentUuid indicates a root conversation
           !currentSessionEntries.isEmpty {
            // Check if this might be a new account starting a fresh conversation
            let recentEntries = currentSessionEntries.suffix(5)
            let hasRecentActivity = recentEntries.contains { entry in
                currentEntry.timestamp.timeIntervalSince(entry.timestamp) < 60 // Within 1 minute
            }
            
            if !hasRecentActivity {
                logger.debug("New session detected: New root conversation after inactivity")
                return true
            }
        }
        
        // Check for dramatic model preference changes
        if currentSessionEntries.count > 10 {
            let recentModels = currentSessionEntries.suffix(10).compactMap(\.model)
            let currentModel = currentEntry.model
            
            if let currentModel = currentModel,
               !recentModels.isEmpty,
               !recentModels.contains(currentModel) {
                logger.debug("Potential new session: Model preference change to \(currentModel)")
                // Don't treat this as definitive, just a signal
            }
        }
        
        return false
    }
    
    private func createSession(from entries: [ClaudeLogEntry]) -> AccountSession? {
        guard let firstEntry = entries.first,
              let lastEntry = entries.last else { return nil }
        
        let totalTokens = entries.reduce(0) { $0 + $1.inputTokens + $1.outputTokens }
        let fingerprint = generateSessionFingerprint(from: entries)
        let sessionId = generateSessionId(fingerprint: fingerprint, startTime: firstEntry.timestamp)
        
        let now = Date()
        let isActive = now.timeIntervalSince(lastEntry.timestamp) < activeSessionThreshold
        
        return AccountSession(
            id: sessionId,
            entries: entries,
            firstSeen: firstEntry.timestamp,
            lastSeen: lastEntry.timestamp,
            totalTokens: totalTokens,
            sessionFingerprint: fingerprint,
            isActive: isActive
        )
    }
    
    private func generateSessionId(fingerprint: String, startTime: Date) -> String {
        // Create a short, readable session ID
        let timeComponent = Int(startTime.timeIntervalSince1970)
        let fingerprintHash = fingerprint.hashValue
        return "session_\(timeComponent)_\(abs(fingerprintHash) % 10000)"
    }
    
    private func detectModelPreference(_ entries: [ClaudeLogEntry]) -> String {
        let models = entries.compactMap(\.model)
        guard !models.isEmpty else { return "unknown" }
        
        // Count model usage
        let modelCounts = models.reduce(into: [:]) { counts, model in
            counts[model, default: 0] += 1
        }
        
        // Find most used model
        let preferredModel = modelCounts.max { $0.value < $1.value }?.key ?? "mixed"
        
        // Simplify model name for fingerprint
        if preferredModel.contains("opus") { return "opus" }
        if preferredModel.contains("sonnet") { return "sonnet" }
        if preferredModel.contains("haiku") { return "haiku" }
        
        return "other"
    }
    
    private func calculateAverageTokensPerRequest(_ entries: [ClaudeLogEntry]) -> String {
        guard !entries.isEmpty else { return "0" }
        
        let totalTokens = entries.reduce(0) { $0 + $1.inputTokens + $1.outputTokens }
        let avgTokens = totalTokens / entries.count
        
        // Bucket into categories
        switch avgTokens {
        case 0..<1000: return "low"
        case 1000..<5000: return "medium"
        case 5000..<20000: return "high"
        default: return "very_high"
        }
    }
    
    private func detectProjectPattern(_ entries: [ClaudeLogEntry]) -> String {
        let projects = entries.compactMap(\.projectName)
        guard !projects.isEmpty else { return "no_project" }
        
        let uniqueProjects = Set(projects)
        
        switch uniqueProjects.count {
        case 1: return "single_project"
        case 2...3: return "few_projects"
        default: return "many_projects"
        }
    }
    
    private func detectConversationPattern(_ entries: [ClaudeLogEntry]) -> String {
        let parentUuids = entries.compactMap(\.parentUuid)
        guard !parentUuids.isEmpty else { return "no_threads" }
        
        let uniqueThreads = Set(parentUuids)
        let avgEntriesPerThread = Double(entries.count) / Double(max(1, uniqueThreads.count))
        
        if avgEntriesPerThread < 2 { return "short_threads" }
        if avgEntriesPerThread < 10 { return "medium_threads" }
        return "long_threads"
    }
}