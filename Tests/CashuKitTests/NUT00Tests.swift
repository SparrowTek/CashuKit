//
//  NUT00Tests.swift
//  CashuKit
//
//  Created by Thomas Rademaker on 7/5/25.
//

import Testing
@testable import CashuKit

@Test func example() async throws {
    // Write your test here and use APIs like `#expect(...)` to check expected conditions.
}

@Test
func blindDiffieHellmanKeyExchange() async throws {
    let secret = CashuKeyUtils.generateRandomSecret()
    let (token, isValid) = try CashuBDHKEProtocol.executeProtocol(secret: secret)
    #expect(isValid)
    
    // Verify token has expected properties
    #expect(!token.secret.isEmpty)
    #expect(!token.signature.isEmpty)
}
