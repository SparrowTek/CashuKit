//
//  RateLimiter.swift
//  CashuKit
//
//  Rate limiting for mint requests
//

import Foundation

// MARK: - Rate Limit Configuration

public struct RateLimitConfiguration: Sendable {
    public let maxRequests: Int
    public let timeWindow: TimeInterval
    public let burstCapacity: Int
    
    public init(
        maxRequests: Int = 60,
        timeWindow: TimeInterval = 60.0,
        burstCapacity: Int = 10
    ) {
        self.maxRequests = maxRequests
        self.timeWindow = timeWindow
        self.burstCapacity = burstCapacity
    }
    
    public static let `default` = RateLimitConfiguration()
    public static let strict = RateLimitConfiguration(maxRequests: 30, timeWindow: 60.0, burstCapacity: 5)
    public static let relaxed = RateLimitConfiguration(maxRequests: 120, timeWindow: 60.0, burstCapacity: 20)
}

// MARK: - Rate Limiter

public actor RateLimiter {
    private let configuration: RateLimitConfiguration
    private var requestTimes: [Date] = []
    private var tokens: Double
    private var lastRefillTime: Date
    
    public init(configuration: RateLimitConfiguration = .default) {
        self.configuration = configuration
        self.tokens = Double(configuration.burstCapacity)
        self.lastRefillTime = Date()
    }
    
    /// Check if a request is allowed under the rate limit
    public func shouldAllowRequest() -> Bool {
        refillTokens()
        cleanupOldRequests()
        
        // Check sliding window
        let recentRequests = requestTimes.filter { request in
            request.timeIntervalSinceNow > -configuration.timeWindow
        }
        
        if recentRequests.count >= configuration.maxRequests {
            logger.warning("Rate limit exceeded: \(recentRequests.count)/\(configuration.maxRequests) requests in window", category: .network)
            return false
        }
        
        // Check token bucket for burst control
        if tokens < 1.0 {
            logger.warning("Rate limit: No tokens available for burst", category: .network)
            return false
        }
        
        return true
    }
    
    /// Record a request and consume a token
    public func recordRequest() {
        requestTimes.append(Date())
        tokens = max(0, tokens - 1)
        logger.debug("Rate limit: Recorded request, tokens remaining: \(Int(tokens))", category: .network)
    }
    
    /// Wait until a request can be made
    public func waitForAvailability() async throws {
        while !shouldAllowRequest() {
            let waitTime = calculateWaitTime()
            logger.info("Rate limit: Waiting \(String(format: "%.2f", waitTime))s before next request", category: .network)
            try await Task.sleep(nanoseconds: UInt64(waitTime * 1_000_000_000))
        }
    }
    
    /// Reset the rate limiter
    public func reset() {
        requestTimes.removeAll()
        tokens = Double(configuration.burstCapacity)
        lastRefillTime = Date()
        logger.debug("Rate limiter reset", category: .network)
    }
    
    /// Get current rate limit status
    public func getStatus() -> RateLimitStatus {
        refillTokens()
        cleanupOldRequests()
        
        let recentRequests = requestTimes.filter { request in
            request.timeIntervalSinceNow > -configuration.timeWindow
        }
        
        return RateLimitStatus(
            requestsUsed: recentRequests.count,
            requestsLimit: configuration.maxRequests,
            tokensAvailable: Int(tokens),
            tokenCapacity: configuration.burstCapacity,
            nextResetTime: calculateNextResetTime()
        )
    }
    
    private func refillTokens() {
        let now = Date()
        let timeSinceLastRefill = now.timeIntervalSince(lastRefillTime)
        
        // Refill tokens based on time elapsed
        let tokensToAdd = (timeSinceLastRefill / configuration.timeWindow) * Double(configuration.maxRequests)
        tokens = min(Double(configuration.burstCapacity), tokens + tokensToAdd)
        
        lastRefillTime = now
    }
    
    private func cleanupOldRequests() {
        let cutoffTime = Date().addingTimeInterval(-configuration.timeWindow)
        requestTimes.removeAll { $0 < cutoffTime }
    }
    
    private func calculateWaitTime() -> TimeInterval {
        // Find the oldest request that would fall outside the window
        let cutoffTime = Date().addingTimeInterval(-configuration.timeWindow)
        
        if let oldestRequest = requestTimes.first(where: { $0 > cutoffTime }) {
            let waitTime = oldestRequest.timeIntervalSinceNow + configuration.timeWindow + 0.1
            return max(0, waitTime)
        }
        
        // If no requests in window, check token refill time
        let tokensNeeded = 1.0 - tokens
        if tokensNeeded > 0 {
            let refillTime = (tokensNeeded / Double(configuration.maxRequests)) * configuration.timeWindow
            return max(0.1, refillTime)
        }
        
        return 0.1 // Default minimal wait
    }
    
    private func calculateNextResetTime() -> Date {
        if let oldestRequest = requestTimes.first {
            return oldestRequest.addingTimeInterval(configuration.timeWindow)
        }
        return Date().addingTimeInterval(configuration.timeWindow)
    }
}

// MARK: - Rate Limit Status

public struct RateLimitStatus: Sendable {
    public let requestsUsed: Int
    public let requestsLimit: Int
    public let tokensAvailable: Int
    public let tokenCapacity: Int
    public let nextResetTime: Date
    
    public var requestsRemaining: Int {
        return max(0, requestsLimit - requestsUsed)
    }
    
    public var isLimited: Bool {
        return requestsUsed >= requestsLimit || tokensAvailable <= 0
    }
    
    public var percentageUsed: Double {
        return Double(requestsUsed) / Double(requestsLimit) * 100
    }
}

// MARK: - Per-Endpoint Rate Limiting

public actor EndpointRateLimiter {
    private var limiters: [String: RateLimiter] = [:]
    private let defaultConfiguration: RateLimitConfiguration
    private let endpointConfigurations: [String: RateLimitConfiguration]
    
    public init(
        defaultConfiguration: RateLimitConfiguration = .default,
        endpointConfigurations: [String: RateLimitConfiguration] = [:]
    ) {
        self.defaultConfiguration = defaultConfiguration
        self.endpointConfigurations = endpointConfigurations
    }
    
    public func shouldAllowRequest(for endpoint: String) async -> Bool {
        let limiter = getLimiter(for: endpoint)
        return await limiter.shouldAllowRequest()
    }
    
    public func recordRequest(for endpoint: String) async {
        let limiter = getLimiter(for: endpoint)
        await limiter.recordRequest()
    }
    
    public func waitForAvailability(for endpoint: String) async throws {
        let limiter = getLimiter(for: endpoint)
        try await limiter.waitForAvailability()
    }
    
    public func getStatus(for endpoint: String) async -> RateLimitStatus {
        let limiter = getLimiter(for: endpoint)
        return await limiter.getStatus()
    }
    
    public func reset(endpoint: String? = nil) async {
        if let endpoint = endpoint {
            let limiter = getLimiter(for: endpoint)
            await limiter.reset()
        } else {
            for (_, limiter) in limiters {
                await limiter.reset()
            }
        }
    }
    
    private func getLimiter(for endpoint: String) -> RateLimiter {
        if let limiter = limiters[endpoint] {
            return limiter
        }
        
        let configuration = endpointConfigurations[endpoint] ?? defaultConfiguration
        let limiter = RateLimiter(configuration: configuration)
        limiters[endpoint] = limiter
        return limiter
    }
}

// MARK: - Rate Limited Network Service

public protocol RateLimitedNetworkService: NetworkService {
    var rateLimiter: EndpointRateLimiter { get }
}

extension RateLimitedNetworkService {
    public func executeWithRateLimit<T: CashuCodabale>(
        method: String,
        path: String,
        payload: Data? = nil
    ) async throws -> T {
        // Wait for rate limit availability
        try await rateLimiter.waitForAvailability(for: path)
        
        // Record the request
        await rateLimiter.recordRequest(for: path)
        
        // Execute the request
        return try await execute(method: method, path: path, payload: payload)
    }
}