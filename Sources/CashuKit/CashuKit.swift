//
//  CashuKit.swift
//  CashuKit
//

@CashuActor
public struct CashuKit {
    public static func setup(baseURL: String) {
        CashuEnvironment.current.setup(baseURL: baseURL)
    }
}

/*
/// Quick start examples for common Cashu operations
public struct CashuExamples {
    
    /// Example: Generate a random secret
    public static func generateSecret() -> String {
        return CashuKeyUtils.generateRandomSecret()
    }
    
    /// Example: Create a mint keypair
    public static func createMintKeypair() throws -> MintKeypair {
        return try CashuKeyUtils.generateMintKeypair()
    }
    
    /// Example: Execute the complete BDHKE protocol
    public static func runBDHKEProtocol(secret: String? = nil) throws -> (token: UnblindedToken, isValid: Bool) {
        let testSecret = secret ?? CashuKeyUtils.generateRandomSecret()
        return try CashuBDHKEProtocol.executeProtocol(secret: testSecret)
    }
    
    /// Example: Create a CashuToken from an unblinded token
    public static func createToken(
        from unblindedToken: UnblindedToken,
        mintURL: String,
        amount: Int,
        unit: String? = nil,
        memo: String? = nil
    ) -> CashuToken {
        return CashuTokenUtils.createToken(
            from: unblindedToken,
            mintURL: mintURL,
            amount: amount,
            unit: unit,
            memo: memo
        )
    }
    
    /// Example: Serialize a token to JSON
    public static func serializeToken(_ token: CashuToken) throws -> String {
        return try CashuTokenUtils.serializeToken(token)
    }
    
    /// Example: Deserialize a token from JSON
    public static func deserializeToken(_ jsonString: String) throws -> CashuToken {
        return try CashuTokenUtils.deserializeToken(jsonString)
    }
    
    /// Example: Get mint information
    public static func getMintInfo(from mintURL: String) async throws -> MintInfo {
        let mintService = await MintService()
        return try await mintService.getMintInfo(from: mintURL)
    }
    
    /// Example: Check if mint is available
    public static func isMintAvailable(_ mintURL: String) async -> Bool {
        let mintService = await MintService()
        return await mintService.isMintAvailable(mintURL)
    }
    
    /// Example: Create mock mint info for testing
    public static func createMockMintInfo() async throws -> MintInfo {
        let keypair = try CashuKeyUtils.generateMintKeypair()
        let pubkey = keypair.publicKey.dataRepresentation.hexString
        let mintService = await MintService()
        return mintService.createMockMintInfo(pubkey: pubkey)
    }
}
*/
