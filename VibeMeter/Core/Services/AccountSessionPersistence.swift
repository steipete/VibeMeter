import Foundation
import os.log

/// Manages persistence of account session metadata and user assignments
@MainActor
public final class AccountSessionPersistence: ObservableObject {
    private let logger = Logger.vibeMeter(category: "AccountSessionPersistence")
    
    // MARK: - Types
    
    /// Persisted account metadata
    public struct AccountMetadata: Codable, Sendable {
        public let sessionId: String
        public let fingerprint: String
        public let firstSeen: Date
        public let lastSeen: Date
        public var userAssignedName: String?
        public var colorTag: String?
        public var notes: String?
        
        public init(
            sessionId: String,
            fingerprint: String,
            firstSeen: Date,
            lastSeen: Date,
            userAssignedName: String? = nil,
            colorTag: String? = nil,
            notes: String? = nil
        ) {
            self.sessionId = sessionId
            self.fingerprint = fingerprint
            self.firstSeen = firstSeen
            self.lastSeen = lastSeen
            self.userAssignedName = userAssignedName
            self.colorTag = colorTag
            self.notes = notes
        }
    }
    
    // MARK: - Properties
    
    @Published public private(set) var savedMetadata: [String: AccountMetadata] = [:]
    
    private let storageKey = "VibeMeter.AccountSessionMetadata"
    private let userDefaults = UserDefaults.standard
    
    // MARK: - Initialization
    
    public init() {
        loadMetadata()
    }
    
    // MARK: - Public Methods
    
    /// Save or update metadata for an account session
    public func saveMetadata(for session: AccountSession, name: String? = nil, colorTag: String? = nil, notes: String? = nil) {
        let metadata = AccountMetadata(
            sessionId: session.id,
            fingerprint: session.sessionFingerprint,
            firstSeen: session.firstSeen,
            lastSeen: session.lastSeen,
            userAssignedName: name ?? savedMetadata[session.id]?.userAssignedName,
            colorTag: colorTag ?? savedMetadata[session.id]?.colorTag,
            notes: notes ?? savedMetadata[session.id]?.notes
        )
        
        savedMetadata[session.id] = metadata
        persistMetadata()
        
        logger.info("Saved metadata for session \(session.id)")
    }
    
    /// Get metadata for a session
    public func getMetadata(for sessionId: String) -> AccountMetadata? {
        savedMetadata[sessionId]
    }
    
    /// Get user-assigned name for a session
    public func getName(for sessionId: String) -> String? {
        savedMetadata[sessionId]?.userAssignedName
    }
    
    /// Update just the name for a session
    public func updateName(for sessionId: String, name: String?) {
        guard var metadata = savedMetadata[sessionId] else { return }
        metadata.userAssignedName = name
        savedMetadata[sessionId] = metadata
        persistMetadata()
    }
    
    /// Find sessions by fingerprint pattern
    public func findSimilarSessions(fingerprint: String) -> [AccountMetadata] {
        savedMetadata.values.filter { metadata in
            // Compare fingerprint components
            let components1 = fingerprint.split(separator: "_")
            let components2 = metadata.fingerprint.split(separator: "_")
            
            // At least 2 components must match for similarity
            var matches = 0
            for i in 0..<min(components1.count, components2.count) {
                if components1[i] == components2[i] {
                    matches += 1
                }
            }
            
            return matches >= 2
        }
    }
    
    /// Merge session history when patterns indicate same account
    public func mergeSessions(_ sessionIds: [String], into primarySessionId: String) {
        guard let primaryMetadata = savedMetadata[primarySessionId] else { return }
        
        // Update all sessions to use the primary session's name
        for sessionId in sessionIds where sessionId != primarySessionId {
            if var metadata = savedMetadata[sessionId] {
                metadata.userAssignedName = primaryMetadata.userAssignedName
                metadata.colorTag = primaryMetadata.colorTag
                savedMetadata[sessionId] = metadata
            }
        }
        
        persistMetadata()
        logger.info("Merged \(sessionIds.count) sessions under primary session \(primarySessionId)")
    }
    
    /// Clean up old metadata (sessions not seen in 30 days)
    public func cleanupOldMetadata() {
        let cutoffDate = Date().addingTimeInterval(-30 * 24 * 60 * 60) // 30 days
        let keysToRemove = savedMetadata.compactMap { key, metadata in
            metadata.lastSeen < cutoffDate ? key : nil
        }
        
        for key in keysToRemove {
            savedMetadata.removeValue(forKey: key)
        }
        
        if !keysToRemove.isEmpty {
            persistMetadata()
            logger.info("Cleaned up \(keysToRemove.count) old session metadata entries")
        }
    }
    
    // MARK: - Private Methods
    
    private func loadMetadata() {
        guard let data = userDefaults.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([String: AccountMetadata].self, from: data) else {
            logger.info("No saved account metadata found")
            return
        }
        
        savedMetadata = decoded
        logger.info("Loaded \(self.savedMetadata.count) account metadata entries")
    }
    
    private func persistMetadata() {
        do {
            let encoded = try JSONEncoder().encode(savedMetadata)
            userDefaults.set(encoded, forKey: storageKey)
            logger.debug("Persisted \(self.savedMetadata.count) metadata entries")
        } catch {
            logger.error("Failed to persist account metadata: \(error)")
        }
    }
}