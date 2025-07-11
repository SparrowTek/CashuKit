//
//  PostRestoreResponse.swift
//  CashuKit
//
//  NUT-09: Restore signatures
//  https://github.com/cashubtc/nuts/blob/main/09.md
//

/// Response structure for restoring blind signatures (NUT-09)
public struct PostRestoreResponse: CashuCodabale {
    public let outputs: [BlindedMessage]
    public let signatures: [BlindSignature]
    
    public init(outputs: [BlindedMessage], signatures: [BlindSignature]) {
        self.outputs = outputs
        self.signatures = signatures
    }
    
    /// Validate that outputs and signatures arrays have matching lengths
    public var isValid: Bool {
        return outputs.count == signatures.count
    }
    
    /// Get signature-output pairs for easier processing
    public var signaturePairs: [(output: BlindedMessage, signature: BlindSignature)] {
        return zip(outputs, signatures).map { ($0, $1) }
    }
}