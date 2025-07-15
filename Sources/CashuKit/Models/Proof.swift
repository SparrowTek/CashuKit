//
//  Proof.swift
//  CashuKit
//
//  Created by Thomas Rademaker on 6/22/25.
//

import Foundation

public struct Proof: CashuCodabale {
    public let amount: Int
    public let id: String
    public let secret: String
    public let C: String
    public let witness: String?
    
    public init(amount: Int, id: String, secret: String, C: String, witness: String? = nil) {
        self.amount = amount
        self.id = id
        self.secret = secret
        self.C = C
        self.witness = witness
    }
    
    public func getWellKnownSecret() -> WellKnownSecret? {
        return try? WellKnownSecret.fromString(secret)
    }
    
    public func hasSpendingCondition() -> Bool {
        return getWellKnownSecret() != nil
    }
    
    public func getP2PKWitness() -> P2PKWitness? {
        guard let witnessString = witness else { return nil }
        return try? P2PKWitness.fromString(witnessString)
    }
    
    public func getP2PKSpendingCondition() -> P2PKSpendingCondition? {
        guard let wellKnownSecret = getWellKnownSecret(),
              wellKnownSecret.kind == SpendingConditionKind.p2pk else {
            return nil
        }
        return try? P2PKSpendingCondition.fromWellKnownSecret(wellKnownSecret)
    }
}
