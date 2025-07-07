//
//  BlindedMessage.swift
//  CashuKit
//
//  Created by Thomas Rademaker on 6/20/25.
//

public struct BlindedMessage: CashuCodabale {
    public let amount: Int
    public let id: String
    public let B_: String
    
    public init(amount: Int, id: String, B_: String) {
        self.amount = amount
        self.id = id
        self.B_ = B_
    }
}
