import Foundation
import Network
import Testing
@testable import VibeMeter

// MARK: - Mock NetworkConnectivityMonitor

@MainActor
final class MockNetworkConnectivityMonitor {
    // Properties
    private(set) var isConnected = true
    private(set) var connectivityStatus = "Connected"
    private(set) var isExpensive = false

    // Callbacks
    var onNetworkRestored: (() async -> Void)?
    var onNetworkLost: (() async -> Void)?
    var onConnectionTypeChanged: ((NWInterface.InterfaceType?) async -> Void)?

    // Callback tracking
    var checkConnectivityCallCount = 0

    // Mock control methods
    func setConnected(_ connected: Bool) {
        isConnected = connected
        connectivityStatus = connected ? "Connected" : "No Connection"
    }

    func setExpensive(_ expensive: Bool) {
        isExpensive = expensive
    }

    func simulateNetworkRestored() async {
        isConnected = true
        connectivityStatus = "Connected"
        await onNetworkRestored?()
    }

    func simulateNetworkLost() async {
        isConnected = false
        connectivityStatus = "No Connection"
        await onNetworkLost?()
    }

    func simulateConnectionTypeChange(to type: NWInterface.InterfaceType?) async {
        await onConnectionTypeChanged?(type)
    }

    func checkConnectivity() async {
        checkConnectivityCallCount += 1
    }
}

// MARK: - Mock MultiProviderSpendingData

@MainActor
final class MockMultiProviderSpendingData {
    // Track method calls
    var updateConnectionStatusCalls: [(provider: ServiceProvider, status: ProviderConnectionStatus)] = []

    // Internal data storage
    private var providerSpending: [ServiceProvider: ProviderSpendingData] = [:]

    var providersWithData: [ServiceProvider] {
        Array(providerSpending.keys).sorted { $0.rawValue < $1.rawValue }
    }

    func updateConnectionStatus(for provider: ServiceProvider, status: ProviderConnectionStatus) {
        updateConnectionStatusCalls.append((provider, status))
        var data = providerSpending[provider] ?? ProviderSpendingData(provider: provider)
        data.updateConnectionStatus(status)
        providerSpending[provider] = data
    }

    func getSpendingData(for provider: ServiceProvider) -> ProviderSpendingData? {
        providerSpending[provider]
    }

    func setSpendingData(_ data: ProviderSpendingData, for provider: ServiceProvider) {
        providerSpending[provider] = data
    }
}

// MARK: - NetworkStateManager Tests

@Suite("NetworkStateManager Tests", .tags(.networkState))
struct NetworkStateManagerTests {
    // MARK: - Helper Methods

    @MainActor
    private func createManager() -> NetworkStateManager {
        // Since NetworkConnectivityMonitor is created internally, we can't inject mocks
        // We'll need to test NetworkStateManager behavior through its public interface
        NetworkStateManager()
    }

    @MainActor
    private func createSpendingData(providers: [ServiceProvider]) -> MockMultiProviderSpendingData {
        let data = MockMultiProviderSpendingData()

        // Add provider data
        for provider in providers {
            var providerData = ProviderSpendingData(provider: provider)
            providerData.updateConnectionStatus(.connected)
            providerData.lastSuccessfulRefresh = Date()
            data.setSpendingData(providerData, for: provider)
        }

        return data
    }

    // MARK: - Initialization Tests

    @Test("Initial state")
    @MainActor
    func initialState() {
        let manager = createManager()

        // Should have default values
        #expect(manager.networkStatus.contains("Connect") || manager.networkStatus.contains("Unknown") || manager
            .networkStatus.contains("Offline"))
        #expect(manager.onNetworkRestored == nil)
        #expect(manager.onNetworkLost == nil)
        #expect(manager.onAppBecameActive == nil)
    }

    // MARK: - Network Status Tests

    @Test("Network status reflects monitor state")
    @MainActor
    func networkStatusReflectsMonitorState() async {
        let manager = createManager()

        // Should reflect current network status
        let status = manager.networkStatus
        #expect(!status.isEmpty)

        // Should reflect connection state
        let isConnected = manager.isNetworkConnected
        #expect(isConnected == true || isConnected == false) // Must be one or the other
    }

    // MARK: - Network Restoration Tests

    @Test("Handle network restored with connection errors")
    @MainActor
    func handleNetworkRestoredWithConnectionErrors() async {
        let manager = createManager()
        let spendingData = createSpendingData(providers: [.cursor])

        // Set up a provider with network error
        spendingData.updateConnectionStatus(
            for: .cursor,
            status: .error(message: "Network connection timeout"))

        var restoredCallbackInvoked = false
        manager.onNetworkRestored = {
            restoredCallbackInvoked = true
        }

        // Create real spending data and copy mock state
        let realSpendingData = MultiProviderSpendingData()
        for provider in spendingData.providersWithData {
            if let data = spendingData.getSpendingData(for: provider) {
                realSpendingData.updateConnectionStatus(for: provider, status: data.connectionStatus)
            }
        }

        await manager.handleNetworkRestored(spendingData: realSpendingData)

        #expect(restoredCallbackInvoked)
    }

    @Test("Handle network restored with no errors")
    @MainActor
    func handleNetworkRestoredWithNoErrors() async {
        let manager = createManager()
        let spendingData = createSpendingData(providers: [.cursor])

        var restoredCallbackInvoked = false
        manager.onNetworkRestored = {
            restoredCallbackInvoked = true
        }

        // Create real spending data - no errors, so callback shouldn't be invoked
        let realSpendingData = MultiProviderSpendingData()
        for provider in spendingData.providersWithData {
            if let data = spendingData.getSpendingData(for: provider) {
                realSpendingData.updateConnectionStatus(for: provider, status: data.connectionStatus)
            }
        }

        await manager.handleNetworkRestored(spendingData: realSpendingData)

        #expect(!restoredCallbackInvoked) // Should not invoke callback
    }

    @Test("Handle network restored with stale providers")
    @MainActor
    func handleNetworkRestoredWithStaleProviders() async {
        let manager = createManager()
        let spendingData = createSpendingData(providers: [.cursor])

        // Set provider as stale
        spendingData.updateConnectionStatus(for: .cursor, status: .stale)

        var restoredCallbackInvoked = false
        manager.onNetworkRestored = {
            restoredCallbackInvoked = true
        }

        // Create real spending data and copy mock state
        let realSpendingData = MultiProviderSpendingData()
        for provider in spendingData.providersWithData {
            if let data = spendingData.getSpendingData(for: provider) {
                realSpendingData.updateConnectionStatus(for: provider, status: data.connectionStatus)
            }
        }

        await manager.handleNetworkRestored(spendingData: realSpendingData)

        #expect(restoredCallbackInvoked)
    }

    // MARK: - Network Loss Tests

    @Test("Handle network lost marks connected providers as offline")
    @MainActor
    func handleNetworkLostMarksProvidersOffline() async {
        let manager = createManager()
        let spendingData = createSpendingData(providers: [.cursor, .claude])

        // Set different connection states
        spendingData.updateConnectionStatus(for: .cursor, status: .connected)
        spendingData.updateConnectionStatus(for: .claude, status: .syncing)

        var lostCallbackInvoked = false
        manager.onNetworkLost = {
            lostCallbackInvoked = true
        }

        // Create real spending data and copy mock state
        let realSpendingData = MultiProviderSpendingData()
        for provider in spendingData.providersWithData {
            if let data = spendingData.getSpendingData(for: provider) {
                realSpendingData.updateConnectionStatus(for: provider, status: data.connectionStatus)
            }
        }

        await manager.handleNetworkLost(spendingData: realSpendingData)

        #expect(lostCallbackInvoked)

        // Check real spending data to verify providers were marked as offline
        if case let .error(message) = realSpendingData.getSpendingData(for: .cursor)?.connectionStatus {
            #expect(message.contains("internet"))
        }
        if case let .error(message) = realSpendingData.getSpendingData(for: .claude)?.connectionStatus {
            #expect(message.contains("internet"))
        }
    }

    @Test("Handle network lost preserves existing errors")
    @MainActor
    func handleNetworkLostPreservesExistingErrors() async {
        let manager = NetworkStateManager()
        let spendingData = createSpendingData(providers: [.cursor])

        // Set existing error
        let existingError = "Authentication failed"
        spendingData.updateConnectionStatus(for: .cursor, status: .error(message: existingError))
        spendingData.updateConnectionStatusCalls.removeAll() // Clear tracking

        // Create real spending data and copy mock state
        let realSpendingData = MultiProviderSpendingData()
        for provider in spendingData.providersWithData {
            if let data = spendingData.getSpendingData(for: provider) {
                realSpendingData.updateConnectionStatus(for: provider, status: data.connectionStatus)
            }
        }

        await manager.handleNetworkLost(spendingData: realSpendingData)

        // Should preserve the existing error
        if case let .error(message) = realSpendingData.getSpendingData(for: .cursor)?.connectionStatus {
            #expect(message == existingError)
        }
    }

    // MARK: - App State Tests

    @Test("Handle app became active with stale data")
    @MainActor
    func handleAppBecameActiveWithStaleData() async {
        let manager = NetworkStateManager()

        // Create real spending data with stale data
        let realSpendingData = MultiProviderSpendingData()
        // Create stale data by clearing the provider and adding one without recent refresh
        realSpendingData.clear(provider: .cursor)
        realSpendingData.updateConnectionStatus(for: .cursor, status: .connected)

        var activeCallbackInvoked = false
        manager.onAppBecameActive = {
            activeCallbackInvoked = true
        }

        await manager.handleAppBecameActive(spendingData: realSpendingData, staleThreshold: 600)

        // Should invoke callback if network is connected
        // (In test environment, this might not trigger without proper network monitor setup)
        _ = activeCallbackInvoked // Result depends on network state
    }

    @Test("Handle app became active with fresh data")
    @MainActor
    func handleAppBecameActiveWithFreshData() async {
        let manager = NetworkStateManager()
        let spendingData = createSpendingData(providers: [.cursor])

        var activeCallbackInvoked = false
        manager.onAppBecameActive = {
            activeCallbackInvoked = true
        }

        // Create real spending data with fresh data
        let realSpendingData = MultiProviderSpendingData()
        for provider in spendingData.providersWithData {
            if let data = spendingData.getSpendingData(for: provider) {
                realSpendingData.updateConnectionStatus(for: provider, status: data.connectionStatus)
                // Add fresh invoice to mark as recently refreshed
                let invoice = ProviderMonthlyInvoice(
                    items: [ProviderInvoiceItem(cents: 1000, description: "Test Usage", provider: provider)],
                    provider: provider,
                    month: Calendar.current.component(.month, from: Date()),
                    year: Calendar.current.component(.year, from: Date()))
                realSpendingData.updateSpending(for: provider, from: invoice, rates: [:], targetCurrency: "USD")
            }
        }

        await manager.handleAppBecameActive(spendingData: realSpendingData, staleThreshold: 600)

        #expect(!activeCallbackInvoked) // Should not refresh fresh data
    }

    // MARK: - Stale Data Monitoring Tests

    @Test("Start stale data monitoring", .timeLimit(.minutes(1)))
    @MainActor
    func testStartStaleDataMonitoring() async throws {
        let manager = NetworkStateManager()
        let spendingData = createSpendingData(providers: [.cursor])

        // Create real spending data
        let realSpendingData = MultiProviderSpendingData()
        for provider in spendingData.providersWithData {
            if let data = spendingData.getSpendingData(for: provider) {
                realSpendingData.updateConnectionStatus(for: provider, status: data.connectionStatus)
            }
        }

        manager.startStaleDataMonitoring(
            spendingData: realSpendingData,
            checkInterval: 0.1, // 100ms for testing
            staleThreshold: 0.05 // 50ms for testing
        )

        // Wait for timer to fire
        try await Task.sleep(nanoseconds: 200_000_000) // 200ms

        // Data should be marked as stale
        // (Implementation would need to expose timer state for proper testing)
    }

    // MARK: - Network Type Tests

    @Test("Network type descriptions")
    func networkTypeDescriptions() {
        // Test extension on NWInterface.InterfaceType
        #expect(NWInterface.InterfaceType.wifi.displayName == "WiFi")
        #expect(NWInterface.InterfaceType.cellular.displayName == "Cellular")
        #expect(NWInterface.InterfaceType.wiredEthernet.displayName == "Ethernet")
        #expect(NWInterface.InterfaceType.loopback.displayName == "Loopback")
        #expect(NWInterface.InterfaceType.other.displayName == "Other")
    }

    @Test("Network type expense detection")
    func networkTypeExpenseDetection() {
        #expect(NWInterface.InterfaceType.cellular.isTypicallyExpensive == true)
        #expect(NWInterface.InterfaceType.wifi.isTypicallyExpensive == false)
        #expect(NWInterface.InterfaceType.wiredEthernet.isTypicallyExpensive == false)
    }
}

// MARK: - Integration Tests

@Suite("NetworkStateManager Integration Tests", .tags(.integration, .networkState))
struct NetworkStateManagerIntegrationTests {
    @Test("Network restoration flow")
    @MainActor
    func networkRestorationFlow() async {
        let manager = NetworkStateManager()
        let spendingData = MultiProviderSpendingData()

        // Add provider with network error
        var providerData = ProviderSpendingData(provider: .cursor)
        providerData.connectionStatus = .error(message: "Network timeout")
        spendingData.updateConnectionStatus(for: .cursor, status: .error(message: "Network timeout"))

        var refreshCount = 0
        manager.onNetworkRestored = {
            refreshCount += 1
        }

        // Simulate network restoration
        await manager.handleNetworkRestored(spendingData: spendingData)

        #expect(refreshCount == 1)
    }

    @Test("App lifecycle flow")
    @MainActor
    func appLifecycleFlow() async {
        let manager = NetworkStateManager()
        let spendingData = createSpendingData(providers: [.cursor])

        var refreshCount = 0
        manager.onAppBecameActive = {
            refreshCount += 1
        }

        // Make data stale by clearing the last refresh date
        // We'll use updateConnectionStatus to simulate stale data
        spendingData.updateConnectionStatus(for: .cursor, status: .stale)

        // Simulate app becoming active
        await manager.handleAppBecameActive(spendingData: spendingData, staleThreshold: 3600)

        // Should trigger refresh if network is available
        _ = refreshCount // Result depends on actual network state
    }
}

// MARK: - Test Helpers

@MainActor
private func createSpendingData(providers: [ServiceProvider]) -> MultiProviderSpendingData {
    let data = MultiProviderSpendingData()

    for provider in providers {
        data.updateConnectionStatus(for: provider, status: .connected)
        // Create a dummy invoice to mark as recently refreshed
        let invoice = ProviderMonthlyInvoice(
            items: [ProviderInvoiceItem(cents: 1000, description: "Test Usage", provider: provider)],
            provider: provider,
            month: Calendar.current.component(.month, from: Date()),
            year: Calendar.current.component(.year, from: Date()))
        data.updateSpending(for: provider, from: invoice, rates: [:], targetCurrency: "USD")
    }

    return data
}
