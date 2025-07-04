import Foundation
import os.log

/// Manages caching of historical Cursor invoice data
@MainActor
public final class CursorInvoiceCache: @unchecked Sendable {
    private let logger = Logger.vibeMeter(category: "CursorInvoiceCache")
    private let userDefaults: UserDefaults
    
    // Cache keys
    private let cacheKey = "com.vibemeter.cursorInvoiceCache"
    private let cacheVersionKey = "com.vibemeter.cursorInvoiceCacheVersion"
    
    // Cache version - increment when format changes
    private let currentCacheVersion = 1
    
    // Singleton
    public static let shared = CursorInvoiceCache()
    
    private init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        
        // Check cache version
        let storedVersion = userDefaults.integer(forKey: cacheVersionKey)
        if storedVersion < currentCacheVersion {
            logger.info("Cache version outdated, clearing cache")
            clearCache()
            userDefaults.set(currentCacheVersion, forKey: cacheVersionKey)
        }
    }
    
    /// Cache entry for a single month's invoice
    private struct CacheEntry: Codable {
        let invoice: ProviderMonthlyInvoice
        let cachedAt: Date
        let teamId: Int?
    }
    
    /// Get cached invoice for a specific month
    public func getCachedInvoice(month: Int, year: Int, teamId: Int?) -> ProviderMonthlyInvoice? {
        let key = cacheKey(for: month, year: year, teamId: teamId)
        
        guard let data = userDefaults.data(forKey: key),
              let entry = try? JSONDecoder().decode(CacheEntry.self, from: data) else {
            return nil
        }
        
        // Check if this is the current month - don't use cache for current month
        let calendar = Calendar.current
        let now = Date()
        let currentMonth = calendar.component(.month, from: now) - 1 // 0-based
        let currentYear = calendar.component(.year, from: now)
        
        if month == currentMonth && year == currentYear {
            logger.debug("Not using cache for current month \(month)/\(year)")
            return nil
        }
        
        logger.debug("Retrieved cached invoice for \(month + 1)/\(year)")
        return entry.invoice
    }
    
    /// Cache an invoice for a specific month
    public func cacheInvoice(_ invoice: ProviderMonthlyInvoice, month: Int, year: Int, teamId: Int?) {
        // Don't cache current month or empty invoices
        let calendar = Calendar.current
        let now = Date()
        let currentMonth = calendar.component(.month, from: now) - 1 // 0-based
        let currentYear = calendar.component(.year, from: now)
        
        if (month == currentMonth && year == currentYear) || invoice.totalSpendingCents == 0 {
            return
        }
        
        let entry = CacheEntry(invoice: invoice, cachedAt: Date(), teamId: teamId)
        
        if let data = try? JSONEncoder().encode(entry) {
            let key = cacheKey(for: month, year: year, teamId: teamId)
            userDefaults.set(data, forKey: key)
            logger.debug("Cached invoice for \(month + 1)/\(year) with \(invoice.items.count) items")
        }
    }
    
    /// Clear all cached invoices
    public func clearCache() {
        let keys = userDefaults.dictionaryRepresentation().keys
        for key in keys where key.hasPrefix(cacheKey) {
            userDefaults.removeObject(forKey: key)
        }
        logger.info("Cleared all cached invoices")
    }
    
    /// Generate cache key for a specific month
    private func cacheKey(for month: Int, year: Int, teamId: Int?) -> String {
        if let teamId = teamId {
            return "\(cacheKey).\(year).\(month).team\(teamId)"
        } else {
            return "\(cacheKey).\(year).\(month).noteam"
        }
    }
}