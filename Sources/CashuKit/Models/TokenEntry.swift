//
//  TokenEntry.swift
//  CashuKit
//
//  Created by Thomas Rademaker on 6/22/25.
//

public struct TokenEntry: CashuCodabale {
    public let mint: String
    public let proofs: [Proof]
    
    public init(mint: String, proofs: [Proof]) {
        self.mint = mint
        self.proofs = proofs
    }
}
