//
//  NUT01_MintInformation.swift
//  CashuKit
//
//  NUT-01: Mint Information
//  https://github.com/cashubtc/nuts/blob/main/01.md
//

import Foundation

// MARK: - NUT-01: Mint Information

/// NUT-01: Mint Information
/// This NUT defines the mint information endpoint and response format
public struct NUT01_MintInformation {
    
    /// Mint information response structure
    public struct MintInfo: Codable, Sendable {
        public let name: String?
        public let pubkey: String
        public let version: String?
        public let description: String?
        public let descriptionLong: String?
        public let contact: [String]?
        public let nuts: [String: String]?
        public let motd: String?
        public let parameter: MintParameters?
        
        public init(
            name: String? = nil,
            pubkey: String,
            version: String? = nil,
            description: String? = nil,
            descriptionLong: String? = nil,
            contact: [String]? = nil,
            nuts: [String: String]? = nil,
            motd: String? = nil,
            parameter: MintParameters? = nil
        ) {
            self.name = name
            self.pubkey = pubkey
            self.version = version
            self.description = description
            self.descriptionLong = descriptionLong
            self.contact = contact
            self.nuts = nuts
            self.motd = motd
            self.parameter = parameter
        }
        
        /// Check if this mint supports a specific NUT
        public func supportsNUT(_ nut: String) -> Bool {
            return nuts?[nut] != nil
        }
        
        /// Get the version of a specific NUT if supported
        public func getNUTVersion(_ nut: String) -> String? {
            return nuts?[nut]
        }
        
        /// Get all supported NUTs
        public func getSupportedNUTs() -> [String] {
            return nuts?.keys.sorted() ?? []
        }
        
        /// Check if mint supports basic operations (NUT-00, NUT-01, NUT-02)
        public func supportsBasicOperations() -> Bool {
            let basicNUTs = ["NUT-00", "NUT-01", "NUT-02"]
            return basicNUTs.allSatisfy { supportsNUT($0) }
        }
    }
    
    /// Mint parameters structure
    public struct MintParameters: Codable, Sendable {
        public let maxMessageLength: Int?
        public let supportedNUTs: [String]?
        
        public init(
            maxMessageLength: Int? = nil,
            supportedNUTs: [String]? = nil
        ) {
            self.maxMessageLength = maxMessageLength
            self.supportedNUTs = supportedNUTs
        }
        
        private enum CodingKeys: String, CodingKey {
            case maxMessageLength = "max_message_length"
            case supportedNUTs = "supported_nuts"
        }
    }
    
    // MARK: - HTTP Client Implementation
    
    /// HTTP client for mint API requests
    private struct MintHTTPClient {
        private let session: URLSession
        private let timeoutInterval: TimeInterval
        
        init(timeoutInterval: TimeInterval = 30.0) {
            self.timeoutInterval = timeoutInterval
            let config = URLSessionConfiguration.default
            config.timeoutIntervalForRequest = timeoutInterval
            config.timeoutIntervalForResource = timeoutInterval
            self.session = URLSession(configuration: config)
        }
        
        /// Make a GET request to a mint endpoint
        func get<T: Codable>(from url: URL) async throws -> T {
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw CashuError.networkError("Invalid response type")
            }
            
            // Check for HTTP errors
            guard httpResponse.statusCode == 200 else {
                switch httpResponse.statusCode {
                case 404:
                    throw CashuError.mintUnavailable
                case 429:
                    throw CashuError.rateLimitExceeded
                case 500...599:
                    throw CashuError.networkError("Server error: \(httpResponse.statusCode)")
                default:
                    throw CashuError.networkError("HTTP \(httpResponse.statusCode)")
                }
            }
            
            // Parse JSON response
            do {
                let decoder = JSONDecoder()
                return try decoder.decode(T.self, from: data)
            } catch {
                throw CashuError.deserializationFailed
            }
        }
    }
    
    // MARK: - Public API Methods
    
    /// Get mint information from a mint URL
    /// - Parameter mintURL: The base URL of the mint (e.g., "https://mint.example.com")
    /// - Returns: Mint information including supported NUTs and parameters
    public static func getMintInfo(from mintURL: String) async throws -> MintInfo {
        // Validate and normalize the mint URL
        let normalizedURL = try normalizeMintURL(mintURL)
        
        // Construct the info endpoint URL
        guard let url = URL(string: "\(normalizedURL)/info") else {
            throw CashuError.invalidMintURL
        }
        
        // Make the HTTP request
        let client = MintHTTPClient()
        let mintInfo: MintInfo = try await client.get(from: url)
        
        // Validate the response
        guard validateMintInfo(mintInfo) else {
            throw CashuError.invalidResponse
        }
        
        return mintInfo
    }
    
    /// Get mint information with timeout
    /// - Parameters:
    ///   - mintURL: The base URL of the mint
    ///   - timeout: Request timeout in seconds
    /// - Returns: Mint information
    public static func getMintInfo(from mintURL: String, timeout: TimeInterval) async throws -> MintInfo {
        let normalizedURL = try normalizeMintURL(mintURL)
        
        guard let url = URL(string: "\(normalizedURL)/info") else {
            throw CashuError.invalidMintURL
        }
        
        let client = MintHTTPClient(timeoutInterval: timeout)
        let mintInfo: MintInfo = try await client.get(from: url)
        
        guard validateMintInfo(mintInfo) else {
            throw CashuError.invalidResponse
        }
        
        return mintInfo
    }
    
    /// Check if a mint is available and responding
    /// - Parameter mintURL: The base URL of the mint
    /// - Returns: True if mint is available, false otherwise
    public static func isMintAvailable(_ mintURL: String) async -> Bool {
        do {
            _ = try await getMintInfo(from: mintURL)
            return true
        } catch {
            return false
        }
    }
    
    /// Get mint information with retry logic
    /// - Parameters:
    ///   - mintURL: The base URL of the mint
    ///   - maxRetries: Maximum number of retry attempts
    ///   - retryDelay: Delay between retries in seconds
    /// - Returns: Mint information
    public static func getMintInfoWithRetry(
        from mintURL: String,
        maxRetries: Int = 3,
        retryDelay: TimeInterval = 1.0
    ) async throws -> MintInfo {
        var lastError: Error?
        
        for attempt in 0...maxRetries {
            do {
                return try await getMintInfo(from: mintURL)
            } catch {
                lastError = error
                
                if attempt < maxRetries {
                    try await Task.sleep(nanoseconds: UInt64(retryDelay * 1_000_000_000))
                }
            }
        }
        
        throw lastError ?? CashuError.mintUnavailable
    }
    
    // MARK: - Validation Methods
    
    /// Validate mint information
    /// - Parameter info: The mint information to validate
    /// - Returns: True if valid, false otherwise
    public static func validateMintInfo(_ info: MintInfo) -> Bool {
        // Basic validation
        guard !info.pubkey.isEmpty else { return false }
        
        // Validate pubkey format (should be a valid hex string)
        guard Data(hexString: info.pubkey) != nil else { return false }
        
        // Validate version if present
        if let version = info.version, version.isEmpty { return false }
        
        // Validate contact array if present
        if let contact = info.contact {
            for contactItem in contact {
                if contactItem.isEmpty { return false }
            }
        }
        
        // Validate nuts dictionary if present
        if let nuts = info.nuts {
            for (key, value) in nuts {
                if key.isEmpty || value.isEmpty { return false }
            }
        }
        
        return true
    }
    
    /// Validate mint URL format
    /// - Parameter mintURL: The URL to validate
    /// - Returns: True if valid, false otherwise
    public static func validateMintURL(_ mintURL: String) -> Bool {
        guard let url = URL(string: mintURL) else { return false }
        
        // Must have a scheme (http or https)
        guard let scheme = url.scheme, ["http", "https"].contains(scheme.lowercased()) else {
            return false
        }
        
        // Must have a host
        guard let host = url.host, !host.isEmpty else { return false }
        
        return true
    }
    
    // MARK: - Utility Methods
    
    /// Normalize a mint URL (add scheme if missing, remove trailing slash)
    /// - Parameter mintURL: The URL to normalize
    /// - Returns: Normalized URL
    private static func normalizeMintURL(_ mintURL: String) throws -> String {
        var normalizedURL = mintURL.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Add https:// if no scheme is present
        if !normalizedURL.contains("://") {
            normalizedURL = "https://" + normalizedURL
        }
        
        // Remove trailing slash
        if normalizedURL.hasSuffix("/") {
            normalizedURL = String(normalizedURL.dropLast())
        }
        
        // Validate the normalized URL
        guard validateMintURL(normalizedURL) else {
            throw CashuError.invalidMintURL
        }
        
        return normalizedURL
    }
    
    /// Create a mock mint info for testing
    /// - Parameter pubkey: The mint's public key
    /// - Returns: Mock mint information
    public static func createMockMintInfo(pubkey: String) -> MintInfo {
        return MintInfo(
            name: "Test Mint",
            pubkey: pubkey,
            version: "1.0.0",
            description: "A test mint for development",
            descriptionLong: "This is a test mint used for development and testing purposes",
            contact: ["admin@testmint.com"],
            nuts: [
                "NUT-00": "1.0",
                "NUT-01": "1.0",
                "NUT-02": "1.0",
                "NUT-03": "1.0"
            ],
            motd: "Welcome to Test Mint!",
            parameter: MintParameters(
                maxMessageLength: 1024,
                supportedNUTs: ["NUT-00", "NUT-01", "NUT-02", "NUT-03"]
            )
        )
    }
    
    /// Compare two mint info objects for compatibility
    /// - Parameters:
    ///   - info1: First mint info
    ///   - info2: Second mint info
    /// - Returns: True if compatible, false otherwise
    public static func areMintsCompatible(_ info1: MintInfo, _ info2: MintInfo) -> Bool {
        // Check if both mints support basic operations
        guard info1.supportsBasicOperations() && info2.supportsBasicOperations() else {
            return false
        }
        
        // Check for common supported NUTs
        let nuts1 = Set(info1.getSupportedNUTs())
        let nuts2 = Set(info2.getSupportedNUTs())
        let commonNUTs = nuts1.intersection(nuts2)
        
        // Must have at least basic NUTs in common
        let basicNUTs = Set(["NUT-00", "NUT-01", "NUT-02"])
        return !basicNUTs.isDisjoint(with: commonNUTs)
    }
} 
