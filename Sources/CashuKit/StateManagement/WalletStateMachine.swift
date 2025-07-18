//
//  WalletStateMachine.swift
//  CashuKit
//
//  State machine implementation for wallet operations
//

import Foundation

// MARK: - Wallet States

/// Represents the various states a wallet can be in
public enum WalletMachineState: String, CaseIterable, Sendable {
    /// Initial state when wallet is created but not yet initialized
    case uninitialized
    
    /// Wallet is being initialized (loading mint info, keysets, etc.)
    case initializing
    
    /// Wallet is ready for operations
    case ready
    
    /// Wallet is performing a transaction
    case transacting
    
    /// Wallet is being restored from backup
    case restoring
    
    /// Wallet is syncing with mint
    case syncing
    
    /// Wallet encountered an error
    case error
    
    /// Wallet is locked (requires authentication)
    case locked
    
    /// Wallet is being shut down
    case shuttingDown
}

// MARK: - Wallet Events

/// Events that trigger state transitions
public enum WalletMachineEvent: Sendable {
    case initialize
    case initializationComplete
    case initializationFailed(any Error)
    case startTransaction(TransactionType)
    case transactionComplete
    case transactionFailed(any Error)
    case startRestore
    case restoreComplete
    case restoreFailed(any Error)
    case startSync
    case syncComplete
    case syncFailed(any Error)
    case lock
    case unlock
    case shutdown
    case errorOccurred(any Error)
    case errorResolved
}

/// Types of transactions
public enum TransactionType: String, Sendable {
    case mint
    case melt
    case swap
    case send
    case receive
}

// MARK: - Transaction States

/// States for individual transactions
public enum TransactionState: String, Sendable {
    case pending
    case preparing
    case executing
    case confirming
    case completed
    case failed
    case cancelled
}

// MARK: - State Machine

/// Main wallet state machine
public actor WalletStateMachine {
    private(set) var currentState: WalletMachineState = .uninitialized
    private var stateHistory: [StateTransition] = []
    private let maxHistorySize = 100
    
    /// Callbacks for state changes
    private var stateChangeCallbacks: [(WalletMachineState, WalletMachineState) -> Void] = []
    
    /// Active transactions
    private var activeTransactions: [UUID: Transaction] = [:]
    
    public init() {}
    
    /// Process an event and transition to a new state if valid
    public func processEvent(_ event: WalletMachineEvent) async throws {
        let oldState = currentState
        let newState = try validateTransition(from: currentState, event: event)
        
        // Perform the transition
        currentState = newState
        
        // Record in history
        let transition = StateTransition(
            from: oldState,
            to: newState,
            event: event,
            timestamp: Date()
        )
        addToHistory(transition)
        
        // Notify callbacks
        for callback in stateChangeCallbacks {
            callback(oldState, newState)
        }
        
        // Handle any side effects
        try await handleSideEffects(for: event, from: oldState, to: newState)
    }
    
    /// Add a callback for state changes
    public func onStateChange(_ callback: @escaping (WalletMachineState, WalletMachineState) -> Void) {
        stateChangeCallbacks.append(callback)
    }
    
    /// Get the current state
    public func getState() -> WalletMachineState {
        return currentState
    }
    
    /// Get state history
    public func getHistory() -> [StateTransition] {
        return stateHistory
    }
    
    /// Check if a transition is valid
    public func canTransition(to event: WalletMachineEvent) -> Bool {
        do {
            _ = try validateTransition(from: currentState, event: event)
            return true
        } catch {
            return false
        }
    }
    
    // MARK: - Transaction Management
    
    /// Start a new transaction
    public func startTransaction(type: TransactionType, id: UUID = UUID()) async throws -> Transaction {
        guard currentState == .ready else {
            throw WalletStateError.invalidState("Cannot start transaction in state: \(currentState)")
        }
        
        let transaction = Transaction(id: id, type: type)
        activeTransactions[id] = transaction
        
        try await processEvent(.startTransaction(type))
        
        return transaction
    }
    
    /// Update transaction state
    public func updateTransaction(_ id: UUID, state: TransactionState) async throws {
        guard var transaction = activeTransactions[id] else {
            throw WalletStateError.transactionNotFound(id)
        }
        
        let oldState = transaction.state
        transaction.state = state
        transaction.lastUpdated = Date()
        
        // Add to transaction history
        transaction.stateHistory.append(
            TransactionStateChange(
                from: oldState,
                to: state,
                timestamp: Date()
            )
        )
        
        activeTransactions[id] = transaction
        
        // Check if we should transition wallet state
        if state == .completed || state == .failed || state == .cancelled {
            // Remove from active transactions
            activeTransactions.removeValue(forKey: id)
            
            // If no more active transactions, return to ready state
            if activeTransactions.isEmpty && currentState == .transacting {
                try await processEvent(state == .completed ? .transactionComplete : .transactionFailed(WalletStateError.transactionFailed))
            }
        }
    }
    
    /// Get active transactions
    public func getActiveTransactions() -> [Transaction] {
        return Array(activeTransactions.values)
    }
    
    /// Get transaction by ID
    public func getTransaction(_ id: UUID) -> Transaction? {
        return activeTransactions[id]
    }
    
    // MARK: - Private Methods
    
    private func validateTransition(from state: WalletMachineState, event: WalletMachineEvent) throws -> WalletMachineState {
        switch (state, event) {
        // Initialization transitions
        case (.uninitialized, .initialize):
            return .initializing
        case (.initializing, .initializationComplete):
            return .ready
        case (.initializing, .initializationFailed):
            return .error
            
        // Transaction transitions
        case (.ready, .startTransaction):
            return .transacting
        case (.transacting, .transactionComplete):
            return .ready
        case (.transacting, .transactionFailed):
            return .error
            
        // Restore transitions
        case (.ready, .startRestore), (.error, .startRestore):
            return .restoring
        case (.restoring, .restoreComplete):
            return .ready
        case (.restoring, .restoreFailed):
            return .error
            
        // Sync transitions
        case (.ready, .startSync):
            return .syncing
        case (.syncing, .syncComplete):
            return .ready
        case (.syncing, .syncFailed):
            return .error
            
        // Lock/Unlock transitions
        case (_, .lock) where state != .locked && state != .shuttingDown:
            return .locked
        case (.locked, .unlock):
            return .ready
            
        // Error transitions
        case (_, .errorOccurred) where state != .shuttingDown:
            return .error
        case (.error, .errorResolved):
            return .ready
            
        // Shutdown transitions
        case (_, .shutdown):
            return .shuttingDown
            
        default:
            throw WalletStateError.invalidTransition(from: state, event: event)
        }
    }
    
    private func addToHistory(_ transition: StateTransition) {
        stateHistory.append(transition)
        
        // Keep history size manageable
        if stateHistory.count > maxHistorySize {
            stateHistory.removeFirst(stateHistory.count - maxHistorySize)
        }
    }
    
    private func handleSideEffects(for event: WalletMachineEvent, from oldState: WalletMachineState, to newState: WalletMachineState) async throws {
        // Handle any side effects of state transitions
        switch event {
        case .errorOccurred(let error):
            // Log error
            print("Wallet error occurred: \(error)")
            
        case .shutdown:
            // Clean up resources
            activeTransactions.removeAll()
            
        default:
            break
        }
    }
}

// MARK: - Supporting Types

/// Records a state transition
public struct StateTransition: Sendable {
    public let from: WalletMachineState
    public let to: WalletMachineState
    public let event: WalletMachineEvent
    public let timestamp: Date
}

/// Represents an active transaction
public struct Transaction: Sendable {
    public let id: UUID
    public let type: TransactionType
    public var state: TransactionState = .pending
    public let createdAt: Date = Date()
    public var lastUpdated: Date = Date()
    public var stateHistory: [TransactionStateChange] = []
    public var metadata: [String: String] = [:]
}

/// Records a transaction state change
public struct TransactionStateChange: Sendable {
    public let from: TransactionState
    public let to: TransactionState
    public let timestamp: Date
}

// MARK: - Errors

public enum WalletStateError: LocalizedError {
    case invalidTransition(from: WalletMachineState, event: WalletMachineEvent)
    case invalidState(String)
    case transactionNotFound(UUID)
    case transactionFailed
    
    public var errorDescription: String? {
        switch self {
        case .invalidTransition(let from, let event):
            return "Invalid transition from state '\(from)' with event '\(event)'"
        case .invalidState(let message):
            return "Invalid state: \(message)"
        case .transactionNotFound(let id):
            return "Transaction not found: \(id)"
        case .transactionFailed:
            return "Transaction failed"
        }
    }
}

// MARK: - Atomic Operations

/// Ensures atomic state transitions
public actor AtomicStateManager {
    private let stateMachine: WalletStateMachine
    private var operationQueue: [() async throws -> Void] = []
    private var isProcessing = false
    
    public init(stateMachine: WalletStateMachine) {
        self.stateMachine = stateMachine
    }
    
    /// Execute an operation atomically
    public func executeAtomic<T: Sendable>(_ operation: @escaping () async throws -> T) async throws -> T {
        // Ensure we process operations one at a time
        while isProcessing {
            try await Task.sleep(nanoseconds: 10_000_000) // 10ms
        }
        
        isProcessing = true
        defer { isProcessing = false }
        
        return try await operation()
    }
    
    /// Execute a state transition atomically
    public func transitionAtomic(_ event: WalletMachineEvent) async throws {
        try await executeAtomic {
            try await self.stateMachine.processEvent(event)
        }
    }
}