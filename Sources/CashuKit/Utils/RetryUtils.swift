//
//  RetryUtils.swift
//  CashuKit
//
//  Retry logic utilities for network operations
//

import Foundation

// MARK: - Retry Configuration

/// Configuration for retry operations
public struct RetryConfiguration: Sendable {
    public let maxAttempts: Int
    public let baseDelay: TimeInterval
    public let maxDelay: TimeInterval
    public let backoffMultiplier: Double
    public let jitter: Bool
    
    /// Default retry configuration
    public static let `default` = RetryConfiguration(
        maxAttempts: 3,
        baseDelay: 1.0,
        maxDelay: 30.0,
        backoffMultiplier: 2.0,
        jitter: true
    )
    
    /// Network operation retry configuration
    public static let networkOperation = RetryConfiguration(
        maxAttempts: 3,
        baseDelay: 0.5,
        maxDelay: 10.0,
        backoffMultiplier: 1.5,
        jitter: true
    )
    
    /// Critical operation retry configuration
    public static let criticalOperation = RetryConfiguration(
        maxAttempts: 5,
        baseDelay: 2.0,
        maxDelay: 60.0,
        backoffMultiplier: 2.0,
        jitter: false
    )
    
    public init(
        maxAttempts: Int,
        baseDelay: TimeInterval,
        maxDelay: TimeInterval,
        backoffMultiplier: Double,
        jitter: Bool
    ) {
        self.maxAttempts = max(1, maxAttempts)
        self.baseDelay = max(0.1, baseDelay)
        self.maxDelay = max(baseDelay, maxDelay)
        self.backoffMultiplier = max(1.0, backoffMultiplier)
        self.jitter = jitter
    }
}

// MARK: - Retry Policy

/// Policy for determining if an error should be retried
public protocol RetryPolicy: Sendable {
    /// Check if the error should be retried
    /// - Parameters:
    ///   - error: The error that occurred
    ///   - attempt: Current attempt number (1-based)
    /// - Returns: True if should retry, false otherwise
    func shouldRetry(error: any Error, attempt: Int) -> Bool
}

/// Default retry policy for network operations
public struct NetworkRetryPolicy: RetryPolicy {
    public init() {}
    
    public func shouldRetry(error: any Error, attempt: Int) -> Bool {
        // Don't retry client errors (4xx) or validation errors
        if let cashuError = error as? CashuError {
            switch cashuError {
            case .networkError:
                return true
            case .mintUnavailable:
                return true
            case .rateLimitExceeded:
                return true
            case .operationTimeout:
                return true
            case .invalidMintURL:
                return false
            case .invalidTokenFormat:
                return false
            case .validationFailed:
                return false
            case .httpError(_, let code):
                // Retry on 5xx errors, not on 4xx
                return code >= 500
            default:
                return false
            }
        }
        
        // Retry on URL errors
        if let urlError = error as? URLError {
            switch urlError.code {
            case .timedOut:
                return true
            case .cannotConnectToHost:
                return true
            case .networkConnectionLost:
                return true
            case .notConnectedToInternet:
                return true
            case .dnsLookupFailed:
                return true
            case .badURL:
                return false
            case .unsupportedURL:
                return false
            default:
                return true
            }
        }
        
        return true
    }
}

/// Strict retry policy (only retry on specific errors)
public struct StrictRetryPolicy: RetryPolicy {
    public init() {}
    
    public func shouldRetry(error: any Error, attempt: Int) -> Bool {
        if let cashuError = error as? CashuError {
            switch cashuError {
            case .networkError:
                return true
            case .mintUnavailable:
                return true
            case .operationTimeout:
                return true
            default:
                return false
            }
        }
        
        if let urlError = error as? URLError {
            switch urlError.code {
            case .timedOut:
                return true
            case .cannotConnectToHost:
                return true
            case .networkConnectionLost:
                return true
            default:
                return false
            }
        }
        
        return false
    }
}

// MARK: - Retry Utilities

/// Utility functions for retry operations
public struct RetryUtils: Sendable {
    
    /// Execute operation with retry logic
    /// - Parameters:
    ///   - configuration: Retry configuration
    ///   - policy: Retry policy
    ///   - operation: Operation to execute
    /// - Returns: Operation result
    /// - Throws: Last error if all attempts fail
    public static func withRetry<T>(
        configuration: RetryConfiguration = .default,
        policy: any RetryPolicy = NetworkRetryPolicy(),
        operation: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        var lastError: (any Error)?
        
        for attempt in 1...configuration.maxAttempts {
            do {
                return try await operation()
            } catch {
                lastError = error
                
                // Check if we should retry
                guard attempt < configuration.maxAttempts && policy.shouldRetry(error: error, attempt: attempt) else {
                    break
                }
                
                // Calculate delay
                let delay = calculateDelay(
                    attempt: attempt,
                    configuration: configuration
                )
                
                // Wait before retry
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }
        
        throw lastError ?? CashuError.operationTimeout
    }
    
    /// Execute operation with exponential backoff
    /// - Parameters:
    ///   - maxAttempts: Maximum number of attempts
    ///   - baseDelay: Base delay in seconds
    ///   - maxDelay: Maximum delay in seconds
    ///   - operation: Operation to execute
    /// - Returns: Operation result
    /// - Throws: Last error if all attempts fail
    public static func withExponentialBackoff<T>(
        maxAttempts: Int = 3,
        baseDelay: TimeInterval = 1.0,
        maxDelay: TimeInterval = 30.0,
        operation: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        let configuration = RetryConfiguration(
            maxAttempts: maxAttempts,
            baseDelay: baseDelay,
            maxDelay: maxDelay,
            backoffMultiplier: 2.0,
            jitter: true
        )
        
        return try await withRetry(
            configuration: configuration,
            policy: NetworkRetryPolicy(),
            operation: operation
        )
    }
    
    /// Execute operation with linear backoff
    /// - Parameters:
    ///   - maxAttempts: Maximum number of attempts
    ///   - delay: Fixed delay between attempts
    ///   - operation: Operation to execute
    /// - Returns: Operation result
    /// - Throws: Last error if all attempts fail
    public static func withLinearBackoff<T>(
        maxAttempts: Int = 3,
        delay: TimeInterval = 1.0,
        operation: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        let configuration = RetryConfiguration(
            maxAttempts: maxAttempts,
            baseDelay: delay,
            maxDelay: delay,
            backoffMultiplier: 1.0,
            jitter: false
        )
        
        return try await withRetry(
            configuration: configuration,
            policy: NetworkRetryPolicy(),
            operation: operation
        )
    }
    
    /// Calculate delay for retry attempt
    /// - Parameters:
    ///   - attempt: Current attempt number (1-based)
    ///   - configuration: Retry configuration
    /// - Returns: Delay in seconds
    private static func calculateDelay(
        attempt: Int,
        configuration: RetryConfiguration
    ) -> TimeInterval {
        // Calculate exponential backoff delay
        let exponentialDelay = configuration.baseDelay * pow(configuration.backoffMultiplier, Double(attempt - 1))
        
        // Apply maximum delay limit
        var delay = min(exponentialDelay, configuration.maxDelay)
        
        // Add jitter to prevent thundering herd
        if configuration.jitter {
            let jitterAmount = delay * 0.1 // 10% jitter
            let randomJitter = Double.random(in: -jitterAmount...jitterAmount)
            delay += randomJitter
        }
        
        return max(0.1, delay) // Minimum 100ms delay
    }
}

// MARK: - Retry Extensions

// MARK: - Async Extensions

extension Task where Success == Never, Failure == Never {
    /// Sleep for a given time interval
    /// - Parameter interval: Time interval in seconds
    static func sleep(interval: TimeInterval) async throws {
        let nanoseconds = UInt64(interval * 1_000_000_000)
        try await Task.sleep(nanoseconds: nanoseconds)
    }
}

// MARK: - Convenient Retry Functions

/// Retry a network operation with sensible defaults
/// - Parameter operation: Network operation to retry
/// - Returns: Operation result
/// - Throws: Last error if all attempts fail
public func retryNetworkOperation<T>(
    _ operation: @escaping @Sendable () async throws -> T
) async throws -> T {
    return try await RetryUtils.withRetry(
        configuration: .networkOperation,
        policy: NetworkRetryPolicy(),
        operation: operation
    )
}

/// Retry a critical operation with more attempts
/// - Parameter operation: Critical operation to retry
/// - Returns: Operation result
/// - Throws: Last error if all attempts fail
public func retryCriticalOperation<T>(
    _ operation: @escaping @Sendable () async throws -> T
) async throws -> T {
    return try await RetryUtils.withRetry(
        configuration: .criticalOperation,
        policy: StrictRetryPolicy(),
        operation: operation
    )
}

/// Retry with custom configuration
/// - Parameters:
///   - maxAttempts: Maximum number of attempts
///   - baseDelay: Base delay between attempts
///   - operation: Operation to retry
/// - Returns: Operation result
/// - Throws: Last error if all attempts fail
public func retryWithCustomConfig<T>(
    maxAttempts: Int,
    baseDelay: TimeInterval,
    _ operation: @escaping @Sendable () async throws -> T
) async throws -> T {
    let configuration = RetryConfiguration(
        maxAttempts: maxAttempts,
        baseDelay: baseDelay,
        maxDelay: baseDelay * 10,
        backoffMultiplier: 1.5,
        jitter: true
    )
    
    return try await RetryUtils.withRetry(
        configuration: configuration,
        policy: NetworkRetryPolicy(),
        operation: operation
    )
}