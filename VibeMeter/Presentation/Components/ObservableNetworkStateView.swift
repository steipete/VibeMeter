import AppKit

/// Example view that tracks network state changes using automatic observation.
///
/// This demonstrates how automatic observation tracking could be used for
/// network state monitoring, though the timer-based approach in NetworkStateManager
/// is actually more appropriate for checking stale data periodically.
@MainActor
final class ObservableNetworkStateView: ObservableTrackingView {
    private let networkStateManager: NetworkStateManager
    private let spendingData: MultiProviderSpendingData
    private var onStaleDataDetected: (() -> Void)?
    
    /// Tracks the last known stale state to detect changes
    private var lastStaleProviders: Set<ServiceProvider> = []
    
    init(networkStateManager: NetworkStateManager,
         spendingData: MultiProviderSpendingData,
         onStaleDataDetected: (() -> Void)? = nil) {
        self.networkStateManager = networkStateManager
        self.spendingData = spendingData
        self.onStaleDataDetected = onStaleDataDetected
        
        super.init(frame: .zero)
        
        // Enable layer backing
        wantsLayer = true
        
        // Hide the view - it's only used for tracking
        isHidden = true
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func trackObservableProperties() {
        // Track network connectivity
        _ = networkStateManager.isNetworkConnected
        _ = networkStateManager.networkStatus
        
        // Track spending data freshness
        var currentStaleProviders: Set<ServiceProvider> = []
        let staleThreshold: TimeInterval = 3600 // 1 hour
        
        for provider in spendingData.providersWithData {
            if let data = spendingData.getSpendingData(for: provider) {
                // Access the connection status to track changes
                _ = data.connectionStatus
                
                // Check if data is stale
                if data.isStale(olderThan: staleThreshold) {
                    currentStaleProviders.insert(provider)
                }
            }
        }
        
        // Detect if stale providers changed
        if currentStaleProviders != lastStaleProviders {
            lastStaleProviders = currentStaleProviders
            if !currentStaleProviders.isEmpty {
                onStaleDataDetected?()
            }
        }
    }
}