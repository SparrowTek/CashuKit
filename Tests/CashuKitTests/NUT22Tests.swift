import Testing
import Foundation
@testable import CashuKit

// Mock NetworkService for testing
private actor MockNetworkService: NetworkService {
    var mockResponses: [String: Any] = [:]
    
    func setMockResponse<T: CashuCodabale>(for path: String, response: T) {
        mockResponses[path] = response
    }
    
    func execute<T: CashuCodabale>(method: String, path: String, payload: Data?) async throws -> T {
        guard let response = mockResponses[path] as? T else {
            throw CashuError.networkError("Mock response not found for \(path)")
        }
        return response
    }
}

@Suite("NUT-22 Token Metadata Tests")
struct NUT22Tests {
    
    // MARK: - AccessToken Tests
    
    @Test("AccessToken initialization")
    func testAccessTokenInitialization() {
        let token = AccessToken(access: "test_access_token")
        #expect(token.access == "test_access_token")
    }
    
    @Test("AccessToken encoding and decoding")
    func testAccessTokenCodable() throws {
        let token = AccessToken(access: "test_token_123")
        
        // Encode
        let encoded = try JSONEncoder().encode(token)
        
        // Decode
        let decoded = try JSONDecoder().decode(AccessToken.self, from: encoded)
        
        #expect(decoded.access == token.access)
    }
    
    // MARK: - Request/Response Tests
    
    @Test("PostAccessTokenRequest initialization")
    func testPostAccessTokenRequestInitialization() {
        let blindedMessages = [
            BlindedMessage(amount: 1, id: "keyset1", B_: "blind1"),
            BlindedMessage(amount: 1, id: "keyset1", B_: "blind2")
        ]
        
        let request = PostAccessTokenRequest(
            quoteId: "quote123",
            blindedMessages: blindedMessages
        )
        
        #expect(request.quoteId == "quote123")
        #expect(request.blindedMessages.count == 2)
        #expect(request.blindedMessages[0].B_ == "blind1")
    }
    
    @Test("PostAccessTokenResponse initialization")
    func testPostAccessTokenResponseInitialization() {
        let signatures = [
            BlindSignature(amount: 1, id: "keyset1", C_: "sig1"),
            BlindSignature(amount: 1, id: "keyset1", C_: "sig2")
        ]
        
        let response = PostAccessTokenResponse(signatures: signatures)
        
        #expect(response.signatures.count == 2)
        #expect(response.signatures[0].C_ == "sig1")
    }
    
    @Test("NUT22SwapRequest with access token")
    func testNUT22SwapRequestWithAccessToken() throws {
        let inputs = [
            Proof(amount: 4, id: "keyset1", secret: "secret1", C: "C1")
        ]
        let outputs = [
            BlindedMessage(amount: 2, id: "keyset1", B_: "blind1"),
            BlindedMessage(amount: 2, id: "keyset1", B_: "blind2")
        ]
        let accessToken = AccessToken(access: "access_secret")
        
        let request = NUT22SwapRequest(
            inputs: inputs,
            outputs: outputs,
            accessToken: accessToken
        )
        
        #expect(request.inputs.count == 1)
        #expect(request.outputs.count == 2)
        #expect(request.accessToken?.access == "access_secret")
        
        // Test encoding
        let encoded = try JSONEncoder().encode(request)
        let json = try JSONSerialization.jsonObject(with: encoded) as? [String: Any]
        
        #expect(json?["access_token"] != nil)
        let accessTokenDict = json?["access_token"] as? [String: String]
        #expect(accessTokenDict?["access"] == "access_secret")
    }
    
    @Test("NUT22SwapRequest without access token")
    func testNUT22SwapRequestWithoutAccessToken() throws {
        let inputs = [
            Proof(amount: 4, id: "keyset1", secret: "secret1", C: "C1")
        ]
        let outputs = [
            BlindedMessage(amount: 4, id: "keyset1", B_: "blind1")
        ]
        
        let request = NUT22SwapRequest(
            inputs: inputs,
            outputs: outputs,
            accessToken: nil
        )
        
        #expect(request.accessToken == nil)
        
        // Test encoding - access_token should not be present
        let encoded = try JSONEncoder().encode(request)
        let json = try JSONSerialization.jsonObject(with: encoded) as? [String: Any]
        
        #expect(json?["access_token"] == nil)
    }
    
    // MARK: - NUT22Settings Tests
    
    @Test("NUT22Settings mandatory mode")
    func testNUT22SettingsMandatory() {
        let settings = NUT22Settings(mandatory: true, endpoints: nil)
        
        #expect(settings.mandatory == true)
        #expect(settings.endpoints == nil)
        
        // All endpoints require access token when mandatory
        #expect(settings.requiresAccessToken(for: "/v1/swap") == true)
        #expect(settings.requiresAccessToken(for: "/v1/melt") == true)
        #expect(settings.requiresAccessToken(for: "/any/endpoint") == true)
    }
    
    @Test("NUT22Settings selective endpoints")
    func testNUT22SettingsSelectiveEndpoints() {
        let settings = NUT22Settings(
            mandatory: false,
            endpoints: ["/v1/swap", "/v1/melt"]
        )
        
        #expect(settings.mandatory == false)
        #expect(settings.endpoints?.count == 2)
        
        // Only specified endpoints require access token
        #expect(settings.requiresAccessToken(for: "/v1/swap") == true)
        #expect(settings.requiresAccessToken(for: "/v1/melt") == true)
        #expect(settings.requiresAccessToken(for: "/v1/mint") == false)
        #expect(settings.requiresAccessToken(for: "/v1/info") == false)
    }
    
    @Test("NUT22Settings no restrictions")
    func testNUT22SettingsNoRestrictions() {
        let settings = NUT22Settings(mandatory: false, endpoints: nil)
        
        #expect(settings.mandatory == false)
        #expect(settings.endpoints == nil)
        
        // No endpoints require access token
        #expect(settings.requiresAccessToken(for: "/v1/swap") == false)
        #expect(settings.requiresAccessToken(for: "/any/endpoint") == false)
    }
    
    // MARK: - AccessTokenService Tests
    
    @Test("AccessTokenService initialization")
    func testAccessTokenServiceInitialization() async {
        let networkService = MockNetworkService()
        let keyExchangeService = await KeyExchangeService()
        let service = AccessTokenService(networkService: networkService, keyExchangeService: keyExchangeService)
        
        // Should have no tokens initially
        #expect(await service.hasAccessTokens(for: "https://mint.example.com") == false)
    }
    
    @Test("AccessTokenService token management")
    func testAccessTokenServiceTokenManagement() async {
        let networkService = MockNetworkService()
        let keyExchangeService = await KeyExchangeService()
        let service = AccessTokenService(networkService: networkService, keyExchangeService: keyExchangeService)
        
        let mintURL = "https://mint.example.com"
        let _ = Proof(amount: 1, id: "keyset1", secret: "secret1", C: "C1")
        let _ = Proof(amount: 1, id: "keyset1", secret: "secret2", C: "C2")
        
        // Initially no tokens
        #expect(await service.hasAccessTokens(for: mintURL) == false)
        #expect(await service.getAccessToken(for: mintURL) == nil)
        
        // Store tokens (simulating what requestAccessTokens would do)
        // Note: In real implementation, this would be done internally by requestAccessTokens
        // For testing, we'd need to expose a method or use the actual request flow
        
        // Clear tokens
        await service.clearAccessTokens(for: mintURL)
        #expect(await service.hasAccessTokens(for: mintURL) == false)
    }
    
    // MARK: - MintInfo Extension Tests
    
    @Test("MintInfo NUT-22 support detection")
    func testMintInfoNUT22Support() {
        // Mint with NUT-22 support
        let mintWithNUT22 = MintInfo(
            name: "Test Mint",
            pubkey: "pubkey",
            version: "1.0",
            description: "Test",
            descriptionLong: nil,
            contact: [],
            nuts: ["22": NutValue.dictionary(["mandatory": AnyCodable(false)])],
            motd: nil
        )
        
        #expect(mintWithNUT22.supportsNUT22 == true)
        
        // Mint without NUT-22 support
        let mintWithoutNUT22 = MintInfo(
            name: "Test Mint",
            pubkey: "pubkey",
            version: "1.0",
            description: "Test",
            descriptionLong: nil,
            contact: [],
            nuts: [:],
            motd: nil
        )
        
        #expect(mintWithoutNUT22.supportsNUT22 == false)
    }
    
    @Test("MintInfo getNUT22Settings")
    func testMintInfoGetNUT22Settings() {
        // Mandatory mode
        let mandatoryMint = MintInfo(
            name: "Test Mint",
            pubkey: "pubkey",
            version: "1.0",
            description: "Test",
            descriptionLong: nil,
            contact: [],
            nuts: ["22": NutValue.dictionary(["mandatory": AnyCodable(true)])],
            motd: nil
        )
        
        let mandatorySettings = mandatoryMint.getNUT22Settings()
        #expect(mandatorySettings?.mandatory == true)
        #expect(mandatorySettings?.endpoints == nil)
        
        // Selective endpoints mode
        let selectiveMint = MintInfo(
            name: "Test Mint",
            pubkey: "pubkey",
            version: "1.0",
            description: "Test",
            descriptionLong: nil,
            contact: [],
            nuts: ["22": NutValue.dictionary([
                "mandatory": AnyCodable(false),
                "endpoints": AnyCodable(anyValue: ["/v1/swap", "/v1/melt"]) ?? AnyCodable.array([])
            ])],
            motd: nil
        )
        
        let selectiveSettings = selectiveMint.getNUT22Settings()
        #expect(selectiveSettings?.mandatory == false)
        #expect(selectiveSettings?.endpoints?.count == 2)
        #expect(selectiveSettings?.endpoints?.contains("/v1/swap") == true)
        
        // No NUT-22
        let noNUT22Mint = MintInfo(
            name: "Test Mint",
            pubkey: "pubkey",
            version: "1.0",
            description: "Test",
            descriptionLong: nil,
            contact: [],
            nuts: [:],
            motd: nil
        )
        
        #expect(noNUT22Mint.getNUT22Settings() == nil)
    }
    
    // MARK: - Error Tests
    
    @Test("CashuError access token errors")
    func testCashuErrorAccessToken() {
        let requiredError = CashuError.accessTokenRequired
        #expect(requiredError.errorDescription?.contains("Access token required") == true)
        
        let failedError = CashuError.accessTokenFailed("invalid token")
        #expect(failedError.errorDescription?.contains("Access token failed") == true)
        #expect(failedError.errorDescription?.contains("invalid token") == true)
    }
    
    // MARK: - Integration Tests
    
    @Test("PostAccessTokenRequest encoding")
    func testPostAccessTokenRequestEncoding() throws {
        let blindedMessages = [
            BlindedMessage(amount: 1, id: "keyset1", B_: "blind1"),
            BlindedMessage(amount: 1, id: "keyset1", B_: "blind2")
        ]
        
        let request = PostAccessTokenRequest(
            quoteId: "quote123",
            blindedMessages: blindedMessages
        )
        
        let encoded = try JSONEncoder().encode(request)
        let json = try JSONSerialization.jsonObject(with: encoded) as? [String: Any]
        
        #expect(json?["quote_id"] as? String == "quote123")
        #expect((json?["blinded_messages"] as? [[String: Any]])?.count == 2)
    }
    
    @Test("Data hex string extension")
    func testDataHexString() {
        let data = Data([0x01, 0x23, 0x45, 0x67, 0x89, 0xAB, 0xCD, 0xEF])
        #expect(data.hexString == "0123456789abcdef")
        
        let emptyData = Data()
        #expect(emptyData.hexString == "")
        
        let singleByte = Data([0xFF])
        #expect(singleByte.hexString == "ff")
    }
}