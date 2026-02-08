//
//  CashuKit+Apple.swift
//  CashuKit
//
//  Apple-specific convenience wrapper for CashuWallet
//

import SwiftUI
import CoreCashu
import Combine

/// Apple-specific wrapper for CashuWallet with SwiftUI integration
@MainActor
public class AppleCashuWallet: ObservableObject {

    // MARK: - Published Properties for SwiftUI

    @Published public private(set) var balance: Int = 0
    @Published public private(set) var isConnected: Bool = false
    @Published public private(set) var currentMintURL: URL?
    @Published public private(set) var isLoading: Bool = false
    @Published public private(set) var lastError: (any Error)?
    @Published public private(set) var proofs: [Proof] = []
    @Published public private(set) var pendingTransactions: [String] = []

    // MARK: - Private Properties

    private var wallet: CashuWallet?
    private let secureStore: KeychainSecureStore
    private let logger: OSLogLogger
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Configuration

    public struct Configuration: Sendable {
        public let keychainAccessGroup: String?
        public let logSubsystem: String
        public let logLevel: LogLevel
        public let enableBiometrics: Bool
        public let enableiCloudSync: Bool
        public let httpTimeoutInterval: TimeInterval
        public let retryAttempts: Int

        public init(
            keychainAccessGroup: String? = nil,
            logSubsystem: String? = nil,
            logLevel: LogLevel = .info,
            enableBiometrics: Bool = false,
            enableiCloudSync: Bool = false,
            httpTimeoutInterval: TimeInterval = 30,
            retryAttempts: Int = 3
        ) {
            self.keychainAccessGroup = keychainAccessGroup
            self.logSubsystem = logSubsystem ?? Bundle.main.bundleIdentifier ?? "com.cashukit"
            self.logLevel = logLevel
            self.enableBiometrics = enableBiometrics
            self.enableiCloudSync = enableiCloudSync
            self.httpTimeoutInterval = httpTimeoutInterval
            self.retryAttempts = retryAttempts
        }

        public static let defaultConfiguration = Configuration()
    }

    private let configuration: Configuration

    // MARK: - Initialization

    /// Initialize with configuration
    public init(configuration: Configuration = .defaultConfiguration) {
        self.configuration = configuration

        // Set up Apple-specific implementations
        self.secureStore = KeychainSecureStore(
            accessGroup: configuration.keychainAccessGroup,
            synchronizable: configuration.enableiCloudSync
        )
        self.logger = OSLogLogger(
            subsystem: configuration.logSubsystem,
            category: "Wallet",
            minimumLevel: configuration.logLevel
        )
    }

    /// Convenience initializer for a specific mint
    public convenience init(
        mintURL: URL,
        configuration: Configuration = .defaultConfiguration
    ) async {
        self.init(configuration: configuration)
        do {
            try await connect(to: mintURL)
        } catch {
            logger.error("Failed to connect to mint during initialization: \(error.localizedDescription)")
        }
    }

    // MARK: - Public Methods

    /// Connect to a mint
    public func connect(to mintURL: URL) async throws {
        isLoading = true
        defer { isLoading = false }

        do {
            // Create wallet configuration for CoreCashu
            let walletConfig = WalletConfiguration(
                mintURL: mintURL.absoluteString,
                unit: "sat",
                retryAttempts: configuration.retryAttempts,
                retryDelay: 1.0,
                operationTimeout: configuration.httpTimeoutInterval
            )

            // Create the wallet with CoreCashu
            let newWallet = await CashuWallet(
                configuration: walletConfig,
                secureStore: secureStore,
                logger: logger
            )

            // Initialize the wallet (fetches mint info and keysets)
            try await newWallet.initialize()

            self.wallet = newWallet
            currentMintURL = mintURL
            isConnected = true
            lastError = nil

            logger.info("Connected to mint: \(mintURL.absoluteString)")

            // Refresh balance after connecting
            await refreshBalance()
        } catch {
            lastError = error
            isConnected = false
            logger.error("Failed to connect to mint: \(error.localizedDescription)")
            throw error
        }
    }

    /// Disconnect from current mint
    public func disconnect() async {
        wallet = nil
        isConnected = false
        currentMintURL = nil
        proofs.removeAll()
        balance = 0
        logger.info("Disconnected from mint")
    }

    /// Mint tokens for a paid quote
    /// - Parameters:
    ///   - quoteID: The mint quote identifier (obtained from requesting a mint quote)
    ///   - amount: Amount to mint
    /// - Returns: MintResult with the minted proofs
    public func mint(quoteID: String, amount: Int) async throws -> MintResult {
        guard let wallet = wallet else {
            throw CashuError.walletNotInitialized
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let result = try await wallet.mint(
                quoteID: quoteID,
                amount: amount
            )

            // Update local proofs
            let newProofs = try await wallet.proofs
            proofs = newProofs
            updateBalance()

            logger.info("Minted \(result.newProofs.count) new proofs for \(amount) sats")
            return result
        } catch {
            lastError = error
            logger.error("Failed to mint: \(error.localizedDescription)")
            throw error
        }
    }

    /// Melt tokens (pay Lightning invoice)
    public func melt(paymentRequest: String) async throws -> MeltResult {
        guard let wallet = wallet else {
            throw CashuError.walletNotInitialized
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let result = try await wallet.melt(paymentRequest: paymentRequest)

            // Update local proofs
            let remainingProofs = try await wallet.proofs
            proofs = remainingProofs
            updateBalance()

            logger.info("Melted tokens for invoice, state: \(result.state)")
            return result
        } catch {
            lastError = error
            logger.error("Failed to melt: \(error.localizedDescription)")
            throw error
        }
    }

    /// Send tokens (create a Cashu token)
    public func send(amount: Int, memo: String? = nil) async throws -> CashuToken {
        guard let wallet = wallet else {
            throw CashuError.walletNotInitialized
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let token = try await wallet.send(amount: amount, memo: memo)

            // Update local proofs (proofs used for sending are removed)
            let remainingProofs = try await wallet.proofs
            proofs = remainingProofs
            updateBalance()

            logger.info("Sent \(amount) sats")
            return token
        } catch {
            lastError = error
            logger.error("Failed to send: \(error.localizedDescription)")
            throw error
        }
    }

    /// Receive tokens
    public func receive(token: String) async throws -> [Proof] {
        guard let wallet = wallet else {
            throw CashuError.walletNotInitialized
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let receivedProofs = try await wallet.importToken(token)

            // Update local proofs
            let allProofs = try await wallet.proofs
            proofs = allProofs
            updateBalance()

            logger.info("Received \(receivedProofs.count) proofs")
            return receivedProofs
        } catch {
            lastError = error
            logger.error("Failed to receive: \(error.localizedDescription)")
            throw error
        }
    }

    /// Receive a CashuToken directly
    public func receive(token: CashuToken) async throws -> [Proof] {
        guard let wallet = wallet else {
            throw CashuError.walletNotInitialized
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let receivedProofs = try await wallet.receive(token: token)

            // Update local proofs
            let allProofs = try await wallet.proofs
            proofs = allProofs
            updateBalance()

            logger.info("Received \(receivedProofs.count) proofs")
            return receivedProofs
        } catch {
            lastError = error
            logger.error("Failed to receive: \(error.localizedDescription)")
            throw error
        }
    }

    /// Check proof states
    public func checkProofStates() async throws {
        guard let wallet = wallet else {
            throw CashuError.walletNotInitialized
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let result = try await wallet.checkProofStates(proofs)

            // The wallet should automatically remove spent proofs
            let validProofs = try await wallet.proofs
            proofs = validProofs
            updateBalance()

            let spentCount = result.getResults(withState: .spent).count
            let unspentCount = result.getResults(withState: .unspent).count
            logger.info("Checked proof states: \(spentCount) spent, \(unspentCount) unspent")
        } catch {
            lastError = error
            logger.error("Failed to check proof states: \(error.localizedDescription)")
            throw error
        }
    }

    /// Restore wallet from mnemonic
    /// - Parameter mnemonic: BIP39 mnemonic phrase (12, 15, 18, 21, or 24 words)
    /// - Throws: `CashuError.invalidMnemonic` if the mnemonic is invalid
    public func restore(mnemonic: String) async throws {
        guard let url = currentMintURL else {
            throw CashuError.invalidMintConfiguration
        }
        
        // Validate mnemonic before persisting (security: prevents storing invalid data)
        // This validates:
        // - Word count (12, 15, 18, 21, or 24 words)
        // - All words are in BIP39 wordlist
        // - Checksum is valid
        guard BIP39.validateMnemonic(mnemonic) else {
            logger.error("Invalid mnemonic: failed BIP39 validation")
            throw CashuError.invalidMnemonic
        }

        isLoading = true
        defer { isLoading = false }

        do {
            // Save mnemonic securely (validation passed)
            try await secureStore.saveMnemonic(mnemonic)

            // Create wallet configuration
            let walletConfig = WalletConfiguration(
                mintURL: url.absoluteString,
                unit: "sat",
                retryAttempts: configuration.retryAttempts,
                retryDelay: 1.0,
                operationTimeout: configuration.httpTimeoutInterval
            )

            // Create new wallet with mnemonic
            let newWallet = try await CashuWallet(
                configuration: walletConfig,
                mnemonic: mnemonic,
                secureStore: secureStore,
                logger: logger
            )

            try await newWallet.initialize()

            // Restore proofs from seed - returns the count of restored proofs
            let restoredCount = try await newWallet.restoreFromSeed()

            self.wallet = newWallet
            // Fetch the proofs from the wallet
            let walletProofs = try await newWallet.proofs
            proofs = walletProofs
            updateBalance()

            logger.info("Restored wallet with \(restoredCount) proofs")
        } catch {
            lastError = error
            logger.error("Failed to restore wallet: \(error.localizedDescription)")
            throw error
        }
    }

    /// Generate new mnemonic
    public func generateMnemonic() async throws -> String {
        do {
            let mnemonic = try BIP39.generateMnemonic()
            try await secureStore.saveMnemonic(mnemonic)
            logger.info("Generated new mnemonic")
            return mnemonic
        } catch {
            lastError = error
            logger.error("Failed to generate mnemonic: \(error.localizedDescription)")
            throw error
        }
    }

    /// Get stored mnemonic
    public func getMnemonic() async throws -> String? {
        try await secureStore.loadMnemonic()
    }

    /// Clear all data
    public func clearAllData() async throws {
        isLoading = true
        defer { isLoading = false }

        do {
            try await secureStore.clearAll()
            try await wallet?.clearAll()
            proofs.removeAll()
            balance = 0
            pendingTransactions.removeAll()
            await disconnect()
            logger.info("Cleared all wallet data")
        } catch {
            lastError = error
            logger.error("Failed to clear data: \(error.localizedDescription)")
            throw error
        }
    }

    /// Refresh balance from wallet
    public func refreshBalance() async {
        guard let wallet = wallet else { return }

        do {
            let currentProofs = try await wallet.proofs
            proofs = currentProofs
            updateBalance()
        } catch {
            logger.error("Failed to refresh balance: \(error.localizedDescription)")
        }
    }

    /// Get mint info
    public var mintInfo: MintInfo? {
        get async {
            await wallet?.mintInfo
        }
    }

    /// Request a mint quote (Lightning invoice for receiving)
    /// - Parameter amount: Amount in sats to mint
    /// - Returns: MintQuoteResponse containing the Lightning invoice and quote ID
    public func requestMintQuote(amount: Int) async throws -> MintQuoteResponse {
        guard let wallet else {
            throw CashuError.walletNotInitialized
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let response = try await wallet.requestMintQuote(amount: amount)
            logger.info("Requested mint quote for \(amount) sats")
            return response
        } catch {
            lastError = error
            logger.error("Failed to request mint quote: \(error.localizedDescription)")
            throw error
        }
    }

    /// Check mint quote status
    /// - Parameter quoteID: The quote identifier to check
    /// - Returns: MintQuoteResponse with current state
    public func checkMintQuote(_ quoteID: String) async throws -> MintQuoteResponse {
        guard let wallet else {
            throw CashuError.walletNotInitialized
        }

        do {
            let response = try await wallet.checkMintQuote(quoteID)
            logger.info("Checked mint quote \(quoteID): state=\(response.state ?? "unknown")")
            return response
        } catch {
            lastError = error
            logger.error("Failed to check mint quote: \(error.localizedDescription)")
            throw error
        }
    }

    /// Get balance breakdown
    public func getBalanceBreakdown() async throws -> BalanceBreakdown {
        guard let wallet = wallet else {
            throw CashuError.walletNotInitialized
        }
        return try await wallet.getBalanceBreakdown()
    }

    /// Export token string for a given amount
    public func exportToken(amount: Int, memo: String? = nil) async throws -> String {
        guard let wallet = wallet else {
            throw CashuError.walletNotInitialized
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let tokenString = try await wallet.exportToken(
                amount: amount,
                memo: memo,
                version: TokenVersion.v3,
                includeURI: false
            )

            // Update local proofs
            let remainingProofs = try await wallet.proofs
            proofs = remainingProofs
            updateBalance()

            logger.info("Exported token for \(amount) sats")
            return tokenString
        } catch {
            lastError = error
            logger.error("Failed to export token: \(error.localizedDescription)")
            throw error
        }
    }

    // MARK: - Private Methods

    private func updateBalance() {
        balance = proofs.reduce(0) { $0 + $1.amount }
    }
}

// MARK: - Token Serialization Extensions

public extension AppleCashuWallet {

    /// Encode a CashuToken to V3 string format
    func encodeToken(_ token: CashuToken) throws -> String {
        try CashuTokenUtils.serializeTokenV3(token)
    }

    /// Decode a Cashu token string
    func decodeToken(_ tokenString: String) throws -> CashuToken {
        try CashuTokenUtils.deserializeToken(tokenString)
    }
}
