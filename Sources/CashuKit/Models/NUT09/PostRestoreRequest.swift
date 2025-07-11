//
//  PostRestoreRequest.swift
//  CashuKit
//
//  NUT-09: Restore signatures
//  https://github.com/cashubtc/nuts/blob/main/09.md
//

/// Request structure for restoring blind signatures (NUT-09)
public struct PostRestoreRequest: CashuCodabale {
    public let outputs: [BlindedMessage]
    
    public init(outputs: [BlindedMessage]) {
        self.outputs = outputs
    }
}