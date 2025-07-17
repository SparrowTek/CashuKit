//
//  NUT21.swift
//  CashuKit
//
//  NUT-21: Clear Authentication
//  https://github.com/cashubtc/nuts/blob/main/21.md
//

import Foundation
import CryptoKit

// MARK: - NUT-21: Clear Authentication

/// NUT-21: Clear Authentication
/// This NUT defines a clear authentication scheme that allows operators to limit the use of their mint
/// to registered users using the OAuth 2.0 and OpenID Connect protocols.

// MARK: - Protected Endpoint Configuration

/// Represents a protected endpoint that requires clear authentication
public struct ProtectedEndpoint: CashuCodabale, Sendable, Hashable {
    /// HTTP method (GET, POST, etc.)
    public let method: String
    
    /// Endpoint path (can be exact match or regex pattern)
    public let path: String
    
    public init(method: String, path: String) {
        self.method = method
        self.path = path
    }
    
    /// Check if this endpoint matches a request
    public func matches(method: String, path: String) -> Bool {
        // Check method match (wildcard "*" matches any method)
        if self.method != "*" && self.method.uppercased() != method.uppercased() {
            return false
        }
        
        // Try exact match first
        if self.path == path {
            return true
        }
        
        // Try regex pattern match
        do {
            let regex = try NSRegularExpression(pattern: self.path, options: [])
            let range = NSRange(location: 0, length: path.utf16.count)
            return regex.firstMatch(in: path, options: [], range: range) != nil
        } catch {
            // If regex fails, fall back to exact match
            return false
        }
    }
    
    /// Get the endpoint identifier
    public var identifier: String {
        return "\(method.uppercased()) \(path)"
    }
}

// MARK: - OpenID Connect Configuration

/// OpenID Connect Discovery configuration
public struct OpenIDConnectConfig: CashuCodabale, Sendable {
    /// The issuer identifier
    public let issuer: String
    
    /// Authorization endpoint
    public let authorizationEndpoint: String
    
    /// Token endpoint
    public let tokenEndpoint: String
    
    /// JSON Web Key Set (JWKS) endpoint
    public let jwksUri: String
    
    /// Supported response types
    public let responseTypesSupported: [String]
    
    /// Supported grant types
    public let grantTypesSupported: [String]
    
    /// Supported subject types
    public let subjectTypesSupported: [String]
    
    /// Supported ID token signing algorithms
    public let idTokenSigningAlgValuesSupported: [String]
    
    /// Supported scopes
    public let scopesSupported: [String]
    
    /// Device authorization endpoint (for device code flow)
    public let deviceAuthorizationEndpoint: String?
    
    /// User info endpoint
    public let userinfoEndpoint: String?
    
    private enum CodingKeys: String, CodingKey {
        case issuer
        case authorizationEndpoint = "authorization_endpoint"
        case tokenEndpoint = "token_endpoint"
        case jwksUri = "jwks_uri"
        case responseTypesSupported = "response_types_supported"
        case grantTypesSupported = "grant_types_supported"
        case subjectTypesSupported = "subject_types_supported"
        case idTokenSigningAlgValuesSupported = "id_token_signing_alg_values_supported"
        case scopesSupported = "scopes_supported"
        case deviceAuthorizationEndpoint = "device_authorization_endpoint"
        case userinfoEndpoint = "userinfo_endpoint"
    }
    
    public init(
        issuer: String,
        authorizationEndpoint: String,
        tokenEndpoint: String,
        jwksUri: String,
        responseTypesSupported: [String],
        grantTypesSupported: [String],
        subjectTypesSupported: [String],
        idTokenSigningAlgValuesSupported: [String],
        scopesSupported: [String],
        deviceAuthorizationEndpoint: String? = nil,
        userinfoEndpoint: String? = nil
    ) {
        self.issuer = issuer
        self.authorizationEndpoint = authorizationEndpoint
        self.tokenEndpoint = tokenEndpoint
        self.jwksUri = jwksUri
        self.responseTypesSupported = responseTypesSupported
        self.grantTypesSupported = grantTypesSupported
        self.subjectTypesSupported = subjectTypesSupported
        self.idTokenSigningAlgValuesSupported = idTokenSigningAlgValuesSupported
        self.scopesSupported = scopesSupported
        self.deviceAuthorizationEndpoint = deviceAuthorizationEndpoint
        self.userinfoEndpoint = userinfoEndpoint
    }
    
    /// Check if authorization code flow is supported
    public var supportsAuthorizationCodeFlow: Bool {
        return grantTypesSupported.contains("authorization_code")
    }
    
    /// Check if device code flow is supported
    public var supportsDeviceCodeFlow: Bool {
        return grantTypesSupported.contains("urn:ietf:params:oauth:grant-type:device_code")
    }
    
    /// Check if refresh token is supported
    public var supportsRefreshToken: Bool {
        return grantTypesSupported.contains("refresh_token")
    }
    
    /// Check if ES256 signature algorithm is supported
    public var supportsES256: Bool {
        return idTokenSigningAlgValuesSupported.contains("ES256")
    }
    
    /// Check if RS256 signature algorithm is supported
    public var supportsRS256: Bool {
        return idTokenSigningAlgValuesSupported.contains("RS256")
    }
}

// MARK: - Clear Authentication Token (CAT)

/// Clear Authentication Token (JWT)
public struct ClearAuthToken: Sendable {
    /// The raw JWT token
    public let rawToken: String
    
    /// JWT header
    public let header: JWTHeader
    
    /// JWT payload
    public let payload: JWTPayload
    
    /// JWT signature (base64url encoded)
    public let signature: String
    
    public init(rawToken: String) throws {
        self.rawToken = rawToken
        
        let components = rawToken.components(separatedBy: ".")
        guard components.count == 3 else {
            throw CashuError.invalidClearAuthToken("Invalid JWT format")
        }
        
        // Decode header
        guard let headerData = Data(base64URLEncoded: components[0]) else {
            throw CashuError.invalidClearAuthToken("Invalid JWT header")
        }
        self.header = try JSONDecoder().decode(JWTHeader.self, from: headerData)
        
        // Decode payload
        guard let payloadData = Data(base64URLEncoded: components[1]) else {
            throw CashuError.invalidClearAuthToken("Invalid JWT payload")
        }
        self.payload = try JSONDecoder().decode(JWTPayload.self, from: payloadData)
        
        // Store signature
        self.signature = components[2]
    }
    
    /// Check if the token is expired
    public var isExpired: Bool {
        guard let exp = payload.exp else { return false }
        return Date().timeIntervalSince1970 > exp
    }
    
    /// Check if the token is valid for a specific audience
    public func isValidForAudience(_ audience: String) -> Bool {
        guard let aud = payload.aud else { return true }
        
        if let audString = aud as? String {
            return audString == audience
        } else if let audArray = aud as? [String] {
            return audArray.contains(audience)
        }
        
        return false
    }
    
    /// Get the subject identifier
    public var subject: String? {
        return payload.sub
    }
    
    /// Get the issuer
    public var issuer: String? {
        return payload.iss
    }
    
    /// Get the expiration time
    public var expirationTime: Date? {
        guard let exp = payload.exp else { return nil }
        return Date(timeIntervalSince1970: exp)
    }
    
    /// Get the issued at time
    public var issuedAt: Date? {
        guard let iat = payload.iat else { return nil }
        return Date(timeIntervalSince1970: iat)
    }
}

/// JWT Header
public struct JWTHeader: Codable, Sendable {
    /// Algorithm used for signing
    public let alg: String
    
    /// Token type
    public let typ: String?
    
    /// Key ID
    public let kid: String?
    
    public init(alg: String, typ: String? = nil, kid: String? = nil) {
        self.alg = alg
        self.typ = typ
        self.kid = kid
    }
}

/// JWT Payload
public struct JWTPayload: Codable, Sendable {
    /// Subject identifier
    public let sub: String?
    
    /// Issuer
    public let iss: String?
    
    /// Audience
    public let aud: AnyCodable?
    
    /// Expiration time
    public let exp: TimeInterval?
    
    /// Issued at time
    public let iat: TimeInterval?
    
    /// Not before time
    public let nbf: TimeInterval?
    
    /// JWT ID
    public let jti: String?
    
    /// Scope
    public let scope: String?
    
    /// Additional claims
    public let additionalClaims: [String: AnyCodable]?
    
    public init(
        sub: String? = nil,
        iss: String? = nil,
        aud: AnyCodable? = nil,
        exp: TimeInterval? = nil,
        iat: TimeInterval? = nil,
        nbf: TimeInterval? = nil,
        jti: String? = nil,
        scope: String? = nil,
        additionalClaims: [String: AnyCodable]? = nil
    ) {
        self.sub = sub
        self.iss = iss
        self.aud = aud
        self.exp = exp
        self.iat = iat
        self.nbf = nbf
        self.jti = jti
        self.scope = scope
        self.additionalClaims = additionalClaims
    }
    
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        self.sub = try container.decodeIfPresent(String.self, forKey: .sub)
        self.iss = try container.decodeIfPresent(String.self, forKey: .iss)
        self.aud = try container.decodeIfPresent(AnyCodable.self, forKey: .aud)
        self.exp = try container.decodeIfPresent(TimeInterval.self, forKey: .exp)
        self.iat = try container.decodeIfPresent(TimeInterval.self, forKey: .iat)
        self.nbf = try container.decodeIfPresent(TimeInterval.self, forKey: .nbf)
        self.jti = try container.decodeIfPresent(String.self, forKey: .jti)
        self.scope = try container.decodeIfPresent(String.self, forKey: .scope)
        
        // Decode any additional claims
        var additionalClaims: [String: AnyCodable] = [:]
        let allKeys = try decoder.container(keyedBy: AnyCodingKey.self)
        for key in allKeys.allKeys {
            if !CodingKeys.allCases.contains(where: { $0.stringValue == key.stringValue }) {
                additionalClaims[key.stringValue] = try allKeys.decodeIfPresent(AnyCodable.self, forKey: key)
            }
        }
        self.additionalClaims = additionalClaims.isEmpty ? nil : additionalClaims
    }
    
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encodeIfPresent(sub, forKey: .sub)
        try container.encodeIfPresent(iss, forKey: .iss)
        try container.encodeIfPresent(aud, forKey: .aud)
        try container.encodeIfPresent(exp, forKey: .exp)
        try container.encodeIfPresent(iat, forKey: .iat)
        try container.encodeIfPresent(nbf, forKey: .nbf)
        try container.encodeIfPresent(jti, forKey: .jti)
        try container.encodeIfPresent(scope, forKey: .scope)
        
        // Encode additional claims
        if let additionalClaims = additionalClaims {
            var additionalContainer = encoder.container(keyedBy: AnyCodingKey.self)
            for (key, value) in additionalClaims {
                try additionalContainer.encode(value, forKey: AnyCodingKey(stringValue: key)!)
            }
        }
    }
    
    private enum CodingKeys: String, CodingKey, CaseIterable {
        case sub, iss, aud, exp, iat, nbf, jti, scope
    }
}

/// Dynamic coding key for additional JWT claims
private struct AnyCodingKey: CodingKey {
    let stringValue: String
    let intValue: Int?
    
    init?(stringValue: String) {
        self.stringValue = stringValue
        self.intValue = nil
    }
    
    init?(intValue: Int) {
        self.stringValue = "\(intValue)"
        self.intValue = intValue
    }
}

// MARK: - NUT-21 Settings

/// NUT-21 settings for clear authentication
public struct NUT21Settings: CashuCodabale, Sendable {
    /// OpenID Connect Discovery endpoint
    public let openidDiscovery: String
    
    /// OpenID Connect Client ID
    public let clientId: String
    
    /// List of protected endpoints
    public let protectedEndpoints: [ProtectedEndpoint]
    
    private enum CodingKeys: String, CodingKey {
        case openidDiscovery = "openid_discovery"
        case clientId = "client_id"
        case protectedEndpoints = "protected_endpoints"
    }
    
    public init(
        openidDiscovery: String,
        clientId: String,
        protectedEndpoints: [ProtectedEndpoint]
    ) {
        self.openidDiscovery = openidDiscovery
        self.clientId = clientId
        self.protectedEndpoints = protectedEndpoints
    }
    
    /// Check if an endpoint is protected
    public func isEndpointProtected(method: String, path: String) -> Bool {
        return protectedEndpoints.contains { endpoint in
            endpoint.matches(method: method, path: path)
        }
    }
    
    /// Get the OpenID Connect discovery URL
    public var discoveryURL: URL? {
        return URL(string: openidDiscovery)
    }
}

// MARK: - OAuth 2.0 Token Response

/// OAuth 2.0 Token Response
public struct OAuthTokenResponse: CashuCodabale, Sendable {
    /// Access token (CAT)
    public let accessToken: String
    
    /// Token type (usually "Bearer")
    public let tokenType: String
    
    /// Expires in seconds
    public let expiresIn: Int?
    
    /// Refresh token
    public let refreshToken: String?
    
    /// Scope
    public let scope: String?
    
    /// ID token (OpenID Connect)
    public let idToken: String?
    
    private enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case tokenType = "token_type"
        case expiresIn = "expires_in"
        case refreshToken = "refresh_token"
        case scope
        case idToken = "id_token"
    }
    
    public init(
        accessToken: String,
        tokenType: String,
        expiresIn: Int? = nil,
        refreshToken: String? = nil,
        scope: String? = nil,
        idToken: String? = nil
    ) {
        self.accessToken = accessToken
        self.tokenType = tokenType
        self.expiresIn = expiresIn
        self.refreshToken = refreshToken
        self.scope = scope
        self.idToken = idToken
    }
    
    /// Get the expiration date
    public var expirationDate: Date? {
        guard let expiresIn = expiresIn else { return nil }
        return Date().addingTimeInterval(TimeInterval(expiresIn))
    }
    
    /// Check if the token is expired
    public var isExpired: Bool {
        guard let expirationDate = expirationDate else { return false }
        return Date() > expirationDate
    }
}

// MARK: - Device Code Flow

/// Device Code Authorization Response
public struct DeviceAuthorizationResponse: CashuCodabale, Sendable {
    /// Device code
    public let deviceCode: String
    
    /// User code
    public let userCode: String
    
    /// Verification URI
    public let verificationUri: String
    
    /// Complete verification URI
    public let verificationUriComplete: String?
    
    /// Expires in seconds
    public let expiresIn: Int
    
    /// Interval for polling
    public let interval: Int?
    
    private enum CodingKeys: String, CodingKey {
        case deviceCode = "device_code"
        case userCode = "user_code"
        case verificationUri = "verification_uri"
        case verificationUriComplete = "verification_uri_complete"
        case expiresIn = "expires_in"
        case interval
    }
    
    public init(
        deviceCode: String,
        userCode: String,
        verificationUri: String,
        verificationUriComplete: String? = nil,
        expiresIn: Int,
        interval: Int? = nil
    ) {
        self.deviceCode = deviceCode
        self.userCode = userCode
        self.verificationUri = verificationUri
        self.verificationUriComplete = verificationUriComplete
        self.expiresIn = expiresIn
        self.interval = interval
    }
    
    /// Get the expiration date
    public var expirationDate: Date {
        return Date().addingTimeInterval(TimeInterval(expiresIn))
    }
    
    /// Check if the device code is expired
    public var isExpired: Bool {
        return Date() > expirationDate
    }
    
    /// Get the polling interval
    public var pollingInterval: TimeInterval {
        return TimeInterval(interval ?? 5)
    }
}

// MARK: - Clear Authentication Service

/// Service for handling clear authentication
public actor ClearAuthService: Sendable {
    private let networkService: NetworkService
    private var tokenStore: [String: OAuthTokenResponse] = [:]
    private var configCache: [String: OpenIDConnectConfig] = [:]
    
    public init(networkService: NetworkService) {
        self.networkService = networkService
    }
    
    /// Discover OpenID Connect configuration
    public func discoverConfiguration(from discoveryURL: URL) async throws -> OpenIDConnectConfig {
        // Check cache first
        if let cached = configCache[discoveryURL.absoluteString] {
            return cached
        }
        
        // Fetch configuration
        var request = URLRequest(url: discoveryURL)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw CashuError.clearAuthFailed("Failed to fetch OpenID Connect configuration")
        }
        
        let config = try JSONDecoder().decode(OpenIDConnectConfig.self, from: data)
        
        // Cache the configuration
        configCache[discoveryURL.absoluteString] = config
        
        return config
    }
    
    /// Start authorization code flow
    public func startAuthorizationCodeFlow(
        config: OpenIDConnectConfig,
        clientId: String,
        redirectUri: String,
        scope: String = "openid profile",
        state: String? = nil
    ) -> URL? {
        guard let authURL = URL(string: config.authorizationEndpoint) else { return nil }
        
        var components = URLComponents(url: authURL, resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "client_id", value: clientId),
            URLQueryItem(name: "redirect_uri", value: redirectUri),
            URLQueryItem(name: "scope", value: scope),
            URLQueryItem(name: "state", value: state ?? UUID().uuidString)
        ]
        
        return components?.url
    }
    
    /// Exchange authorization code for tokens
    public func exchangeAuthorizationCode(
        config: OpenIDConnectConfig,
        clientId: String,
        code: String,
        redirectUri: String,
        codeVerifier: String? = nil
    ) async throws -> OAuthTokenResponse {
        guard let tokenURL = URL(string: config.tokenEndpoint) else {
            throw CashuError.clearAuthFailed("Invalid token endpoint URL")
        }
        
        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        var params = [
            "grant_type": "authorization_code",
            "client_id": clientId,
            "code": code,
            "redirect_uri": redirectUri
        ]
        
        if let codeVerifier = codeVerifier {
            params["code_verifier"] = codeVerifier
        }
        
        let body = params.map { "\($0.key)=\($0.value)" }.joined(separator: "&")
        request.httpBody = body.data(using: .utf8)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw CashuError.clearAuthFailed("Failed to exchange authorization code")
        }
        
        let tokenResponse = try JSONDecoder().decode(OAuthTokenResponse.self, from: data)
        
        // Store the token
        tokenStore[clientId] = tokenResponse
        
        return tokenResponse
    }
    
    /// Start device code flow
    public func startDeviceCodeFlow(
        config: OpenIDConnectConfig,
        clientId: String,
        scope: String = "openid profile"
    ) async throws -> DeviceAuthorizationResponse {
        guard let deviceAuthURL = config.deviceAuthorizationEndpoint,
              let url = URL(string: deviceAuthURL) else {
            throw CashuError.clearAuthFailed("Device authorization endpoint not available")
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let params = [
            "client_id": clientId,
            "scope": scope
        ]
        
        let body = params.map { "\($0.key)=\($0.value)" }.joined(separator: "&")
        request.httpBody = body.data(using: .utf8)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw CashuError.clearAuthFailed("Failed to start device code flow")
        }
        
        return try JSONDecoder().decode(DeviceAuthorizationResponse.self, from: data)
    }
    
    /// Poll for device code token
    public func pollDeviceCodeToken(
        config: OpenIDConnectConfig,
        clientId: String,
        deviceCode: String
    ) async throws -> OAuthTokenResponse {
        guard let tokenURL = URL(string: config.tokenEndpoint) else {
            throw CashuError.clearAuthFailed("Invalid token endpoint URL")
        }
        
        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let params = [
            "grant_type": "urn:ietf:params:oauth:grant-type:device_code",
            "client_id": clientId,
            "device_code": deviceCode
        ]
        
        let body = params.map { "\($0.key)=\($0.value)" }.joined(separator: "&")
        request.httpBody = body.data(using: .utf8)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw CashuError.clearAuthFailed("Invalid response")
        }
        
        if httpResponse.statusCode == 200 {
            let tokenResponse = try JSONDecoder().decode(OAuthTokenResponse.self, from: data)
            
            // Store the token
            tokenStore[clientId] = tokenResponse
            
            return tokenResponse
        } else {
            // Handle polling errors
            if let errorData = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let error = errorData["error"] as? String {
                if error == "authorization_pending" {
                    throw CashuError.clearAuthPending("Authorization pending")
                } else if error == "slow_down" {
                    throw CashuError.clearAuthSlowDown("Slow down")
                } else if error == "expired_token" {
                    throw CashuError.clearAuthExpired("Device code expired")
                } else {
                    throw CashuError.clearAuthFailed("Device code flow failed: \(error)")
                }
            }
            
            throw CashuError.clearAuthFailed("Failed to poll device code token")
        }
    }
    
    /// Refresh access token
    public func refreshAccessToken(
        config: OpenIDConnectConfig,
        clientId: String,
        refreshToken: String
    ) async throws -> OAuthTokenResponse {
        guard let tokenURL = URL(string: config.tokenEndpoint) else {
            throw CashuError.clearAuthFailed("Invalid token endpoint URL")
        }
        
        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let params = [
            "grant_type": "refresh_token",
            "client_id": clientId,
            "refresh_token": refreshToken
        ]
        
        let body = params.map { "\($0.key)=\($0.value)" }.joined(separator: "&")
        request.httpBody = body.data(using: .utf8)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw CashuError.clearAuthFailed("Failed to refresh access token")
        }
        
        let tokenResponse = try JSONDecoder().decode(OAuthTokenResponse.self, from: data)
        
        // Store the updated token
        tokenStore[clientId] = tokenResponse
        
        return tokenResponse
    }
    
    /// Get stored token for client
    public func getStoredToken(for clientId: String) -> OAuthTokenResponse? {
        return tokenStore[clientId]
    }
    
    /// Clear stored token for client
    public func clearStoredToken(for clientId: String) {
        tokenStore.removeValue(forKey: clientId)
    }
}

// MARK: - JWT Token Validator

/// JWT token validator for Clear Authentication Tokens
public struct JWTTokenValidator: Sendable {
    /// Validate a JWT token
    public static func validate(
        token: ClearAuthToken,
        config: OpenIDConnectConfig,
        audience: String? = nil
    ) async throws -> Bool {
        // Check if token is expired
        if token.isExpired {
            throw CashuError.clearAuthExpired("Token is expired")
        }
        
        // Check audience if provided
        if let audience = audience, !token.isValidForAudience(audience) {
            throw CashuError.clearAuthFailed("Invalid audience")
        }
        
        // Check issuer
        if let issuer = token.issuer, issuer != config.issuer {
            throw CashuError.clearAuthFailed("Invalid issuer")
        }
        
        // Validate signature (simplified - in production use proper JWT library)
        try await validateSignature(token: token, config: config)
        
        return true
    }
    
    /// Validate JWT signature (simplified implementation)
    private static func validateSignature(
        token: ClearAuthToken,
        config: OpenIDConnectConfig
    ) async throws {
        // In a real implementation, this would:
        // 1. Fetch the JWKS from config.jwksUri
        // 2. Find the correct key using token.header.kid
        // 3. Verify the signature using the public key
        // 4. Support both ES256 and RS256 algorithms
        
        // For this example, we'll do a basic validation
        guard token.header.alg == "ES256" || token.header.alg == "RS256" else {
            throw CashuError.clearAuthFailed("Unsupported signature algorithm")
        }
        
        // In a real implementation, you would validate the actual signature here
        // For now, we'll just check that the token format is correct
        if token.signature.isEmpty {
            throw CashuError.clearAuthFailed("Missing signature")
        }
    }
}

// MARK: - MintInfo Extensions

extension MintInfo {
    /// Check if the mint supports NUT-21 (Clear Authentication)
    public var supportsClearAuth: Bool {
        return supportsNUT("21")
    }
    
    /// Get NUT-21 settings if supported
    public func getNUT21Settings() -> NUT21Settings? {
        guard let nut21Data = nuts?["21"]?.dictionaryValue else { return nil }
        
        guard let openidDiscovery = nut21Data["openid_discovery"] as? String,
              let clientId = nut21Data["client_id"] as? String else {
            return nil
        }
        
        var protectedEndpoints: [ProtectedEndpoint] = []
        
        if let endpointsData = nut21Data["protected_endpoints"] as? [[String: Any]] {
            protectedEndpoints = endpointsData.compactMap { endpointDict in
                guard let method = endpointDict["method"] as? String,
                      let path = endpointDict["path"] as? String else {
                    return nil
                }
                
                return ProtectedEndpoint(method: method, path: path)
            }
        }
        
        return NUT21Settings(
            openidDiscovery: openidDiscovery,
            clientId: clientId,
            protectedEndpoints: protectedEndpoints
        )
    }
    
    /// Check if clear authentication is required for an endpoint
    public func requiresClearAuth(for method: String, path: String) -> Bool {
        guard let settings = getNUT21Settings() else { return false }
        return settings.isEndpointProtected(method: method, path: path)
    }
}

// MARK: - Request Authentication

/// Authentication header manager for HTTP requests
public struct ClearAuthHeaderManager: Sendable {
    /// Add clear authentication header to request
    public static func addAuthHeader(
        to request: inout URLRequest,
        token: String
    ) {
        request.setValue(token, forHTTPHeaderField: "Clear-auth")
    }
    
    /// Check if request has clear auth header
    public static func hasAuthHeader(_ request: URLRequest) -> Bool {
        return request.value(forHTTPHeaderField: "Clear-auth") != nil
    }
    
    /// Get clear auth token from request
    public static func getAuthToken(from request: URLRequest) -> String? {
        return request.value(forHTTPHeaderField: "Clear-auth")
    }
}

// MARK: - Error Extensions

extension CashuError {
    /// Clear authentication failed
    public static func clearAuthFailed(_ message: String) -> CashuError {
        return .networkError("Clear authentication failed: \(message)")
    }
    
    /// Clear authentication pending
    public static func clearAuthPending(_ message: String) -> CashuError {
        return .networkError("Clear authentication pending: \(message)")
    }
    
    /// Clear authentication slow down
    public static func clearAuthSlowDown(_ message: String) -> CashuError {
        return .networkError("Clear authentication slow down: \(message)")
    }
    
    /// Clear authentication expired
    public static func clearAuthExpired(_ message: String) -> CashuError {
        return .networkError("Clear authentication expired: \(message)")
    }
    
    /// Invalid clear authentication token
    public static func invalidClearAuthToken(_ message: String) -> CashuError {
        return .networkError("Invalid clear authentication token: \(message)")
    }
}

// MARK: - Base64URL Extensions

extension Data {
    /// Base64URL encoding (without padding)
    func base64URLEncodedString() -> String {
        return base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
    
    /// Base64URL decoding
    init?(base64URLEncoded string: String) {
        var base64 = string
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        
        // Add padding if needed
        let padding = 4 - (base64.count % 4)
        if padding != 4 {
            base64 += String(repeating: "=", count: padding)
        }
        
        guard let data = Data(base64Encoded: base64) else {
            return nil
        }
        
        self = data
    }
}

// MARK: - Common Redirect URLs

/// Common redirect URLs for Cashu wallets
public struct CashuWalletRedirectURLs {
    /// Localhost callback URL
    public static let localhost = "http://localhost:33388/callback"
    
    /// Common wallet redirect URLs
    public static let commonWalletURLs = [
        "cashu://callback",
        "nutshell://callback",
        "minibits://callback",
        "feni://callback",
        "eNuts://callback"
    ]
    
    /// All supported redirect URLs
    public static let allSupportedURLs = [localhost] + commonWalletURLs
}