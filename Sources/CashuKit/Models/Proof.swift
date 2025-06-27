//
//  Proof.swift
//  CashuKit
//
//  Created by Thomas Rademaker on 6/22/25.
//

public struct Proof: Codable, Sendable {
 public let amount: Int
 public let id: String
 public let secret: String
 public let C: String
}
