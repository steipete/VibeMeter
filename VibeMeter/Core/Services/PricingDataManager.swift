import Foundation
import os.log

// MARK: - Pricing Data Manager

/// Manages pricing data for AI services with intelligent caching and resource management.
/// Implements the Disposable pattern for automatic cleanup of resources.
public final class PricingDataManager: @unchecked Sendable {
    // MARK: - Types

    public struct ModelPricing: Sendable {
        public let inputCostPerToken: Double?
        public let outputCostPerToken: Double?
        public let cacheCreationCostPerToken: Double?
        public let cacheReadCostPerToken: Double?

        public init(
            inputCostPerToken: Double? = nil,
            outputCostPerToken: Double? = nil,
            cacheCreationCostPerToken: Double? = nil,
            cacheReadCostPerToken: Double? = nil) {
            self.inputCostPerToken = inputCostPerToken
            self.outputCostPerToken = outputCostPerToken
            self.cacheCreationCostPerToken = cacheCreationCostPerToken
            self.cacheReadCostPerToken = cacheReadCostPerToken
        }
    }

    public enum CostMode {
        case auto // Use pre-calculated if available, otherwise calculate
        case calculate // Always calculate from tokens
        case display // Only use pre-calculated values
    }

    // MARK: - Properties

    private let logger = Logger.vibeMeter(category: "PricingDataManager")
    private let userDefaults: UserDefaults

    // Cache keys
    private let pricingCacheKey = "com.vibemeter.pricingDataCache"
    private let cacheTimestampKey = "com.vibemeter.pricingCacheTimestamp"

    // Cache validity duration (24 hours)
    private let cacheValidityDuration: TimeInterval = 86400

    // Thread-safe cache access
    private let queue = DispatchQueue(label: "com.vibemeter.pricingdata", attributes: .concurrent)
    private var _cachedPricing: [String: ModelPricing]?
    private var _cacheTimestamp: Date?

    // MARK: - Singleton

    public static let shared = PricingDataManager()

    // MARK: - Initialization

    public init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        loadCachedData()
    }

    // MARK: - Disposable Protocol

    deinit {
        clearCache()
    }

    // MARK: - Public Methods

    /// Get pricing for a specific model
    public func getPricing(for model: String) async -> ModelPricing? {
        let pricing = await ensurePricingLoaded()

        // Direct match
        if let directMatch = pricing[model] {
            return directMatch
        }

        // Try variations
        let variations = [
            model,
            "anthropic/\(model)",
            "claude-3-5-\(model)",
            "claude-3-\(model)",
            "claude-\(model)",
        ]

        for variant in variations {
            if let match = pricing[variant] {
                return match
            }
        }

        // Try partial matches
        let lowerModel = model.lowercased()
        for (key, value) in pricing {
            if key.lowercased().contains(lowerModel) || lowerModel.contains(key.lowercased()) {
                return value
            }
        }

        return nil
    }

    /// Calculate cost based on token usage
    public func calculateCost(
        tokens: TokenUsage,
        model: String,
        mode: CostMode = .auto,
        preCalculatedCost: Double? = nil) async -> Double {
        switch mode {
        case .display:
            // Only use pre-calculated cost
            return preCalculatedCost ?? 0

        case .calculate:
            // Always calculate from tokens
            guard let pricing = await getPricing(for: model) else {
                logger.warning("No pricing found for model: \(model)")
                return 0
            }
            return calculateCostFromPricing(tokens: tokens, pricing: pricing)

        case .auto:
            // Use pre-calculated if available, otherwise calculate
            if let preCalculatedCost {
                return preCalculatedCost
            }

            guard let pricing = await getPricing(for: model) else {
                logger.warning("No pricing found for model: \(model)")
                return 0
            }
            return calculateCostFromPricing(tokens: tokens, pricing: pricing)
        }
    }

    /// Clear all cached data
    public func clearCache() {
        queue.async(flags: .barrier) {
            self._cachedPricing = nil
            self._cacheTimestamp = nil
            self.userDefaults.removeObject(forKey: self.pricingCacheKey)
            self.userDefaults.removeObject(forKey: self.cacheTimestampKey)
        }
    }

    /// Force refresh pricing data
    public func refreshPricing() async {
        clearCache()
        _ = await ensurePricingLoaded()
    }

    // MARK: - Private Methods

    private func ensurePricingLoaded() async -> [String: ModelPricing] {
        // Check cache validity
        await withCheckedContinuation { continuation in
            queue.async(flags: .barrier) {
                if let cached = self._cachedPricing,
                   let timestamp = self._cacheTimestamp,
                   Date().timeIntervalSince(timestamp) < self.cacheValidityDuration {
                    continuation.resume(returning: cached)
                    return
                }

                // Fetch fresh data
                Task {
                    do {
                        let pricing = try await self.fetchPricingData()
                        self.queue.async(flags: .barrier) {
                            self._cachedPricing = pricing
                            self._cacheTimestamp = Date()
                            self.saveCachedData()
                            continuation.resume(returning: pricing)
                        }
                    } catch {
                        self.logger.error("Failed to fetch pricing data: \(error)")
                        // Return hardcoded fallback pricing
                        let fallback = self.getFallbackPricing()
                        continuation.resume(returning: fallback)
                    }
                }
            }
        }
    }

    private func fetchPricingData() async throws -> [String: ModelPricing] {
        // In a real implementation, this would fetch from an API
        // For now, return hardcoded pricing data
        logger.info("Fetching pricing data...")

        // Simulate network delay
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds

        return getFallbackPricing()
    }

    private func getFallbackPricing() -> [String: ModelPricing] {
        [
            // Claude models
            "claude-3-5-sonnet-20241022": ModelPricing(
                inputCostPerToken: 0.000003,
                outputCostPerToken: 0.000015,
                cacheCreationCostPerToken: 0.00000375,
                cacheReadCostPerToken: 0.0000003
            ),
            "claude-3-5-haiku-20241022": ModelPricing(
                inputCostPerToken: 0.000001,
                outputCostPerToken: 0.000005,
                cacheCreationCostPerToken: 0.00000125,
                cacheReadCostPerToken: 0.0000001
            ),
            "claude-3-opus-20240229": ModelPricing(
                inputCostPerToken: 0.000015,
                outputCostPerToken: 0.000075,
                cacheCreationCostPerToken: 0.00001875,
                cacheReadCostPerToken: 0.0000015
            ),
            // Claude 4 models
            "claude-opus-4-20250514": ModelPricing(
                inputCostPerToken: 0.000005,
                outputCostPerToken: 0.000025,
                cacheCreationCostPerToken: 0.00000625,
                cacheReadCostPerToken: 0.0000005
            ),
            "claude-sonnet-4-20250514": ModelPricing(
                inputCostPerToken: 0.000003,
                outputCostPerToken: 0.000015,
                cacheCreationCostPerToken: 0.00000375,
                cacheReadCostPerToken: 0.0000003
            ),
            // Cursor models (simplified)
            "gpt-4": ModelPricing(
                inputCostPerToken: 0.00003,
                outputCostPerToken: 0.00006
            ),
            "gpt-4o": ModelPricing(
                inputCostPerToken: 0.000005,
                outputCostPerToken: 0.000015
            ),
            "gpt-4o-mini": ModelPricing(
                inputCostPerToken: 0.00000015,
                outputCostPerToken: 0.0000006
            ),
            "claude-3.5-sonnet": ModelPricing(
                inputCostPerToken: 0.000003,
                outputCostPerToken: 0.000015
            ),
            "cursor-small": ModelPricing(
                inputCostPerToken: 0.000001,
                outputCostPerToken: 0.000002
            ),
        ]
    }

    private func calculateCostFromPricing(tokens: TokenUsage, pricing: ModelPricing) -> Double {
        var cost = 0.0

        // Input tokens
        if let inputCost = pricing.inputCostPerToken {
            cost += Double(tokens.inputTokens) * inputCost
        }

        // Output tokens
        if let outputCost = pricing.outputCostPerToken {
            cost += Double(tokens.outputTokens) * outputCost
        }

        // Cache creation tokens
        if let cacheCreationCost = pricing.cacheCreationCostPerToken,
           let cacheCreationTokens = tokens.cacheCreationTokens {
            cost += Double(cacheCreationTokens) * cacheCreationCost
        }

        // Cache read tokens
        if let cacheReadCost = pricing.cacheReadCostPerToken,
           let cacheReadTokens = tokens.cacheReadTokens {
            cost += Double(cacheReadTokens) * cacheReadCost
        }

        return cost
    }

    private func loadCachedData() {
        queue.async(flags: .barrier) {
            // Load cached pricing
            if let data = self.userDefaults.data(forKey: self.pricingCacheKey),
               let decoded = try? JSONDecoder().decode([String: ModelPricingCodable].self, from: data) {
                self._cachedPricing = decoded.mapValues { $0.toModelPricing() }
            }

            // Load timestamp
            self._cacheTimestamp = self.userDefaults.object(forKey: self.cacheTimestampKey) as? Date
        }
    }

    private func saveCachedData() {
        // Convert to codable format
        guard let pricing = _cachedPricing else { return }

        let codablePricing = pricing.mapValues { ModelPricingCodable(from: $0) }

        if let encoded = try? JSONEncoder().encode(codablePricing) {
            userDefaults.set(encoded, forKey: pricingCacheKey)
            userDefaults.set(_cacheTimestamp, forKey: cacheTimestampKey)
        }
    }
}

// MARK: - Supporting Types

/// Token usage data structure
public struct TokenUsage {
    public let inputTokens: Int
    public let outputTokens: Int
    public let cacheCreationTokens: Int?
    public let cacheReadTokens: Int?

    public init(
        inputTokens: Int,
        outputTokens: Int,
        cacheCreationTokens: Int? = nil,
        cacheReadTokens: Int? = nil) {
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.cacheCreationTokens = cacheCreationTokens
        self.cacheReadTokens = cacheReadTokens
    }
}

// MARK: - Codable Support

private struct ModelPricingCodable: Codable {
    let inputCostPerToken: Double?
    let outputCostPerToken: Double?
    let cacheCreationCostPerToken: Double?
    let cacheReadCostPerToken: Double?

    init(from pricing: PricingDataManager.ModelPricing) {
        self.inputCostPerToken = pricing.inputCostPerToken
        self.outputCostPerToken = pricing.outputCostPerToken
        self.cacheCreationCostPerToken = pricing.cacheCreationCostPerToken
        self.cacheReadCostPerToken = pricing.cacheReadCostPerToken
    }

    func toModelPricing() -> PricingDataManager.ModelPricing {
        PricingDataManager.ModelPricing(
            inputCostPerToken: inputCostPerToken,
            outputCostPerToken: outputCostPerToken,
            cacheCreationCostPerToken: cacheCreationCostPerToken,
            cacheReadCostPerToken: cacheReadCostPerToken)
    }
}
