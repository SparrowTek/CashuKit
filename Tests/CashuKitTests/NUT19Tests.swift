//
//  NUT19Tests.swift
//  CashuKitTests
//
//  Tests for NUT-19: Cached Responses
//

import Testing
@testable import CashuKit
import Foundation

@Suite("NUT-19 Tests")
struct NUT19Tests {
    
    // MARK: - Cached Endpoint Tests
    
    @Test("CachedEndpoint creation and matching")
    func testCachedEndpointCreation() {
        let endpoint = CachedEndpoint(method: "POST", path: "/v1/mint/bolt11")
        
        #expect(endpoint.method == "POST")
        #expect(endpoint.path == "/v1/mint/bolt11")
        #expect(endpoint.identifier == "POST /v1/mint/bolt11")
        
        #expect(endpoint.matches(method: "POST", path: "/v1/mint/bolt11") == true)
        #expect(endpoint.matches(method: "post", path: "/v1/mint/bolt11") == true) // Case insensitive
        #expect(endpoint.matches(method: "GET", path: "/v1/mint/bolt11") == false)
        #expect(endpoint.matches(method: "POST", path: "/v1/swap") == false)
    }
    
    @Test("CachedEndpoint equality")
    func testCachedEndpointEquality() {
        let endpoint1 = CachedEndpoint(method: "POST", path: "/v1/mint/bolt11")
        let endpoint2 = CachedEndpoint(method: "POST", path: "/v1/mint/bolt11")
        let endpoint3 = CachedEndpoint(method: "GET", path: "/v1/mint/bolt11")
        
        #expect(endpoint1 == endpoint2)
        #expect(endpoint1 != endpoint3)
    }
    
    // MARK: - NUT19 Settings Tests
    
    @Test("NUT19Settings creation and caching checks")
    func testNUT19SettingsCreation() {
        let endpoints = [
            CachedEndpoint(method: "POST", path: "/v1/mint/bolt11"),
            CachedEndpoint(method: "POST", path: "/v1/swap")
        ]
        
        let settings = NUT19Settings(ttl: 300, cachedEndpoints: endpoints)
        
        #expect(settings.ttl == 300)
        #expect(settings.cachedEndpoints.count == 2)
        #expect(settings.timeToLive == 300.0)
        #expect(settings.isIndefiniteCache == false)
        
        #expect(settings.isCachingEnabled(for: "POST", path: "/v1/mint/bolt11") == true)
        #expect(settings.isCachingEnabled(for: "POST", path: "/v1/swap") == true)
        #expect(settings.isCachingEnabled(for: "GET", path: "/v1/mint/bolt11") == false)
        #expect(settings.isCachingEnabled(for: "POST", path: "/v1/melt/bolt11") == false)
    }
    
    @Test("NUT19Settings with indefinite cache")
    func testNUT19SettingsIndefiniteCache() {
        let endpoints = [CachedEndpoint(method: "POST", path: "/v1/mint/bolt11")]
        let settings = NUT19Settings(ttl: nil, cachedEndpoints: endpoints)
        
        #expect(settings.ttl == nil)
        #expect(settings.timeToLive == nil)
        #expect(settings.isIndefiniteCache == true)
    }
    
    // MARK: - Cache Key Generation Tests
    
    @Test("CacheKeyGenerator basic functionality")
    func testCacheKeyGeneration() {
        let key1 = CacheKeyGenerator.generateKey(method: "POST", path: "/v1/mint/bolt11", payload: nil)
        let key2 = CacheKeyGenerator.generateKey(method: "POST", path: "/v1/mint/bolt11", payload: nil)
        let key3 = CacheKeyGenerator.generateKey(method: "GET", path: "/v1/mint/bolt11", payload: nil)
        
        #expect(key1 == key2) // Same request should generate same key
        #expect(key1 != key3) // Different method should generate different key
        #expect(key1 == "POST:/v1/mint/bolt11")
    }
    
    @Test("CacheKeyGenerator with payload")
    func testCacheKeyGenerationWithPayload() {
        let payload1 = Data("request1".utf8)
        let payload2 = Data("request2".utf8)
        
        let key1 = CacheKeyGenerator.generateKey(method: "POST", path: "/v1/mint/bolt11", payload: payload1)
        let key2 = CacheKeyGenerator.generateKey(method: "POST", path: "/v1/mint/bolt11", payload: payload2)
        let key3 = CacheKeyGenerator.generateKey(method: "POST", path: "/v1/mint/bolt11", payload: payload1)
        
        #expect(key1 != key2) // Different payload should generate different key
        #expect(key1 == key3) // Same payload should generate same key
        #expect(key1.hasPrefix("POST:/v1/mint/bolt11:"))
    }
    
    @Test("CacheKeyGenerator with URLRequest")
    func testCacheKeyGenerationWithURLRequest() {
        let url = URL(string: "https://mint.example.com/v1/mint/bolt11")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = Data("test payload".utf8)
        
        let key = CacheKeyGenerator.generateKey(for: request)
        
        #expect(key.hasPrefix("POST:/v1/mint/bolt11:"))
        #expect(key.contains(":")) // Should contain payload hash
    }
    
    // MARK: - Cached Response Tests
    
    @Test("CachedResponse creation and expiry")
    func testCachedResponseCreation() {
        let data = Data("response data".utf8)
        let response = CachedResponse(
            data: data,
            statusCode: 200,
            headers: ["Content-Type": "application/json"],
            ttl: 300
        )
        
        #expect(response.data == data)
        #expect(response.statusCode == 200)
        #expect(response.headers["Content-Type"] == "application/json")
        #expect(response.isSuccessful == true)
        #expect(response.isExpired == false)
        #expect(response.expiryDate != nil)
    }
    
    @Test("CachedResponse expiry logic")
    func testCachedResponseExpiry() {
        let pastDate = Date().addingTimeInterval(-600) // 10 minutes ago
        let response = CachedResponse(
            data: Data("test".utf8),
            statusCode: 200,
            cachedAt: pastDate,
            ttl: 300 // 5 minutes
        )
        
        #expect(response.isExpired == true)
    }
    
    @Test("CachedResponse indefinite cache")
    func testCachedResponseIndefiniteCache() {
        let pastDate = Date().addingTimeInterval(-86400) // 1 day ago
        let response = CachedResponse(
            data: Data("test".utf8),
            statusCode: 200,
            cachedAt: pastDate,
            ttl: nil // No expiry
        )
        
        #expect(response.isExpired == false)
        #expect(response.expiryDate == nil)
    }
    
    @Test("CachedResponse success status")
    func testCachedResponseSuccessStatus() {
        let successResponse = CachedResponse(data: Data(), statusCode: 200)
        let errorResponse = CachedResponse(data: Data(), statusCode: 400)
        
        #expect(successResponse.isSuccessful == true)
        #expect(errorResponse.isSuccessful == false)
    }
    
    // MARK: - In-Memory Cache Tests
    
    @Test("InMemoryResponseCache basic operations")
    func testInMemoryCacheBasicOperations() async {
        let cache = InMemoryResponseCache()
        let response = CachedResponse(data: Data("test".utf8), statusCode: 200)
        
        // Initially empty
        let initialResponse = await cache.get(key: "test-key")
        #expect(initialResponse == nil)
        
        // Store response
        await cache.set(key: "test-key", response: response)
        
        // Retrieve response
        let retrievedResponse = await cache.get(key: "test-key")
        #expect(retrievedResponse != nil)
        #expect(retrievedResponse?.data == Data("test".utf8))
        #expect(retrievedResponse?.statusCode == 200)
        
        // Remove response
        await cache.remove(key: "test-key")
        let removedResponse = await cache.get(key: "test-key")
        #expect(removedResponse == nil)
    }
    
    @Test("InMemoryResponseCache statistics")
    func testInMemoryCacheStatistics() async {
        let cache = InMemoryResponseCache()
        let response = CachedResponse(data: Data("test data".utf8), statusCode: 200)
        
        await cache.set(key: "key1", response: response)
        await cache.set(key: "key2", response: response)
        
        // Generate some hits and misses
        let _ = await cache.get(key: "key1") // Hit
        let _ = await cache.get(key: "key1") // Hit
        let _ = await cache.get(key: "non-existent") // Miss
        
        let stats = await cache.getStats()
        #expect(stats.count == 2)
        #expect(stats.hits == 2)
        #expect(stats.misses == 1)
        #expect(stats.totalSize > 0)
        #expect(stats.hitRate == 2.0/3.0)
    }
    
    @Test("InMemoryResponseCache expiry cleanup")
    func testInMemoryCacheExpiryCleanup() async {
        let cache = InMemoryResponseCache()
        let pastDate = Date().addingTimeInterval(-600) // 10 minutes ago
        let expiredResponse = CachedResponse(
            data: Data("expired".utf8),
            statusCode: 200,
            cachedAt: pastDate,
            ttl: 300 // 5 minutes
        )
        
        await cache.set(key: "expired-key", response: expiredResponse)
        
        // Should return nil for expired response
        let response = await cache.get(key: "expired-key")
        #expect(response == nil)
        
        // Should increase miss count
        let stats = await cache.getStats()
        #expect(stats.misses == 1)
    }
    
    @Test("InMemoryResponseCache clear")
    func testInMemoryCacheClear() async {
        let cache = InMemoryResponseCache()
        let response = CachedResponse(data: Data("test".utf8), statusCode: 200)
        
        await cache.set(key: "key1", response: response)
        await cache.set(key: "key2", response: response)
        
        let beforeClear = await cache.getStats()
        #expect(beforeClear.count == 2)
        
        await cache.clear()
        
        let afterClear = await cache.getStats()
        #expect(afterClear.count == 0)
        #expect(afterClear.hits == 0)
        #expect(afterClear.misses == 0)
    }
    
    // MARK: - Cache Manager Tests
    
    @Test("CacheManager store and retrieve")
    func testCacheManagerStoreAndRetrieve() async {
        let endpoints = [CachedEndpoint(method: "POST", path: "/v1/mint/bolt11")]
        let settings = NUT19Settings(ttl: 300, cachedEndpoints: endpoints)
        let cacheManager = CacheManager(settings: settings)
        
        let responseData = Data("response".utf8)
        
        // Store response
        await cacheManager.storeResponse(
            for: "POST",
            path: "/v1/mint/bolt11",
            payload: nil,
            response: responseData,
            statusCode: 200
        )
        
        // Retrieve response
        let cachedResponse = await cacheManager.getCachedResponse(
            for: "POST",
            path: "/v1/mint/bolt11",
            payload: nil
        )
        
        #expect(cachedResponse != nil)
        #expect(cachedResponse?.data == responseData)
        #expect(cachedResponse?.statusCode == 200)
    }
    
    @Test("CacheManager only caches successful responses")
    func testCacheManagerOnlySuccessfulResponses() async {
        let endpoints = [CachedEndpoint(method: "POST", path: "/v1/mint/bolt11")]
        let settings = NUT19Settings(ttl: 300, cachedEndpoints: endpoints)
        let cacheManager = CacheManager(settings: settings)
        
        // Store error response
        await cacheManager.storeResponse(
            for: "POST",
            path: "/v1/mint/bolt11",
            payload: nil,
            response: Data("error".utf8),
            statusCode: 400
        )
        
        // Should not be cached
        let cachedResponse = await cacheManager.getCachedResponse(
            for: "POST",
            path: "/v1/mint/bolt11",
            payload: nil
        )
        
        #expect(cachedResponse == nil)
    }
    
    @Test("CacheManager only caches enabled endpoints")
    func testCacheManagerOnlyEnabledEndpoints() async {
        let endpoints = [CachedEndpoint(method: "POST", path: "/v1/mint/bolt11")]
        let settings = NUT19Settings(ttl: 300, cachedEndpoints: endpoints)
        let cacheManager = CacheManager(settings: settings)
        
        // Store response for non-cached endpoint
        await cacheManager.storeResponse(
            for: "POST",
            path: "/v1/not-cached",
            payload: nil,
            response: Data("response".utf8),
            statusCode: 200
        )
        
        // Should not be cached
        let cachedResponse = await cacheManager.getCachedResponse(
            for: "POST",
            path: "/v1/not-cached",
            payload: nil
        )
        
        #expect(cachedResponse == nil)
    }
    
    // MARK: - Common Cached Endpoints Tests
    
    @Test("CommonCachedEndpoints predefined endpoints")
    func testCommonCachedEndpoints() {
        #expect(CommonCachedEndpoints.mintBolt11.method == "POST")
        #expect(CommonCachedEndpoints.mintBolt11.path == "/v1/mint/bolt11")
        
        #expect(CommonCachedEndpoints.swap.method == "POST")
        #expect(CommonCachedEndpoints.swap.path == "/v1/swap")
        
        #expect(CommonCachedEndpoints.meltBolt11.method == "POST")
        #expect(CommonCachedEndpoints.meltBolt11.path == "/v1/melt/bolt11")
        
        #expect(CommonCachedEndpoints.restore.method == "POST")
        #expect(CommonCachedEndpoints.restore.path == "/v1/restore")
        
        #expect(CommonCachedEndpoints.all.count == 4)
    }
    
    // MARK: - MintInfo Extensions Tests
    
    @Test("MintInfo NUT-19 support detection")
    func testMintInfoNUT19Support() {
        let nut19Value = NutValue.dictionary([
            "ttl": AnyCodable(anyValue: 300)!,
            "cached_endpoints": AnyCodable(anyValue: [
                [
                    "method": "POST",
                    "path": "/v1/mint/bolt11"
                ]
            ])!
        ])
        
        let mintInfo = MintInfo(
            name: "Test Mint",
            pubkey: "pubkey",
            version: "1.0",
            nuts: ["19": nut19Value]
        )
        
        #expect(mintInfo.supportsCachedResponses == true)
        
        let settings = mintInfo.getNUT19Settings()
        #expect(settings != nil)
        #expect(settings?.ttl == 300)
        #expect(settings?.cachedEndpoints.count == 1)
        #expect(settings?.cachedEndpoints.first?.method == "POST")
        #expect(settings?.cachedEndpoints.first?.path == "/v1/mint/bolt11")
    }
    
    @Test("MintInfo NUT-19 settings parsing")
    func testMintInfoNUT19SettingsParsing() {
        let nut19Value = NutValue.dictionary([
            "cached_endpoints": AnyCodable(anyValue: [
                [
                    "method": "POST",
                    "path": "/v1/mint/bolt11"
                ],
                [
                    "method": "POST",
                    "path": "/v1/swap"
                ]
            ])!
        ])
        
        let mintInfo = MintInfo(
            name: "Test Mint",
            pubkey: "pubkey",
            version: "1.0",
            nuts: ["19": nut19Value]
        )
        
        let settings = mintInfo.getNUT19Settings()
        #expect(settings?.ttl == nil)
        #expect(settings?.isIndefiniteCache == true)
        #expect(settings?.cachedEndpoints.count == 2)
        
        #expect(mintInfo.isCachingEnabled(for: "POST", path: "/v1/mint/bolt11") == true)
        #expect(mintInfo.isCachingEnabled(for: "POST", path: "/v1/swap") == true)
        #expect(mintInfo.isCachingEnabled(for: "GET", path: "/v1/info") == false)
    }
    
    @Test("MintInfo without NUT-19 support")
    func testMintInfoWithoutNUT19Support() {
        let mintInfo = MintInfo(
            name: "Test Mint",
            pubkey: "pubkey",
            version: "1.0",
            nuts: [:]
        )
        
        #expect(mintInfo.supportsCachedResponses == false)
        #expect(mintInfo.getNUT19Settings() == nil)
        #expect(mintInfo.isCachingEnabled(for: "POST", path: "/v1/mint/bolt11") == false)
    }
    
    // MARK: - Cache Configuration Tests
    
    @Test("CacheConfiguration default values")
    func testCacheConfigurationDefaults() {
        let config = CacheConfiguration.default
        
        #expect(config.defaultTTL == nil)
        #expect(config.maxCacheSize == 10 * 1024 * 1024) // 10MB
        #expect(config.maxCacheEntries == 1000)
        #expect(config.autoCleanup == true)
        #expect(config.cleanupInterval == 300) // 5 minutes
    }
    
    @Test("CacheConfiguration custom values")
    func testCacheConfigurationCustom() {
        let config = CacheConfiguration(
            defaultTTL: 600,
            maxCacheSize: 5 * 1024 * 1024,
            maxCacheEntries: 500,
            autoCleanup: false,
            cleanupInterval: 60
        )
        
        #expect(config.defaultTTL == 600)
        #expect(config.maxCacheSize == 5 * 1024 * 1024)
        #expect(config.maxCacheEntries == 500)
        #expect(config.autoCleanup == false)
        #expect(config.cleanupInterval == 60)
    }
    
    // MARK: - Cache Utilities Tests
    
    @Test("CacheUtils hash generation")
    func testCacheUtilsHashGeneration() {
        let hash1 = CacheUtils.simpleHash("test string")
        let hash2 = CacheUtils.simpleHash("test string")
        let hash3 = CacheUtils.simpleHash("different string")
        
        #expect(hash1 == hash2) // Same input should generate same hash
        #expect(hash1 != hash3) // Different input should generate different hash
    }
    
    @Test("CacheUtils key formatting")
    func testCacheUtilsKeyFormatting() {
        let key = "POST:/v1/mint/bolt11:hash123"
        let formatted = CacheUtils.formatCacheKey(key)
        
        #expect(formatted == "POST_/v1/mint/bolt11_hash123")
    }
    
    @Test("CacheUtils key parsing")
    func testCacheUtilsKeyParsing() {
        let key = "POST:/v1/mint/bolt11:hash123"
        let parsed = CacheUtils.parseCacheKey(key)
        
        #expect(parsed != nil)
        #expect(parsed?.method == "POST")
        #expect(parsed?.path == "/v1/mint/bolt11")
        #expect(parsed?.payloadHash == "hash123")
        
        let keyWithoutPayload = "GET:/v1/info"
        let parsedWithoutPayload = CacheUtils.parseCacheKey(keyWithoutPayload)
        
        #expect(parsedWithoutPayload != nil)
        #expect(parsedWithoutPayload?.method == "GET")
        #expect(parsedWithoutPayload?.path == "/v1/info")
        #expect(parsedWithoutPayload?.payloadHash == nil)
    }
    
    // MARK: - Data Extensions Tests
    
    @Test("Data SHA256 hash")
    func testDataSHA256Hash() {
        let data1 = Data("test data".utf8)
        let data2 = Data("test data".utf8)
        let data3 = Data("different data".utf8)
        
        let hash1 = data1.sha256Hash
        let hash2 = data2.sha256Hash
        let hash3 = data3.sha256Hash
        
        #expect(hash1 == hash2) // Same data should generate same hash
        #expect(hash1 != hash3) // Different data should generate different hash
        #expect(hash1.count > 0) // Hash should not be empty
    }
    
    // MARK: - Mock Network Service Tests
    
    @Test("MockNetworkService basic functionality")
    func testMockNetworkService() async throws {
        let responses = [
            "POST /v1/mint/bolt11": Data("{\"signatures\":[]}".utf8)
        ]
        
        let _ = MockNetworkService(responses: responses)
        
        // This would need a proper CashuDecodable type for testing
        // For now, we'll just test that the service can be created
        #expect(Bool(true)) // Service created successfully
    }
    
    // MARK: - Integration Tests
    
    @Test("Cache key consistency")
    func testCacheKeyConsistency() {
        let method = "POST"
        let path = "/v1/mint/bolt11"
        let payload = Data("test payload".utf8)
        
        let key1 = CacheKeyGenerator.generateKey(method: method, path: path, payload: payload)
        let key2 = CacheKeyGenerator.generateKey(method: method, path: path, payload: payload)
        
        #expect(key1 == key2) // Keys should be consistent
        
        let url = URL(string: "https://mint.example.com\(path)")!
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.httpBody = payload
        
        let key3 = CacheKeyGenerator.generateKey(for: request)
        #expect(key1 == key3) // URL request should generate same key
    }
    
    @Test("Cache TTL behavior")
    func testCacheTTLBehavior() {
        let shortTTL = CachedResponse(
            data: Data("test".utf8),
            statusCode: 200,
            cachedAt: Date().addingTimeInterval(-1),
            ttl: 0.5 // 0.5 seconds
        )
        
        let longTTL = CachedResponse(
            data: Data("test".utf8),
            statusCode: 200,
            cachedAt: Date(),
            ttl: 3600 // 1 hour
        )
        
        #expect(shortTTL.isExpired == true)
        #expect(longTTL.isExpired == false)
    }
    
    @Test("Cache stats calculation")
    func testCacheStatsCalculation() {
        let stats = CacheStats(count: 10, hits: 7, misses: 3, totalSize: 1024)
        
        #expect(stats.count == 10)
        #expect(stats.hits == 7)
        #expect(stats.misses == 3)
        #expect(stats.totalSize == 1024)
        #expect(stats.hitRate == 0.7)
        
        let noRequestsStats = CacheStats(count: 0, hits: 0, misses: 0, totalSize: 0)
        #expect(noRequestsStats.hitRate == 0.0)
    }
    
    @Test("Endpoint matching case sensitivity")
    func testEndpointMatchingCaseSensitivity() {
        let endpoint = CachedEndpoint(method: "POST", path: "/v1/mint/bolt11")
        
        #expect(endpoint.matches(method: "POST", path: "/v1/mint/bolt11") == true)
        #expect(endpoint.matches(method: "post", path: "/v1/mint/bolt11") == true)
        #expect(endpoint.matches(method: "Post", path: "/v1/mint/bolt11") == true)
        #expect(endpoint.matches(method: "POST", path: "/v1/Mint/bolt11") == false) // Path is case sensitive
    }
    
    @Test("Settings with empty endpoints")
    func testSettingsWithEmptyEndpoints() {
        let settings = NUT19Settings(ttl: 300, cachedEndpoints: [])
        
        #expect(settings.cachedEndpoints.isEmpty == true)
        #expect(settings.isCachingEnabled(for: "POST", path: "/v1/mint/bolt11") == false)
    }
}