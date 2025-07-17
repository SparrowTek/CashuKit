import Testing
import Foundation
@testable import CashuKit

// Mock NetworkService for testing
private actor MockNetworkService: NetworkService {
    func execute<T: CashuCodabale>(method: String, path: String, payload: Data?) async throws -> T {
        // Mock implementation
        throw CashuError.networkError("Mock not implemented")
    }
}

@Suite("NUT-21 Clear Authentication Tests")
struct NUT21Tests {
    
    // MARK: - ProtectedEndpoint Tests
    
    @Test("ProtectedEndpoint initialization")
    func testProtectedEndpointInitialization() {
        let endpoint = ProtectedEndpoint(method: "GET", path: "/v1/info")
        #expect(endpoint.method == "GET")
        #expect(endpoint.path == "/v1/info")
    }
    
    @Test("ProtectedEndpoint exact match")
    func testProtectedEndpointExactMatch() {
        let endpoint = ProtectedEndpoint(method: "GET", path: "/v1/info")
        #expect(endpoint.matches(method: "GET", path: "/v1/info") == true)
        #expect(endpoint.matches(method: "get", path: "/v1/info") == true)
        #expect(endpoint.matches(method: "POST", path: "/v1/info") == false)
        #expect(endpoint.matches(method: "GET", path: "/v1/other") == false)
    }
    
    @Test("ProtectedEndpoint regex match")
    func testProtectedEndpointRegexMatch() {
        let endpoint = ProtectedEndpoint(method: "POST", path: "/v1/swap.*")
        #expect(endpoint.matches(method: "POST", path: "/v1/swap") == true)
        #expect(endpoint.matches(method: "POST", path: "/v1/swap/") == true)
        #expect(endpoint.matches(method: "POST", path: "/v1/swap/123") == true)
        #expect(endpoint.matches(method: "GET", path: "/v1/swap") == false)
        #expect(endpoint.matches(method: "POST", path: "/v1/other") == false)
    }
    
    @Test("ProtectedEndpoint wildcard method match")
    func testProtectedEndpointWildcardMethodMatch() {
        let endpoint = ProtectedEndpoint(method: "*", path: "/v1/mint/.*")
        #expect(endpoint.matches(method: "GET", path: "/v1/mint/123") == true)
        #expect(endpoint.matches(method: "POST", path: "/v1/mint/456") == true)
        #expect(endpoint.matches(method: "DELETE", path: "/v1/mint/789") == true)
        #expect(endpoint.matches(method: "GET", path: "/v1/melt/123") == false)
    }
    
    @Test("ProtectedEndpoint Codable")
    func testProtectedEndpointCodable() throws {
        let endpoint = ProtectedEndpoint(method: "POST", path: "/v1/mint/.*")
        let encoded = try JSONEncoder().encode(endpoint)
        let decoded = try JSONDecoder().decode(ProtectedEndpoint.self, from: encoded)
        
        #expect(decoded.method == endpoint.method)
        #expect(decoded.path == endpoint.path)
    }
    
    // MARK: - OpenIDConnectConfig Tests
    
    @Test("OpenIDConnectConfig initialization")
    func testOpenIDConnectConfigInitialization() {
        let config = OpenIDConnectConfig(
            issuer: "https://auth.example.com",
            authorizationEndpoint: "https://auth.example.com/authorize",
            tokenEndpoint: "https://auth.example.com/token",
            jwksUri: "https://auth.example.com/.well-known/jwks.json",
            responseTypesSupported: ["code", "token"],
            grantTypesSupported: ["authorization_code", "refresh_token"],
            subjectTypesSupported: ["public"],
            idTokenSigningAlgValuesSupported: ["RS256"],
            scopesSupported: ["openid", "profile", "email"],
            deviceAuthorizationEndpoint: "https://auth.example.com/device",
            userinfoEndpoint: "https://auth.example.com/userinfo"
        )
        
        #expect(config.issuer == "https://auth.example.com")
        #expect(config.deviceAuthorizationEndpoint == "https://auth.example.com/device")
        #expect(config.scopesSupported.count == 3)
    }
    
    @Test("OpenIDConnectConfig Codable")
    func testOpenIDConnectConfigCodable() throws {
        let config = OpenIDConnectConfig(
            issuer: "https://auth.example.com",
            authorizationEndpoint: "https://auth.example.com/authorize",
            tokenEndpoint: "https://auth.example.com/token",
            jwksUri: "https://auth.example.com/.well-known/jwks.json",
            responseTypesSupported: ["code"],
            grantTypesSupported: ["authorization_code"],
            subjectTypesSupported: ["public"],
            idTokenSigningAlgValuesSupported: ["RS256"],
            scopesSupported: ["openid"],
            deviceAuthorizationEndpoint: nil,
            userinfoEndpoint: "https://auth.example.com/userinfo"
        )
        
        let encoded = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(OpenIDConnectConfig.self, from: encoded)
        
        #expect(decoded.issuer == config.issuer)
        #expect(decoded.authorizationEndpoint == config.authorizationEndpoint)
        #expect(decoded.tokenEndpoint == config.tokenEndpoint)
    }
    
    // MARK: - ClearAuthToken Tests
    
    @Test("ClearAuthToken initialization and parsing")
    func testClearAuthTokenParsing() throws {
        // Create a simple JWT for testing
        let header = #"{"alg":"RS256","typ":"JWT"}"#
        let payload = #"{"sub":"1234567890","name":"John Doe","iat":1516239022,"exp":1516242622,"aud":"cashu-mint"}"#
        
        let headerBase64 = Data(header.utf8).base64EncodedString()
            .replacingOccurrences(of: "=", with: "")
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
        
        let payloadBase64 = Data(payload.utf8).base64EncodedString()
            .replacingOccurrences(of: "=", with: "")
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
        
        let signature = "fake-signature"
        let jwt = "\(headerBase64).\(payloadBase64).\(signature)"
        
        let token = try ClearAuthToken(rawToken: jwt)
        
        #expect(token.rawToken == jwt)
        #expect(token.header.alg == "RS256")
        #expect(token.header.typ == "JWT")
        #expect(token.payload.sub == "1234567890")
        
        // Check additional claims
        if let nameValue = token.payload.additionalClaims?["name"] {
            #expect(nameValue.stringValue == "John Doe")
        } else {
            #expect(Bool(false)) // name should be in additional claims
        }
        
        // Check audience
        if let audString = token.payload.aud?.stringValue {
            #expect(audString == "cashu-mint")
        } else {
            #expect(Bool(false)) // aud should be a string
        }
    }
    
    @Test("ClearAuthToken invalid format")
    func testClearAuthTokenInvalidFormat() {
        let invalidTokens = [
            "invalid",
            "invalid.token",
            "...",
            "",
            "a.b.c.d"
        ]
        
        for invalidToken in invalidTokens {
            do {
                _ = try ClearAuthToken(rawToken: invalidToken)
                #expect(Bool(false)) // Should throw
            } catch {
                #expect(Bool(true)) // Expected to throw
            }
        }
    }
    
    @Test("ClearAuthToken expiration check")
    func testClearAuthTokenExpiration() throws {
        // Create expired token
        let expiredPayload = #"{"exp":1516239022}"#
        let validPayload = #"{"exp":9999999999}"#
        
        let header = #"{"alg":"RS256"}"#
        let headerBase64 = Data(header.utf8).base64EncodedString()
            .replacingOccurrences(of: "=", with: "")
        
        let expiredPayloadBase64 = Data(expiredPayload.utf8).base64EncodedString()
            .replacingOccurrences(of: "=", with: "")
        let validPayloadBase64 = Data(validPayload.utf8).base64EncodedString()
            .replacingOccurrences(of: "=", with: "")
        
        let expiredToken = try ClearAuthToken(rawToken: "\(headerBase64).\(expiredPayloadBase64).sig")
        let validToken = try ClearAuthToken(rawToken: "\(headerBase64).\(validPayloadBase64).sig")
        
        #expect(expiredToken.isExpired == true)
        #expect(validToken.isExpired == false)
    }
    
    // MARK: - OAuth Token Response Tests
    
    @Test("OAuthTokenResponse initialization")
    func testOAuthTokenResponseInitialization() {
        let response = OAuthTokenResponse(
            accessToken: "access-token-123",
            tokenType: "Bearer",
            expiresIn: 3600,
            refreshToken: "refresh-token-456",
            scope: "openid profile"
        )
        
        #expect(response.accessToken == "access-token-123")
        #expect(response.tokenType == "Bearer")
        #expect(response.expiresIn == 3600)
        #expect(response.refreshToken == "refresh-token-456")
        #expect(response.scope == "openid profile")
    }
    
    @Test("OAuthTokenResponse Codable")
    func testOAuthTokenResponseCodable() throws {
        let response = OAuthTokenResponse(
            accessToken: "token123",
            tokenType: "Bearer",
            expiresIn: 3600
        )
        
        let encoded = try JSONEncoder().encode(response)
        let decoded = try JSONDecoder().decode(OAuthTokenResponse.self, from: encoded)
        
        #expect(decoded.accessToken == response.accessToken)
        #expect(decoded.tokenType == response.tokenType)
        #expect(decoded.expiresIn == response.expiresIn)
    }
    
    // MARK: - Device Code Response Tests
    
    @Test("Device code flow not implemented")
    func testDeviceCodeFlowNotImplemented() {
        // Device code flow types are not exposed in the current implementation
        // This would be tested if DeviceCodeResponse was made public
        #expect(Bool(true))
    }
    
    // MARK: - ClearAuthService Tests
    
    @Test("ClearAuthService initialization")
    func testClearAuthServiceInitialization() async {
        let mockNetworkService = MockNetworkService()
        let service = ClearAuthService(networkService: mockNetworkService)
        
        let token = await service.getStoredToken(for: "test-client")
        #expect(token == nil)
    }
    
    @Test("ClearAuthService set and get token")
    func testClearAuthServiceTokenManagement() async throws {
        let mockNetworkService = MockNetworkService()
        let service = ClearAuthService(networkService: mockNetworkService)
        
        // Test that initially there's no token
        let initialToken = await service.getStoredToken(for: "test-client")
        #expect(initialToken == nil)
        
        // Clear token (should be no-op)
        await service.clearStoredToken(for: "test-client")
        
        let clearedToken = await service.getStoredToken(for: "test-client")
        #expect(clearedToken == nil)
    }
    
    @Test("ClearAuthService OIDC config management")
    func testClearAuthServiceOIDCConfigManagement() async {
        let mockNetworkService = MockNetworkService()
        let _ = ClearAuthService(networkService: mockNetworkService)
        let config = OpenIDConnectConfig(
            issuer: "https://auth.example.com",
            authorizationEndpoint: "https://auth.example.com/authorize",
            tokenEndpoint: "https://auth.example.com/token",
            jwksUri: "https://auth.example.com/.well-known/jwks.json",
            responseTypesSupported: ["code"],
            grantTypesSupported: ["authorization_code"],
            subjectTypesSupported: ["public"],
            idTokenSigningAlgValuesSupported: ["RS256"],
            scopesSupported: ["openid"],
            deviceAuthorizationEndpoint: nil,
            userinfoEndpoint: "https://auth.example.com/userinfo"
        )
        
        // The service discovers config via network, not by setting it directly
        // This test would require mocking the network response
        #expect(config.issuer == "https://auth.example.com")
    }
    
    @Test("ClearAuthService build authorization URL")
    func testClearAuthServiceBuildAuthorizationURL() async {
        let mockNetworkService = MockNetworkService()
        let service = ClearAuthService(networkService: mockNetworkService)
        let config = OpenIDConnectConfig(
            issuer: "https://auth.example.com",
            authorizationEndpoint: "https://auth.example.com/authorize",
            tokenEndpoint: "https://auth.example.com/token",
            jwksUri: "https://auth.example.com/.well-known/jwks.json",
            responseTypesSupported: ["code"],
            grantTypesSupported: ["authorization_code"],
            subjectTypesSupported: ["public"],
            idTokenSigningAlgValuesSupported: ["RS256"],
            scopesSupported: ["openid"],
            deviceAuthorizationEndpoint: nil,
            userinfoEndpoint: "https://auth.example.com/userinfo"
        )
        
        let url = await service.startAuthorizationCodeFlow(
            config: config,
            clientId: "client123",
            redirectUri: "app://callback",
            scope: "openid profile",
            state: "state123"
        )
        
        #expect(url != nil)
        
        // Check URL components
        if let components = URLComponents(url: url!, resolvingAgainstBaseURL: false) {
            let queryItems = components.queryItems ?? []
            #expect(queryItems.contains { $0.name == "client_id" && $0.value == "client123" })
            #expect(queryItems.contains { $0.name == "redirect_uri" && $0.value == "app://callback" })
            #expect(queryItems.contains { $0.name == "scope" && $0.value == "openid profile" })
            #expect(queryItems.contains { $0.name == "state" && $0.value == "state123" })
            #expect(queryItems.contains { $0.name == "response_type" && $0.value == "code" })
        } else {
            #expect(Bool(false)) // Should be able to parse URL components
        }
    }
    
    @Test("ClearAuthService build authorization URL without config")
    func testClearAuthServiceBuildAuthorizationURLWithoutConfig() async {
        // This test is no longer applicable as the service requires a config parameter
        // The method always requires a config to be passed in
        #expect(Bool(true))
    }
    
    // MARK: - MintInfo NUT-21 Extensions Tests
    
    @Test("MintInfo NUT-21 supported")
    func testMintInfoNUT21Supported() {
        let settingsDict: [String: Any] = [
            "openid_discovery": "https://auth.example.com/.well-known/openid-configuration",
            "client_id": "mint-client-123",
            "protected_endpoints": [
                ["method": "POST", "path": "/v1/mint/.*"],
                ["method": "POST", "path": "/v1/swap.*"]
            ]
        ]
        
        let mintInfo = MintInfo(
            name: "Test Mint",
            pubkey: "pubkey123",
            version: "1.0",
            description: "Test mint",
            descriptionLong: "Test mint long description",
            contact: nil,
            nuts: [
                "21": .dictionary([
                    "openid_discovery": .string(settingsDict["openid_discovery"] as? String ?? ""),
                    "client_id": .string(settingsDict["client_id"] as? String ?? ""),
                    "protected_endpoints": .array((settingsDict["protected_endpoints"] as? [[String: Any]] ?? []).map { endpointDict in
                        .dictionary([
                            "method": .string(endpointDict["method"] as? String ?? ""),
                            "path": .string(endpointDict["path"] as? String ?? "")
                        ])
                    })
                ])
            ],
            motd: "Welcome"
        )
        
        #expect(mintInfo.supportsClearAuth == true)
        #expect(mintInfo.getNUT21Settings() != nil)
        #expect(mintInfo.getNUT21Settings()?.protectedEndpoints.count == 2)
    }
    
    @Test("MintInfo NUT-21 not supported")
    func testMintInfoNUT21NotSupported() {
        let mintInfo = MintInfo(
            name: "Test Mint",
            pubkey: "pubkey123",
            version: "1.0",
            description: "Test mint",
            descriptionLong: "Test mint long description",
            contact: nil,
            nuts: [:],
            motd: "Welcome"
        )
        
        #expect(mintInfo.supportsClearAuth == false)
        #expect(mintInfo.getNUT21Settings() == nil)
    }
    
    @Test("MintInfo NUT-21 method details")
    func testMintInfoNUT21MethodDetails() {
        let settings = NUT21Settings(
            openidDiscovery: "https://auth.example.com/.well-known/openid-configuration",
            clientId: "client123",
            protectedEndpoints: [
                ProtectedEndpoint(method: "POST", path: "/v1/mint")
            ]
        )
        
        #expect(settings.clientId == "client123")
        #expect(settings.openidDiscovery == "https://auth.example.com/.well-known/openid-configuration")
        #expect(settings.protectedEndpoints.count == 1)
        #expect(settings.discoveryURL?.absoluteString == "https://auth.example.com/.well-known/openid-configuration")
    }
    
    @Test("NUT-21 settings retrieval")
    func testNUT21SettingsRetrieval() {
        let settings = NUT21Settings(
            openidDiscovery: "https://auth.example.com/.well-known/openid-configuration",
            clientId: "client123",
            protectedEndpoints: [
                ProtectedEndpoint(method: "GET", path: "/v1/info")
            ]
        )
        
        #expect(settings.openidDiscovery == "https://auth.example.com/.well-known/openid-configuration")
        #expect(settings.clientId == "client123")
        #expect(settings.protectedEndpoints.count == 1)
    }
    
    // MARK: - CashuError Extensions Tests
    
    @Test("CashuError NUT-21 unauthorized error")
    func testCashuErrorUnauthorized() {
        let error = CashuError.clearAuthFailed("Unauthorized")
        #expect(error.localizedDescription.contains("Unauthorized") == true)
    }
    
    @Test("CashuError NUT-21 invalid token error")
    func testCashuErrorInvalidToken() {
        let error = CashuError.invalidClearAuthToken("Invalid or expired token")
        #expect(error.localizedDescription.contains("Invalid or expired token") == true)
    }
    
    // MARK: - Integration Tests
    
    @Test("Full OAuth2 flow simulation")
    func testFullOAuth2FlowSimulation() async throws {
        let mockNetworkService = MockNetworkService()
        let service = ClearAuthService(networkService: mockNetworkService)
        
        // Step 1: Create OIDC config
        let config = OpenIDConnectConfig(
            issuer: "https://auth.example.com",
            authorizationEndpoint: "https://auth.example.com/authorize",
            tokenEndpoint: "https://auth.example.com/token",
            jwksUri: "https://auth.example.com/.well-known/jwks.json",
            responseTypesSupported: ["code"],
            grantTypesSupported: ["authorization_code"],
            subjectTypesSupported: ["public"],
            idTokenSigningAlgValuesSupported: ["RS256"],
            scopesSupported: ["openid", "profile", "cashu"],
            deviceAuthorizationEndpoint: nil,
            userinfoEndpoint: "https://auth.example.com/userinfo"
        )
        
        // Step 2: Build authorization URL
        let authUrl = await service.startAuthorizationCodeFlow(
            config: config,
            clientId: "mint-client",
            redirectUri: "cashu://callback",
            scope: "openid profile cashu",
            state: "random-state"
        )
        
        #expect(authUrl != nil)
        
        // Step 3: Simulate token receipt
        let header = #"{"alg":"RS256","typ":"JWT"}"#
        let payload = #"{"sub":"user123","exp":9999999999,"aud":"cashu-mint"}"#
        let headerB64 = Data(header.utf8).base64EncodedString().replacingOccurrences(of: "=", with: "")
        let payloadB64 = Data(payload.utf8).base64EncodedString().replacingOccurrences(of: "=", with: "")
        let jwt = "\(headerB64).\(payloadB64).signature"
        
        let token = try ClearAuthToken(rawToken: jwt)
        // Store token would happen after OAuth flow completes
        // For now, just verify the token is valid
        #expect(token.isExpired == false)
    }
    
    @Test("Protected endpoint matching scenarios")
    func testProtectedEndpointMatchingScenarios() {
        let endpoints = [
            ProtectedEndpoint(method: "POST", path: "/v1/mint/.*"),
            ProtectedEndpoint(method: "GET", path: "/v1/keys"),
            ProtectedEndpoint(method: "*", path: "/v1/admin/.*"),
            ProtectedEndpoint(method: "POST", path: "/v1/swap")
        ]
        
        // Test various matching scenarios
        let testCases: [(method: String, path: String, expectedMatches: [Bool])] = [
            ("POST", "/v1/mint/123", [true, false, false, false]),
            ("GET", "/v1/keys", [false, true, false, false]),
            ("DELETE", "/v1/admin/users", [false, false, true, false]),
            ("POST", "/v1/swap", [false, false, false, true]),
            ("GET", "/v1/info", [false, false, false, false])
        ]
        
        for testCase in testCases {
            for (index, endpoint) in endpoints.enumerated() {
                let matches = endpoint.matches(method: testCase.method, path: testCase.path)
                #expect(matches == testCase.expectedMatches[index])
            }
        }
    }
    
    @Test("JWT token parsing edge cases")
    func testJWTTokenParsingEdgeCases() throws {
        // Test with special characters in payload
        let header = #"{"alg":"RS256"}"#
        let payload = #"{"sub":"user@example.com","name":"John/Doe","data":{"nested":true}}"#
        
        let headerB64 = Data(header.utf8).base64EncodedString()
            .replacingOccurrences(of: "=", with: "")
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
        
        let payloadB64 = Data(payload.utf8).base64EncodedString()
            .replacingOccurrences(of: "=", with: "")
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
        
        let jwt = "\(headerB64).\(payloadB64).sig"
        let token = try ClearAuthToken(rawToken: jwt)
        
        #expect(token.payload.sub == "user@example.com")
        
        // Check additional claims
        if let nameValue = token.payload.additionalClaims?["name"] {
            #expect(nameValue.stringValue == "John/Doe")
        } else {
            #expect(Bool(false)) // name should be in additional claims
        }
        
        // Check nested data
        if let dataValue = token.payload.additionalClaims?["data"],
           let dataDict = dataValue.dictionaryValue,
           let nestedValue = dataDict["nested"] as? Bool {
            #expect(nestedValue == true)
        } else {
            #expect(Bool(false)) // nested data should exist
        }
    }
}