//
//  NUT02.swift
//  CashuKit
//
//  NUT-02: Keysets and fees
//  https://github.com/cashubtc/nuts/blob/main/02.md
//

import Foundation
import P256K
import CryptoKit

/// NUT-02: Keysets and fees
/// This NUT defines the keyset and fee structure for Cashu mints

// MARK: - Wallet Implementation Helper Structures

/// Result of wallet synchronization with mint
public struct WalletSyncResult: Sendable {
    public var newKeysets: [String] = []
    public var newlyActiveKeysets: [String] = []
    public var newlyInactiveKeysets: [String] = []
    
    public init() {}
    
    /// Check if any changes were detected
    public var hasChanges: Bool {
        return !newKeysets.isEmpty || !newlyActiveKeysets.isEmpty || !newlyInactiveKeysets.isEmpty
    }
}

/// Proof selection option for transactions
public struct ProofSelectionOption: Sendable {
    public let selectedProofs: [Proof]
    public let totalAmount: Int
    public let totalFee: Int
    public let keysetID: String
    public let efficiency: Double // targetAmount / (totalAmount + totalFee)
    
    public init(selectedProofs: [Proof], totalAmount: Int, totalFee: Int, keysetID: String, efficiency: Double) {
        self.selectedProofs = selectedProofs
        self.totalAmount = totalAmount
        self.totalFee = totalFee
        self.keysetID = keysetID
        self.efficiency = efficiency
    }
    
    /// Amount available for change
    public var changeAmount: Int {
        return totalAmount - totalFee
    }
}

/// Result of proof selection calculation
public struct ProofSelectionResult: Sendable {
    public let recommended: ProofSelectionOption?
    public let alternatives: [ProofSelectionOption]
    
    public init(recommended: ProofSelectionOption?, alternatives: [ProofSelectionOption]) {
        self.recommended = recommended
        self.alternatives = alternatives
    }
}

/// Transaction validation result
public struct TransactionValidationResult: Sendable {
    public let isValid: Bool
    public let totalInputs: Int
    public let totalOutputs: Int
    public let totalFees: Int
    public let balance: Int // Should be 0 if valid
    public let feeBreakdown: [String: (count: Int, totalFeePpk: Int, totalFee: Int)]
    
    public init(isValid: Bool, totalInputs: Int, totalOutputs: Int, totalFees: Int, balance: Int, feeBreakdown: [String: (count: Int, totalFeePpk: Int, totalFee: Int)]) {
        self.isValid = isValid
        self.totalInputs = totalInputs
        self.totalOutputs = totalOutputs
        self.totalFees = totalFees
        self.balance = balance
        self.feeBreakdown = feeBreakdown
    }
}

// MARK: - Keyset ID Derivation

/// Keyset ID utilities
public struct KeysetID {
    /// Current keyset ID version
    public static let currentVersion = "00"
    
    /// Derive keyset ID from public keys
    /// Following NUT-02 specification:
    /// 1. Sort public keys by their amount in ascending order
    /// 2. Concatenate all public keys to one byte array
    /// 3. HASH_SHA256 the concatenated public keys
    /// 4. Take the first 14 characters of the hex-encoded hash
    /// 5. Prefix it with a keyset ID version byte
    public static func deriveKeysetID(from keys: [String: String]) -> String {
        // Sort keys by amount (ascending order)
        let sortedKeys = keys.sorted { lhs, rhs in
            let lhsAmount = Int(lhs.key) ?? 0
            let rhsAmount = Int(rhs.key) ?? 0
            return lhsAmount < rhsAmount
        }
        
        // Concatenate all public keys
        var concatenatedKeys = Data()
        for (_, publicKeyHex) in sortedKeys {
            if let keyData = Data(hexString: publicKeyHex) {
                concatenatedKeys.append(keyData)
            }
        }
        
        // Hash the concatenated keys
        let hash = SHA256.hash(data: concatenatedKeys)
        let hashHex = Data(hash).hexString
        
        // Take first 14 characters and prefix with version
        let keysetID = currentVersion + String(hashHex.prefix(14))
        
        return keysetID
    }
    
    /// Validate keyset ID format
    public static func validateKeysetID(_ id: String) -> Bool {
        // Must be 16 characters (2 for version + 14 for hash)
        guard id.count == 16 else { return false }
        
        // Must be valid hex
        guard id.isValidHex else { return false }
        
        // Must start with current version
        guard id.hasPrefix(currentVersion) else { return false }
        
        return true
    }
}

// MARK: - Fee Calculation

/// Fee calculation utilities following NUT-02 specification
public struct FeeCalculator {
    
    /// Calculate fees for a transaction with Proof inputs
    /// Following NUT-02 specification: fees = ceil(sum(input_fee_ppk) / 1000)
    /// - parameters:
    ///   - proofs: Array of Proof objects to calculate fees for
    ///   - keysetInfo: Dictionary mapping keyset ID to fee information
    /// - returns: Total fee rounded up to next integer
    public static func calculateFees(for proofs: [Proof], keysetInfo: [String: KeysetInfo]) -> Int {
        let totalFeePpk = proofs.reduce(0) { sum, proof in
            let feePpk = keysetInfo[proof.id]?.inputFeePpk ?? 0
            return sum + feePpk
        }
        return (totalFeePpk + 999) / 1000 // Integer division equivalent to ceil(totalFeePpk / 1000)
    }
    
    /// Calculate fees for a transaction using keyset fee lookup
    /// - parameters:
    ///   - proofs: Array of Proof objects
    ///   - feeProvider: Async function to get fee for a keyset ID
    /// - returns: Total fee rounded up to next integer
    public static func calculateFees(
        for proofs: [Proof], 
        feeProvider: (String) async throws -> Int
    ) async throws -> Int {
        var totalFeePpk = 0
        
        for proof in proofs {
            let feePpk = try await feeProvider(proof.id)
            totalFeePpk += feePpk
        }
        
        return (totalFeePpk + 999) / 1000
    }
    
    /// Calculate fees for specific keyset inputs
    /// - parameters:
    ///   - inputs: Array of tuples (keysetID, inputFeePpk)
    /// - returns: Total fee rounded up to next integer
    public static func calculateTotalFee(inputs: [(keysetID: String, inputFeePpk: Int)]) -> Int {
        let totalFeePpk = inputs.reduce(0) { sum, input in
            sum + input.inputFeePpk
        }
        return (totalFeePpk + 999) / 1000
    }
    
    /// Calculate individual fee for a single proof
    /// - parameters:
    ///   - proof: The proof to calculate fee for
    ///   - keysetInfo: Keyset information containing fee data
    /// - returns: Fee in ppk for this proof
    public static func calculateProofFeePpk(for proof: Proof, keysetInfo: KeysetInfo) -> Int {
        return keysetInfo.inputFeePpk ?? 0
    }
    
    /// Validate transaction equation: sum(inputs) - fees == sum(outputs)
    /// - parameters:
    ///   - inputProofs: Input proofs for the transaction
    ///   - outputAmounts: Array of output amounts
    ///   - keysetInfo: Dictionary mapping keyset ID to fee information
    /// - returns: True if equation balances, false otherwise
    public static func validateTransactionBalance(
        inputProofs: [Proof],
        outputAmounts: [Int],
        keysetInfo: [String: KeysetInfo]
    ) -> Bool {
        let totalInputs = inputProofs.reduce(0) { sum, proof in sum + proof.amount }
        let totalOutputs = outputAmounts.reduce(0, +)
        let totalFees = calculateFees(for: inputProofs, keysetInfo: keysetInfo)
        
        return totalInputs - totalFees == totalOutputs
    }
    
    /// Get fee breakdown by keyset for transparency
    /// - parameters:
    ///   - proofs: Input proofs
    ///   - keysetInfo: Dictionary mapping keyset ID to fee information
    /// - returns: Dictionary mapping keyset ID to total fee for that keyset
    public static func getFeeBreakdown(
        for proofs: [Proof],
        keysetInfo: [String: KeysetInfo]
    ) -> [String: (count: Int, totalFeePpk: Int, totalFee: Int)] {
        var breakdown: [String: (count: Int, totalFeePpk: Int)] = [:]
        
        for proof in proofs {
            let feePpk = keysetInfo[proof.id]?.inputFeePpk ?? 0
            if let existing = breakdown[proof.id] {
                breakdown[proof.id] = (existing.count + 1, existing.totalFeePpk + feePpk)
            } else {
                breakdown[proof.id] = (1, feePpk)
            }
        }
        
        return breakdown.mapValues { (count, totalFeePpk) in
            let totalFee = (totalFeePpk + 999) / 1000
            return (count: count, totalFeePpk: totalFeePpk, totalFee: totalFee)
        }
    }
}

// MARK: - Keyset Management Service (NUT-02 specific functionality)

@CashuActor
public struct KeysetManagementService: Sendable {
    private let router: NetworkRouter<KeysetAPI>
    
    public init() async {
        self.router = NetworkRouter<KeysetAPI>(decoder: .cashuDecoder)
        self.router.delegate = CashuEnvironment.current.routerDelegate
    }
    
    /// Get keyset information (without full keys) - NUT-02 specific endpoint
    /// - parameter mintURL: The base URL of the mint
    /// - returns: GetKeysetsResponse with keyset information
    public func getKeysets(from mintURL: String) async throws -> GetKeysetsResponse {
        let normalizedURL = try normalizeMintURL(mintURL)
        CashuEnvironment.current.setup(baseURL: normalizedURL)
        
        return try await router.execute(.getKeysets)
    }
    
    /// Get active keysets only
    /// - parameter mintURL: The base URL of the mint
    /// - returns: Array of active KeysetInfo
    public func getActiveKeysets(from mintURL: String) async throws -> [KeysetInfo] {
        let response = try await getKeysets(from: mintURL)
        return response.keysets.filter { $0.active }
    }
    
    /// Get inactive keysets only
    /// - parameter mintURL: The base URL of the mint
    /// - returns: Array of inactive KeysetInfo
    public func getInactiveKeysets(from mintURL: String) async throws -> [KeysetInfo] {
        let response = try await getKeysets(from: mintURL)
        return response.keysets.filter { !$0.active }
    }
    
    /// Check if a keyset is active
    /// - parameters:
    ///   - keysetID: The keyset ID to check
    ///   - mintURL: The base URL of the mint
    /// - returns: True if the keyset is active, false otherwise
    public func isKeysetActive(keysetID: String, at mintURL: String) async throws -> Bool {
        let response = try await getKeysets(from: mintURL)
        return response.keysets.first { $0.id == keysetID }?.active ?? false
    }
    
    /// Get keyset information by ID
    /// - parameters:
    ///   - keysetID: The keyset ID to find
    ///   - mintURL: The base URL of the mint
    /// - returns: KeysetInfo if found, nil otherwise
    public func getKeysetInfo(keysetID: String, from mintURL: String) async throws -> KeysetInfo? {
        let response = try await getKeysets(from: mintURL)
        return response.keysets.first { $0.id == keysetID }
    }
    
    /// Get fee information for a keyset
    /// - parameters:
    ///   - keysetID: The keyset ID
    ///   - mintURL: The base URL of the mint
    /// - returns: Fee in parts per thousand, or 0 if not specified
    public func getKeysetFee(keysetID: String, from mintURL: String) async throws -> Int {
        let response = try await getKeysets(from: mintURL)
        return response.keysets.first { $0.id == keysetID }?.inputFeePpk ?? 0
    }
    
    /// Get all keysets with specific fee structure
    /// - parameters:
    ///   - feePpk: Fee in parts per thousand
    ///   - mintURL: The base URL of the mint
    /// - returns: Array of keysets with the specified fee
    public func getKeysetsWithFee(_ feePpk: Int, from mintURL: String) async throws -> [KeysetInfo] {
        let response = try await getKeysets(from: mintURL)
        return response.keysets.filter { ($0.inputFeePpk ?? 0) == feePpk }
    }
    
    /// Check keyset rotation - detect if any keysets have changed status
    /// - parameters:
    ///   - previousKeysets: Previously known keysets
    ///   - mintURL: The base URL of the mint
    /// - returns: Tuple with (newly active, newly inactive, new keysets)
    public func detectKeysetRotation(
        previousKeysets: [KeysetInfo],
        at mintURL: String
    ) async throws -> (newlyActive: [KeysetInfo], newlyInactive: [KeysetInfo], newKeysets: [KeysetInfo]) {
        let currentResponse = try await getKeysets(from: mintURL)
        let currentKeysets = currentResponse.keysets
        
        let previousDict = Dictionary(uniqueKeysWithValues: previousKeysets.map { ($0.id, $0) })
        
        var newlyActive: [KeysetInfo] = []
        var newlyInactive: [KeysetInfo] = []
        var newKeysets: [KeysetInfo] = []
        
        // Check for status changes and new keysets
        for current in currentKeysets {
            if let previous = previousDict[current.id] {
                // Existing keyset - check for status change
                if previous.active != current.active {
                    if current.active {
                        newlyActive.append(current)
                    } else {
                        newlyInactive.append(current)
                    }
                }
            } else {
                // New keyset
                newKeysets.append(current)
            }
        }
        
        return (newlyActive, newlyInactive, newKeysets)
    }
    
    /// Wallet implementation helper: Check if we need to rotate ecash from inactive keysets
    /// - parameters:
    ///   - proofs: Current proofs in wallet
    ///   - mintURL: The base URL of the mint
    /// - returns: Array of keyset IDs that need rotation (are inactive)
    public func getKeysetsNeedingRotation(for proofs: [Proof], from mintURL: String) async throws -> [String] {
        let response = try await getKeysets(from: mintURL)
        let inactiveKeysetIDs = Set(response.keysets.filter { !$0.active }.map { $0.id })
        
        let proofKeysetIDs = Set(proofs.map { $0.id })
        return Array(proofKeysetIDs.intersection(inactiveKeysetIDs))
    }
    
    // MARK: - Wallet Implementation Guidance (NUT-02)
    
    /// Implement the recommended wallet flow from NUT-02 specification
    /// - parameter mintURL: The base URL of the mint
    /// - returns: WalletSyncResult with actions needed
    public func performWalletSync(
        storedKeysets: [String: KeysetInfo],
        from mintURL: String
    ) async throws -> WalletSyncResult {
        let currentResponse = try await getKeysets(from: mintURL)
        let currentKeysets = currentResponse.keysets
        
        var result = WalletSyncResult()
        
        // Check for new keysets
        for keyset in currentKeysets {
            if storedKeysets[keyset.id] == nil {
                result.newKeysets.append(keyset.id)
            } else if let stored = storedKeysets[keyset.id], stored.active != keyset.active {
                // Status changed
                if keyset.active {
                    result.newlyActiveKeysets.append(keyset.id)
                } else {
                    result.newlyInactiveKeysets.append(keyset.id)
                }
            }
        }
        
        return result
    }
    
    /// Check if wallet should prioritize swapping proofs from inactive keysets
    /// - parameters:
    ///   - proofs: Current wallet proofs
    ///   - mintURL: The base URL of the mint
    /// - returns: Proofs that should be prioritized for swapping
    public func getProofsPrioritizedForSwap(proofs: [Proof], from mintURL: String) async throws -> [Proof] {
        let inactiveKeysetIDs = try await getKeysetsNeedingRotation(for: proofs, from: mintURL)
        let inactiveSet = Set(inactiveKeysetIDs)
        
        return proofs.filter { inactiveSet.contains($0.id) }
    }
    
    /// Calculate optimal fee strategy for a transaction
    /// - parameters:
    ///   - availableProofs: Available proofs in wallet
    ///   - targetAmount: Target transaction amount
    ///   - mintURL: The base URL of the mint
    /// - returns: Recommended proof selection with fee information
    public func calculateOptimalProofSelection(
        availableProofs: [Proof],
        targetAmount: Int,
        from mintURL: String
    ) async throws -> ProofSelectionResult {
        let response = try await getKeysets(from: mintURL)
        let keysetDict = Dictionary(uniqueKeysWithValues: response.keysets.map { ($0.id, $0) })
        
        // Group proofs by keyset
        let proofsByKeyset = Dictionary(grouping: availableProofs) { $0.id }
        
        var selections: [ProofSelectionOption] = []
        
        // Try different combinations, prioritizing low-fee keysets
        for (keysetID, proofs) in proofsByKeyset {
            guard let keysetInfo = keysetDict[keysetID] else { continue }
            
            let sortedProofs = proofs.sorted { $0.amount > $1.amount } // Largest first for efficiency
            let option = selectProofsForAmount(sortedProofs, targetAmount: targetAmount, keysetInfo: keysetInfo)
            if option.totalAmount >= targetAmount {
                selections.append(option)
            }
        }
        
        // Sort by efficiency (lowest fees, fewest proofs)
        selections.sort { lhs, rhs in
            if lhs.totalFee != rhs.totalFee {
                return lhs.totalFee < rhs.totalFee
            }
            return lhs.selectedProofs.count < rhs.selectedProofs.count
        }
        
        return ProofSelectionResult(
            recommended: selections.first,
            alternatives: Array(selections.dropFirst())
        )
    }
    
    private func selectProofsForAmount(
        _ proofs: [Proof],
        targetAmount: Int,
        keysetInfo: KeysetInfo
    ) -> ProofSelectionOption {
        var selectedProofs: [Proof] = []
        var totalAmount = 0
        
        for proof in proofs {
            if totalAmount >= targetAmount { break }
            selectedProofs.append(proof)
            totalAmount += proof.amount
        }
        
        let totalFee = FeeCalculator.calculateFees(
            for: selectedProofs,
            keysetInfo: [keysetInfo.id: keysetInfo]
        )
        
        return ProofSelectionOption(
            selectedProofs: selectedProofs,
            totalAmount: totalAmount,
            totalFee: totalFee,
            keysetID: keysetInfo.id,
            efficiency: Double(targetAmount) / Double(totalAmount + totalFee)
        )
    }
    
    // MARK: - Validation Methods
    
    /// Validate keyset information
    public nonisolated func validateKeyset(_ keyset: Keyset) -> Bool {
        guard !keyset.id.isEmpty,
              !keyset.unit.isEmpty,
              !keyset.keys.isEmpty else {
            return false
        }
        
        guard KeysetID.validateKeysetID(keyset.id) else {
            return false
        }
        
        return keyset.validateKeys()
    }
    
    /// Validate keysets response
    public nonisolated func validateKeysetsResponse(_ response: GetKeysetsResponse) -> Bool {
        guard !response.keysets.isEmpty else { return false }
        
        for keysetInfo in response.keysets {
            guard !keysetInfo.id.isEmpty,
                  !keysetInfo.unit.isEmpty,
                  KeysetID.validateKeysetID(keysetInfo.id) else {
                return false
            }
        }
        
        return true
    }
    
    // MARK: - Utility Methods
    
    /// Normalize mint URL
    private nonisolated func normalizeMintURL(_ mintURL: String) throws -> String {
        var normalizedURL = mintURL.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if !normalizedURL.contains("://") {
            normalizedURL = "https://" + normalizedURL
        }
        
        if normalizedURL.hasSuffix("/") {
            normalizedURL = String(normalizedURL.dropLast())
        }
        
        guard let url = URL(string: normalizedURL),
              let scheme = url.scheme,
              ["http", "https"].contains(scheme.lowercased()),
              let host = url.host,
              !host.isEmpty else {
            throw CashuError.invalidMintURL
        }
        
        return normalizedURL
    }
}

// MARK: - API Endpoints (NUT-02 specific)

enum KeysetAPI {
    case getKeysets
}

extension KeysetAPI: EndpointType {
    public var baseURL: URL {
        guard let baseURL = CashuEnvironment.current.baseURL, 
              let url = URL(string: baseURL) else { 
            fatalError("The baseURL for the mint must be set") 
        }
        return url
    }
    
    var path: String {
        switch self {
        case .getKeysets:
            return "/v1/keysets"
        }
    }
    
    var httpMethod: HTTPMethod {
        switch self {
        case .getKeysets:
            return .get
        }
    }
    
    var task: HTTPTask {
        switch self {
        case .getKeysets:
            return .request
        }
    }
    
    var headers: HTTPHeaders? {
        return ["Accept": "application/json"]
    }
}
