import Testing
@testable import CashuKit

@Test
func tokenUtils() throws {
    // Create a test token
    let secret = CashuKeyUtils.generateRandomSecret()
    let (unblindedToken, _) = try CashuBDHKEProtocol.executeProtocol(secret: secret)
    
    let token = CashuTokenUtils.createToken(
        from: unblindedToken,
        mintURL: "https://example.com/mint",
        amount: 1000,
        unit: "sat",
        memo: "Test token"
    )
    
    // Test serialization
    let jsonString = try CashuTokenUtils.serializeToken(token)
    let deserializedToken = try CashuTokenUtils.deserializeToken(jsonString)
    
    // Test validation
    let isValid = CashuTokenUtils.validateToken(deserializedToken)
    #expect(isValid)
}

@Test
func keyUtils() throws {
    // Test secret generation
    let secret = CashuKeyUtils.generateRandomSecret()
    let isValidSecret = try CashuKeyUtils.validateSecret(secret)
    #expect(isValidSecret)
    
    // Test keypair generation
    let keypair = try CashuKeyUtils.generateMintKeypair()
    let privateKeyHex = CashuKeyUtils.privateKeyToHex(keypair.privateKey)
    let restoredKeypair = try CashuKeyUtils.privateKeyFromHex(privateKeyHex)
    
    #expect(keypair.privateKey.rawRepresentation == restoredKeypair.rawRepresentation)
}
