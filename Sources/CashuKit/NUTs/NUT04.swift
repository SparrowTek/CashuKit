//
//  NUT04.swift
//  CashuKit
//
//  NUT-04: Mint tokens
//  https://github.com/cashubtc/nuts/blob/main/04.md
//

import Foundation
@preconcurrency import P256K

// MARK: - NUT-04: Mint tokens

/// NUT-04: Mint tokens
/// This NUT defines the minting process for all payment methods

// MARK: - Request/Response Structures

/// Generic request structure for POST /v1/mint/quote/{method}
public struct MintQuoteRequest: CashuCodabale {
    public let unit: String
    public let amount: Int?
    
    public init(unit: String, amount: Int? = nil) {
        self.unit = unit
        self.amount = amount
    }
    
    /// Validate the mint quote request
    public func validate() -> Bool {
        guard !unit.isEmpty else { return false }
        
        if let amount = amount {
            guard amount > 0 else { return false }
        }
        
        return true
    }
}

/// Generic response structure for POST /v1/mint/quote/{method}
public struct MintQuoteResponse: CashuCodabale {
    public let quote: String
    public let request: String
    public let unit: String
    public let paid: Bool?
    public let expiry: Int?
    public let state: String?
    
    public init(quote: String, request: String, unit: String, paid: Bool? = nil, expiry: Int? = nil, state: String? = nil) {
        self.quote = quote
        self.request = request
        self.unit = unit
        self.paid = paid
        self.expiry = expiry
        self.state = state
    }
    
    /// Validate the mint quote response
    public func validate() -> Bool {
        guard !quote.isEmpty,
              !request.isEmpty,
              !unit.isEmpty else {
            return false
        }
        
        return true
    }
    
    /// Check if quote is paid
    public var isPaid: Bool {
        return paid ?? false
    }
    
    /// Check if quote is expired
    public var isExpired: Bool {
        guard let expiry = expiry else { return false }
        return Int(Date().timeIntervalSince1970) > expiry
    }
    
    /// Check if quote is in valid state for minting
    public var canMint: Bool {
        return isPaid && !isExpired && state != "EXPIRED"
    }
}

/// Request structure for POST /v1/mint/{method}
public struct MintRequest: CashuCodabale {
    public let quote: String
    public let outputs: [BlindedMessage]
    
    public init(quote: String, outputs: [BlindedMessage]) {
        self.quote = quote
        self.outputs = outputs
    }
    
    /// Validate the mint request
    public func validate() -> Bool {
        guard !quote.isEmpty,
              !outputs.isEmpty else {
            return false
        }
        
        for output in outputs {
            guard output.amount > 0,
                  !output.id.isEmpty,
                  !output.B_.isEmpty else {
                return false
            }
        }
        
        return true
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

/// Response structure for POST /v1/mint/{method}
public struct MintResponse: CashuCodabale {
    public let signatures: [BlindSignature]
    
    public init(signatures: [BlindSignature]) {
        self.signatures = signatures
    }
    
    /// Validate the mint response
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

// MARK: - Mint Method Settings

/// Settings for a specific mint method-unit pair
public struct MintMethodSetting: CashuCodabale {
    public let method: String
    public let unit: String
    public let minAmount: Int?
    public let maxAmount: Int?
    public let options: [String: String]?
    
    public init(method: String, unit: String, minAmount: Int? = nil, maxAmount: Int? = nil, options: [String: String]? = nil) {
        self.method = method
        self.unit = unit
        self.minAmount = minAmount
        self.maxAmount = maxAmount
        self.options = options
    }
    
    private enum CodingKeys: String, CodingKey {
        case method
        case unit
        case minAmount = "min_amount"
        case maxAmount = "max_amount"
        case options
    }
    
    /// Validate amount against method settings
    public func validateAmount(_ amount: Int) -> Bool {
        if let min = minAmount, amount < min {
            return false
        }
        
        if let max = maxAmount, amount > max {
            return false
        }
        
        return true
    }
    
    /// Check if method-unit pair is supported
    public func isSupported(method: String, unit: String) -> Bool {
        return self.method == method && self.unit == unit
    }
}

/// NUT-04 settings structure
public struct NUT04Settings: CashuCodabale {
    public let methods: [MintMethodSetting]
    public let disabled: Bool
    
    public init(methods: [MintMethodSetting], disabled: Bool = false) {
        self.methods = methods
        self.disabled = disabled
    }
    
    /// Get settings for specific method-unit pair
    public func getMethodSetting(method: String, unit: String) -> MintMethodSetting? {
        return methods.first { $0.isSupported(method: method, unit: unit) }
    }
    
    /// Check if method-unit pair is supported
    public func isSupported(method: String, unit: String) -> Bool {
        return !disabled && getMethodSetting(method: method, unit: unit) != nil
    }
    
    /// Get all supported methods
    public var supportedMethods: [String] {
        return Array(Set(methods.map { $0.method }))
    }
    
    /// Get all supported units
    public var supportedUnits: [String] {
        return Array(Set(methods.map { $0.unit }))
    }
}

// MARK: - Mint Operation Types

/// Type of mint operation
public enum MintOperationType: String, CaseIterable, Sendable {
    case mint = "mint"
    case quote = "quote"
    case check = "check"
}

/// Mint operation result
public struct MintResult: Sendable {
    public let newProofs: [Proof]
    public let quote: String
    public let totalAmount: Int
    public let method: String
    public let unit: String
    
    public init(newProofs: [Proof], quote: String, totalAmount: Int, method: String, unit: String) {
        self.newProofs = newProofs
        self.quote = quote
        self.totalAmount = totalAmount
        self.method = method
        self.unit = unit
    }
}

/// Mint preparation result
public struct MintPreparation: Sendable {
    public let quote: String
    public let blindedMessages: [BlindedMessage]
    public let blindingData: [WalletBlindingData]
    public let totalAmount: Int
    public let method: String
    public let unit: String
    
    public init(quote: String, blindedMessages: [BlindedMessage], blindingData: [WalletBlindingData], totalAmount: Int, method: String, unit: String) {
        self.quote = quote
        self.blindedMessages = blindedMessages
        self.blindingData = blindingData
        self.totalAmount = totalAmount
        self.method = method
        self.unit = unit
    }
}

// MARK: - Mint Service

@CashuActor
public struct MintService: Sendable {
    private let router: NetworkRouter<MintAPI>
    
    public init() async {
        self.router = NetworkRouter<MintAPI>(decoder: .cashuDecoder)
        self.router.delegate = CashuEnvironment.current.routerDelegate
    }
    
    /// Request a mint quote
    /// - parameters:
    ///   - request: The mint quote request
    ///   - method: The payment method (e.g., "bolt11")
    ///   - mintURL: The base URL of the mint
    /// - returns: MintQuoteResponse with quote information
    public func requestMintQuote(_ request: MintQuoteRequest, method: String, at mintURL: String) async throws -> MintQuoteResponse {
        guard request.validate() else {
            throw CashuError.validationFailed
        }
        
        let normalizedURL = try normalizeMintURL(mintURL)
        CashuEnvironment.current.setup(baseURL: normalizedURL)
        
        return try await router.execute(.mintQuote(method: method, request: request))
    }
    
    /// Check mint quote state
    /// - parameters:
    ///   - quoteID: The quote ID to check
    ///   - method: The payment method
    ///   - mintURL: The base URL of the mint
    /// - returns: MintQuoteResponse with current state
    public func checkMintQuote(_ quoteID: String, method: String, at mintURL: String) async throws -> MintQuoteResponse {
        let normalizedURL = try normalizeMintURL(mintURL)
        CashuEnvironment.current.setup(baseURL: normalizedURL)
        
        return try await router.execute(.checkMintQuote(method: method, quoteID: quoteID))
    }
    
    /// Execute mint operation
    /// - parameters:
    ///   - request: The mint request with quote and outputs
    ///   - method: The payment method
    ///   - mintURL: The base URL of the mint
    /// - returns: MintResponse with blind signatures
    public func executeMint(_ request: MintRequest, method: String, at mintURL: String) async throws -> MintResponse {
        guard request.validate() else {
            throw CashuError.validationFailed
        }
        
        let normalizedURL = try normalizeMintURL(mintURL)
        CashuEnvironment.current.setup(baseURL: normalizedURL)
        
        return try await router.execute(.mint(method: method, request: request))
    }
    
    /// Prepare mint operation (create blinded messages)
    /// - parameters:
    ///   - quote: The quote ID
    ///   - amount: The amount to mint
    ///   - method: The payment method
    ///   - unit: The currency unit
    ///   - mintURL: The base URL of the mint
    /// - returns: MintPreparation with prepared data
    public func prepareMint(
        quote: String,
        amount: Int,
        method: String,
        unit: String,
        at mintURL: String
    ) async throws -> MintPreparation {
        let outputAmounts = createOptimalDenominations(for: amount)
        
        let keyExchangeService = await KeyExchangeService()
        let activeKeysets = try await keyExchangeService.getActiveKeysets(from: mintURL)
        guard let activeKeyset = activeKeysets.first(where: { $0.unit == unit }) else {
            throw CashuError.nutNotImplemented("No active keyset found for unit: \(unit)")
        }
        
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
        
        return MintPreparation(
            quote: quote,
            blindedMessages: blindedMessages,
            blindingData: blindingData,
            totalAmount: amount,
            method: method,
            unit: unit
        )
    }
    
    /// Execute complete mint operation (prepare + execute + unblind)
    /// - parameters:
    ///   - preparation: Prepared mint data
    ///   - method: The payment method
    ///   - mintURL: The base URL of the mint
    /// - returns: MintResult with new proofs
    public func executeCompleteMint(
        preparation: MintPreparation,
        method: String,
        at mintURL: String
    ) async throws -> MintResult {
        let request = MintRequest(
            quote: preparation.quote,
            outputs: preparation.blindedMessages
        )
        
        let response = try await executeMint(request, method: method, at: mintURL)
        
        guard response.validate(),
              response.signatures.count == preparation.blindingData.count else {
            throw CashuError.invalidResponse
        }
        
        let keyExchangeService = await KeyExchangeService()
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
        
        var newProofs: [Proof] = []
        
        for (index, signature) in response.signatures.enumerated() {
            let blindingData = preparation.blindingData[index]
            let mintKeyKey = "\(signature.id)_\(signature.amount)"
            
            guard let mintPublicKey = mintKeys[mintKeyKey] else {
                throw CashuError.invalidSignature
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
        
        return MintResult(
            newProofs: newProofs,
            quote: preparation.quote,
            totalAmount: preparation.totalAmount,
            method: method,
            unit: preparation.unit
        )
    }
    
    /// Complete mint flow: quote -> pay -> mint
    /// - parameters:
    ///   - amount: Amount to mint
    ///   - method: Payment method
    ///   - unit: Currency unit
    ///   - mintURL: The base URL of the mint
    /// - returns: Tuple with (quote response, mint result)
    public func completeMintFlow(
        amount: Int,
        method: String,
        unit: String,
        at mintURL: String
    ) async throws -> (quote: MintQuoteResponse, result: MintResult) {
        let quoteRequest = MintQuoteRequest(unit: unit, amount: amount)
        let quoteResponse = try await requestMintQuote(quoteRequest, method: method, at: mintURL)
        
        let preparation = try await prepareMint(
            quote: quoteResponse.quote,
            amount: amount,
            method: method,
            unit: unit,
            at: mintURL
        )
        
        let result = try await executeCompleteMint(preparation: preparation, method: method, at: mintURL)
        
        return (quoteResponse, result)
    }
    
    // MARK: - Utility Methods
    
    /// Create optimal denominations for an amount (powers of 2)
    private nonisolated func createOptimalDenominations(for amount: Int) -> [Int] {
        var denominations: [Int] = []
        var remaining = amount
        var power = 0
        
        while remaining > 0 {
            let denomination = 1 << power
            if remaining & denomination != 0 {
                denominations.append(denomination)
                remaining -= denomination
            }
            power += 1
        }
        
        return denominations.sorted()
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
    
    /// Validate mint quote state
    public nonisolated func validateMintQuote(_ quote: MintQuoteResponse) -> Bool {
        return quote.validate() && quote.canMint
    }
    
    /// Validate mint request against quote
    public nonisolated func validateMintRequest(_ request: MintRequest, against quote: MintQuoteResponse) -> Bool {
        return request.validate() && request.quote == quote.quote
    }
    
    /// Check if method-unit pair is supported
    public func isMethodSupported(_ method: String, unit: String, at mintURL: String) async throws -> Bool {
        let mintInfoService = await MintInfoService()
        let mintInfo = try await mintInfoService.getMintInfo(from: mintURL)
        
        return mintInfo.supportsMinting(method: method, unit: unit)
    }
}

// MARK: - API Endpoints

enum MintAPI {
    case mintQuote(method: String, request: MintQuoteRequest)
    case checkMintQuote(method: String, quoteID: String)
    case mint(method: String, request: MintRequest)
}

extension MintAPI: EndpointType {
    public var baseURL: URL {
        guard let baseURL = CashuEnvironment.current.baseURL,
              let url = URL(string: baseURL) else {
            fatalError("The baseURL for the mint must be set")
        }
        return url
    }
    
    var path: String {
        switch self {
        case .mintQuote(let method, _):
            return "/v1/mint/quote/\(method)"
        case .checkMintQuote(let method, let quoteID):
            return "/v1/mint/quote/\(method)/\(quoteID)"
        case .mint(let method, _):
            return "/v1/mint/\(method)"
        }
    }
    
    var httpMethod: HTTPMethod {
        switch self {
        case .mintQuote, .mint:
            return .post
        case .checkMintQuote:
            return .get
        }
    }
    
    var task: HTTPTask {
        switch self {
        case .mintQuote(_, let request):
            return .requestParameters(encoding: .jsonEncodableEncoding(encodable: request))
        case .checkMintQuote:
            return .request
        case .mint(_, let request):
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

/// Extension for easier mint operations
extension MintService {
    /// Simple mint operation with default settings
    public func mint(
        amount: Int,
        method: String = "bolt11",
        unit: String = "sat",
        at mintURL: String
    ) async throws -> MintResult {
        let (_, result) = try await completeMintFlow(
            amount: amount,
            method: method,
            unit: unit,
            at: mintURL
        )
        return result
    }
    
    /// Get mint quote for specific amount
    public func getMintQuote(
        amount: Int,
        method: String = "bolt11",
        unit: String = "sat",
        at mintURL: String
    ) async throws -> MintQuoteResponse {
        let request = MintQuoteRequest(unit: unit, amount: amount)
        return try await requestMintQuote(request, method: method, at: mintURL)
    }
    
    /// Check if quote is ready for minting
    public func isQuoteReady(
        _ quoteID: String,
        method: String = "bolt11",
        at mintURL: String
    ) async throws -> Bool {
        let quote = try await checkMintQuote(quoteID, method: method, at: mintURL)
        return quote.canMint
    }
}
