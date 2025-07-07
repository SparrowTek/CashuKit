//
//  CashuToken.swift
//  CashuKit
//
//  Created by Thomas Rademaker on 6/22/25.
//

public struct CashuToken: CashuCodabale {
    public let token: [TokenEntry]
    public let unit: String?
    public let memo: String?
    
    public init(token: [TokenEntry], unit: String? = nil, memo: String? = nil) {
        self.token = token
        self.unit = unit
        self.memo = memo
    }
}
