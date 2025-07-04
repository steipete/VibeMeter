import Foundation
import GRDB
import os.log

@MainActor
final class DatabaseManager {
    static let shared = DatabaseManager()
    
    private let logger = Logger(subsystem: "com.steipete.VibeMeter", category: "DatabaseManager")
    private var dbQueue: DatabaseQueue?
    
    private init() {}
    
    var isInitialized: Bool {
        dbQueue != nil
    }
    
    func initialize() async throws {
        let databaseURL = try getDatabaseURL()
        logger.info("Initializing database at: \(databaseURL.path)")
        
        let queue = try DatabaseQueue(path: databaseURL.path)
        
        try await queue.write { db in
            try ClaudeLogRecord.createTable(in: db)
            try FileHashCache.createTable(in: db)
        }
        
        self.dbQueue = queue
        logger.info("Database initialized successfully")
    }
    
    private func getDatabaseURL() throws -> URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory,
                                                  in: .userDomainMask).first!
        let appFolder = appSupport.appendingPathComponent("VibeMeter", isDirectory: true)
        
        if !FileManager.default.fileExists(atPath: appFolder.path) {
            try FileManager.default.createDirectory(at: appFolder,
                                                  withIntermediateDirectories: true)
        }
        
        return appFolder.appendingPathComponent("vibemeter.db")
    }
    
    func insertClaudeLogs(_ logs: [DailyClaudeUsage], filePath: String? = nil, fileHash: String? = nil) async throws {
        guard let queue = dbQueue else {
            throw DatabaseError.notInitialized
        }
        
        let records = logs.map { ClaudeLogRecord.fromClaudeUsage($0, filePath: filePath, fileHash: fileHash) }
        
        try await queue.write { db in
            for record in records {
                try record.insert(db, onConflict: .ignore)
            }
        }
        
        logger.debug("Inserted \(records.count) Claude log records")
    }
    
    func fetchClaudeLogs(from startDate: Date, to endDate: Date) async throws -> [DailyClaudeUsage] {
        guard let queue = dbQueue else {
            throw DatabaseError.notInitialized
        }
        
        return try await queue.read { db in
            let records = try ClaudeLogRecord
                .filter(ClaudeLogRecord.Columns.timestamp >= startDate)
                .filter(ClaudeLogRecord.Columns.timestamp <= endDate)
                .order(ClaudeLogRecord.Columns.timestamp.desc)
                .fetchAll(db)
            
            return records.map { $0.toDailyClaudeUsage() }
        }
    }
    
    func fetchClaudeLogs(byModel model: String? = nil, limit: Int? = nil) async throws -> [DailyClaudeUsage] {
        guard let queue = dbQueue else {
            throw DatabaseError.notInitialized
        }
        
        return try await queue.read { db in
            var request = ClaudeLogRecord.all()
            
            if let model = model {
                request = request.filter(ClaudeLogRecord.Columns.model == model)
            }
            
            request = request.order(ClaudeLogRecord.Columns.timestamp.desc)
            
            if let limit = limit {
                request = request.limit(limit)
            }
            
            let records = try request.fetchAll(db)
            return records.map { $0.toDailyClaudeUsage() }
        }
    }
    
    func getTotalSpending(from startDate: Date? = nil, to endDate: Date? = nil) async throws -> Double {
        guard let queue = dbQueue else {
            throw DatabaseError.notInitialized
        }
        
        return try await queue.read { db in
            var request = ClaudeLogRecord.select(sum(ClaudeLogRecord.Columns.costUSD))
            
            if let startDate = startDate {
                request = request.filter(ClaudeLogRecord.Columns.timestamp >= startDate)
            }
            
            if let endDate = endDate {
                request = request.filter(ClaudeLogRecord.Columns.timestamp <= endDate)
            }
            
            return try Double.fetchOne(db, request) ?? 0.0
        }
    }
    
    func getSpendingByModel(from startDate: Date? = nil, to endDate: Date? = nil) async throws -> [String: Double] {
        guard let queue = dbQueue else {
            throw DatabaseError.notInitialized
        }
        
        return try await queue.read { db in
            var request = ClaudeLogRecord
                .select(
                    ClaudeLogRecord.Columns.model,
                    sum(ClaudeLogRecord.Columns.costUSD).forKey("total")
                )
                .group(ClaudeLogRecord.Columns.model)
            
            if let startDate = startDate {
                request = request.filter(ClaudeLogRecord.Columns.timestamp >= startDate)
            }
            
            if let endDate = endDate {
                request = request.filter(ClaudeLogRecord.Columns.timestamp <= endDate)
            }
            
            let rows = try Row.fetchAll(db, request)
            
            var result: [String: Double] = [:]
            for row in rows {
                let model: String = row["model"]
                let total: Double = row["total"]
                result[model] = total
            }
            
            return result
        }
    }
    
    func hasLogsForFile(hash: String) async throws -> Bool {
        guard let queue = dbQueue else {
            throw DatabaseError.notInitialized
        }
        
        return try await queue.read { db in
            try ClaudeLogRecord
                .filter(ClaudeLogRecord.Columns.fileHash == hash)
                .fetchCount(db) > 0
        }
    }
    
    func clearAllData() async throws {
        guard let queue = dbQueue else {
            throw DatabaseError.notInitialized
        }
        
        try await queue.write { db in
            try db.execute(sql: "DELETE FROM \(ClaudeLogRecord.databaseTableName)")
            try db.execute(sql: "DELETE FROM \(FileHashCache.databaseTableName)")
        }
        
        logger.info("Cleared all database data")
    }
}

enum DatabaseError: LocalizedError {
    case notInitialized
    
    var errorDescription: String? {
        switch self {
        case .notInitialized:
            return "Database has not been initialized"
        }
    }
}

struct FileHashCache {
    var id: Int64?
    var filePath: String
    var fileHash: String
    var lastModified: Date
    var recordCount: Int
}

extension FileHashCache: Codable, FetchableRecord, PersistableRecord {
    static var databaseTableName: String { "file_hash_cache" }
    
    enum Columns: String, ColumnExpression {
        case id
        case filePath = "file_path"
        case fileHash = "file_hash"
        case lastModified = "last_modified"
        case recordCount = "record_count"
    }
    
    static func createTable(in db: Database) throws {
        try db.create(table: databaseTableName, ifNotExists: true) { t in
            t.autoIncrementedPrimaryKey(Columns.id.rawValue)
            t.column(Columns.filePath.rawValue, .text).notNull().unique()
            t.column(Columns.fileHash.rawValue, .text).notNull()
            t.column(Columns.lastModified.rawValue, .datetime).notNull()
            t.column(Columns.recordCount.rawValue, .integer).notNull().defaults(to: 0)
        }
    }
}