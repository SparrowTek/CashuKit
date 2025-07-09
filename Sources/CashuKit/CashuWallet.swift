//
//  CashuWallet.swift
//  CashuKit
//
//  Main wallet implementation for Cashu operations
//

import Foundation

// MARK: - Wallet Configuration

/// Configuration for the Cashu wallet
public struct WalletConfiguration: Sendable {
    public let mintURL: String
    public let unit: String
    public let retryAttempts: Int
    public let retryDelay: TimeInterval
    public let operationTimeout: TimeInterval
    
    public init(
        mintURL: String,
        unit: String = "sat",
        retryAttempts: Int = 3,
        retryDelay: TimeInterval = 1.0,
        operationTimeout: TimeInterval = 30.0
    ) {
        self.mintURL = mintURL
        self.unit = unit
        self.retryAttempts = retryAttempts
        self.retryDelay = retryDelay
        self.operationTimeout = operationTimeout
    }
}

// MARK: - Wallet State

/// Current state of the wallet
public enum WalletState: Sendable {
    case uninitialized
    case initializing
    case ready
    case syncing
    case error(CashuError)
}

// MARK: - Wallet Result Types

// Using existing MintResult and MeltResult from NUT services

// MARK: - Cashu Wallet

/// Main Cashu wallet implementation
/// Thread-safe actor that manages all wallet operations
public actor CashuWallet {
    
    // MARK: - Properties
    
    private let configuration: WalletConfiguration
    private let proofManager: ProofManager
    private let mintInfoService: MintInfoService
    
    private var mintService: MintService?
    private var meltService: MeltService?
    private var swapService: SwapService?
    private var keyExchangeService: KeyExchangeService?
    private var keysetManagementService: KeysetManagementService?
    
    private var currentMintInfo: MintInfo?
    private var currentKeysets: [String: Keyset] = [:]
    private var walletState: WalletState = .uninitialized
    
    // MARK: - Initialization
    
    /// Initialize a new Cashu wallet
    /// - Parameters:
    ///   - configuration: Wallet configuration
    ///   - proofStorage: Optional custom proof storage (defaults to in-memory)
    public init(
        configuration: WalletConfiguration,
        proofStorage: ProofStorage? = nil
    ) async {
        self.configuration = configuration
        self.proofManager = ProofManager(storage: proofStorage ?? InMemoryProofStorage())
        self.mintInfoService = await MintInfoService()
        
        // Initialize services
        await setupServices()
    }
    
    /// Initialize wallet with mint URL
    /// - Parameters:
    ///   - mintURL: The mint URL
    ///   - unit: Currency unit (defaults to "sat")
    public init(
        mintURL: String,
        unit: String = "sat"
    ) async {
        let config = WalletConfiguration(mintURL: mintURL, unit: unit)
        await self.init(configuration: config)
    }
    
    // MARK: - Wallet State Management
    
    /// Get current wallet state
    public var state: WalletState {
        walletState
    }
    
    /// Check if wallet is ready for operations
    public var isReady: Bool {
        switch walletState {
        case .ready:
            return true
        default:
            return false
        }
    }
    
    /// Initialize the wallet (fetch mint info and keysets)
    public func initialize() async throws {
        guard case .uninitialized = walletState else {
            throw CashuError.walletAlreadyInitialized
        }
        
        walletState = .initializing
        
        do {
            // Fetch mint information
            currentMintInfo = try await mintInfoService.getMintInfoWithRetry(
                from: configuration.mintURL,
                maxRetries: configuration.retryAttempts,
                retryDelay: configuration.retryDelay
            )
            
            // Validate mint supports basic operations
            guard let mintInfo = currentMintInfo, mintInfo.supportsBasicOperations() else {
                throw CashuError.invalidMintConfiguration
            }
            
            // Fetch active keysets
            try await syncKeysets()
            
            walletState = .ready
        } catch {
            walletState = .error(error as? CashuError ?? CashuError.invalidMintConfiguration)
            throw error
        }
    }
    
    /// Sync wallet state with mint (fetch latest keysets and mint info)
    public func sync() async throws {
        guard isReady else {
            throw CashuError.walletNotInitialized
        }
        
        let previousState = walletState
        walletState = .syncing
        
        do {
            // Refresh mint info
            currentMintInfo = try await mintInfoService.getMintInfoWithRetry(
                from: configuration.mintURL,
                maxRetries: configuration.retryAttempts,
                retryDelay: configuration.retryDelay
            )
            
            // Sync keysets
            try await syncKeysets()
            
            walletState = .ready
        } catch {
            walletState = previousState
            throw error
        }
    }
    
    // MARK: - Balance Operations
    
    /// Get current wallet balance
    public var balance: Int {
        get async throws {
            guard isReady else {
                throw CashuError.walletNotInitialized
            }
            
            return try await proofManager.getTotalBalance()
        }
    }
    
    /// Get balance by keyset
    public func balance(for keysetID: String) async throws -> Int {
        guard isReady else {
            throw CashuError.walletNotInitialized
        }
        
        return try await proofManager.getBalance(keysetID: keysetID)
    }
    
    /// Get all available proofs
    public var proofs: [Proof] {
        get async throws {
            guard isReady else {
                throw CashuError.walletNotInitialized
            }
            
            return try await proofManager.getAvailableProofs()
        }
    }
    
    // MARK: - Core Wallet Operations
    
    /// Mint new tokens from a payment request
    /// - Parameters:
    ///   - amount: Amount to mint
    ///   - paymentRequest: Payment request (e.g., Lightning invoice)
    ///   - method: Payment method (defaults to "bolt11")
    /// - Returns: Mint result with new proofs
    public func mint(
        amount: Int,
        paymentRequest: String,
        method: String = "bolt11"
    ) async throws -> MintResult {
        guard isReady else {
            throw CashuError.walletNotInitialized
        }
        
        guard amount > 0 else {
            throw CashuError.invalidAmount
        }
        
        guard let mintService = mintService else {
            throw CashuError.nutNotImplemented("NUT-04")
        }
        
        // Use the existing high-level mint method
        return try await mintService.mint(
            amount: amount,
            method: method,
            unit: configuration.unit,
            at: configuration.mintURL
        )
    }
    
    /// Send tokens (prepare for transfer)
    /// - Parameters:
    ///   - amount: Amount to send
    ///   - memo: Optional memo
    /// - Returns: Cashu token ready for transfer
    public func send(amount: Int, memo: String? = nil) async throws -> CashuToken {
        guard isReady else {
            throw CashuError.walletNotInitialized
        }
        
        guard amount > 0 else {
            throw CashuError.invalidAmount
        }
        
        // Simplified implementation - create a basic token structure
        let selectedProofs = try await proofManager.selectProofs(amount: amount)
        
        let tokenEntry = TokenEntry(
            mint: configuration.mintURL,
            proofs: selectedProofs
        )
        
        return CashuToken(
            token: [tokenEntry],
            unit: configuration.unit,
            memo: memo
        )
    }
    
    /// Receive tokens from another wallet
    /// - Parameter token: Cashu token to receive
    /// - Returns: Array of new proofs
    public func receive(token: CashuToken) async throws -> [Proof] {
        guard isReady else {
            throw CashuError.walletNotInitialized
        }
        
        var allNewProofs: [Proof] = []
        
        // Process each token entry
        for tokenEntry in token.token {
            // Validate token entry is for our mint
            guard tokenEntry.mint == configuration.mintURL else {
                throw CashuError.invalidMintConfiguration
            }
            
            // Add proofs to our storage
            try await proofManager.addProofs(tokenEntry.proofs)
            allNewProofs.append(contentsOf: tokenEntry.proofs)
        }
        
        return allNewProofs
    }
    
    /// Melt tokens (spend via Lightning)
    /// - Parameters:
    ///   - paymentRequest: Lightning payment request
    ///   - method: Payment method (defaults to "bolt11")
    /// - Returns: Melt result
    public func melt(
        paymentRequest: String,
        method: String = "bolt11"
    ) async throws -> MeltResult {
        guard isReady else {
            throw CashuError.walletNotInitialized
        }
        
        guard let meltService = meltService else {
            throw CashuError.nutNotImplemented("NUT-05")
        }
        
        // Simplified implementation - use the existing high-level methods
        let availableProofs = try await proofManager.getAvailableProofs()
        
        // For now, just use the service's meltToPayment method
        return try await meltService.meltToPayment(
            paymentRequest: paymentRequest,
            method: PaymentMethod.bolt11,
            unit: configuration.unit,
            from: availableProofs,
            at: configuration.mintURL
        )
    }
    
    // MARK: - Utility Methods
    
    /// Get mint information
    public var mintInfo: MintInfo? {
        currentMintInfo
    }
    
    /// Get current keysets
    public var keysets: [String: Keyset] {
        currentKeysets
    }
    
    /// Clear all wallet data
    public func clearAll() async throws {
        try await proofManager.clearAll()
        currentMintInfo = nil
        currentKeysets.removeAll()
        walletState = .uninitialized
    }
    
    /// Get wallet statistics
    public func getStatistics() async throws -> WalletStatistics {
        let totalBalance = try await proofManager.getTotalBalance()
        let proofCount = try await proofManager.getProofCount()
        let spentProofCount = await proofManager.getSpentProofCount()
        
        return WalletStatistics(
            totalBalance: totalBalance,
            proofCount: proofCount,
            spentProofCount: spentProofCount,
            keysetCount: currentKeysets.count,
            mintURL: configuration.mintURL
        )
    }
    
    // MARK: - Private Methods
    
    /// Setup wallet services
    private func setupServices() async {
        mintService = await MintService()
        meltService = await MeltService()
        swapService = await SwapService()
        keyExchangeService = await KeyExchangeService()
        keysetManagementService = await KeysetManagementService()
    }
    
    /// Sync keysets with mint
    private func syncKeysets() async throws {
        guard let keyExchangeService = keyExchangeService else {
            throw CashuError.nutNotImplemented("NUT-01")
        }
        
        // Use the existing method to get active keys
        let keysets = try await keyExchangeService.getActiveKeys(
            from: configuration.mintURL, 
            unit: CurrencyUnit(rawValue: configuration.unit) ?? .sat
        )
        
        for keyset in keysets {
            currentKeysets[keyset.id] = keyset
        }
    }
    
    /// Placeholder for future implementation
    private func generateBlindedOutputs(amount: Int) async throws -> [BlindedMessage] {
        // This would be implemented using the existing NUT services
        throw CashuError.nutNotImplemented("generateBlindedOutputs")
    }
    
    /// Placeholder for future implementation
    private func unblindSignatures(signatures: [BlindSignature], amount: Int) async throws -> [Proof] {
        // This would be implemented using the existing NUT services
        throw CashuError.nutNotImplemented("unblindSignatures")
    }
    
    /// Placeholder for future implementation
    private func rollbackSpentProofs(_ proofs: [Proof]) async throws {
        // This would be implemented in ProofManager
        print("Warning: Need to implement rollback for proofs")
    }
    
    /// Execute operation with timeout
    private func withTimeout<T: Sendable>(_ timeout: TimeInterval, operation: @escaping @Sendable () async throws -> T) async throws -> T {
        return try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                return try await operation()
            }
            
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                throw CashuError.operationTimeout
            }
            
            defer { group.cancelAll() }
            
            guard let result = try await group.next() else {
                throw CashuError.operationTimeout
            }
            
            return result
        }
    }
}

// MARK: - Wallet Statistics

/// Wallet statistics and info
public struct WalletStatistics: Sendable {
    public let totalBalance: Int
    public let proofCount: Int
    public let spentProofCount: Int
    public let keysetCount: Int
    public let mintURL: String
    
    public init(
        totalBalance: Int,
        proofCount: Int,
        spentProofCount: Int,
        keysetCount: Int,
        mintURL: String
    ) {
        self.totalBalance = totalBalance
        self.proofCount = proofCount
        self.spentProofCount = spentProofCount
        self.keysetCount = keysetCount
        self.mintURL = mintURL
    }
}