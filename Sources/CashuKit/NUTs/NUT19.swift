//
//  NUT19.swift
//  CashuKit
//
//  NUT-19: Cached Responses
//  https://github.com/cashubtc/nuts/blob/main/19.md
//

import Foundation

// MARK: - NUT-19: Cached Responses

/// NUT-19: Cached Responses
/// This NUT introduces a caching mechanism for successful responses to minimize the risk of loss of funds
/// due to network errors during critical operations such as minting, swapping, and melting

// MARK: - Cached Endpoint Configuration

/// Cached endpoint configuration
public struct CachedEndpoint: CashuCodabale, Sendable, Hashable {
    /// HTTP method
    public let method: String
    
    /// Endpoint path
    public let path: String
    
    public init(method: String, path: String) {
        self.method = method
        self.path = path
    }
    
    /// Check if this endpoint matches a request
    public func matches(method: String, path: String) -> Bool {
        return self.method.uppercased() == method.uppercased() && self.path == path
    }
    
    /// Get the endpoint identifier
    public var identifier: String {
        return "\(method.uppercased()) \(path)"
    }
}

/// NUT-19 settings structure
public struct NUT19Settings: CashuCodabale, Sendable {
    /// Time to live for cached responses in seconds (null = indefinite)
    public let ttl: Int?
    
    /// List of cached endpoints
    public let cachedEndpoints: [CachedEndpoint]
    
    public init(ttl: Int? = nil, cachedEndpoints: [CachedEndpoint]) {
        self.ttl = ttl
        self.cachedEndpoints = cachedEndpoints
    }
    
    /// Check if caching is enabled for a specific endpoint
    public func isCachingEnabled(for method: String, path: String) -> Bool {
        return cachedEndpoints.contains { $0.matches(method: method, path: path) }
    }
    
    /// Get the TTL in seconds
    public var timeToLive: TimeInterval? {
        return ttl.map { TimeInterval($0) }
    }
    
    /// Check if responses are cached indefinitely
    public var isIndefiniteCache: Bool {
        return ttl == nil
    }
}

// MARK: - Cache Key Generation

/// Cache key generator for requests
public struct CacheKeyGenerator: Sendable {
    /// Generate a cache key for a request
    /// The key depends on the method, path, and payload of the request
    public static func generateKey(
        method: String,
        path: String,
        payload: Data?
    ) -> String {
        var components = [method.uppercased(), path]
        
        if let payload = payload {
            let payloadHash = payload.sha256Hash
            components.append(payloadHash)
        }
        
        return components.joined(separator: ":")
    }
    
    /// Generate a cache key for a URLRequest
    public static func generateKey(for request: URLRequest) -> String {
        let method = request.httpMethod ?? "GET"
        let path = request.url?.path ?? "/"
        let payload = request.httpBody
        
        return generateKey(method: method, path: path, payload: payload)
    }
}

// MARK: - Cached Response

/// Cached response structure
public struct CachedResponse: Sendable {
    /// The cached response data
    public let data: Data
    
    /// The HTTP status code
    public let statusCode: Int
    
    /// Response headers
    public let headers: [String: String]
    
    /// Timestamp when the response was cached
    public let cachedAt: Date
    
    /// Time to live for this response
    public let ttl: TimeInterval?
    
    public init(
        data: Data,
        statusCode: Int,
        headers: [String: String] = [:],
        cachedAt: Date = Date(),
        ttl: TimeInterval? = nil
    ) {
        self.data = data
        self.statusCode = statusCode
        self.headers = headers
        self.cachedAt = cachedAt
        self.ttl = ttl
    }
    
    /// Check if the cached response has expired
    public var isExpired: Bool {
        guard let ttl = ttl else { return false } // Indefinite cache
        return Date().timeIntervalSince(cachedAt) > ttl
    }
    
    /// Get the expiry date for this cached response
    public var expiryDate: Date? {
        guard let ttl = ttl else { return nil }
        return cachedAt.addingTimeInterval(ttl)
    }
    
    /// Check if the response is successful (status code 200)
    public var isSuccessful: Bool {
        return statusCode == 200
    }
}

// MARK: - Response Cache Protocol

/// Protocol for response caching implementations
public protocol ResponseCache: Sendable {
    /// Get a cached response for a key
    func get(key: String) async -> CachedResponse?
    
    /// Store a response in the cache
    func set(key: String, response: CachedResponse) async
    
    /// Remove a response from the cache
    func remove(key: String) async
    
    /// Clear all cached responses
    func clear() async
    
    /// Get all cached keys
    func getAllKeys() async -> [String]
    
    /// Get cache statistics
    func getStats() async -> CacheStats
}

/// Cache statistics
public struct CacheStats: Sendable {
    /// Number of cached responses
    public let count: Int
    
    /// Cache hit count
    public let hits: Int
    
    /// Cache miss count
    public let misses: Int
    
    /// Total size in bytes
    public let totalSize: Int
    
    public init(count: Int, hits: Int, misses: Int, totalSize: Int) {
        self.count = count
        self.hits = hits
        self.misses = misses
        self.totalSize = totalSize
    }
    
    /// Calculate hit rate
    public var hitRate: Double {
        let total = hits + misses
        return total > 0 ? Double(hits) / Double(total) : 0.0
    }
}

// MARK: - In-Memory Cache Implementation

/// In-memory implementation of ResponseCache
public actor InMemoryResponseCache: ResponseCache {
    private var cache: [String: CachedResponse] = [:]
    private var hitCount = 0
    private var missCount = 0
    
    public init() {}
    
    public func get(key: String) async -> CachedResponse? {
        if let response = cache[key] {
            if response.isExpired {
                cache.removeValue(forKey: key)
                missCount += 1
                return nil
            }
            hitCount += 1
            return response
        }
        missCount += 1
        return nil
    }
    
    public func set(key: String, response: CachedResponse) async {
        cache[key] = response
    }
    
    public func remove(key: String) async {
        cache.removeValue(forKey: key)
    }
    
    public func clear() async {
        cache.removeAll()
        hitCount = 0
        missCount = 0
    }
    
    public func getAllKeys() async -> [String] {
        return Array(cache.keys)
    }
    
    public func getStats() async -> CacheStats {
        let totalSize = cache.values.reduce(0) { $0 + $1.data.count }
        return CacheStats(
            count: cache.count,
            hits: hitCount,
            misses: missCount,
            totalSize: totalSize
        )
    }
    
    /// Clean up expired entries
    public func cleanupExpired() async {
        let keysToRemove = cache.compactMap { key, response in
            response.isExpired ? key : nil
        }
        
        for key in keysToRemove {
            cache.removeValue(forKey: key)
        }
    }
}

// MARK: - Cached Network Service

/// Network service with caching support
public actor CachedNetworkService: Sendable {
    private let cache: any ResponseCache
    private let networkService: any NetworkService
    private let settings: NUT19Settings
    
    public init(
        cache: any ResponseCache = InMemoryResponseCache(),
        networkService: any NetworkService,
        settings: NUT19Settings
    ) {
        self.cache = cache
        self.networkService = networkService
        self.settings = settings
    }
    
    /// Execute a request with caching
    public func execute<T: CashuCodabale>(
        method: String,
        path: String,
        payload: Data? = nil
    ) async throws -> T {
        // Check if caching is enabled for this endpoint
        guard settings.isCachingEnabled(for: method, path: path) else {
            // No caching, execute normally
            return try await networkService.execute(method: method, path: path, payload: payload)
        }
        
        // Generate cache key
        let cacheKey = CacheKeyGenerator.generateKey(method: method, path: path, payload: payload)
        
        // Try to get cached response
        if let cachedResponse = await cache.get(key: cacheKey) {
            // Decode and return cached response
            return try JSONDecoder().decode(T.self, from: cachedResponse.data)
        }
        
        // No cached response, execute the request
        let response: T = try await networkService.execute(method: method, path: path, payload: payload)
        
        // Cache the successful response
        let responseData = try JSONEncoder().encode(response)
        let cachedResponse = CachedResponse(
            data: responseData,
            statusCode: 200,
            ttl: settings.timeToLive
        )
        
        await cache.set(key: cacheKey, response: cachedResponse)
        
        return response
    }
    
    /// Execute a URLRequest with caching
    public func execute<T: CashuCodabale>(_ request: URLRequest) async throws -> T {
        let method = request.httpMethod ?? "GET"
        let path = request.url?.path ?? "/"
        let payload = request.httpBody
        
        return try await execute(method: method, path: path, payload: payload)
    }
    
    /// Clear cache for a specific endpoint
    public func clearCache(for method: String, path: String) async {
        let cacheKey = CacheKeyGenerator.generateKey(method: method, path: path, payload: nil)
        await cache.remove(key: cacheKey)
    }
    
    /// Clear all cache
    public func clearAllCache() async {
        await cache.clear()
    }
    
    /// Get cache statistics
    public func getCacheStats() async -> CacheStats {
        return await cache.getStats()
    }
}

// MARK: - Cache Manager

/// Manager for handling cached responses
public actor CacheManager: Sendable {
    private let cache: any ResponseCache
    private let settings: NUT19Settings
    
    public init(cache: any ResponseCache = InMemoryResponseCache(), settings: NUT19Settings) {
        self.cache = cache
        self.settings = settings
    }
    
    /// Store a response in cache
    public func storeResponse(
        for method: String,
        path: String,
        payload: Data?,
        response: Data,
        statusCode: Int,
        headers: [String: String] = [:]
    ) async {
        // Only cache successful responses
        guard statusCode == 200 else { return }
        
        // Only cache if enabled for this endpoint
        guard settings.isCachingEnabled(for: method, path: path) else { return }
        
        let cacheKey = CacheKeyGenerator.generateKey(method: method, path: path, payload: payload)
        let cachedResponse = CachedResponse(
            data: response,
            statusCode: statusCode,
            headers: headers,
            ttl: settings.timeToLive
        )
        
        await cache.set(key: cacheKey, response: cachedResponse)
    }
    
    /// Retrieve a cached response
    public func getCachedResponse(
        for method: String,
        path: String,
        payload: Data?
    ) async -> CachedResponse? {
        guard settings.isCachingEnabled(for: method, path: path) else { return nil }
        
        let cacheKey = CacheKeyGenerator.generateKey(method: method, path: path, payload: payload)
        return await cache.get(key: cacheKey)
    }
    
    /// Clean up expired cache entries
    public func cleanupExpired() async {
        if let inMemoryCache = cache as? InMemoryResponseCache {
            await inMemoryCache.cleanupExpired()
        }
    }
    
    /// Get cache statistics
    public func getStats() async -> CacheStats {
        return await cache.getStats()
    }
}

// MARK: - Common Cached Endpoints

/// Common cached endpoints for Cashu operations
public struct CommonCachedEndpoints {
    /// Mint bolt11 endpoint
    public static let mintBolt11 = CachedEndpoint(method: "POST", path: "/v1/mint/bolt11")
    
    /// Swap endpoint
    public static let swap = CachedEndpoint(method: "POST", path: "/v1/swap")
    
    /// Melt bolt11 endpoint
    public static let meltBolt11 = CachedEndpoint(method: "POST", path: "/v1/melt/bolt11")
    
    /// Restore endpoint
    public static let restore = CachedEndpoint(method: "POST", path: "/v1/restore")
    
    /// All common cached endpoints
    public static let all: [CachedEndpoint] = [
        mintBolt11,
        swap,
        meltBolt11,
        restore
    ]
}

// MARK: - MintInfo Extensions

extension MintInfo {
    /// Check if the mint supports NUT-19 (Cached Responses)
    public var supportsCachedResponses: Bool {
        return supportsNUT("19")
    }
    
    /// Get NUT-19 settings if supported
    public func getNUT19Settings() -> NUT19Settings? {
        guard let nut19Data = nuts?["19"]?.dictionaryValue else { return nil }
        
        // Parse TTL
        let ttl = nut19Data["ttl"] as? Int
        
        // Parse cached endpoints
        guard let endpointsData = nut19Data["cached_endpoints"] as? [[String: Any]] else {
            return NUT19Settings(ttl: ttl, cachedEndpoints: [])
        }
        
        let endpoints = endpointsData.compactMap { endpointDict -> CachedEndpoint? in
            guard let method = endpointDict["method"] as? String,
                  let path = endpointDict["path"] as? String else {
                return nil
            }
            
            return CachedEndpoint(method: method, path: path)
        }
        
        return NUT19Settings(ttl: ttl, cachedEndpoints: endpoints)
    }
    
    /// Check if caching is enabled for a specific endpoint
    public func isCachingEnabled(for method: String, path: String) -> Bool {
        guard let settings = getNUT19Settings() else { return false }
        return settings.isCachingEnabled(for: method, path: path)
    }
}

// MARK: - Data Extensions

extension Data {
    /// Calculate SHA256 hash of the data
    var sha256Hash: String {
        // This is a simplified hash implementation
        // In a real implementation, you would use CryptoKit or similar
        return String(format: "%02x", self.reduce(0) { $0 &+ Int($1) })
    }
}

// MARK: - Cache Configuration

/// Configuration for response caching
public struct CacheConfiguration: Sendable {
    /// Default TTL for cached responses
    public let defaultTTL: TimeInterval?
    
    /// Maximum cache size in bytes
    public let maxCacheSize: Int
    
    /// Maximum number of cached entries
    public let maxCacheEntries: Int
    
    /// Whether to enable automatic cleanup of expired entries
    public let autoCleanup: Bool
    
    /// Cleanup interval in seconds
    public let cleanupInterval: TimeInterval
    
    public init(
        defaultTTL: TimeInterval? = nil,
        maxCacheSize: Int = 10 * 1024 * 1024, // 10MB
        maxCacheEntries: Int = 1000,
        autoCleanup: Bool = true,
        cleanupInterval: TimeInterval = 300 // 5 minutes
    ) {
        self.defaultTTL = defaultTTL
        self.maxCacheSize = maxCacheSize
        self.maxCacheEntries = maxCacheEntries
        self.autoCleanup = autoCleanup
        self.cleanupInterval = cleanupInterval
    }
    
    /// Default cache configuration
    public static let `default` = CacheConfiguration()
}

// MARK: - Network Service Protocol

/// Protocol for network service implementations
public protocol NetworkService: Sendable {
    /// Execute a network request
    func execute<T: CashuCodabale>(method: String, path: String, payload: Data?) async throws -> T
}

// MARK: - Mock Network Service

/// Mock network service for testing
public struct MockNetworkService: NetworkService {
    private let responses: [String: Data]
    
    public init(responses: [String: Data] = [:]) {
        self.responses = responses
    }
    
    public func execute<T: CashuCodabale>(method: String, path: String, payload: Data?) async throws -> T {
        let key = "\(method.uppercased()) \(path)"
        guard let responseData = responses[key] else {
            throw CashuError.networkError("No mock response for \(key)")
        }
        
        return try JSONDecoder().decode(T.self, from: responseData)
    }
}

// MARK: - Cache Utility Functions

/// Utility functions for cache operations
public struct CacheUtils {
    /// Generate a simple hash for cache keys
    public static func simpleHash(_ input: String) -> String {
        // Simple hash implementation for demonstration
        // In production, use a proper hash function
        return String(format: "%08x", input.hashValue)
    }
    
    /// Format cache key for readability
    public static func formatCacheKey(_ key: String) -> String {
        return key.replacingOccurrences(of: ":", with: "_")
    }
    
    /// Parse cache key components
    public static func parseCacheKey(_ key: String) -> (method: String, path: String, payloadHash: String?)? {
        let components = key.components(separatedBy: ":")
        guard components.count >= 2 else { return nil }
        
        let method = components[0]
        let path = components[1]
        let payloadHash = components.count > 2 ? components[2] : nil
        
        return (method: method, path: path, payloadHash: payloadHash)
    }
}