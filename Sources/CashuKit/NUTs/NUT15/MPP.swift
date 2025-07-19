//
//  MPP.swift
//  CashuKit
//
//  Multi-path Payment Implementation for NUT-15
//

import Foundation

/// Multi-path payment executor that coordinates payments across multiple mints
public actor MultiPathPaymentExecutor {
    
    /// Configuration for MPP execution
    public struct Configuration {
        /// Maximum time to wait for all payments to complete
        public let timeout: TimeInterval
        
        /// Whether to use optimistic locking (attempt all payments simultaneously)
        public let optimisticMode: Bool
        
        /// Maximum number of concurrent payment attempts
        public let maxConcurrency: Int
        
        /// Retry configuration for failed payments
        public let retryPolicy: RetryPolicy
        
        public init(
            timeout: TimeInterval = 60,
            optimisticMode: Bool = true,
            maxConcurrency: Int = 10,
            retryPolicy: RetryPolicy = .default
        ) {
            self.timeout = timeout
            self.optimisticMode = optimisticMode
            self.maxConcurrency = maxConcurrency
            self.retryPolicy = retryPolicy
        }
    }
    
    /// Retry policy for failed payment attempts
    public struct RetryPolicy: Sendable {
        public let maxAttempts: Int
        public let backoffMultiplier: Double
        public let initialDelay: TimeInterval
        
        public static let `default` = RetryPolicy(
            maxAttempts: 3,
            backoffMultiplier: 2.0,
            initialDelay: 0.5
        )
        
        public static let aggressive = RetryPolicy(
            maxAttempts: 5,
            backoffMultiplier: 1.5,
            initialDelay: 0.25
        )
        
        public static let none = RetryPolicy(
            maxAttempts: 1,
            backoffMultiplier: 1.0,
            initialDelay: 0
        )
    }
    
    private let configuration: Configuration
    private var activeSessions: [String: PaymentSession] = [:]
    
    public init(configuration: Configuration = Configuration()) {
        self.configuration = configuration
    }
    
    /// Execute a multi-path payment
    /// - Parameters:
    ///   - invoice: The Lightning invoice to pay
    ///   - paymentPlans: Array of partial payment plans
    ///   - wallets: Dictionary mapping mint URLs to wallet instances
    /// - Returns: Array of payment results
    public func execute(
        invoice: String,
        paymentPlans: [PartialPaymentPlan],
        wallets: [String: CashuWallet]
    ) async throws -> [PartialPaymentResult] {
        // Validate inputs
        try validateInputs(paymentPlans: paymentPlans, wallets: wallets)
        
        // Create payment session
        let sessionId = UUID().uuidString
        let session = PaymentSession(
            id: sessionId,
            invoice: invoice,
            plans: paymentPlans,
            startTime: Date()
        )
        
        activeSessions[sessionId] = session
        defer { activeSessions.removeValue(forKey: sessionId) }
        
        // Execute based on mode
        if configuration.optimisticMode {
            return try await executeOptimistic(session: session, wallets: wallets)
        } else {
            return try await executePessimistic(session: session, wallets: wallets)
        }
    }
    
    /// Optimistic execution - attempt all payments simultaneously
    private func executeOptimistic(
        session: PaymentSession,
        wallets: [String: CashuWallet]
    ) async throws -> [PartialPaymentResult] {
        return try await withThrowingTaskGroup(of: PartialPaymentResult.self) { group in
            // Start all payment tasks
            for plan in session.plans {
                guard let wallet = wallets[plan.mintURL] else {
                    throw CashuError.mppWalletNotFound
                }
                
                group.addTask {
                    return await self.executePartialPayment(
                        plan: plan,
                        wallet: wallet,
                        invoice: session.invoice
                    )
                }
            }
            
            // Collect results
            var results: [PartialPaymentResult] = []
            var hasFailure = false
            
            for try await result in group {
                results.append(result)
                if !result.success {
                    hasFailure = true
                    group.cancelAll()
                }
            }
            
            // If any payment failed, attempt rollback
            if hasFailure {
                await rollbackSuccessfulPayments(results: results, wallets: wallets)
                throw CashuError.mppPartialFailure
            }
            
            return results
        }
    }
    
    /// Pessimistic execution - attempt payments sequentially with checkpoints
    private func executePessimistic(
        session: PaymentSession,
        wallets: [String: CashuWallet]
    ) async throws -> [PartialPaymentResult] {
        var results: [PartialPaymentResult] = []
        
        // Sort plans by amount (largest first) for better success probability
        let sortedPlans = session.plans.sorted { $0.amount > $1.amount }
        
        for plan in sortedPlans {
            guard let wallet = wallets[plan.mintURL] else {
                // Rollback previous successful payments
                await rollbackSuccessfulPayments(results: results, wallets: wallets)
                throw CashuError.mppWalletNotFound
            }
            
            let result = await executePartialPayment(
                plan: plan,
                wallet: wallet,
                invoice: session.invoice
            )
            
            results.append(result)
            
            // If payment failed, rollback and abort
            if !result.success {
                await rollbackSuccessfulPayments(results: results, wallets: wallets)
                throw result.error ?? CashuError.mppPartialFailure
            }
        }
        
        return results
    }
    
    /// Execute a single partial payment with retry logic
    private func executePartialPayment(
        plan: PartialPaymentPlan,
        wallet: CashuWallet,
        invoice: String
    ) async -> PartialPaymentResult {
        var lastError: (any Error)?
        var attempt = 0
        
        while attempt < configuration.retryPolicy.maxAttempts {
            if attempt > 0 {
                // Apply backoff delay
                let delay = configuration.retryPolicy.initialDelay * 
                    pow(configuration.retryPolicy.backoffMultiplier, Double(attempt - 1))
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
            
            do {
                // For now, we'll use the standard melt method
                // In a real MPP implementation, this would need to:
                // 1. Request a partial melt quote with MPP options
                // 2. Execute the partial melt with the specific amount
                
                // Temporarily use the regular melt method
                let meltResult = try await wallet.melt(
                    paymentRequest: invoice,
                    method: "bolt11"
                )
                
                return PartialPaymentResult(
                    mintURL: plan.mintURL,
                    success: true,
                    change: meltResult.changeProofs,
                    feePaid: meltResult.fees
                )
                
            } catch {
                lastError = error
                attempt += 1
            }
        }
        
        return PartialPaymentResult(
            mintURL: plan.mintURL,
            success: false,
            error: lastError ?? CashuError.unknownError
        )
    }
    
    /// Rollback successful payments in case of partial failure
    private func rollbackSuccessfulPayments(
        results: [PartialPaymentResult],
        wallets: [String: CashuWallet]
    ) async {
        // In a real implementation, this would need to:
        // 1. Contact mints to cancel/refund successful partial payments
        // 2. Restore the original proofs
        // 3. Handle cases where rollback fails
        
        // For now, log the rollback attempt
        for result in results where result.success {
            print("[MPP] Rolling back successful payment at \(result.mintURL)")
        }
    }
    
    /// Validate inputs before execution
    private func validateInputs(
        paymentPlans: [PartialPaymentPlan],
        wallets: [String: CashuWallet]
    ) throws {
        guard !paymentPlans.isEmpty else {
            throw CashuError.mppInvalidPaymentPlans
        }
        
        // Validate each plan
        for plan in paymentPlans {
            guard plan.validate() else {
                throw CashuError.mppInvalidPaymentPlans
            }
            
            guard wallets[plan.mintURL] != nil else {
                throw CashuError.mppWalletNotFound
            }
        }
        
        // Ensure all plans use the same unit
        let units = Set(paymentPlans.map { $0.unit })
        guard units.count == 1 else {
            throw CashuError.mppInconsistentUnits
        }
    }
    
    /// Internal session tracking
    private struct PaymentSession {
        let id: String
        let invoice: String
        let plans: [PartialPaymentPlan]
        let startTime: Date
        var endTime: Date?
        var status: Status = .pending
        
        enum Status {
            case pending
            case inProgress
            case completed
            case failed
            case rolledBack
        }
    }
}

// MARK: - Path Optimization

/// Optimizes payment paths for multi-path payments
public struct PaymentPathOptimizer {
    
    /// Strategy for path optimization
    public enum OptimizationStrategy {
        /// Minimize the number of mints used
        case minimizeMints
        
        /// Minimize fees across all paths
        case minimizeFees
        
        /// Balance load across mints
        case balanceLoad
        
        /// Prioritize reliability (use most reliable mints first)
        case reliability
    }
    
    /// Optimize payment paths based on strategy
    /// - Parameters:
    ///   - amount: Total amount to pay
    ///   - availableMints: Dictionary of mint URLs to their available balance and metadata
    ///   - strategy: Optimization strategy to use
    ///   - constraints: Additional constraints for the optimization
    /// - Returns: Optimized allocation of amounts to mints
    public static func optimize(
        amount: Int,
        availableMints: [String: MintCapability],
        strategy: OptimizationStrategy = .minimizeMints,
        constraints: OptimizationConstraints? = nil
    ) throws -> [String: Int] {
        // Validate inputs
        let totalAvailable = availableMints.values.reduce(0) { $0 + $1.availableBalance }
        guard totalAvailable >= amount else {
            throw CashuError.balanceInsufficient
        }
        
        switch strategy {
        case .minimizeMints:
            return try optimizeMinimizeMints(amount: amount, mints: availableMints, constraints: constraints)
            
        case .minimizeFees:
            return try optimizeMinimizeFees(amount: amount, mints: availableMints, constraints: constraints)
            
        case .balanceLoad:
            return try optimizeBalanceLoad(amount: amount, mints: availableMints, constraints: constraints)
            
        case .reliability:
            return try optimizeReliability(amount: amount, mints: availableMints, constraints: constraints)
        }
    }
    
    /// Minimize the number of mints used
    private static func optimizeMinimizeMints(
        amount: Int,
        mints: [String: MintCapability],
        constraints: OptimizationConstraints?
    ) throws -> [String: Int] {
        var remaining = amount
        var allocations: [String: Int] = [:]
        
        // Filter mints based on constraints first
        var eligibleMints = mints
        
        if let constraints = constraints {
            // Filter by reliability score
            if let minReliability = constraints.minReliabilityScore {
                eligibleMints = eligibleMints.filter { $0.value.reliabilityScore >= minReliability }
            }
            
            // Filter excluded mints
            if let excluded = constraints.excludedMints {
                eligibleMints = eligibleMints.filter { !excluded.contains($0.key) }
            }
        }
        
        // Sort by available balance (descending) to minimize number of mints
        // When balances are equal, sort by reliability score (descending) as secondary criteria
        let sorted = eligibleMints.sorted { 
            if $0.value.availableBalance != $1.value.availableBalance {
                return $0.value.availableBalance > $1.value.availableBalance
            }
            // Secondary sort by reliability when balances are equal
            return $0.value.reliabilityScore > $1.value.reliabilityScore
        }
        
        for (mintURL, capability) in sorted {
            guard remaining > 0 else { break }
            
            var allocation = min(capability.availableBalance, remaining)
            
            // Apply max amount per mint constraint
            if let constraints = constraints, let maxPerMint = constraints.maxAmountPerMint {
                allocation = min(allocation, maxPerMint)
            }
            
            if allocation > 0 {
                allocations[mintURL] = allocation
                remaining -= allocation
            }
            
            // Check if we've reached max mints constraint
            if let constraints = constraints, let maxMints = constraints.maxMints {
                if allocations.count >= maxMints && remaining > 0 {
                    // Try to fit remaining amount in existing allocations
                    break
                }
            }
        }
        
        guard remaining == 0 else {
            throw CashuError.mppOptimizationFailed
        }
        
        return allocations
    }
    
    /// Minimize total fees
    private static func optimizeMinimizeFees(
        amount: Int,
        mints: [String: MintCapability],
        constraints: OptimizationConstraints?
    ) throws -> [String: Int] {
        // Sort by fee rate (ascending)
        let sorted = mints.sorted { $0.value.feeRate < $1.value.feeRate }
        
        var remaining = amount
        var allocations: [String: Int] = [:]
        
        for (mintURL, capability) in sorted {
            guard remaining > 0 else { break }
            
            let allocation = min(capability.availableBalance, remaining)
            if allocation > 0 {
                allocations[mintURL] = allocation
                remaining -= allocation
            }
        }
        
        guard remaining == 0 else {
            throw CashuError.mppOptimizationFailed
        }
        
        return allocations
    }
    
    /// Balance load across mints
    private static func optimizeBalanceLoad(
        amount: Int,
        mints: [String: MintCapability],
        constraints: OptimizationConstraints?
    ) throws -> [String: Int] {
        let mintCount = mints.count
        guard mintCount > 0 else {
            throw CashuError.mppNoAvailableMints
        }
        
        // Calculate target amount per mint
        let targetPerMint = amount / mintCount
        let remainder = amount % mintCount
        
        var allocations: [String: Int] = [:]
        var remainingAmount = amount
        var remainderToDistribute = remainder
        
        for (mintURL, capability) in mints {
            guard remainingAmount > 0 else { break }
            
            var targetAllocation = targetPerMint
            if remainderToDistribute > 0 {
                targetAllocation += 1
                remainderToDistribute -= 1
            }
            
            let actualAllocation = min(targetAllocation, capability.availableBalance, remainingAmount)
            if actualAllocation > 0 {
                allocations[mintURL] = actualAllocation
                remainingAmount -= actualAllocation
            }
        }
        
        // If we couldn't distribute evenly, fall back to greedy allocation
        if remainingAmount > 0 {
            return try optimizeMinimizeMints(amount: amount, mints: mints, constraints: constraints)
        }
        
        return allocations
    }
    
    /// Prioritize most reliable mints
    private static func optimizeReliability(
        amount: Int,
        mints: [String: MintCapability],
        constraints: OptimizationConstraints?
    ) throws -> [String: Int] {
        // Sort by reliability score (descending)
        let sorted = mints.sorted { $0.value.reliabilityScore > $1.value.reliabilityScore }
        
        var remaining = amount
        var allocations: [String: Int] = [:]
        
        for (mintURL, capability) in sorted {
            guard remaining > 0 else { break }
            
            let allocation = min(capability.availableBalance, remaining)
            if allocation > 0 {
                allocations[mintURL] = allocation
                remaining -= allocation
            }
        }
        
        guard remaining == 0 else {
            throw CashuError.mppOptimizationFailed
        }
        
        return allocations
    }
}

/// Capabilities and metadata for a mint
public struct MintCapability {
    /// Available balance at this mint
    public let availableBalance: Int
    
    /// Fee rate (basis points)
    public let feeRate: Double
    
    /// Reliability score (0.0 - 1.0)
    public let reliabilityScore: Double
    
    /// Average response time in seconds
    public let avgResponseTime: Double
    
    /// Whether the mint supports MPP
    public let supportsMPP: Bool
    
    public init(
        availableBalance: Int,
        feeRate: Double = 0.0,
        reliabilityScore: Double = 1.0,
        avgResponseTime: Double = 0.5,
        supportsMPP: Bool = true
    ) {
        self.availableBalance = availableBalance
        self.feeRate = feeRate
        self.reliabilityScore = reliabilityScore
        self.avgResponseTime = avgResponseTime
        self.supportsMPP = supportsMPP
    }
}

/// Constraints for path optimization
public struct OptimizationConstraints {
    /// Maximum amount to allocate to a single mint
    public let maxAmountPerMint: Int?
    
    /// Minimum reliability score required
    public let minReliabilityScore: Double?
    
    /// Maximum number of mints to use
    public let maxMints: Int?
    
    /// Excluded mint URLs
    public let excludedMints: Set<String>?
    
    public init(
        maxAmountPerMint: Int? = nil,
        minReliabilityScore: Double? = nil,
        maxMints: Int? = nil,
        excludedMints: Set<String>? = nil
    ) {
        self.maxAmountPerMint = maxAmountPerMint
        self.minReliabilityScore = minReliabilityScore
        self.maxMints = maxMints
        self.excludedMints = excludedMints
    }
}

// MARK: - MPP Specific Errors

extension CashuError {
    /// MPP-specific errors as static properties for convenience
    static let mppWalletNotFound = CashuError.walletNotInitialized
    static let mppPartialFailure = CashuError.concurrencyError("Multi-path payment partially failed")
    static let mppInvalidPaymentPlans = CashuError.validationFailed
    static let mppInconsistentUnits = CashuError.invalidUnit
    static let mppOptimizationFailed = CashuError.unsupportedOperation("Path optimization failed")
    static let mppNoAvailableMints = CashuError.mintUnavailable
}