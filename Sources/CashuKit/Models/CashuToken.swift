//
//  CashuToken.swift
//  CashuKit
//
//  Created by Thomas Rademaker on 6/22/25.
//

public struct CashuToken: Codable, Sendable {
   public let token: [TokenEntry]
   public let unit: String?
   public let memo: String?
}
