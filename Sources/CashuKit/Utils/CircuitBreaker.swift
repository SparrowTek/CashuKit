import Foundation

public struct CircuitBreakerConfiguration: Sendable {
    public let failureThreshold: Int
    public let openTimeout: TimeInterval
    public let halfOpenMaxAttempts: Int

    public init(failureThreshold: Int = 5, openTimeout: TimeInterval = 15.0, halfOpenMaxAttempts: Int = 1) {
        self.failureThreshold = failureThreshold
        self.openTimeout = openTimeout
        self.halfOpenMaxAttempts = halfOpenMaxAttempts
    }

    public static let `default` = CircuitBreakerConfiguration()
}

public enum CircuitBreakerState: Sendable, Equatable {
    case closed(failureCount: Int)
    case open(openedAt: Date)
    case halfOpen(remainingAllowance: Int)
}

public actor EndpointCircuitBreaker {
    private var state: CircuitBreakerState = .closed(failureCount: 0)
    private let configuration: CircuitBreakerConfiguration

    public init(configuration: CircuitBreakerConfiguration = .default) {
        self.configuration = configuration
    }

    public func currentState() -> CircuitBreakerState { state }

    public func allowRequest(now: Date = Date()) -> Bool {
        switch state {
        case .closed:
            return true
        case .open(let openedAt):
            if now.timeIntervalSince(openedAt) >= configuration.openTimeout {
                state = .halfOpen(remainingAllowance: configuration.halfOpenMaxAttempts)
                return true
            }
            return false
        case .halfOpen(let remaining):
            if remaining > 0 {
                state = .halfOpen(remainingAllowance: remaining - 1)
                return true
            } else {
                return false
            }
        }
    }

    public func recordSuccess() {
        // Any success resets the breaker
        state = .closed(failureCount: 0)
    }

    public func recordFailure(now: Date = Date()) {
        switch state {
        case .closed(let failureCount):
            let newCount = failureCount + 1
            if newCount >= configuration.failureThreshold {
                state = .open(openedAt: now)
            } else {
                state = .closed(failureCount: newCount)
            }
        case .halfOpen:
            // On failure while half-open, trip to open
            state = .open(openedAt: now)
        case .open:
            // remain open; update timestamp to extend window
            state = .open(openedAt: now)
        }
    }
}


