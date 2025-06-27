import Testing
@testable import CashuKit

@Test func example() async throws {
    // Write your test here and use APIs like `#expect(...)` to check expected conditions.
}

@Test func testNUT01MintInformation() throws {
    // Test NUT-01: Mint Information functionality
    
    // Test URL validation
    #expect(NUT01_MintInformation.validateMintURL("https://mint.example.com"))
    #expect(NUT01_MintInformation.validateMintURL("http://localhost:3338"))
    #expect(!NUT01_MintInformation.validateMintURL(""))
    #expect(!NUT01_MintInformation.validateMintURL("not-a-url"))
    
    // Test mock mint info creation
    let keypair = try CashuKeyUtils.generateMintKeypair()
    let pubkey = keypair.publicKey.compressedRepresentation.hexString
    let mockInfo = NUT01_MintInformation.createMockMintInfo(pubkey: pubkey)
    
    // Validate the mock info
    #expect(NUT01_MintInformation.validateMintInfo(mockInfo))
    #expect(mockInfo.pubkey == pubkey)
    #expect(mockInfo.name == "Test Mint")
    #expect(mockInfo.version == "1.0.0")
    
    // Test NUT support checking
    #expect(mockInfo.supportsNUT("NUT-00"))
    #expect(mockInfo.supportsNUT("NUT-01"))
    #expect(mockInfo.supportsNUT("NUT-02"))
    #expect(!mockInfo.supportsNUT("NUT-99"))
    
    // Test basic operations support
    #expect(mockInfo.supportsBasicOperations())
    
    // Test supported NUTs list
    let supportedNUTs = mockInfo.getSupportedNUTs()
    #expect(supportedNUTs.contains("NUT-00"))
    #expect(supportedNUTs.contains("NUT-01"))
    #expect(supportedNUTs.contains("NUT-02"))
    #expect(supportedNUTs.contains("NUT-03"))
    
    // Test NUT version retrieval
    #expect(mockInfo.getNUTVersion("NUT-00") == "1.0")
    #expect(mockInfo.getNUTVersion("NUT-01") == "1.0")
    #expect(mockInfo.getNUTVersion("NUT-99") == nil)
    
    // Test mint compatibility
    let mockInfo2 = NUT01_MintInformation.createMockMintInfo(pubkey: pubkey)
    #expect(NUT01_MintInformation.areMintsCompatible(mockInfo, mockInfo2))
}

@Test func testNUT01HTTPClient() async throws {
    // Test HTTP client functionality with a mock server
    // Note: This test requires a running mint server or will fail gracefully
    
    // Test with an invalid URL (should fail gracefully)
    do {
        _ = try await NUT01_MintInformation.getMintInfo(from: "https://invalid-mint-url-that-does-not-exist.com")
        #expect(false, "Should have thrown an error for invalid URL")
    } catch {
        // Expected to fail
        #expect(error is CashuError)
    }
    
    // Test availability check with invalid URL
    let isAvailable = await NUT01_MintInformation.isMintAvailable("https://invalid-mint-url-that-does-not-exist.com")
    #expect(!isAvailable)
}
