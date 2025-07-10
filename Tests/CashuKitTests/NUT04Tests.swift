//
//  NUT04Tests.swift
//  CashuKit
//
//  Tests for NUT-04: Mint tokens
//

import Foundation
import Testing
@testable import CashuKit

@Suite("NUT 04 Tests")
struct NUT04Tests {
    
    // MARK: - Data Structure Tests
    
    @Test("MintQuoteRequest validation")
    func mintQuoteRequestValidation() {
        // Valid request
        let validRequest = MintQuoteRequest(unit: "sat", amount: 100)
        #expect(validRequest.validate())
        
        // Invalid request - empty unit
        let invalidRequest1 = MintQuoteRequest(unit: "", amount: 100)
        #expect(!invalidRequest1.validate())
        
        // Invalid request - zero amount
        let invalidRequest2 = MintQuoteRequest(unit: "sat", amount: 0)
        #expect(!invalidRequest2.validate())
        
        // Invalid request - negative amount
        let invalidRequest3 = MintQuoteRequest(unit: "sat", amount: -100)
        #expect(!invalidRequest3.validate())
        
        // Valid request - no amount specified
        let validRequest2 = MintQuoteRequest(unit: "sat")
        #expect(validRequest2.validate())
    }
    
    @Test("MintQuoteResponse validation and state checking")
    func mintQuoteResponseValidation() {
        // Valid response
        let validResponse = MintQuoteResponse(
            quote: "quote123",
            request: "lnbc1000n1...",
            unit: "sat",
            paid: false,
            expiry: Int(Date().timeIntervalSince1970) + 3600,
            state: "UNPAID"
        )
        #expect(validResponse.validate())
        #expect(!validResponse.isPaid)
        #expect(!validResponse.isExpired)
        #expect(!validResponse.canMint)
        
        // Invalid response - empty quote
        let invalidResponse1 = MintQuoteResponse(
            quote: "",
            request: "lnbc1000n1...",
            unit: "sat"
        )
        #expect(!invalidResponse1.validate())
        
        // Invalid response - empty request
        let invalidResponse2 = MintQuoteResponse(
            quote: "quote123",
            request: "",
            unit: "sat"
        )
        #expect(!invalidResponse2.validate())
        
        // Valid paid response
        let paidResponse = MintQuoteResponse(
            quote: "quote123",
            request: "lnbc1000n1...",
            unit: "sat",
            paid: true,
            expiry: Int(Date().timeIntervalSince1970) + 3600,
            state: "PAID"
        )
        #expect(paidResponse.isPaid)
        #expect(paidResponse.canMint)
        
        // Expired response
        let expiredResponse = MintQuoteResponse(
            quote: "quote123",
            request: "lnbc1000n1...",
            unit: "sat",
            paid: true,
            expiry: Int(Date().timeIntervalSince1970) - 3600,
            state: "EXPIRED"
        )
        #expect(expiredResponse.isExpired)
        #expect(!expiredResponse.canMint)
    }
    
    @Test("MintRequest validation and privacy features")
    func mintRequestValidation() {
        // Create test blinded messages
        let blindedMessage1 = BlindedMessage(amount: 64, id: "keyset123", B_: "02abcd...")
        let blindedMessage2 = BlindedMessage(amount: 32, id: "keyset123", B_: "03efgh...")
        
        // Valid request
        let validRequest = MintRequest(
            quote: "quote123",
            outputs: [blindedMessage2, blindedMessage1] // Correct order: 32, 64
        )
        #expect(validRequest.validate())
        #expect(validRequest.totalOutputAmount == 96)
        #expect(validRequest.hasPrivacyPreservingOrder)
        
        // Invalid request - empty quote
        let invalidRequest1 = MintRequest(quote: "", outputs: [blindedMessage1])
        #expect(!invalidRequest1.validate())
        
        // Invalid request - no outputs
        let invalidRequest2 = MintRequest(quote: "quote123", outputs: [])
        #expect(!invalidRequest2.validate())
        
        // Test privacy-preserving order
        let unorderedOutputs = [blindedMessage1, blindedMessage2] // 64, 32 - not ascending
        let unorderedRequest = MintRequest(quote: "quote123", outputs: unorderedOutputs)
        #expect(!unorderedRequest.hasPrivacyPreservingOrder)
    }
    
    @Test("MintResponse validation")
    func mintResponseValidation() {
        // Create test blind signatures
        let signature1 = BlindSignature(amount: 32, id: "keyset123", C_: "02abcd...")
        let signature2 = BlindSignature(amount: 64, id: "keyset123", C_: "03efgh...")
        
        // Valid response
        let validResponse = MintResponse(signatures: [signature1, signature2])
        #expect(validResponse.validate())
        #expect(validResponse.totalAmount == 96)
        
        // Invalid response - no signatures
        let invalidResponse = MintResponse(signatures: [])
        #expect(!invalidResponse.validate())
    }
    
    // MARK: - Settings Tests
    
    @Test("MintMethodSetting validation")
    func mintMethodSettingValidation() {
        let setting = MintMethodSetting(
            method: "bolt11",
            unit: "sat",
            minAmount: 1,
            maxAmount: 1000000
        )
        
        #expect(setting.validateAmount(100))
        #expect(setting.validateAmount(1))
        #expect(setting.validateAmount(1000000))
        #expect(!setting.validateAmount(0))
        #expect(!setting.validateAmount(1000001))
        
        #expect(setting.isSupported(method: "bolt11", unit: "sat"))
        #expect(!setting.isSupported(method: "bolt12", unit: "sat"))
        #expect(!setting.isSupported(method: "bolt11", unit: "usd"))
    }
    
    @Test("NUT04Settings validation and configuration")
    func nut04SettingsValidation() {
        let method1 = MintMethodSetting(method: "bolt11", unit: "sat", minAmount: 1, maxAmount: 1000000)
        let method2 = MintMethodSetting(method: "bolt11", unit: "usd", minAmount: 100, maxAmount: 10000000)
        
        let settings = NUT04Settings(methods: [method1, method2], disabled: false)
        
        #expect(settings.isSupported(method: "bolt11", unit: "sat"))
        #expect(settings.isSupported(method: "bolt11", unit: "usd"))
        #expect(!settings.isSupported(method: "bolt12", unit: "sat"))
        
        #expect(Set(settings.supportedMethods) == Set(["bolt11"]))
        #expect(Set(settings.supportedUnits) == Set(["sat", "usd"]))
        
        let satSetting = settings.getMethodSetting(method: "bolt11", unit: "sat")
        #expect(satSetting != nil)
        #expect(satSetting?.minAmount == 1)
        #expect(satSetting?.maxAmount == 1000000)
        
        // Test disabled settings
        let disabledSettings = NUT04Settings(methods: [method1], disabled: true)
        #expect(!disabledSettings.isSupported(method: "bolt11", unit: "sat"))
    }
    
    // MARK: - Utility Tests
    
    @Test("Optimal denominations calculation")
    func optimalDenominations() {
        // Test the optimal denominations concept with manual calculation
        // 96 should become [32, 64] in binary decomposition
        // 100 should become [4, 32, 64] in binary decomposition
        
        let amount = 96
        var denominations: [Int] = []
        var remaining = amount
        var power = 0
        
        while remaining > 0 {
            let denomination = 1 << power
            if remaining & denomination != 0 {
                denominations.append(denomination)
                remaining -= denomination
            }
            power += 1
        }
        
        let expectedDenominations = [32, 64] // sorted
        #expect(denominations.sorted() == expectedDenominations)
        #expect(denominations.reduce(0, +) == amount)
        
        // Test another amount
        let amount2 = 100
        var denominations2: [Int] = []
        var remaining2 = amount2
        power = 0
        
        while remaining2 > 0 {
            let denomination = 1 << power
            if remaining2 & denomination != 0 {
                denominations2.append(denomination)
                remaining2 -= denomination
            }
            power += 1
        }
        
        let expectedDenominations2 = [4, 32, 64] // sorted
        #expect(denominations2.sorted() == expectedDenominations2)
        #expect(denominations2.reduce(0, +) == amount2)
    }
    
    // MARK: - Integration Tests
    
    @Test("MintInfo NUT-04 integration")
    func mintInfoNUT04Integration() throws {
        let mintInfo = MintInfo(
            name: "Test Mint",
            pubkey: "02a1b2c3d4e5f6...",
            nuts: [
                "4": .dictionary([
                    "methods": .array([
                        .dictionary([
                            "method": .string("bolt11"),
                            "unit": .string("sat"),
                            "min_amount": .int(1),
                            "max_amount": .int(1000000)
                        ]),
                        .dictionary([
                            "method": .string("bolt11"),
                            "unit": .string("usd"),
                            "min_amount": .int(100),
                            "max_amount": .int(10000000)
                        ])
                    ]),
                    "disabled": .bool(false)
                ])
            ]
        )
        
        let nut04Settings = mintInfo.getNUT04Settings()
        #expect(nut04Settings != nil)
        #expect(!nut04Settings!.disabled)
        #expect(nut04Settings!.methods.count == 2)
        
        #expect(mintInfo.supportsMinting(method: "bolt11", unit: "sat"))
        #expect(mintInfo.supportsMinting(method: "bolt11", unit: "usd"))
        #expect(!mintInfo.supportsMinting(method: "bolt12", unit: "sat"))
    }
    
    @Test("MintInfo NUT-04 with disabled minting")
    func mintInfoNUT04WithDisabledMinting() {
        let mintInfo = MintInfo(
            name: "Test Mint",
            pubkey: "02a1b2c3d4e5f6...",
            nuts: [
                "4": .dictionary([
                    "methods": .array([
                        .dictionary([
                            "method": .string("bolt11"),
                            "unit": .string("sat"),
                            "min_amount": .int(1),
                            "max_amount": .int(1000000)
                        ])
                    ]),
                    "disabled": .bool(true)
                ])
            ]
        )
        
        let nut04Settings = mintInfo.getNUT04Settings()
        #expect(nut04Settings != nil)
        #expect(nut04Settings!.disabled)
        
        #expect(!mintInfo.supportsMinting(method: "bolt11", unit: "sat"))
    }
    
    @Test("MintInfo without NUT-04")
    func mintInfoWithoutNUT04() {
        let mintInfo = MintInfo(
            name: "Test Mint",
            pubkey: "02a1b2c3d4e5f6...",
            nuts: [
                "NUT-01": .string("1.0"),
                "NUT-02": .string("1.0")
            ]
        )
        
        let nut04Settings = mintInfo.getNUT04Settings()
        #expect(nut04Settings == nil)
        
        #expect(!mintInfo.supportsMinting(method: "bolt11", unit: "sat"))
    }
    
    // MARK: - Error Handling Tests
    
    @Test("MintRequest validation with invalid outputs")
    func mintRequestValidationWithInvalidOutputs() {
        // Test with invalid blinded messages
        let invalidBlindedMessage = BlindedMessage(amount: 0, id: "", B_: "")
        let invalidRequest = MintRequest(quote: "quote123", outputs: [invalidBlindedMessage])
        
        #expect(!invalidRequest.validate())
    }
    
    @Test("MintResponse validation with invalid signatures")
    func mintResponseValidationWithInvalidSignatures() {
        // Test with invalid blind signatures
        let invalidSignature = BlindSignature(amount: 0, id: "", C_: "")
        let invalidResponse = MintResponse(signatures: [invalidSignature])
        
        #expect(!invalidResponse.validate())
    }
    
    // MARK: - Sendable Conformance Tests
    
    @Test("All NUT-04 types are Sendable")
    func sendableConformance() async {
        // This test ensures all types properly conform to Sendable
        
        let request = MintQuoteRequest(unit: "sat", amount: 100)
        let response = MintQuoteResponse(quote: "test", request: "test", unit: "sat")
        let mintRequest = MintRequest(quote: "test", outputs: [])
        let mintResponse = MintResponse(signatures: [])
        let setting = MintMethodSetting(method: "bolt11", unit: "sat")
        let settings = NUT04Settings(methods: [setting])
        let result = MintResult(newProofs: [], quote: "test", totalAmount: 100, method: "bolt11", unit: "sat")
        let preparation = MintPreparation(quote: "test", blindedMessages: [], blindingData: [], totalAmount: 100, method: "bolt11", unit: "sat")
        
        // If this compiles, the types are properly Sendable
        Task {
            let _ = [request, response, mintRequest, mintResponse, setting, settings, result, preparation]
        }
        
        // Test enum is Sendable
        let operationType: MintOperationType = .mint
        Task {
            let _ = operationType
        }
        
        #expect(true) // If we reach here, all types are properly Sendable
    }
    
    // MARK: - Method-specific Tests
    
    @Test("Mint operation types")
    func mintOperationTypes() {
        let allTypes = MintOperationType.allCases
        #expect(allTypes.contains(.mint))
        #expect(allTypes.contains(.quote))
        #expect(allTypes.contains(.check))
        #expect(allTypes.count == 3)
        
        #expect(MintOperationType.mint.rawValue == "mint")
        #expect(MintOperationType.quote.rawValue == "quote")
        #expect(MintOperationType.check.rawValue == "check")
    }
    
    @Test("MintResult properties")
    func mintResultProperties() {
        let proofs = [Proof(amount: 100, id: "test", secret: "secret", C: "signature")]
        let result = MintResult(
            newProofs: proofs,
            quote: "quote123",
            totalAmount: 100,
            method: "bolt11",
            unit: "sat"
        )
        
        #expect(result.newProofs.count == 1)
        #expect(result.quote == "quote123")
        #expect(result.totalAmount == 100)
        #expect(result.method == "bolt11")
        #expect(result.unit == "sat")
    }
    
    @Test("MintPreparation properties")
    func mintPreparationProperties() {
        let blindedMessages = [BlindedMessage(amount: 100, id: "test", B_: "blinded")]
        let blindingData = [WalletBlindingData]() // Empty for test
        
        let preparation = MintPreparation(
            quote: "quote123",
            blindedMessages: blindedMessages,
            blindingData: blindingData,
            totalAmount: 100,
            method: "bolt11",
            unit: "sat"
        )
        
        #expect(preparation.quote == "quote123")
        #expect(preparation.blindedMessages.count == 1)
        #expect(preparation.blindingData.isEmpty)
        #expect(preparation.totalAmount == 100)
        #expect(preparation.method == "bolt11")
        #expect(preparation.unit == "sat")
    }
}
