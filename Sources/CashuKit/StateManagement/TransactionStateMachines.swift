//
//  TransactionStateMachines.swift
//  CashuKit
//
//  State machines for specific transaction flows
//

import Foundation

// MARK: - Mint Transaction State Machine

/// State machine for mint (invoice payment) transactions
public actor MintTransactionStateMachine {
    public enum State: String, Sendable {
        case idle
        case requestingQuote
        case awaitingPayment
        case checkingPayment
        case minting
        case complete
        case failed
    }
    
    public enum Event: Sendable {
        case requestQuote(amount: Int, unit: String)
        case quoteReceived(quote: String, request: String)
        case quoteFailed(any Error)
        case checkPayment
        case paymentConfirmed
        case paymentNotConfirmed
        case mintTokens(outputs: [BlindedMessage])
        case tokensReceived(signatures: [BlindSignature])
        case mintFailed(any Error)
        case timeout
        case cancel
    }
    
    private(set) var currentState: State = .idle
    private var stateHistory: [(from: State, to: State, event: Event, timestamp: Date)] = []
    private var metadata: [String: Any] = [:]
    
    public init() {}
    
    public func processEvent(_ event: Event) async throws -> State {
        let oldState = currentState
        let newState = try validateTransition(from: currentState, event: event)
        
        currentState = newState
        stateHistory.append((from: oldState, to: newState, event: event, timestamp: Date()))
        
        return newState
    }
    
    public func getMetadata<T>(key: String, as type: T.Type) -> T? {
        return metadata[key] as? T
    }
    
    public func setMetadata(key: String, value: Any) {
        metadata[key] = value
    }
    
    private func validateTransition(from state: State, event: Event) throws -> State {
        switch (state, event) {
        case (.idle, .requestQuote):
            return .requestingQuote
        case (.requestingQuote, .quoteReceived):
            return .awaitingPayment
        case (.requestingQuote, .quoteFailed):
            return .failed
        case (.awaitingPayment, .checkPayment):
            return .checkingPayment
        case (.checkingPayment, .paymentConfirmed):
            return .awaitingPayment
        case (.checkingPayment, .paymentNotConfirmed):
            return .awaitingPayment
        case (.awaitingPayment, .mintTokens):
            return .minting
        case (.minting, .tokensReceived):
            return .complete
        case (.minting, .mintFailed):
            return .failed
        case (_, .timeout), (_, .cancel):
            return .failed
        default:
            throw TransactionStateError.invalidTransition(from: "\(state)", to: "\(event)")
        }
    }
}

// MARK: - Melt Transaction State Machine

/// State machine for melt (lightning payment) transactions
public actor MeltTransactionStateMachine {
    public enum State: String, Sendable {
        case idle
        case requestingQuote
        case preparingProofs
        case melting
        case complete
        case failed
    }
    
    public enum Event: Sendable {
        case requestQuote(request: String, unit: String)
        case quoteReceived(quote: String, amount: Int, fee: Int)
        case quoteFailed(any Error)
        case prepareProofs(amount: Int)
        case proofsReady(proofs: [Proof])
        case melt(quote: String, inputs: [Proof])
        case meltSuccess(paid: Bool, preimage: String?)
        case meltFailed(any Error)
        case cancel
    }
    
    private(set) var currentState: State = .idle
    private var stateHistory: [(from: State, to: State, event: Event, timestamp: Date)] = []
    
    public init() {}
    
    public func processEvent(_ event: Event) async throws -> State {
        let oldState = currentState
        let newState = try validateTransition(from: currentState, event: event)
        
        currentState = newState
        stateHistory.append((from: oldState, to: newState, event: event, timestamp: Date()))
        
        return newState
    }
    
    private func validateTransition(from state: State, event: Event) throws -> State {
        switch (state, event) {
        case (.idle, .requestQuote):
            return .requestingQuote
        case (.requestingQuote, .quoteReceived):
            return .preparingProofs
        case (.requestingQuote, .quoteFailed):
            return .failed
        case (.preparingProofs, .proofsReady):
            return .melting
        case (.melting, .meltSuccess):
            return .complete
        case (.melting, .meltFailed):
            return .failed
        case (_, .cancel):
            return .failed
        default:
            throw TransactionStateError.invalidTransition(from: "\(state)", to: "\(event)")
        }
    }
}

// MARK: - Swap Transaction State Machine

/// State machine for swap (proof refresh) transactions
public actor SwapTransactionStateMachine {
    public enum State: String, Sendable {
        case idle
        case preparingInputs
        case preparingOutputs
        case swapping
        case complete
        case failed
    }
    
    public enum Event: Sendable {
        case prepareSwap(proofs: [Proof])
        case inputsReady(inputs: [Proof], totalAmount: Int)
        case outputsPrepared(outputs: [BlindedMessage])
        case swap
        case swapSuccess(signatures: [BlindSignature])
        case swapFailed(any Error)
        case cancel
    }
    
    private(set) var currentState: State = .idle
    private var stateHistory: [(from: State, to: State, event: Event, timestamp: Date)] = []
    
    public init() {}
    
    public func processEvent(_ event: Event) async throws -> State {
        let oldState = currentState
        let newState = try validateTransition(from: currentState, event: event)
        
        currentState = newState
        stateHistory.append((from: oldState, to: newState, event: event, timestamp: Date()))
        
        return newState
    }
    
    private func validateTransition(from state: State, event: Event) throws -> State {
        switch (state, event) {
        case (.idle, .prepareSwap):
            return .preparingInputs
        case (.preparingInputs, .inputsReady):
            return .preparingOutputs
        case (.preparingOutputs, .outputsPrepared):
            return .swapping
        case (.swapping, .swapSuccess):
            return .complete
        case (.swapping, .swapFailed):
            return .failed
        case (_, .cancel):
            return .failed
        default:
            throw TransactionStateError.invalidTransition(from: "\(state)", to: "\(event)")
        }
    }
}

// MARK: - Send/Receive State Machine

/// State machine for send/receive token transactions
public actor SendReceiveStateMachine {
    public enum State: String, Sendable {
        case idle
        case preparing
        case encoding
        case complete
        case failed
    }
    
    public enum Event: Sendable {
        case prepareSend(proofs: [Proof], amount: Int?, memo: String?)
        case prepareReceive(token: String)
        case encodingComplete(token: String)
        case decodingComplete(proofs: [Proof])
        case operationFailed(any Error)
        case cancel
    }
    
    private(set) var currentState: State = .idle
    
    public init() {}
    
    public func processEvent(_ event: Event) async throws -> State {
        let newState = try validateTransition(from: currentState, event: event)
        currentState = newState
        return newState
    }
    
    private func validateTransition(from state: State, event: Event) throws -> State {
        switch (state, event) {
        case (.idle, .prepareSend), (.idle, .prepareReceive):
            return .preparing
        case (.preparing, .encodingComplete):
            return .encoding
        case (.encoding, .encodingComplete), (.preparing, .decodingComplete):
            return .complete
        case (_, .operationFailed), (_, .cancel):
            return .failed
        default:
            throw TransactionStateError.invalidTransition(from: "\(state)", to: "\(event)")
        }
    }
}

// MARK: - Transaction Coordinator

/// Coordinates multiple transaction state machines
public actor TransactionCoordinator {
    private let walletStateMachine: WalletStateMachine
    private var activeTransactions: [UUID: (any TransactionStateMachine)] = [:]
    
    public init(walletStateMachine: WalletStateMachine) {
        self.walletStateMachine = walletStateMachine
    }
    
    /// Start a mint transaction
    public func startMintTransaction(amount: Int, unit: String = "sat") async throws -> (UUID, MintTransactionStateMachine) {
        let transactionId = UUID()
        let stateMachine = MintTransactionStateMachine()
        
        let transaction = try await walletStateMachine.startTransaction(type: .mint, id: transactionId)
        activeTransactions[transactionId] = stateMachine
        
        _ = try await stateMachine.processEvent(.requestQuote(amount: amount, unit: unit))
        try await walletStateMachine.updateTransaction(transactionId, state: .preparing)
        
        return (transactionId, stateMachine)
    }
    
    /// Start a melt transaction
    public func startMeltTransaction(request: String, unit: String = "sat") async throws -> (UUID, MeltTransactionStateMachine) {
        let transactionId = UUID()
        let stateMachine = MeltTransactionStateMachine()
        
        let transaction = try await walletStateMachine.startTransaction(type: .melt, id: transactionId)
        activeTransactions[transactionId] = stateMachine
        
        _ = try await stateMachine.processEvent(.requestQuote(request: request, unit: unit))
        try await walletStateMachine.updateTransaction(transactionId, state: .preparing)
        
        return (transactionId, stateMachine)
    }
    
    /// Start a swap transaction
    public func startSwapTransaction(proofs: [Proof]) async throws -> (UUID, SwapTransactionStateMachine) {
        let transactionId = UUID()
        let stateMachine = SwapTransactionStateMachine()
        
        let transaction = try await walletStateMachine.startTransaction(type: .swap, id: transactionId)
        activeTransactions[transactionId] = stateMachine
        
        _ = try await stateMachine.processEvent(.prepareSwap(proofs: proofs))
        try await walletStateMachine.updateTransaction(transactionId, state: .preparing)
        
        return (transactionId, stateMachine)
    }
    
    /// Complete a transaction
    public func completeTransaction(_ id: UUID) async throws {
        try await walletStateMachine.updateTransaction(id, state: .completed)
        activeTransactions.removeValue(forKey: id)
    }
    
    /// Fail a transaction
    public func failTransaction(_ id: UUID, error: any Error) async throws {
        try await walletStateMachine.updateTransaction(id, state: .failed)
        activeTransactions.removeValue(forKey: id)
    }
    
    /// Cancel a transaction
    public func cancelTransaction(_ id: UUID) async throws {
        try await walletStateMachine.updateTransaction(id, state: .cancelled)
        activeTransactions.removeValue(forKey: id)
    }
}

// MARK: - Protocols

/// Protocol for all transaction state machines
protocol TransactionStateMachine: Actor {
    associatedtype State
    associatedtype Event
    
    var currentState: State { get }
    func processEvent(_ event: Event) async throws -> State
}

// Make our state machines conform to the protocol
extension MintTransactionStateMachine: TransactionStateMachine {}
extension MeltTransactionStateMachine: TransactionStateMachine {}
extension SwapTransactionStateMachine: TransactionStateMachine {}
extension SendReceiveStateMachine: TransactionStateMachine {}

// MARK: - Errors

public enum TransactionStateError: LocalizedError {
    case invalidTransition(from: String, to: String)
    case transactionNotFound
    case invalidState
    
    public var errorDescription: String? {
        switch self {
        case .invalidTransition(let from, let to):
            return "Invalid transition from '\(from)' to '\(to)'"
        case .transactionNotFound:
            return "Transaction not found"
        case .invalidState:
            return "Invalid transaction state"
        }
    }
}