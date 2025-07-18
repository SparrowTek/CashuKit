//
//  StateManagementTests.swift
//  CashuKitTests
//
//  Tests for wallet state management
//

import Testing
@testable import CashuKit
import Foundation

@Suite("State Management Tests")
struct StateManagementTests {
    
    // MARK: - Wallet State Machine Tests
    
    @Test("Initial wallet state")
    func testInitialWalletState() async {
        let stateMachine = WalletStateMachine()
        let state = await stateMachine.getState()
        #expect(state == .uninitialized)
    }
    
    @Test("Valid state transitions")
    func testValidStateTransitions() async throws {
        let stateMachine = WalletStateMachine()
        
        // Test initialization flow
        try await stateMachine.processEvent(.initialize)
        #expect(await stateMachine.getState() == .initializing)
        
        try await stateMachine.processEvent(.initializationComplete)
        #expect(await stateMachine.getState() == .ready)
        
        // Test transaction flow
        try await stateMachine.processEvent(.startTransaction(.mint))
        #expect(await stateMachine.getState() == .transacting)
        
        try await stateMachine.processEvent(.transactionComplete)
        #expect(await stateMachine.getState() == .ready)
    }
    
    @Test("Invalid state transitions")
    func testInvalidStateTransitions() async throws {
        let stateMachine = WalletStateMachine()
        
        // Cannot complete initialization without starting it
        await #expect(throws: WalletStateError.self) {
            try await stateMachine.processEvent(.initializationComplete)
        }
        
        // Cannot start transaction before initialization
        await #expect(throws: WalletStateError.self) {
            try await stateMachine.processEvent(.startTransaction(.mint))
        }
    }
    
    @Test("State history tracking")
    func testStateHistoryTracking() async throws {
        let stateMachine = WalletStateMachine()
        
        try await stateMachine.processEvent(.initialize)
        try await stateMachine.processEvent(.initializationComplete)
        
        let history = await stateMachine.getHistory()
        #expect(history.count == 2)
        #expect(history[0].from == .uninitialized)
        #expect(history[0].to == .initializing)
        #expect(history[1].from == .initializing)
        #expect(history[1].to == .ready)
    }
    
    @Test("State change callbacks")
    func testStateChangeCallbacks() async throws {
        let stateMachine = WalletStateMachine()
        var callbackInvoked = false
        var fromState: WalletMachineState?
        var toState: WalletMachineState?
        
        await stateMachine.onStateChange { from, to in
            callbackInvoked = true
            fromState = from
            toState = to
        }
        
        try await stateMachine.processEvent(.initialize)
        
        #expect(callbackInvoked == true)
        #expect(fromState == .uninitialized)
        #expect(toState == .initializing)
    }
    
    @Test("Lock and unlock transitions")
    func testLockUnlockTransitions() async throws {
        let stateMachine = WalletStateMachine()
        
        // Initialize to ready state
        try await stateMachine.processEvent(.initialize)
        try await stateMachine.processEvent(.initializationComplete)
        
        // Lock the wallet
        try await stateMachine.processEvent(.lock)
        #expect(await stateMachine.getState() == .locked)
        
        // Unlock the wallet
        try await stateMachine.processEvent(.unlock)
        #expect(await stateMachine.getState() == .ready)
    }
    
    @Test("Error state transitions")
    func testErrorStateTransitions() async throws {
        let stateMachine = WalletStateMachine()
        
        // Initialize to ready state
        try await stateMachine.processEvent(.initialize)
        try await stateMachine.processEvent(.initializationComplete)
        
        // Simulate error
        try await stateMachine.processEvent(.errorOccurred(CashuError.networkError("Test error")))
        #expect(await stateMachine.getState() == .error)
        
        // Resolve error
        try await stateMachine.processEvent(.errorResolved)
        #expect(await stateMachine.getState() == .ready)
    }
    
    // MARK: - Transaction Management Tests
    
    @Test("Transaction creation and tracking")
    func testTransactionCreation() async throws {
        let stateMachine = WalletStateMachine()
        
        // Initialize wallet
        try await stateMachine.processEvent(.initialize)
        try await stateMachine.processEvent(.initializationComplete)
        
        // Start a transaction
        let transaction = try await stateMachine.startTransaction(type: .mint)
        
        #expect(transaction.type == .mint)
        #expect(transaction.state == .pending)
        #expect(await stateMachine.getState() == .transacting)
        
        // Check active transactions
        let activeTransactions = await stateMachine.getActiveTransactions()
        #expect(activeTransactions.count == 1)
        #expect(activeTransactions[0].id == transaction.id)
    }
    
    @Test("Transaction state updates")
    func testTransactionStateUpdates() async throws {
        let stateMachine = WalletStateMachine()
        
        // Initialize wallet
        try await stateMachine.processEvent(.initialize)
        try await stateMachine.processEvent(.initializationComplete)
        
        // Start a transaction
        let transaction = try await stateMachine.startTransaction(type: .swap)
        
        // Update transaction state
        try await stateMachine.updateTransaction(transaction.id, state: .executing)
        
        let updatedTransaction = await stateMachine.getTransaction(transaction.id)
        #expect(updatedTransaction?.state == .executing)
    }
    
    @Test("Transaction completion")
    func testTransactionCompletion() async throws {
        let stateMachine = WalletStateMachine()
        
        // Initialize wallet
        try await stateMachine.processEvent(.initialize)
        try await stateMachine.processEvent(.initializationComplete)
        
        // Start a transaction
        let transaction = try await stateMachine.startTransaction(type: .melt)
        
        // Complete the transaction
        try await stateMachine.updateTransaction(transaction.id, state: .completed)
        
        // Should return to ready state
        #expect(await stateMachine.getState() == .ready)
        
        // Transaction should be removed from active list
        let activeTransactions = await stateMachine.getActiveTransactions()
        #expect(activeTransactions.isEmpty)
    }
    
    // MARK: - Atomic Operations Tests
    
    @Test("Atomic state transitions")
    func testAtomicStateTransitions() async throws {
        let stateMachine = WalletStateMachine()
        let atomicManager = AtomicStateManager(stateMachine: stateMachine)
        
        // Perform atomic transition
        try await atomicManager.transitionAtomic(.initialize)
        #expect(await stateMachine.getState() == .initializing)
    }
    
    @Test("Concurrent atomic operations")
    func testConcurrentAtomicOperations() async throws {
        let stateMachine = WalletStateMachine()
        let atomicManager = AtomicStateManager(stateMachine: stateMachine)
        
        // Initialize first
        try await atomicManager.transitionAtomic(.initialize)
        try await atomicManager.transitionAtomic(.initializationComplete)
        
        // Start multiple concurrent operations
        let tasks = (0..<5).map { _ in
            Task {
                try await atomicManager.executeAtomic {
                    // Simulate some work
                    try await Task.sleep(nanoseconds: 10_000_000) // 10ms
                    return true
                }
            }
        }
        
        // Wait for all tasks to complete
        let results = try await withThrowingTaskGroup(of: Bool.self) { group in
            for task in tasks {
                group.addTask {
                    try await task.value
                }
            }
            
            var results: [Bool] = []
            for try await result in group {
                results.append(result)
            }
            return results
        }
        
        #expect(results.count == 5)
        #expect(results.allSatisfy { $0 == true })
    }
    
    // MARK: - Mint Transaction State Machine Tests
    
    @Test("Mint transaction flow")
    func testMintTransactionFlow() async throws {
        let mintStateMachine = MintTransactionStateMachine()
        
        #expect(await mintStateMachine.currentState == .idle)
        
        // Request quote
        let state1 = try await mintStateMachine.processEvent(.requestQuote(amount: 1000, unit: "sat"))
        #expect(state1 == .requestingQuote)
        
        // Quote received
        let state2 = try await mintStateMachine.processEvent(.quoteReceived(quote: "test-quote", request: "lnbc..."))
        #expect(state2 == .awaitingPayment)
        
        // Check payment
        let state3 = try await mintStateMachine.processEvent(.checkPayment)
        #expect(state3 == .checkingPayment)
        
        // Payment confirmed
        let state4 = try await mintStateMachine.processEvent(.paymentConfirmed)
        #expect(state4 == .awaitingPayment)
        
        // Mint tokens
        let state5 = try await mintStateMachine.processEvent(.mintTokens(outputs: []))
        #expect(state5 == .minting)
        
        // Tokens received
        let state6 = try await mintStateMachine.processEvent(.tokensReceived(signatures: []))
        #expect(state6 == .complete)
    }
    
    @Test("Mint transaction metadata")
    func testMintTransactionMetadata() async throws {
        let mintStateMachine = MintTransactionStateMachine()
        
        // Set metadata
        await mintStateMachine.setMetadata(key: "quote", value: "test-quote-123")
        await mintStateMachine.setMetadata(key: "amount", value: 1000)
        
        // Retrieve metadata
        let quote = await mintStateMachine.getMetadata(key: "quote", as: String.self)
        let amount = await mintStateMachine.getMetadata(key: "amount", as: Int.self)
        
        #expect(quote == "test-quote-123")
        #expect(amount == 1000)
    }
    
    // MARK: - Melt Transaction State Machine Tests
    
    @Test("Melt transaction flow")
    func testMeltTransactionFlow() async throws {
        let meltStateMachine = MeltTransactionStateMachine()
        
        #expect(await meltStateMachine.currentState == .idle)
        
        // Request quote
        let state1 = try await meltStateMachine.processEvent(.requestQuote(request: "lnbc...", unit: "sat"))
        #expect(state1 == .requestingQuote)
        
        // Quote received
        let state2 = try await meltStateMachine.processEvent(.quoteReceived(quote: "test-quote", amount: 1000, fee: 10))
        #expect(state2 == .preparingProofs)
        
        // Proofs ready
        let state3 = try await meltStateMachine.processEvent(.proofsReady(proofs: []))
        #expect(state3 == .melting)
        
        // Melt success
        let state4 = try await meltStateMachine.processEvent(.meltSuccess(paid: true, preimage: "test-preimage"))
        #expect(state4 == .complete)
    }
    
    // MARK: - Swap Transaction State Machine Tests
    
    @Test("Swap transaction flow")
    func testSwapTransactionFlow() async throws {
        let swapStateMachine = SwapTransactionStateMachine()
        
        #expect(await swapStateMachine.currentState == .idle)
        
        // Prepare swap
        let state1 = try await swapStateMachine.processEvent(.prepareSwap(proofs: []))
        #expect(state1 == .preparingInputs)
        
        // Inputs ready
        let state2 = try await swapStateMachine.processEvent(.inputsReady(inputs: [], totalAmount: 1000))
        #expect(state2 == .preparingOutputs)
        
        // Outputs prepared
        let state3 = try await swapStateMachine.processEvent(.outputsPrepared(outputs: []))
        #expect(state3 == .swapping)
        
        // Swap success
        let state4 = try await swapStateMachine.processEvent(.swapSuccess(signatures: []))
        #expect(state4 == .complete)
    }
    
    // MARK: - Transaction Coordinator Tests
    
    @Test("Transaction coordinator mint flow")
    func testTransactionCoordinatorMint() async throws {
        let walletStateMachine = WalletStateMachine()
        let coordinator = TransactionCoordinator(walletStateMachine: walletStateMachine)
        
        // Initialize wallet
        try await walletStateMachine.processEvent(.initialize)
        try await walletStateMachine.processEvent(.initializationComplete)
        
        // Start mint transaction
        let (transactionId, mintStateMachine) = try await coordinator.startMintTransaction(amount: 1000)
        
        #expect(await walletStateMachine.getState() == .transacting)
        #expect(await mintStateMachine.currentState == .requestingQuote)
        
        // Complete transaction
        try await coordinator.completeTransaction(transactionId)
        
        #expect(await walletStateMachine.getState() == .ready)
    }
    
    @Test("Transaction coordinator error handling")
    func testTransactionCoordinatorError() async throws {
        let walletStateMachine = WalletStateMachine()
        let coordinator = TransactionCoordinator(walletStateMachine: walletStateMachine)
        
        // Initialize wallet
        try await walletStateMachine.processEvent(.initialize)
        try await walletStateMachine.processEvent(.initializationComplete)
        
        // Start swap transaction
        let (transactionId, _) = try await coordinator.startSwapTransaction(proofs: [])
        
        // Fail transaction
        try await coordinator.failTransaction(transactionId, error: CashuError.insufficientFunds)
        
        // After a failed transaction, the wallet should be in error state
        #expect(await walletStateMachine.getState() == .error)
        
        // Resolve the error to return to ready state
        try await walletStateMachine.processEvent(.errorResolved)
        #expect(await walletStateMachine.getState() == .ready)
    }
}