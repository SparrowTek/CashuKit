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
    
    public init(amount: Int, id: String, secret: String, C: String) {
        self.amount = amount
        self.id = id
        self.secret = secret
        self.C = C
    }
    
    public func getWellKnownSecret() -> WellKnownSecret? {
        return try? WellKnownSecret.fromString(secret)
    }
    
    public func hasSpendingCondition() -> Bool {
        return getWellKnownSecret() != nil
    }
}
