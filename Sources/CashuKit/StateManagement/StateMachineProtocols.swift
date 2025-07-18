//
//  StateMachineProtocols.swift
//  CashuKit
//
//  Protocols and types for state machine integration
//

import Foundation

// MARK: - State Machine Protocols

/// Protocol for wallet operations that support state management
public protocol StatefulWalletOperations {
    /// Initialize state management
    func initializeStateManagement() async throws
    
    /// Get current wallet state
    func getCurrentState() async -> WalletMachineState?
    
    /// Mint tokens with state tracking
    func mintTokensStateful(amount: Int, unit: String) async throws -> [Proof]
    
    /// Melt tokens with state tracking
    func meltTokensStateful(request: String, proofs: [Proof]?, unit: String) async throws -> PostMeltResponse
    
    /// Swap proofs with state tracking
    func swapProofsStateful(proofs: [Proof], outputs: [BlindedMessage]?) async throws -> [Proof]
}

// MARK: - State Management Container

/// Container for state management components
public struct StateManagementContainer {
    public let stateMachine: WalletStateMachine
    public let atomicStateManager: AtomicStateManager
    public let transactionCoordinator: TransactionCoordinator
    
    public init() {
        self.stateMachine = WalletStateMachine()
        self.atomicStateManager = AtomicStateManager(stateMachine: stateMachine)
        self.transactionCoordinator = TransactionCoordinator(walletStateMachine: stateMachine)
    }
}

// MARK: - Example Integration

/// Example of how to integrate state management with a wallet
public class StatefulWalletExample {
    private let stateContainer: StateManagementContainer
    
    public init() {
        self.stateContainer = StateManagementContainer()
    }
    
    /// Initialize the wallet with state management
    public func initialize() async throws {
        try await stateContainer.atomicStateManager.transitionAtomic(.initialize)
        
        // Simulate initialization work
        try await Task.sleep(nanoseconds: 100_000_000) // 100ms
        
        try await stateContainer.atomicStateManager.transitionAtomic(.initializationComplete)
    }
    
    /// Example mint operation with state tracking
    public func mintExample(amount: Int) async throws {
        let (transactionId, mintStateMachine) = try await stateContainer.transactionCoordinator.startMintTransaction(
            amount: amount,
            unit: "sat"
        )
        
        do {
            // Simulate quote request
            _ = try await mintStateMachine.processEvent(.requestQuote(amount: amount, unit: "sat"))
            
            // Simulate quote received
            _ = try await mintStateMachine.processEvent(.quoteReceived(quote: "mock-quote", request: "lnbc..."))
            
            // Simulate payment check
            _ = try await mintStateMachine.processEvent(.checkPayment)
            _ = try await mintStateMachine.processEvent(.paymentConfirmed)
            
            // Simulate minting
            _ = try await mintStateMachine.processEvent(.mintTokens(outputs: []))
            _ = try await mintStateMachine.processEvent(.tokensReceived(signatures: []))
            
            // Complete transaction
            try await stateContainer.transactionCoordinator.completeTransaction(transactionId)
            
        } catch {
            try await stateContainer.transactionCoordinator.failTransaction(transactionId, error: error)
            throw error
        }
    }
    
    /// Get current state
    public func getCurrentState() async -> WalletMachineState {
        await stateContainer.stateMachine.getState()
    }
    
    /// Get active transactions
    public func getActiveTransactions() async -> [Transaction] {
        await stateContainer.stateMachine.getActiveTransactions()
    }
}

// MARK: - State Observers

/// Protocol for observing state changes
public protocol WalletStateObserver: AnyObject {
    func walletStateDidChange(from oldState: WalletMachineState, to newState: WalletMachineState)
}

/// Manager for state observers
public actor StateObserverManager {
    private var observers: [WeakObserver] = []
    
    private struct WeakObserver {
        weak var observer: WalletStateObserver?
    }
    
    public init() {}
    
    public func addObserver(_ observer: WalletStateObserver) {
        observers.append(WeakObserver(observer: observer))
        cleanupObservers()
    }
    
    public func removeObserver(_ observer: WalletStateObserver) {
        observers.removeAll { $0.observer === observer }
    }
    
    public func notifyStateChange(from oldState: WalletMachineState, to newState: WalletMachineState) {
        cleanupObservers()
        
        for weakObserver in observers {
            weakObserver.observer?.walletStateDidChange(from: oldState, to: newState)
        }
    }
    
    private func cleanupObservers() {
        observers.removeAll { $0.observer == nil }
    }
}