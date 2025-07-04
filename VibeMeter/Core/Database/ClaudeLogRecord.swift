import Foundation
import GRDB

/// Simple representation of daily Claude usage for database storage
public struct DailyClaudeUsage: Sendable {
    public let conversationId: String
    public let timestamp: Date
    public let model: String
    public let inputTokens: Int
    public let outputTokens: Int
    public let cacheCreationTokens: Int
    public let cacheReadTokens: Int
    public let costUSD: Double
    public let project: String?
    public let title: String?
    
    public init(
        conversationId: String,
        timestamp: Date,
        model: String,
        inputTokens: Int,
        outputTokens: Int,
        cacheCreationTokens: Int,
        cacheReadTokens: Int,
        costUSD: Double,
        project: String? = nil,
        title: String? = nil
    ) {
        self.conversationId = conversationId
        self.timestamp = timestamp
        self.model = model
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.cacheCreationTokens = cacheCreationTokens
        self.cacheReadTokens = cacheReadTokens
        self.costUSD = costUSD
        self.project = project
        self.title = title
    }
}

struct ClaudeLogRecord: Codable {
    var id: Int64?
    var conversationId: String
    var timestamp: Date
    var model: String
    var inputTokens: Int
    var outputTokens: Int
    var cacheCreationTokens: Int
    var cacheReadTokens: Int
    var costUSD: Double
    var project: String?
    var title: String?
    var filePath: String?
    var fileHash: String?
    
    init(
        id: Int64? = nil,
        conversationId: String,
        timestamp: Date,
        model: String,
        inputTokens: Int,
        outputTokens: Int,
        cacheCreationTokens: Int,
        cacheReadTokens: Int,
        costUSD: Double,
        project: String? = nil,
        title: String? = nil,
        filePath: String? = nil,
        fileHash: String? = nil
    ) {
        self.id = id
        self.conversationId = conversationId
        self.timestamp = timestamp
        self.model = model
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.cacheCreationTokens = cacheCreationTokens
        self.cacheReadTokens = cacheReadTokens
        self.costUSD = costUSD
        self.project = project
        self.title = title
        self.filePath = filePath
        self.fileHash = fileHash
    }
}

extension ClaudeLogRecord: FetchableRecord, PersistableRecord {
    static var databaseTableName: String { "claude_logs" }
    
    enum Columns: String, ColumnExpression {
        case id
        case conversationId = "conversation_id"
        case timestamp
        case model
        case inputTokens = "input_tokens"
        case outputTokens = "output_tokens"
        case cacheCreationTokens = "cache_creation_tokens"
        case cacheReadTokens = "cache_read_tokens"
        case costUSD = "cost_usd"
        case project
        case title
        case filePath = "file_path"
        case fileHash = "file_hash"
    }
    
    static func fromClaudeUsage(_ usage: DailyClaudeUsage, filePath: String? = nil, fileHash: String? = nil) -> ClaudeLogRecord {
        ClaudeLogRecord(
            conversationId: usage.conversationId,
            timestamp: usage.timestamp,
            model: usage.model,
            inputTokens: usage.inputTokens,
            outputTokens: usage.outputTokens,
            cacheCreationTokens: usage.cacheCreationTokens,
            cacheReadTokens: usage.cacheReadTokens,
            costUSD: usage.costUSD,
            project: usage.project,
            title: usage.title,
            filePath: filePath,
            fileHash: fileHash
        )
    }
    
    func toDailyClaudeUsage() -> DailyClaudeUsage {
        DailyClaudeUsage(
            conversationId: conversationId,
            timestamp: timestamp,
            model: model,
            inputTokens: inputTokens,
            outputTokens: outputTokens,
            cacheCreationTokens: cacheCreationTokens,
            cacheReadTokens: cacheReadTokens,
            costUSD: costUSD,
            project: project,
            title: title
        )
    }
}

extension ClaudeLogRecord {
    static func createTable(in db: Database) throws {
        try db.create(table: databaseTableName, ifNotExists: true) { t in
            t.autoIncrementedPrimaryKey(Columns.id.rawValue)
            t.column(Columns.conversationId.rawValue, .text).notNull()
            t.column(Columns.timestamp.rawValue, .datetime).notNull()
            t.column(Columns.model.rawValue, .text).notNull()
            t.column(Columns.inputTokens.rawValue, .integer).notNull().defaults(to: 0)
            t.column(Columns.outputTokens.rawValue, .integer).notNull().defaults(to: 0)
            t.column(Columns.cacheCreationTokens.rawValue, .integer).notNull().defaults(to: 0)
            t.column(Columns.cacheReadTokens.rawValue, .integer).notNull().defaults(to: 0)
            t.column(Columns.costUSD.rawValue, .double).notNull().defaults(to: 0.0)
            t.column(Columns.project.rawValue, .text)
            t.column(Columns.title.rawValue, .text)
            t.column(Columns.filePath.rawValue, .text)
            t.column(Columns.fileHash.rawValue, .text)
            
            t.uniqueKey([Columns.conversationId.rawValue, Columns.timestamp.rawValue])
        }
        
        try db.create(index: "idx_timestamp", on: databaseTableName, columns: [Columns.timestamp.rawValue])
        try db.create(index: "idx_model", on: databaseTableName, columns: [Columns.model.rawValue])
        try db.create(index: "idx_file_hash", on: databaseTableName, columns: [Columns.fileHash.rawValue])
    }
}