//
//  BlindSignature.swift
//  CashuKit
//
//  Created by Thomas Rademaker on 6/22/25.
//

public struct BlindSignature: CashuCodabale {
    public let amount: Int
    public let id: String
    public let C_: String
    public let dleq: DLEQProof?
    
    public init(amount: Int, id: String, C_: String, dleq: DLEQProof? = nil) {
        self.amount = amount
        self.id = id
        self.C_ = C_
        self.dleq = dleq
    }
}
