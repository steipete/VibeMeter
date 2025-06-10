import Foundation
import Network
import os.log

/// Modern network connectivity monitor using the Network framework.
///
/// This service monitors network reachability and provides callbacks for connectivity changes.
/// It uses the latest Network framework APIs available in macOS 15+ for optimal performance
/// and accuracy. The monitor tracks both connectivity state and connection type changes.
@Observable
@MainActor
public final class NetworkConnectivityMonitor {
    // MARK: - Published Properties

    /// Current network connectivity state
    public private(set) var isConnected = false

    /// Type of current network connection (WiFi, Cellular, Ethernet, etc.)
    public private(set) var connectionType: NWInterface.InterfaceType?

    /// Whether the connection is expensive (cellular, hotspot, etc.)
    public private(set) var isExpensive = false

    /// Whether the connection is constrained (low data mode, etc.)
    public private(set) var isConstrained = false

    /// Connectivity status for display purposes
    public var connectivityStatus: String {
        if !isConnected {
            return "Offline"
        }

        var status = connectionType?.displayName ?? "Connected"

        if isExpensive {
            status += " (Expensive)"
        }

        if isConstrained {
            status += " (Constrained)"
        }

        return status
    }

    // MARK: - Callbacks

    /// Called when network connectivity is restored after being offline
    public var onNetworkRestored: (() async -> Void)?

    /// Called when network goes offline
    public var onNetworkLost: (() async -> Void)?

    /// Called when connection type changes (WiFi to Ethernet, etc.)
    public var onConnectionTypeChanged: ((NWInterface.InterfaceType?) async -> Void)?

    // MARK: - Private Properties

    private let monitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "com.vibemeter.networkmonitor", qos: .utility)
    private let logger = Logger.vibeMeter(category: "NetworkMonitor")

    private var lastConnectionState = false
    private var lastConnectionType: NWInterface.InterfaceType?
    private var isMonitoring = false

    // MARK: - Initialization

    public init() {
        logger.info("NetworkConnectivityMonitor initialized")
        startMonitoring()
    }

    deinit {
        stopMonitoring()
    }

    // MARK: - Public Methods

    /// Manually check current connectivity status
    public func checkConnectivity() async {
        let currentPath = monitor.currentPath
        await processPathUpdate(currentPath)
    }

    /// Force a connectivity state refresh
    public func refreshConnectivity() async {
        logger.info("Forcing connectivity refresh")
        await checkConnectivity()
    }

    // MARK: - Private Methods

    private func startMonitoring() {
        guard !isMonitoring else {
            logger.warning("Network monitoring already started")
            return
        }

        logger.info("Starting network connectivity monitoring")
        isMonitoring = true

        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                await self?.processPathUpdate(path)
            }
        }

        monitor.start(queue: self.monitorQueue)
        logger.info("Network monitor started on queue: \(self.monitorQueue.label)")
    }

    private nonisolated func stopMonitoring() {
        logger.info("Stopping network connectivity monitoring")
        monitor.cancel()
    }

    private func processPathUpdate(_ path: NWPath) async {
        let newConnectionState = path.status == .satisfied
        let newConnectionType = path.availableInterfaces.first?.type
        let newIsExpensive = path.isExpensive
        let newIsConstrained = path.isConstrained

        let debugMessage = "Network path update: connected=\(newConnectionState), " +
            "type=\(newConnectionType?.displayName ?? "none"), expensive=\(newIsExpensive), " +
            "constrained=\(newIsConstrained)"
        logger.debug("\(debugMessage)")

        // Update state
        let wasConnected = isConnected
        let wasConnectionType = connectionType

        isConnected = newConnectionState
        connectionType = newConnectionType
        isExpensive = newIsExpensive
        isConstrained = newIsConstrained

        // Handle state transitions
        await handleConnectivityChanges(
            wasConnected: wasConnected,
            isNowConnected: newConnectionState,
            wasConnectionType: wasConnectionType,
            newConnectionType: newConnectionType)
    }

    private func handleConnectivityChanges(
        wasConnected: Bool,
        isNowConnected: Bool,
        wasConnectionType: NWInterface.InterfaceType?,
        newConnectionType: NWInterface.InterfaceType?) async {
        // Network restored
        if !wasConnected, isNowConnected {
            logger.info("Network connectivity restored (type: \(newConnectionType?.displayName ?? "unknown"))")
            await onNetworkRestored?()
        }

        // Network lost
        if wasConnected, !isNowConnected {
            logger.warning("Network connectivity lost")
            await onNetworkLost?()
        }

        // Connection type changed while connected
        if isNowConnected, wasConnected, wasConnectionType != newConnectionType {
            let typeChangeMessage = "Connection type changed from \(wasConnectionType?.displayName ?? "none") " +
                "to \(newConnectionType?.displayName ?? "none")"
            logger.info("\(typeChangeMessage)")
            await onConnectionTypeChanged?(newConnectionType)
        }
    }
}

// MARK: - NWInterface.InterfaceType Extension

extension NWInterface.InterfaceType {
    /// Human-readable display name for the interface type
    var displayName: String {
        switch self {
        case .wifi:
            "WiFi"
        case .cellular:
            "Cellular"
        case .wiredEthernet:
            "Ethernet"
        case .loopback:
            "Loopback"
        default:
            "Other"
        }
    }

    /// Whether this connection type is typically expensive
    var isTypicallyExpensive: Bool {
        switch self {
        case .cellular:
            true
        default:
            false
        }
    }
}

// MARK: - Network Status Provider Protocol

/// Protocol for providing network status information
@MainActor
public protocol NetworkStatusProvider {
    var isConnected: Bool { get }
    var connectionType: NWInterface.InterfaceType? { get }
    var isExpensive: Bool { get }
    var isConstrained: Bool { get }
    var connectivityStatus: String { get }
}

extension NetworkConnectivityMonitor: NetworkStatusProvider {}

// MARK: - Preview Support

#if DEBUG
    /// Mock network monitor for previews and testing
    @MainActor
    public final class MockNetworkConnectivityMonitor: NetworkStatusProvider, ObservableObject {
        @Published
        public var isConnected = true
        @Published
        public var connectionType: NWInterface.InterfaceType? = .wifi
        @Published
        public var isExpensive = false
        @Published
        public var isConstrained = false

        public var connectivityStatus: String {
            isConnected ? connectionType?.displayName ?? "Connected" : "Offline"
        }

        public var onNetworkRestored: (() async -> Void)?
        public var onNetworkLost: (() async -> Void)?
        public var onConnectionTypeChanged: ((NWInterface.InterfaceType?) async -> Void)?

        public init() {}

        public func simulateNetworkLoss() async {
            isConnected = false
            connectionType = nil
            await onNetworkLost?()
        }

        public func simulateNetworkRestore() async {
            isConnected = true
            connectionType = .wifi
            await onNetworkRestored?()
        }

        public func simulateConnectionTypeChange(to type: NWInterface.InterfaceType) async {
            connectionType = type
            await onConnectionTypeChanged?(type)
        }
    }
#endif
