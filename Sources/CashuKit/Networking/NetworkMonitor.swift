//
//  NetworkMonitor.swift
//  CashuKit
//
//  Network connectivity monitoring and offline operation queueing
//

import Foundation
import Network
import CoreCashu
import Combine
import Vault

// MARK: - Secure Storage for Queued Operations

/// Securely stores queued operations using the Keychain instead of UserDefaults.
/// This is important because queued operations may contain sensitive token data —
/// so items are stored `AfterFirstUnlockThisDeviceOnly` in the data-protection
/// keychain (never restorable onto another device from a backup).
actor QueuedOperationsStorage {
    private static let configuration = KeychainConfiguration(
        serviceName: "com.cashukit.network",
        accessGroup: nil,
        accountName: "queued.operations",
        accessibility: .afterFirstUnlockThisDeviceOnly
    )

    private let vault = Vault(configuration: QueuedOperationsStorage.configuration)

    func save(_ operations: [NetworkMonitor.QueuedOperation]) async {
        guard let data = try? JSONEncoder().encode(operations),
              let jsonString = String(data: data, encoding: .utf8) else {
            return
        }

        try? await vault.save(jsonString)
    }

    func load() async -> [NetworkMonitor.QueuedOperation] {
        guard let jsonString = try? await vault.read(),
              let data = jsonString.data(using: .utf8) else {
            return []
        }
        return (try? JSONDecoder().decode([NetworkMonitor.QueuedOperation].self, from: data)) ?? []
    }

    func clear() async {
        try? await vault.delete()
    }
}

/// Monitors network connectivity and manages offline operations
@MainActor
public final class NetworkMonitor: ObservableObject {
    
    // MARK: - Types
    
    public enum ConnectionType: Sendable {
        case wifi
        case cellular
        case wired
        case unknown
        case none
        
        var displayName: String {
            switch self {
            case .wifi: return "Wi-Fi"
            case .cellular: return "Cellular"
            case .wired: return "Ethernet"
            case .unknown: return "Unknown"
            case .none: return "No Connection"
            }
        }
        
        var isConnected: Bool {
            self != .none
        }
    }
    
    public struct NetworkStatus: Sendable {
        public let connectionType: ConnectionType
        public let isExpensive: Bool
        public let isConstrained: Bool
        public let supportsIPv4: Bool
        public let supportsIPv6: Bool
        public let supportsDNS: Bool
        
        public var isConnected: Bool {
            connectionType.isConnected
        }
        
        public var qualityScore: Double {
            var score = 0.0
            
            switch connectionType {
            case .wifi, .wired: score += 1.0
            case .cellular: score += 0.7
            case .unknown: score += 0.3
            case .none: return 0.0
            }
            
            if !isExpensive { score += 0.5 }
            if !isConstrained { score += 0.5 }
            if supportsIPv4 { score += 0.3 }
            if supportsIPv6 { score += 0.2 }
            if supportsDNS { score += 0.5 }
            
            return min(score / 3.0, 1.0)
        }
    }
    
    /// Represents an operation that can be queued for offline execution
    public struct QueuedOperation: Identifiable, Sendable, Codable {
        public let id: UUID
        public let type: OperationType
        public let data: Data
        public let priority: Priority
        public let createdAt: Date
        public var retryCount: Int = 0
        public var lastAttempt: Date?

        public init(
            id: UUID = UUID(),
            type: OperationType,
            data: Data,
            priority: Priority,
            createdAt: Date = Date(),
            retryCount: Int = 0,
            lastAttempt: Date? = nil
        ) {
            self.id = id
            self.type = type
            self.data = data
            self.priority = priority
            self.createdAt = createdAt
            self.retryCount = retryCount
            self.lastAttempt = lastAttempt
        }
        
        public enum OperationType: String, Sendable, Codable {
            case sendToken
            case receiveToken
            case checkProofs
            case refreshMint
        }
        
        public enum Priority: Int, Comparable, Sendable, Codable {
            case low = 0
            case normal = 1
            case high = 2
            case critical = 3
            
            public static func < (lhs: Priority, rhs: Priority) -> Bool {
                lhs.rawValue < rhs.rawValue
            }
        }
    }
    
    // MARK: - Properties
    
    @Published public private(set) var currentStatus: NetworkStatus
    @Published public private(set) var isConnected: Bool = false
    @Published public private(set) var connectionType: ConnectionType = .none
    @Published public private(set) var queuedOperations: [QueuedOperation] = []
    
    private var monitor: NWPathMonitor
    private var isMonitoring = false
    private let queue: DispatchQueue
    private let logger: OSLogLogger
    private var cancellables = Set<AnyCancellable>()

    /// Executes a queued operation when connectivity returns. The host app supplies
    /// this (wiring it to its `CashuWallet`); operations stay queued until it is set —
    /// CashuKit itself has no wallet reference and must never pretend to process
    /// money-moving work.
    public var operationHandler: (@Sendable (QueuedOperation) async throws -> Void)?
    
    // Retry configuration
    private let maxRetryAttempts = 5
    private let baseRetryDelay: TimeInterval = 2.0
    private let maxRetryDelay: TimeInterval = 60.0
    
    // Operation queue
    private var operationQueue: [QueuedOperation] = []
    private var isProcessingQueue = false
    
    // Secure storage for queued operations (may contain sensitive token data)
    private let secureStorage: QueuedOperationsStorage
    
    // MARK: - Initialization
    
    public init() {
        self.monitor = NWPathMonitor()
        self.queue = DispatchQueue(label: "com.cashukit.networkmonitor", qos: .utility)
        self.logger = OSLogLogger(category: "NetworkMonitor", minimumLevel: .info)
        self.secureStorage = QueuedOperationsStorage()
        
        // Initialize with unknown status
        self.currentStatus = NetworkStatus(
            connectionType: .unknown,
            isExpensive: false,
            isConstrained: false,
            supportsIPv4: false,
            supportsIPv6: false,
            supportsDNS: false
        )
        
        setupMonitoring()
        loadQueuedOperations()
    }
    
    // MARK: - Public Methods
    
    /// Start monitoring network connectivity. Safe to call after `stopMonitoring()`:
    /// a cancelled `NWPathMonitor` can never be restarted, so a fresh one is created.
    public func startMonitoring() {
        guard !isMonitoring else { return }

        monitor = NWPathMonitor()
        installPathHandler()
        monitor.start(queue: queue)
        isMonitoring = true
        logger.info("Network monitoring started")
    }

    /// Stop monitoring network connectivity
    public func stopMonitoring() {
        guard isMonitoring else { return }
        monitor.cancel()
        isMonitoring = false
        logger.info("Network monitoring stopped")
    }
    
    /// Queue an operation for later execution when network is available
    public func queueOperation(
        type: QueuedOperation.OperationType,
        data: Data,
        priority: QueuedOperation.Priority = .normal
    ) {
        let operation = QueuedOperation(
            type: type,
            data: data,
            priority: priority,
            createdAt: Date()
        )
        
        operationQueue.append(operation)
        operationQueue.sort { $0.priority > $1.priority || 
                              ($0.priority == $1.priority && $0.createdAt < $1.createdAt) }
        queuedOperations = operationQueue
        
        saveQueuedOperations()
        logger.info("Queued operation: \(type.rawValue) with priority: \(priority)")
        
        // Try to process immediately if connected
        if isConnected {
            Task {
                await processQueuedOperations()
            }
        }
    }
    
    /// Remove a queued operation
    public func removeQueuedOperation(_ id: UUID) {
        operationQueue.removeAll { $0.id == id }
        queuedOperations = operationQueue
        saveQueuedOperations()
        logger.info("Removed queued operation: \(id)")
    }
    
    /// Clear all queued operations
    public func clearQueue() {
        operationQueue.removeAll()
        queuedOperations = []
        Task {
            await secureStorage.clear()
        }
        logger.info("Cleared operation queue")
    }
    
    /// Wait for connectivity with timeout
    public func waitForConnectivity(timeout: TimeInterval = 30) async -> Bool {
        if isConnected { return true }

        return await withCheckedContinuation { continuation in
            var connectivityCancellable: AnyCancellable?
            var timeoutCancellable: AnyCancellable?

            timeoutCancellable = Timer.publish(every: timeout, on: .main, in: .common)
                .autoconnect()
                .first()
                .sink { _ in
                    connectivityCancellable?.cancel()
                    timeoutCancellable?.cancel()
                    continuation.resume(returning: false)
                }

            connectivityCancellable = $isConnected
                .filter { $0 }
                .first()
                .sink { _ in
                    connectivityCancellable?.cancel()
                    timeoutCancellable?.cancel()
                    continuation.resume(returning: true)
                }
        }
    }
    
    /// Check if we should use expensive network operations
    public func shouldUseExpensiveOperations() -> Bool {
        // Allow expensive operations on WiFi or wired connections
        // Or if user has explicitly allowed cellular data
        return !currentStatus.isExpensive || 
               connectionType == .wifi || 
               connectionType == .wired ||
               UserDefaults.standard.bool(forKey: "AllowCellularData")
    }
    
    // MARK: - Private Methods
    
    private func setupMonitoring() {
        installPathHandler()
        monitor.start(queue: queue)
        isMonitoring = true
    }

    private func installPathHandler() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor [weak self] in
                guard let self = self else { return }

                let oldStatus = self.currentStatus
                let newStatus = self.mapPathToStatus(path)

                self.currentStatus = newStatus
                self.isConnected = newStatus.isConnected
                self.connectionType = newStatus.connectionType

                // Log status change
                if oldStatus.connectionType != newStatus.connectionType {
                    self.logger.info("Network status changed: \(newStatus.connectionType.displayName)")
                }

                // Process queued operations if we're back online
                if !oldStatus.isConnected && newStatus.isConnected {
                    self.logger.info("Network reconnected, processing queued operations")
                    await self.processQueuedOperations()
                }
            }
        }
    }
    
    private func mapPathToStatus(_ path: NWPath) -> NetworkStatus {
        let connectionType: ConnectionType
        
        if path.status == .satisfied {
            if path.usesInterfaceType(.wifi) {
                connectionType = .wifi
            } else if path.usesInterfaceType(.cellular) {
                connectionType = .cellular
            } else if path.usesInterfaceType(.wiredEthernet) {
                connectionType = .wired
            } else {
                connectionType = .unknown
            }
        } else {
            connectionType = .none
        }
        
        return NetworkStatus(
            connectionType: connectionType,
            isExpensive: path.isExpensive,
            isConstrained: path.isConstrained,
            supportsIPv4: path.supportsIPv4,
            supportsIPv6: path.supportsIPv6,
            supportsDNS: path.supportsDNS
        )
    }
    
    // MARK: - Queue Processing
    
    private func processQueuedOperations() async {
        guard !isProcessingQueue && isConnected && !operationQueue.isEmpty else { return }

        // No handler installed → nothing can actually execute these. They stay queued
        // (and persisted) rather than being logged and deleted: a queued sendToken IS
        // the money, and discarding it while reporting success loses it.
        guard let operationHandler else {
            logger.warning("Queued operations pending but no operationHandler is set; leaving \(operationQueue.count) operation(s) queued")
            return
        }

        isProcessingQueue = true
        defer { isProcessingQueue = false }

        logger.info("Processing \(operationQueue.count) queued operations")

        // Process operations in priority order
        let operations = operationQueue

        for operation in operations {
            // Operations over the retry ceiling are skipped but never silently deleted —
            // surfacing them (via `queuedOperations`) lets the app decide their fate.
            if operation.retryCount >= maxRetryAttempts {
                logger.warning("Operation \(operation.id) exceeded max retries; leaving it queued for the app to resolve")
                continue
            }

            // Calculate retry delay with exponential backoff
            if let lastAttempt = operation.lastAttempt {
                let delay = calculateRetryDelay(for: operation.retryCount)
                let timeSinceLastAttempt = Date().timeIntervalSince(lastAttempt)

                if timeSinceLastAttempt < delay {
                    // Skip this operation for now
                    continue
                }
            }

            // Process the operation
            do {
                try await operationHandler(operation)
                removeQueuedOperation(operation.id)
                logger.info("Successfully processed queued operation: \(operation.type.rawValue)")
            } catch {
                // Update retry count and last attempt
                if let index = operationQueue.firstIndex(where: { $0.id == operation.id }) {
                    operationQueue[index].retryCount += 1
                    operationQueue[index].lastAttempt = Date()
                }

                logger.error("Failed to process operation \(operation.type.rawValue): \(error.localizedDescription)")
            }

            // Check if we're still connected
            if !isConnected {
                logger.info("Lost connection, stopping queue processing")
                break
            }
        }

        // Update published queue
        queuedOperations = operationQueue
        saveQueuedOperations()
    }
    
    private func calculateRetryDelay(for attempt: Int) -> TimeInterval {
        let delay = baseRetryDelay * pow(2.0, Double(attempt))
        return min(delay, maxRetryDelay)
    }
    
    // MARK: - Persistence (Secure Storage)
    
    private func saveQueuedOperations() {
        // Use secure Keychain storage instead of UserDefaults
        // because queued operations may contain sensitive token data
        Task {
            await secureStorage.save(operationQueue)
        }
    }
    
    private func loadQueuedOperations() {
        // Load from secure Keychain storage
        Task {
            let operations = await secureStorage.load()
            await MainActor.run {
                // MERGE with anything queued while the load was in flight — replacing
                // wholesale would drop operations enqueued in that window, and the next
                // save would erase them from the keychain too.
                let pending = self.operationQueue.filter { current in
                    !operations.contains(where: { $0.id == current.id })
                }
                let merged = (operations + pending).sorted {
                    $0.priority > $1.priority ||
                    ($0.priority == $1.priority && $0.createdAt < $1.createdAt)
                }
                self.operationQueue = merged
                self.queuedOperations = merged
                if !operations.isEmpty {
                    self.logger.info("Loaded \(operations.count) queued operations from secure storage")
                }
            }
        }
    }

    deinit {
        monitor.cancel()
    }
}

// MARK: - Circuit Breaker Integration

public extension NetworkMonitor {
    
    /// Create a circuit breaker configuration based on network status
    struct CircuitBreakerConfig: Sendable {
        let failureThreshold: Int
        let resetTimeout: TimeInterval
        let halfOpenMaxAttempts: Int
        
        init(failureThreshold: Int = 5, resetTimeout: TimeInterval = 60, halfOpenMaxAttempts: Int = 3) {
            self.failureThreshold = failureThreshold
            self.resetTimeout = resetTimeout
            self.halfOpenMaxAttempts = halfOpenMaxAttempts
        }
    }
    
    func createCircuitBreakerConfig() -> CircuitBreakerConfig {
        let baseConfig = CircuitBreakerConfig()
        
        // Adjust based on network quality
        let quality = currentStatus.qualityScore
        
        if quality < 0.3 {
            // Poor connection - be more conservative
            return CircuitBreakerConfig(
                failureThreshold: 2,
                resetTimeout: 120,
                halfOpenMaxAttempts: 1
            )
        } else if quality < 0.7 {
            // Moderate connection
            return CircuitBreakerConfig(
                failureThreshold: 3,
                resetTimeout: 60,
                halfOpenMaxAttempts: 2
            )
        } else {
            // Good connection - use defaults
            return baseConfig
        }
    }
    
    /// Check if network is suitable for a given operation
    func isNetworkSuitable(for operation: QueuedOperation.OperationType) -> Bool {
        guard isConnected else { return false }
        
        switch operation {
        case .sendToken, .receiveToken:
            // Critical operations - any connection is fine
            return true
        case .checkProofs, .refreshMint:
            // Background operations - prefer good connection
            return currentStatus.qualityScore > 0.5 || !currentStatus.isExpensive
        }
    }
}

// MARK: - SwiftUI Integration

import SwiftUI

/// View modifier to show network status
public struct NetworkStatusModifier: ViewModifier {
    @ObservedObject private var monitor: NetworkMonitor
    @State private var showBanner = false
    
    public init(monitor: NetworkMonitor) {
        self.monitor = monitor
    }
    
    public func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                if !monitor.isConnected && showBanner {
                    NetworkStatusBanner(monitor: monitor)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .onChange(of: monitor.isConnected) { _, isConnected in
                withAnimation(.easeInOut) {
                    showBanner = !isConnected
                }
            }
    }
}

struct NetworkStatusBanner: View {
    @ObservedObject private var monitor: NetworkMonitor
    
    init(monitor: NetworkMonitor) {
        self.monitor = monitor
    }
    
    var body: some View {
        HStack {
            Image(systemName: "wifi.slash")
            Text("No Internet Connection")
                .font(.subheadline)
            
            if !monitor.queuedOperations.isEmpty {
                Text("(\(monitor.queuedOperations.count) operations queued)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(Color.red.opacity(0.9))
        .foregroundColor(.white)
    }
}

public extension View {
    /// Monitor network connectivity and show status
    func networkStatus(monitor: NetworkMonitor) -> some View {
        modifier(NetworkStatusModifier(monitor: monitor))
    }
}

// MARK: - Combine Publishers

public extension NetworkMonitor {
    
    /// Publisher for connection status changes
    var connectionPublisher: AnyPublisher<Bool, Never> {
        $isConnected
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
    
    /// Publisher for connection type changes
    var connectionTypePublisher: AnyPublisher<ConnectionType, Never> {
        $connectionType
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
    
    /// Publisher for network quality changes
    var networkQualityPublisher: AnyPublisher<Double, Never> {
        $currentStatus
            .map { $0.qualityScore }
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
}
