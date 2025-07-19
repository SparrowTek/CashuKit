//
//  NUT03.swift
//  CashuKit
//
//  NUT-03: Swap tokens
//  https://github.com/cashubtc/nuts/blob/main/03.md
//

import Foundation
@preconcurrency import P256K

// MARK: - NUT-03: Swap tokens

/// NUT-03: Swap tokens
/// This NUT defines the swap operation for splitting and combining tokens

// MARK: - Request/Response Structures

/// Request structure for POST /v1/swap
public struct PostSwapRequest: CashuCodabale {
    public let inputs: [Proof]
    public let outputs: [BlindedMessage]
    
    public init(inputs: [Proof], outputs: [BlindedMessage]) {
        self.inputs = inputs
        self.outputs = outputs
    }
    
    /// Validate the swap request structure
    public func validate() -> Bool {
        // Must have inputs and outputs
        guard !inputs.isEmpty, !outputs.isEmpty else { return false }
        
        // Basic validation for inputs
        for input in inputs {
            guard input.amount > 0,
                  !input.id.isEmpty,
                  !input.secret.isEmpty,
                  !input.C.isEmpty else {
                return false
            }
        }
        
        // Basic validation for outputs
        for output in outputs {
            guard output.amount > 0,
                  let outputId = output.id, !outputId.isEmpty,
                  !output.B_.isEmpty else {
                return false
            }
        }
        
        // If any input has a witness, validate it exists for corresponding outputs
        for input in inputs {
            if input.witness != nil {
                // Witness validation is handled by the mint
                continue
            }
        }
        
        return true
    }
    
    /// Get total input amount
    public var totalInputAmount: Int {
        return inputs.reduce(0) { $0 + $1.amount }
    }
    
    /// Get total output amount
    public var totalOutputAmount: Int {
        return outputs.reduce(0) { $0 + $1.amount }
    }
    
    /// Check if outputs are privacy-preserving (ordered by amount ascending)
    public var hasPrivacyPreservingOrder: Bool {
        let amounts = outputs.map { $0.amount }
        return amounts == amounts.sorted()
    }
}

/// Response structure for POST /v1/swap
public struct PostSwapResponse: CashuCodabale {
    public let signatures: [BlindSignature]
    
    public init(signatures: [BlindSignature]) {
        self.signatures = signatures
    }
    
    /// Validate the swap response structure
    public func validate() -> Bool {
        guard !signatures.isEmpty else { return false }
        
        for signature in signatures {
            guard signature.amount > 0,
                  !signature.id.isEmpty,
                  !signature.C_.isEmpty else {
                return false
            }
        }
        
        return true
    }
    
    /// Get total signature amount
    public var totalAmount: Int {
        return signatures.reduce(0) { $0 + $1.amount }
    }
}

// MARK: - Swap Operation Types

/// Type of swap operation
public enum SwapType: String, CaseIterable, Sendable {
    case send = "send"           // Swap to prepare tokens for sending
    case receive = "receive"     // Swap to receive and invalidate tokens
    case split = "split"         // Swap to split large denominations
    case combine = "combine"     // Swap to combine small denominations
    case rotate = "rotate"       // Swap from inactive to active keysets
}

/// Swap operation result
public struct SwapResult: Sendable {
    public let newProofs: [Proof]
    public let invalidatedProofs: [Proof]
    public let swapType: SwapType
    public let totalAmount: Int
    public let fees: Int
    
    public init(newProofs: [Proof], invalidatedProofs: [Proof], swapType: SwapType, totalAmount: Int, fees: Int) {
        self.newProofs = newProofs
        self.invalidatedProofs = invalidatedProofs
        self.swapType = swapType
        self.totalAmount = totalAmount
        self.fees = fees
    }
}

/// Swap preparation result
public struct SwapPreparation: Sendable {
    public let inputProofs: [Proof]
    public let blindedMessages: [BlindedMessage]
    public let blindingData: [WalletBlindingData]
    public let targetAmount: Int?
    public let changeAmount: Int
    public let fees: Int
    
    public init(inputProofs: [Proof], blindedMessages: [BlindedMessage], blindingData: [WalletBlindingData], targetAmount: Int?, changeAmount: Int, fees: Int) {
        self.inputProofs = inputProofs
        self.blindedMessages = blindedMessages
        self.blindingData = blindingData
        self.targetAmount = targetAmount
        self.changeAmount = changeAmount
        self.fees = fees
    }
}

// MARK: - Swap Service

@CashuActor
public struct SwapService: Sendable {
    private let router: NetworkRouter<SwapAPI>
    private let keyExchangeService: KeyExchangeService
    private let keysetManagementService: KeysetManagementService
    
    public init() async {
        self.router = NetworkRouter<SwapAPI>(decoder: .cashuDecoder)
        self.router.delegate = CashuEnvironment.current.routerDelegate
        self.keyExchangeService = await KeyExchangeService()
        self.keysetManagementService = await KeysetManagementService()
    }
    
    /// Execute a swap operation
    /// - parameters:
    ///   - request: The swap request with inputs and outputs
    ///   - mintURL: The base URL of the mint
    ///   - accessToken: Optional access token for NUT-22 authentication
    /// - returns: PostSwapResponse with blind signatures
    public func executeSwap(_ request: PostSwapRequest, at mintURL: String, accessToken: AccessToken? = nil) async throws -> PostSwapResponse {
        // Enhanced validation using NUTValidation
        let validation = NUTValidation.validateSwapRequest(request)
        guard validation.isValid else {
            throw CashuError.validationFailed
        }
        
        // Setup networking
        let normalizedURL = try ValidationUtils.normalizeMintURL(mintURL)
        CashuEnvironment.current.setup(baseURL: normalizedURL)
        
        // Execute swap - use NUT22 request if access token is provided
        if let accessToken = accessToken {
            let nut22Request = NUT22SwapRequest(
                inputs: request.inputs,
                outputs: request.outputs,
                accessToken: accessToken
            )
            return try await router.execute(.swapWithAccessToken(nut22Request))
        } else {
            return try await router.execute(.swap(request))
        }
    }
    
    /// Prepare a swap to send tokens (split for target amount)
    /// - parameters:
    ///   - availableProofs: Available proofs in wallet
    ///   - targetAmount: Amount to prepare for sending
    ///   - mintURL: The base URL of the mint
    /// - returns: SwapPreparation with prepared inputs and outputs
    public func prepareSwapToSend(
        availableProofs: [Proof],
        targetAmount: Int,
        at mintURL: String
    ) async throws -> SwapPreparation {
        // Get keyset information for fee calculation
        let keysetResponse = try await keysetManagementService.getKeysets(from: mintURL)
        let keysetDict = Dictionary(uniqueKeysWithValues: keysetResponse.keysets.map { ($0.id, $0) })
        
        // Select optimal proofs for the target amount
        let selectionResult = try await keysetManagementService.calculateOptimalProofSelection(
            availableProofs: availableProofs,
            targetAmount: targetAmount,
            from: mintURL
        )
        
        guard let selection = selectionResult.recommended else {
            throw CashuError.insufficientFunds
        }
        
        // Calculate fees
        let fees = FeeCalculator.calculateFees(for: selection.selectedProofs, keysetInfo: keysetDict)
        let totalInput = selection.totalAmount
        let totalOutput = totalInput - fees
        
        // Create target denominations (optimal split)
        let targetAmountOutputs = createOptimalDenominations(for: targetAmount)
        let changeAmount = totalOutput - targetAmount
        let changeOutputs = changeAmount > 0 ? createOptimalDenominations(for: changeAmount) : []
        
        // Combine and order outputs for privacy
        var allOutputAmounts = targetAmountOutputs + changeOutputs
        allOutputAmounts.sort() // Privacy-preserving ascending order
        
        // Get active keyset for outputs
        let activeKeysets = try await keysetManagementService.getActiveKeysets(from: mintURL)
        guard let activeKeyset = activeKeysets.first else {
            throw CashuError.keysetInactive
        }
        
        // Create blinded messages
        var blindedMessages: [BlindedMessage] = []
        var blindingData: [WalletBlindingData] = []
        
        for amount in allOutputAmounts {
            let secret = CashuKeyUtils.generateRandomSecret()
            let walletBlindingData = try WalletBlindingData(secret: secret)
            let blindedMessage = BlindedMessage(
                amount: amount,
                id: activeKeyset.id,
                B_: walletBlindingData.blindedMessage.dataRepresentation.hexString
            )
            
            blindedMessages.append(blindedMessage)
            blindingData.append(walletBlindingData)
        }
        
        return SwapPreparation(
            inputProofs: selection.selectedProofs,
            blindedMessages: blindedMessages,
            blindingData: blindingData,
            targetAmount: targetAmount,
            changeAmount: changeAmount,
            fees: fees
        )
    }
    
    /// Prepare a swap to receive tokens (invalidate received tokens)
    /// - parameters:
    ///   - receivedProofs: Proofs received from another user
    ///   - preferredDenominations: Preferred output denominations (optional)
    ///   - mintURL: The base URL of the mint
    /// - returns: SwapPreparation with prepared inputs and outputs
    public func prepareSwapToReceive(
        receivedProofs: [Proof],
        preferredDenominations: [Int]? = nil,
        at mintURL: String
    ) async throws -> SwapPreparation {
        // Get keyset information for fee calculation
        let keysetResponse = try await keysetManagementService.getKeysets(from: mintURL)
        let keysetDict = Dictionary(uniqueKeysWithValues: keysetResponse.keysets.map { ($0.id, $0) })
        
        // Calculate fees
        let fees = FeeCalculator.calculateFees(for: receivedProofs, keysetInfo: keysetDict)
        let totalInput = receivedProofs.reduce(0) { $0 + $1.amount }
        let totalOutput = totalInput - fees
        
        // Create output denominations
        let outputAmounts: [Int]
        if let preferred = preferredDenominations {
            outputAmounts = preferred.sorted() // Privacy-preserving order
        } else {
            outputAmounts = createOptimalDenominations(for: totalOutput)
        }
        
        // Get active keyset for outputs
        let activeKeysets = try await keysetManagementService.getActiveKeysets(from: mintURL)
        guard let activeKeyset = activeKeysets.first else {
            throw CashuError.keysetInactive
        }
        
        // Create blinded messages
        var blindedMessages: [BlindedMessage] = []
        var blindingData: [WalletBlindingData] = []
        
        for amount in outputAmounts {
            let secret = CashuKeyUtils.generateRandomSecret()
            let walletBlindingData = try WalletBlindingData(secret: secret)
            let blindedMessage = BlindedMessage(
                amount: amount,
                id: activeKeyset.id,
                B_: walletBlindingData.blindedMessage.dataRepresentation.hexString
            )
            
            blindedMessages.append(blindedMessage)
            blindingData.append(walletBlindingData)
        }
        
        return SwapPreparation(
            inputProofs: receivedProofs,
            blindedMessages: blindedMessages,
            blindingData: blindingData,
            targetAmount: nil,
            changeAmount: totalOutput,
            fees: fees
        )
    }
    
    /// Execute a complete swap operation (prepare + execute + unblind)
    /// - parameters:
    ///   - preparation: Prepared swap data
    ///   - mintURL: The base URL of the mint
    /// - returns: SwapResult with new proofs
    public func executeCompleteSwap(
        preparation: SwapPreparation,
        at mintURL: String
    ) async throws -> SwapResult {
        // Create swap request
        let request = PostSwapRequest(
            inputs: preparation.inputProofs,
            outputs: preparation.blindedMessages
        )
        
        // Execute swap
        let response = try await executeSwap(request, at: mintURL)
        
        // Validate response
        guard response.validate(),
              response.signatures.count == preparation.blindingData.count else {
            throw CashuError.invalidResponse
        }
        
        // Get mint public keys for unblinding
        let keyResponse = try await keyExchangeService.getKeys(from: mintURL)
        let mintKeys = Dictionary(uniqueKeysWithValues: keyResponse.keysets.flatMap { keyset in
            keyset.keys.compactMap { (amountStr, publicKeyHex) -> (String, P256K.KeyAgreement.PublicKey)? in
                guard let amount = Int(amountStr),
                      let publicKeyData = Data(hexString: publicKeyHex),
                      let publicKey = try? P256K.KeyAgreement.PublicKey(dataRepresentation: publicKeyData, format: .compressed) else {
                    return nil
                }
                return ("\(keyset.id)_\(amount)", publicKey)
            }
        })
        
        // Unblind signatures to create new proofs
        var newProofs: [Proof] = []
        
        for (index, signature) in response.signatures.enumerated() {
            let blindingData = preparation.blindingData[index]
            let mintKeyKey = "\(signature.id)_\(signature.amount)"
            
            guard let mintPublicKey = mintKeys[mintKeyKey] else {
                throw CashuError.invalidSignature("Mint public key not found for amount \(signature.amount)")
            }
            
            guard let blindedSignatureData = Data(hexString: signature.C_) else {
                throw CashuError.invalidHexString
            }
            
            let unblindedToken = try Wallet.unblindSignature(
                blindedSignature: blindedSignatureData,
                blindingData: blindingData,
                mintPublicKey: mintPublicKey
            )
            
            let proof = Proof(
                amount: signature.amount,
                id: signature.id,
                secret: unblindedToken.secret,
                C: unblindedToken.signature.hexString
            )
            
            newProofs.append(proof)
        }
        
        // Determine swap type
        let swapType: SwapType
        if preparation.targetAmount != nil {
            swapType = .send
        } else {
            swapType = .receive
        }
        
        return SwapResult(
            newProofs: newProofs,
            invalidatedProofs: preparation.inputProofs,
            swapType: swapType,
            totalAmount: preparation.changeAmount,
            fees: preparation.fees
        )
    }
    
    /// Rotate tokens from inactive keysets to active ones
    /// - parameters:
    ///   - proofs: Proofs to rotate
    ///   - mintURL: The base URL of the mint
    /// - returns: SwapResult with rotated proofs
    public func rotateTokens(proofs: [Proof], at mintURL: String) async throws -> SwapResult {
        // Check which keysets need rotation
        let inactiveKeysetIDs = try await keysetManagementService.getKeysetsNeedingRotation(for: proofs, from: mintURL)
        
        let proofsToRotate = proofs.filter { inactiveKeysetIDs.contains($0.id) }
        guard !proofsToRotate.isEmpty else {
            // No rotation needed
            return SwapResult(
                newProofs: proofs,
                invalidatedProofs: [],
                swapType: .rotate,
                totalAmount: proofs.reduce(0) { $0 + $1.amount },
                fees: 0
            )
        }
        
        // Prepare swap to rotate
        let preparation = try await prepareSwapToReceive(
            receivedProofs: proofsToRotate,
            at: mintURL
        )
        
        // Execute rotation
        let result = try await executeCompleteSwap(preparation: preparation, at: mintURL)
        
        // Combine rotated proofs with non-rotated ones
        let nonRotatedProofs = proofs.filter { !inactiveKeysetIDs.contains($0.id) }
        let allNewProofs = result.newProofs + nonRotatedProofs
        
        return SwapResult(
            newProofs: allNewProofs,
            invalidatedProofs: proofsToRotate,
            swapType: .rotate,
            totalAmount: result.totalAmount,
            fees: result.fees
        )
    }
    
    // MARK: - Utility Methods
    
    /// Create optimal denominations for an amount (powers of 2)
    private func createOptimalDenominations(for amount: Int) -> [Int] {
        var denominations: [Int] = []
        var remaining = amount
        var power = 0
        
        while remaining > 0 {
            let denomination = 1 << power // 2^power
            if remaining & denomination != 0 {
                denominations.append(denomination)
                remaining -= denomination
            }
            power += 1
        }
        
        return denominations.sorted() // Privacy-preserving order
    }
    
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
    
    // MARK: - Validation Methods
    
    /// Validate swap inputs and outputs balance
    public nonisolated func validateSwapBalance(
        _ request: PostSwapRequest,
        keysetInfo: [String: KeysetInfo]
    ) -> Bool {
        let totalInputs = request.totalInputAmount
        let totalOutputs = request.totalOutputAmount
        let fees = FeeCalculator.calculateFees(for: request.inputs, keysetInfo: keysetInfo)
        
        return totalInputs - fees == totalOutputs
    }
    
    /// Check if all inputs are from active keysets
    public func validateInputsAreFromActiveKeysets(
        inputs: [Proof],
        at mintURL: String
    ) async throws -> Bool {
        let activeKeysets = try await keysetManagementService.getActiveKeysets(from: mintURL)
        let activeKeysetIDs = Set(activeKeysets.map { $0.id })
        
        return inputs.allSatisfy { activeKeysetIDs.contains($0.id) }
    }
    
    /// Check if all outputs target active keysets
    public func validateOutputsTargetActiveKeysets(
        outputs: [BlindedMessage],
        at mintURL: String
    ) async throws -> Bool {
        let activeKeysets = try await keysetManagementService.getActiveKeysets(from: mintURL)
        let activeKeysetIDs = Set(activeKeysets.map { $0.id })
        
        return outputs.allSatisfy { output in
            guard let outputId = output.id else { return false }
            return activeKeysetIDs.contains(outputId)
        }
    }
}

// MARK: - API Endpoints

enum SwapAPI {
    case swap(PostSwapRequest)
    case swapWithAccessToken(NUT22SwapRequest)
}

extension SwapAPI: EndpointType {
    public var baseURL: URL {
        guard let baseURL = CashuEnvironment.current.baseURL,
              let url = URL(string: baseURL) else {
            fatalError("The baseURL for the mint must be set")
        }
        return url
    }
    
    var path: String {
        switch self {
        case .swap, .swapWithAccessToken:
            return "/v1/swap"
        }
    }
    
    var httpMethod: HTTPMethod {
        switch self {
        case .swap, .swapWithAccessToken:
            return .post
        }
    }
    
    var task: HTTPTask {
        switch self {
        case .swap(let request):
            return .requestParameters(encoding: .jsonEncodableEncoding(encodable: request))
        case .swapWithAccessToken(let request):
            return .requestParameters(encoding: .jsonEncodableEncoding(encodable: request))
        }
    }
    
    var headers: HTTPHeaders? {
        return [
            "Accept": "application/json",
            "Content-Type": "application/json"
        ]
    }
}

// MARK: - Convenience Extensions

/// Extension for easier swap operations
extension SwapService {
    /// Simple swap for sending specific amount
    public func swapToSend(
        from availableProofs: [Proof],
        amount: Int,
        at mintURL: String
    ) async throws -> SwapResult {
        let preparation = try await prepareSwapToSend(
            availableProofs: availableProofs,
            targetAmount: amount,
            at: mintURL
        )
        
        return try await executeCompleteSwap(preparation: preparation, at: mintURL)
    }
    
    /// Simple swap for receiving tokens
    public func swapToReceive(
        proofs: [Proof],
        at mintURL: String
    ) async throws -> SwapResult {
        let preparation = try await prepareSwapToReceive(
            receivedProofs: proofs,
            at: mintURL
        )
        
        return try await executeCompleteSwap(preparation: preparation, at: mintURL)
    }
}
