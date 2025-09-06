//
//  MintCapabilities.swift
//  CoreCashu
//
//  Capability discovery and feature gating for Cashu mints
//

import Foundation

/// Represents a specific capability/feature of a mint
public struct MintFeatureCapability: Hashable, Sendable {
    /// The NUT identifier (e.g., "01", "07", "09")
    public let nutID: String
    
    /// Human-readable name of the capability
    public let name: String
    
    /// Description of what this capability enables
    public let description: String
    
    /// Whether this capability is required for basic wallet operations
    public let isRequired: Bool
    
    /// Version requirement for this capability
    public let minVersion: String?
    
    public init(
        nutID: String,
        name: String,
        description: String,
        isRequired: Bool = false,
        minVersion: String? = nil
    ) {
        self.nutID = nutID
        self.name = name
        self.description = description
        self.isRequired = isRequired
        self.minVersion = minVersion
    }
}

/// Standard mint capabilities
public extension MintFeatureCapability {
    // Core capabilities
    static let mintInfo = MintFeatureCapability(
        nutID: "06",
        name: "Mint Information",
        description: "Provides mint metadata and supported features",
        isRequired: true
    )
    
    static let keysets = MintFeatureCapability(
        nutID: "01",
        name: "Keysets",
        description: "Mint keyset management",
        isRequired: true
    )
    
    static let mintTokens = MintFeatureCapability(
        nutID: "04",
        name: "Mint Tokens",
        description: "Create new tokens",
        isRequired: true
    )
    
    static let meltTokens = MintFeatureCapability(
        nutID: "05",
        name: "Melt Tokens",
        description: "Redeem tokens for Lightning payment",
        isRequired: true
    )
    
    static let swap = MintFeatureCapability(
        nutID: "03",
        name: "Token Swap",
        description: "Split and combine tokens",
        isRequired: true
    )
    
    // Optional capabilities
    static let stateCheck = MintFeatureCapability(
        nutID: "07",
        name: "State Check",
        description: "Check if tokens are spent or unspent"
    )
    
    static let restore = MintFeatureCapability(
        nutID: "09",
        name: "Restore",
        description: "Recover signatures for backup restoration"
    )
    
    static let p2pk = MintFeatureCapability(
        nutID: "11",
        name: "Pay to Public Key",
        description: "Lock tokens to public keys"
    )
    
    static let dleq = MintFeatureCapability(
        nutID: "12",
        name: "DLEQ Proofs",
        description: "Discrete log equality proofs for enhanced privacy"
    )
    
    static let deterministicSecrets = MintFeatureCapability(
        nutID: "13",
        name: "Deterministic Secrets",
        description: "HD wallet support for backup and recovery"
    )
    
    static let htlc = MintFeatureCapability(
        nutID: "14",
        name: "HTLCs",
        description: "Hash Time Locked Contracts for atomic swaps"
    )
    
    static let mpp = MintFeatureCapability(
        nutID: "15",
        name: "Multi-Path Payments",
        description: "Split payments across multiple mints"
    )
    
    static let overpayOutputSelection = MintFeatureCapability(
        nutID: "16",
        name: "Overpaid Fees",
        description: "Return overpaid lightning fees"
    )
    
    static let websockets = MintFeatureCapability(
        nutID: "17",
        name: "WebSockets",
        description: "Real-time subscription to mint events"
    )
    
    static let paymentRequests = MintFeatureCapability(
        nutID: "18",
        name: "Payment Requests",
        description: "Standardized payment request format"
    )
    
    static let singleUse = MintFeatureCapability(
        nutID: "19",
        name: "Single-Use Secrets",
        description: "Enforce single-use semantics for secrets"
    )
    
    static let signatureMintQuotes = MintFeatureCapability(
        nutID: "20",
        name: "Signature Mint Quotes",
        description: "Signed mint quotes for accountability"
    )
    
    static let preMint = MintFeatureCapability(
        nutID: "21",
        name: "Pre-Mint",
        description: "Reserve tokens before payment completion"
    )
    
    static let accessTokenAuth = MintFeatureCapability(
        nutID: "22",
        name: "Access Token Authentication",
        description: "Bearer token authentication for mint access"
    )
    
    static let proofOfReserves = MintFeatureCapability(
        nutID: "23",
        name: "Proof of Reserves",
        description: "Cryptographic proof of mint reserves"
    )
    
    static let http402 = MintFeatureCapability(
        nutID: "24",
        name: "HTTP 402 Payment Required",
        description: "Pay for mint services using HTTP 402"
    )
}

/// Manages capability discovery and feature gating for a mint
public struct MintFeatureCapabilityManager: Sendable {
    private let mintInfo: MintInfo
    private let mintURL: URL
    
    public init(mintInfo: MintInfo, mintURL: URL) {
        self.mintInfo = mintInfo
        self.mintURL = mintURL
    }
    
    /// Check if a specific capability is supported
    public func isSupported(_ capability: MintFeatureCapability) -> Bool {
        return mintInfo.supportsNUT(capability.nutID)
    }
    
    /// Get all supported capabilities
    public func supportedCapabilities() -> Set<MintFeatureCapability> {
        var capabilities = Set<MintFeatureCapability>()
        
        // Check all known capabilities
        let allCapabilities: [MintFeatureCapability] = [
            .mintInfo, .keysets, .mintTokens, .meltTokens, .swap,
            .stateCheck, .restore, .p2pk, .dleq, .deterministicSecrets,
            .htlc, .mpp, .overpayOutputSelection, .websockets,
            .paymentRequests, .singleUse, .signatureMintQuotes,
            .preMint, .accessTokenAuth, .proofOfReserves, .http402
        ]
        
        for capability in allCapabilities {
            if isSupported(capability) {
                capabilities.insert(capability)
            }
        }
        
        return capabilities
    }
    
    /// Get missing required capabilities
    public func missingRequiredCapabilities() -> Set<MintFeatureCapability> {
        let required: Set<MintFeatureCapability> = [
            .mintInfo, .keysets, .mintTokens, .meltTokens, .swap
        ]
        
        return required.filter { !isSupported($0) }
    }
    
    /// Check if mint supports all required capabilities
    public func hasRequiredCapabilities() -> Bool {
        return missingRequiredCapabilities().isEmpty
    }
    
    /// Create a detailed error for unsupported operation
    public func unsupportedOperationError(
        capability: MintFeatureCapability,
        operation: String? = nil
    ) -> CashuError {
        let operationDesc = operation ?? capability.name
        
        // Build helpful guidance
        var guidance = "The mint at \(mintURL.absoluteString) does not support \(capability.name) (NUT-\(capability.nutID))."
        
        if capability.isRequired {
            guidance += " This is a required feature for basic wallet operations."
        } else {
            guidance += " This is an optional feature."
        }
        
        // Add alternatives if available
        if capability == .stateCheck {
            guidance += " Consider using manual proof tracking as an alternative."
        } else if capability == .restore {
            guidance += " Backup restoration will not be available with this mint."
        } else if capability == .mpp {
            guidance += " Multi-path payments are not available. Use single-mint payments instead."
        }
        
        return CashuError.capabilityNotSupported(
            mintURL: mintURL.absoluteString,
            capability: capability.nutID,
            operation: operationDesc,
            guidance: guidance
        )
    }
}

/// Extension to CashuError for capability-based errors
public extension CashuError {
    /// Create a detailed capability error
    static func capabilityNotSupported(
        mintURL: String,
        capability: String,
        operation: String,
        guidance: String
    ) -> CashuError {
        // Use a more descriptive error that includes all context
        let message = """
        Operation '\(operation)' requires NUT-\(capability) support.
        Mint: \(mintURL)
        \(guidance)
        """
        return .unsupportedOperation(message)
    }
}

/// Protocol for feature probing
public protocol FeatureProbe: Sendable {
    /// Check if a feature is available
    func isAvailable() async -> Bool
    
    /// Get the reason if a feature is not available
    func unavailableReason() async -> String?
    
    /// Attempt to use the feature with graceful degradation
    func executeWithFallback<T>(_ operation: () async throws -> T) async throws -> T?
}

/// Default implementation of feature probe
public struct DefaultFeatureProbe: FeatureProbe {
    private let capability: MintFeatureCapability
    private let capabilityManager: MintFeatureCapabilityManager
    
    public init(capability: MintFeatureCapability, capabilityManager: MintFeatureCapabilityManager) {
        self.capability = capability
        self.capabilityManager = capabilityManager
    }
    
    public func isAvailable() async -> Bool {
        return capabilityManager.isSupported(capability)
    }
    
    public func unavailableReason() async -> String? {
        guard !capabilityManager.isSupported(capability) else { return nil }
        return "NUT-\(capability.nutID) (\(capability.name)) is not supported by this mint"
    }
    
    public func executeWithFallback<T>(_ operation: () async throws -> T) async throws -> T? {
        guard await isAvailable() else {
            // Return nil to indicate the feature is not available
            // Caller can implement fallback logic
            return nil
        }
        
        return try await operation()
    }
}

/// Feature probe factory
public struct FeatureProbeFactory {
    private let capabilityManager: MintFeatureCapabilityManager
    
    public init(capabilityManager: MintFeatureCapabilityManager) {
        self.capabilityManager = capabilityManager
    }
    
    /// Create a probe for a specific capability
    public func probe(for capability: MintFeatureCapability) -> any FeatureProbe {
        return DefaultFeatureProbe(
            capability: capability,
            capabilityManager: capabilityManager
        )
    }
    
    /// Create probes for all capabilities
    public func allProbes() -> [MintFeatureCapability: any FeatureProbe] {
        let capabilities: [MintFeatureCapability] = [
            .stateCheck, .restore, .p2pk, .dleq, .deterministicSecrets,
            .htlc, .mpp, .overpayOutputSelection, .websockets,
            .paymentRequests, .singleUse, .signatureMintQuotes,
            .preMint, .accessTokenAuth, .proofOfReserves, .http402
        ]
        
        var probes: [MintFeatureCapability: any FeatureProbe] = [:]
        for capability in capabilities {
            probes[capability] = probe(for: capability)
        }
        
        return probes
    }
}