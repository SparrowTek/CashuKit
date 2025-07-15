//
//  BlindedMessage.swift
//  CashuKit
//
//  Created by Thomas Rademaker on 6/20/25.
//

import Foundation

public struct BlindedMessage: CashuCodabale {
    public let amount: Int
    public let id: String?
    public let B_: String
    public let witness: String?
    
    public init(amount: Int, id: String? = nil, B_: String, witness: String? = nil) {
        self.amount = amount
        self.id = id
        self.B_ = B_
        self.witness = witness
    }
    
    public func getP2PKWitness() -> P2PKWitness? {
        guard let witnessString = witness else { return nil }
        return try? P2PKWitness.fromString(witnessString)
    }
}
