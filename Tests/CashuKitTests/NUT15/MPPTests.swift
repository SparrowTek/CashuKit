//
//  MPPTests.swift
//  CashuKitTests
//
//  Tests for Multi-path Payment implementation
//

import Testing
@testable import CashuKit
import Foundation

@Suite("MPP Implementation Tests")
struct MPPTests {
    
    @Test("Payment path optimizer - minimize mints strategy")
    func testOptimizerMinimizeMints() throws {
        let mints = [
            "https://mint1.example.com": MintCapability(availableBalance: 100),
            "https://mint2.example.com": MintCapability(availableBalance: 50),
            "https://mint3.example.com": MintCapability(availableBalance: 30)
        ]
        
        // Should use mint1 only
        let allocations = try PaymentPathOptimizer.optimize(
            amount: 80,
            availableMints: mints,
            strategy: .minimizeMints
        )
        
        #expect(allocations.count == 1)
        #expect(allocations["https://mint1.example.com"] == 80)
        
        // Should use mint1 and mint2
        let allocations2 = try PaymentPathOptimizer.optimize(
            amount: 120,
            availableMints: mints,
            strategy: .minimizeMints
        )
        
        #expect(allocations2.count == 2)
        #expect(allocations2["https://mint1.example.com"] == 100)
        #expect(allocations2["https://mint2.example.com"] == 20)
    }
    
    @Test("Payment path optimizer - minimize fees strategy")
    func testOptimizerMinimizeFees() throws {
        let mints = [
            "https://mint1.example.com": MintCapability(
                availableBalance: 100,
                feeRate: 1.0 // 1% fee
            ),
            "https://mint2.example.com": MintCapability(
                availableBalance: 100,
                feeRate: 0.5 // 0.5% fee
            ),
            "https://mint3.example.com": MintCapability(
                availableBalance: 100,
                feeRate: 2.0 // 2% fee
            )
        ]
        
        // Should prioritize mint2 (lowest fee)
        let allocations = try PaymentPathOptimizer.optimize(
            amount: 80,
            availableMints: mints,
            strategy: .minimizeFees
        )
        
        #expect(allocations["https://mint2.example.com"] == 80)
    }
    
    @Test("Payment path optimizer - balance load strategy")
    func testOptimizerBalanceLoad() throws {
        let mints = [
            "https://mint1.example.com": MintCapability(availableBalance: 100),
            "https://mint2.example.com": MintCapability(availableBalance: 100),
            "https://mint3.example.com": MintCapability(availableBalance: 100)
        ]
        
        // Should distribute evenly
        let allocations = try PaymentPathOptimizer.optimize(
            amount: 90,
            availableMints: mints,
            strategy: .balanceLoad
        )
        
        #expect(allocations.count == 3)
        // Each should get 30
        for (_, amount) in allocations {
            #expect(amount == 30)
        }
        
        // Test with remainder
        let allocations2 = try PaymentPathOptimizer.optimize(
            amount: 100,
            availableMints: mints,
            strategy: .balanceLoad
        )
        
        let amounts = allocations2.values.sorted()
        #expect(amounts == [33, 33, 34] || amounts == [33, 34, 33] || amounts == [34, 33, 33])
    }
    
    @Test("Payment path optimizer - reliability strategy")
    func testOptimizerReliability() throws {
        let mints = [
            "https://mint1.example.com": MintCapability(
                availableBalance: 100,
                reliabilityScore: 0.8
            ),
            "https://mint2.example.com": MintCapability(
                availableBalance: 100,
                reliabilityScore: 0.95
            ),
            "https://mint3.example.com": MintCapability(
                availableBalance: 100,
                reliabilityScore: 0.6
            )
        ]
        
        // Should prioritize mint2 (highest reliability)
        let allocations = try PaymentPathOptimizer.optimize(
            amount: 80,
            availableMints: mints,
            strategy: .reliability
        )
        
        #expect(allocations["https://mint2.example.com"] == 80)
    }
    
    @Test("Payment path optimizer with constraints")
    func testOptimizerWithConstraints() throws {
        let mints = [
            "https://mint1.example.com": MintCapability(
                availableBalance: 100,
                reliabilityScore: 0.9
            ),
            "https://mint2.example.com": MintCapability(
                availableBalance: 100,
                reliabilityScore: 0.85  // Changed to meet constraint
            ),
            "https://mint3.example.com": MintCapability(
                availableBalance: 100,
                reliabilityScore: 0.5
            )
        ]
        
        let constraints = OptimizationConstraints(
            maxAmountPerMint: 50,
            minReliabilityScore: 0.8
        )
        
        // Should use mint1 and mint2, each with max 50
        let allocations = try PaymentPathOptimizer.optimize(
            amount: 80,
            availableMints: mints,
            strategy: .minimizeMints,
            constraints: constraints
        )
        
        // Should use multiple mints due to constraint
        #expect(allocations.count == 2)
        #expect(allocations["https://mint1.example.com"] == 50)
        #expect(allocations["https://mint2.example.com"] == 30)
        for (_, amount) in allocations {
            #expect(amount <= 50)
        }
    }
    
    @Test("MPP executor configuration")
    func testExecutorConfiguration() {
        let config = MultiPathPaymentExecutor.Configuration(
            timeout: 30,
            optimisticMode: false,
            maxConcurrency: 5
        )
        
        #expect(config.timeout == 30)
        #expect(config.optimisticMode == false)
        #expect(config.maxConcurrency == 5)
        
        // Test retry policies
        let defaultPolicy = MultiPathPaymentExecutor.RetryPolicy.default
        #expect(defaultPolicy.maxAttempts == 3)
        #expect(defaultPolicy.backoffMultiplier == 2.0)
        
        let aggressivePolicy = MultiPathPaymentExecutor.RetryPolicy.aggressive
        #expect(aggressivePolicy.maxAttempts == 5)
        #expect(aggressivePolicy.backoffMultiplier == 1.5)
        
        let nonePolicy = MultiPathPaymentExecutor.RetryPolicy.none
        #expect(nonePolicy.maxAttempts == 1)
    }
    
    @Test("MPP executor input validation")
    func testExecutorInputValidation() async throws {
        let executor = MultiPathPaymentExecutor()
        let emptyPlans: [PartialPaymentPlan] = []
        let emptyWallets: [String: CashuWallet] = [:]
        
        do {
            _ = try await executor.execute(
                invoice: "lnbc...",
                paymentPlans: emptyPlans,
                wallets: emptyWallets
            )
            #expect(Bool(false), "Should have thrown for empty plans")
        } catch {
            // Expected
            #expect(error.localizedDescription.contains("Validation failed"))
        }
    }
    
    @Test("Mint capability initialization")
    func testMintCapability() {
        let capability = MintCapability(
            availableBalance: 1000,
            feeRate: 0.5,
            reliabilityScore: 0.95,
            avgResponseTime: 0.3,
            supportsMPP: true
        )
        
        #expect(capability.availableBalance == 1000)
        #expect(capability.feeRate == 0.5)
        #expect(capability.reliabilityScore == 0.95)
        #expect(capability.avgResponseTime == 0.3)
        #expect(capability.supportsMPP == true)
        
        // Test defaults
        let defaultCapability = MintCapability(availableBalance: 500)
        #expect(defaultCapability.feeRate == 0.0)
        #expect(defaultCapability.reliabilityScore == 1.0)
        #expect(defaultCapability.avgResponseTime == 0.5)
        #expect(defaultCapability.supportsMPP == true)
    }
    
    @Test("Optimization constraints")
    func testOptimizationConstraints() {
        let constraints = OptimizationConstraints(
            maxAmountPerMint: 100,
            minReliabilityScore: 0.8,
            maxMints: 3,
            excludedMints: ["https://bad.mint.com"]
        )
        
        #expect(constraints.maxAmountPerMint == 100)
        #expect(constraints.minReliabilityScore == 0.8)
        #expect(constraints.maxMints == 3)
        #expect(constraints.excludedMints?.contains("https://bad.mint.com") == true)
    }
    
    @Test("CashuError MPP extensions")
    func testCashuErrorMPPExtensions() {
        let walletNotFound = CashuError.mppWalletNotFound
        #expect(walletNotFound.localizedDescription.contains("Wallet not initialized"))
        
        let partialFailure = CashuError.mppPartialFailure
        #expect(partialFailure.localizedDescription.contains("Multi-path payment partially failed"))
        
        let invalidPlans = CashuError.mppInvalidPaymentPlans
        #expect(invalidPlans.localizedDescription.contains("Validation failed"))
        
        let inconsistentUnits = CashuError.mppInconsistentUnits
        #expect(inconsistentUnits.localizedDescription.contains("Invalid unit"))
        
        let optimizationFailed = CashuError.mppOptimizationFailed
        #expect(optimizationFailed.localizedDescription.contains("Path optimization failed"))
        
        let noMints = CashuError.mppNoAvailableMints
        #expect(noMints.localizedDescription.contains("Mint is unavailable"))
    }
}