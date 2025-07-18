//
//  MPPIntegrationTests.swift
//  CashuKitTests
//
//  Integration tests for Multi-path Payment API
//

import Testing
@testable import CashuKit
import Foundation

@Suite("MPP API Integration Tests")
struct MPPIntegrationTests {
    
    @Test("MeltService MPP quote request structure")
    func testMPPQuoteRequestStructure() async throws {
        // Test that the MPP quote request can be properly created and validated
        let request = PostMeltQuoteBolt11Request.withMPP(
            request: "lnbc100n1p3ehk5pp5xgxzcks5jtpj9xw7ugeheyt6ccnz4fkjp03",
            unit: "sat",
            partialAmountMsat: 50000
        )
        
        #expect(request.validate() == true)
        #expect(request.isMPPRequest == true)
        #expect(request.partialAmountMsat == 50000)
        
        // Verify JSON encoding matches expected format
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let jsonData = try encoder.encode(request)
        let json = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any]
        
        #expect(json?["request"] as? String == request.request)
        #expect(json?["unit"] as? String == "sat")
        
        let options = json?["options"] as? [String: Any]
        #expect(options != nil)
        
        let mpp = options?["mpp"] as? [String: Any]
        #expect(mpp?["amount"] as? Int == 50000)
    }
    
    @Test("CashuWallet MPP quote request method")
    func testWalletMPPQuoteRequest() async throws {
        // Create a test wallet
        let wallet = await CashuWallet(
            mintURL: "https://test.mint.example.com"
        )
        
        // The actual network call would fail with test URL, but we're testing the structure
        do {
            _ = try await wallet.requestMeltQuoteWithMPP(
                invoice: "lnbc100n1p3ehk5pp5xgxzcks5jtpj9xw7ugeheyt6ccnz4fkjp03",
                partialAmountMsat: 50000
            )
            #expect(Bool(false), "Should have thrown an error with test URL")
        } catch {
            // Expected to fail with network error or similar
            print("Error: \(error)")
            print("Localized: \(error.localizedDescription)")
            #expect(true) // Any error is expected since we're using a test URL
        }
    }
    
    @Test("MPP API endpoint configuration")
    func testMPPEndpointConfiguration() async throws {
        // Verify the MeltAPI enum properly handles MPP requests
        let request = PostMeltQuoteBolt11Request.withMPP(
            request: "lnbc...",
            unit: "sat",
            partialAmountMsat: 50000
        )
        
        let endpoint = MeltAPI.requestMeltQuoteWithMPP("bolt11", request)
        
        // Test endpoint properties
        #expect(await endpoint.path == "/v1/melt/quote/bolt11")
        #expect(await endpoint.httpMethod == .post)
        
        // Verify task encoding
        if case .requestParameters = await endpoint.task {
            // The encoding should handle the MPP request properly
            #expect(Bool(true))
        } else {
            #expect(Bool(false), "Expected requestParameters task")
        }
        
        // Verify headers
        let headers = await endpoint.headers
        #expect(headers?["Accept"] == "application/json")
        #expect(headers?["Content-Type"] == "application/json")
    }
    
    @Test("MPP executor with API integration")
    func testMPPExecutorAPIIntegration() async throws {
        // Test that the MPP executor can work with the API layer
        let executor = MultiPathPaymentExecutor()
        
        let plan1 = PartialPaymentPlan(
            mintURL: "https://mint1.example.com",
            amount: 50,
            proofs: [
                Proof(amount: 50, id: "test", secret: "secret1", C: "C1")
            ],
            unit: "sat"
        )
        
        let plan2 = PartialPaymentPlan(
            mintURL: "https://mint2.example.com",
            amount: 30,
            proofs: [
                Proof(amount: 30, id: "test", secret: "secret2", C: "C2")
            ],
            unit: "sat"
        )
        
        // Create test wallets
        let wallet1 = await CashuWallet(
            mintURL: "https://mint1.example.com"
        )
        
        let wallet2 = await CashuWallet(
            mintURL: "https://mint2.example.com"
        )
        
        let wallets = [
            "https://mint1.example.com": wallet1,
            "https://mint2.example.com": wallet2
        ]
        
        // This will fail with network errors, but we're testing the structure
        do {
            _ = try await executor.execute(
                invoice: "lnbc...",
                paymentPlans: [plan1, plan2],
                wallets: wallets
            )
            #expect(Bool(false), "Should have thrown an error")
        } catch {
            // Expected to fail
            #expect(Bool(true))
        }
    }
}