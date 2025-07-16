//
//  NUT15Tests.swift
//  CashuKitTests
//
//  Tests for NUT-15: Partial multi-path payments
//

import Testing
@testable import CashuKit
import Foundation

@Suite("NUT-15 Tests")
struct NUT15Tests {
    
    @Test("MPP options serialization")
    func testMPPOptionsSerialization() throws {
        let mppOptions = MPPOptions(amount: 50000) // 50 sats in millisats
        let options = MeltQuoteOptions(mpp: mppOptions)
        
        let jsonData = try JSONEncoder().encode(options)
        let jsonString = String(data: jsonData, encoding: .utf8)!
        
        #expect(jsonString.contains("\"mpp\""))
        #expect(jsonString.contains("\"amount\":50000"))
        
        // Test deserialization
        let decoded = try JSONDecoder().decode(MeltQuoteOptions.self, from: jsonData)
        #expect(decoded.mpp?.amount == 50000)
    }
    
    @Test("PostMeltQuoteBolt11Request with MPP")
    func testMeltQuoteRequestWithMPP() throws {
        let request = PostMeltQuoteBolt11Request.withMPP(
            request: "lnbc100n1p3ehk5pp5xgxzcks5jtpj9xw7ugeheyt6ccnz4fkjp03",
            unit: "sat",
            partialAmountMsat: 50000
        )
        
        #expect(request.isMPPRequest == true)
        #expect(request.partialAmountMsat == 50000)
        #expect(request.validate() == true)
        
        // Test JSON serialization
        let jsonData = try JSONEncoder().encode(request)
        let jsonString = String(data: jsonData, encoding: .utf8)!
        
        #expect(jsonString.contains("\"request\""))
        #expect(jsonString.contains("\"unit\":\"sat\""))
        #expect(jsonString.contains("\"options\""))
        #expect(jsonString.contains("\"mpp\""))
        #expect(jsonString.contains("\"amount\":50000"))
    }
    
    @Test("PostMeltQuoteBolt11Request without MPP")
    func testMeltQuoteRequestWithoutMPP() throws {
        let request = PostMeltQuoteBolt11Request(
            request: "lnbc100n1p3ehk5pp5xgxzcks5jtpj9xw7ugeheyt6ccnz4fkjp03",
            unit: "sat"
        )
        
        #expect(request.isMPPRequest == false)
        #expect(request.partialAmountMsat == nil)
        #expect(request.validate() == true)
    }
    
    @Test("MPP amount splitting")
    func testAmountSplitting() throws {
        // Test basic splitting
        let balances = [
            "https://mint1.example.com": 30,
            "https://mint2.example.com": 50,
            "https://mint3.example.com": 20
        ]
        
        let allocations = try MultiPathPaymentCoordinator.splitAmount(
            totalAmount: 75,
            availableBalances: balances
        )
        
        // Should use mint2 (50) and mint1 (25)
        #expect(allocations.count <= 3)
        #expect(allocations.values.reduce(0, +) == 75)
        
        // Verify allocations don't exceed available balances
        for (mint, amount) in allocations {
            #expect(amount <= balances[mint]!)
        }
    }
    
    @Test("MPP amount splitting - insufficient balance")
    func testAmountSplittingInsufficientBalance() throws {
        let balances = [
            "https://mint1.example.com": 30,
            "https://mint2.example.com": 20
        ]
        
        do {
            _ = try MultiPathPaymentCoordinator.splitAmount(
                totalAmount: 100,
                availableBalances: balances
            )
            #expect(Bool(false), "Should have thrown insufficient balance error")
        } catch CashuError.balanceInsufficient {
            // Expected
            #expect(true)
        } catch {
            #expect(Bool(false), "Wrong error type")
        }
    }
    
    @Test("Millisats conversion")
    func testMillisatsConversion() {
        // Test sat to msat conversion
        let msatFromSat = MultiPathPaymentCoordinator.toMillisats(amount: 100, unit: "sat")
        #expect(msatFromSat == 100000)
        
        // Test msat to msat (no conversion)
        let msatFromMsat = MultiPathPaymentCoordinator.toMillisats(amount: 100000, unit: "msat")
        #expect(msatFromMsat == 100000)
    }
    
    @Test("Partial payment plan validation")
    func testPartialPaymentPlanValidation() {
        let proofs = [
            Proof(amount: 50, id: "test", secret: "secret1", C: "C1"),
            Proof(amount: 30, id: "test", secret: "secret2", C: "C2")
        ]
        
        // Valid plan
        let validPlan = PartialPaymentPlan(
            mintURL: "https://mint.example.com",
            amount: 75,
            proofs: proofs,
            unit: "sat"
        )
        
        #expect(validPlan.validate() == true)
        #expect(validPlan.proofsTotal == 80)
        
        // Invalid plan - amount exceeds proofs
        let invalidPlan = PartialPaymentPlan(
            mintURL: "https://mint.example.com",
            amount: 100,
            proofs: proofs,
            unit: "sat"
        )
        
        #expect(invalidPlan.validate() == false)
        
        // Invalid plan - empty proofs
        let emptyProofsPlan = PartialPaymentPlan(
            mintURL: "https://mint.example.com",
            amount: 50,
            proofs: [],
            unit: "sat"
        )
        
        #expect(emptyProofsPlan.validate() == false)
    }
    
    @Test("NUT-15 settings parsing")
    func testNUT15SettingsParsing() throws {
        let settings = NUT15Settings(methods: [
            MPPMethodUnit(method: "bolt11", unit: "sat"),
            MPPMethodUnit(method: "bolt11", unit: "usd"),
            MPPMethodUnit(method: "bolt12", unit: "sat")
        ])
        
        #expect(settings.supportsMPP(method: "bolt11", unit: "sat") == true)
        #expect(settings.supportsMPP(method: "bolt11", unit: "usd") == true)
        #expect(settings.supportsMPP(method: "bolt12", unit: "sat") == true)
        #expect(settings.supportsMPP(method: "bolt12", unit: "usd") == false)
        
        let supportedMethods = settings.supportedMethods.sorted()
        #expect(supportedMethods == ["bolt11", "bolt12"])
        
        let supportedUnits = settings.supportedUnits.sorted()
        #expect(supportedUnits == ["sat", "usd"])
    }
    
    @Test("MintInfo NUT-15 support")
    func testMintInfoNUT15Support() throws {
        // Create test mint info with NUT-15 support
        let methodsArray: [[String: String]] = [
            ["method": "bolt11", "unit": "sat"],
            ["method": "bolt11", "unit": "usd"]
        ]
        let nut15Value = NutValue.dictionary([
            "methods": AnyCodable(anyValue: methodsArray)!
        ])
        
        let mintInfo = MintInfo(
            name: "Test Mint",
            pubkey: "pubkey",
            version: "1.0",
            nuts: ["15": nut15Value]
        )
        
        #expect(mintInfo.supportsMPP == true)
        
        let settings = mintInfo.getNUT15Settings()
        #expect(settings != nil)
        #expect(settings?.methods.count == 2)
        
        #expect(mintInfo.supportsMPP(method: "bolt11", unit: "sat") == true)
        #expect(mintInfo.supportsMPP(method: "bolt11", unit: "eur") == false)
    }
    
    @Test("MPP support validation")
    func testMPPSupportValidation() {
        let methodsArray1: [[String: String]] = [["method": "bolt11", "unit": "sat"]]
        let methodsArray2: [[String: String]] = [["method": "bolt11", "unit": "sat"]]
        
        let mintInfos = [
            "https://mint1.example.com": MintInfo(
                name: "Mint 1",
                nuts: ["15": NutValue.dictionary([
                    "methods": AnyCodable(anyValue: methodsArray1)!
                ])]
            ),
            "https://mint2.example.com": MintInfo(
                name: "Mint 2",
                nuts: ["15": NutValue.dictionary([
                    "methods": AnyCodable(anyValue: methodsArray2)!
                ])]
            )
        ]
        
        // All mints support bolt11/sat
        let allSupport = MultiPathPaymentCoordinator.validateMPPSupport(
            mintURLs: ["https://mint1.example.com", "https://mint2.example.com"],
            method: "bolt11",
            unit: "sat",
            mintInfos: mintInfos
        )
        
        #expect(allSupport == true)
        
        // Not all mints support bolt11/usd
        let partialSupport = MultiPathPaymentCoordinator.validateMPPSupport(
            mintURLs: ["https://mint1.example.com", "https://mint2.example.com"],
            method: "bolt11",
            unit: "usd",
            mintInfos: mintInfos
        )
        
        #expect(partialSupport == false)
    }
    
    @Test("Partial payment result")
    func testPartialPaymentResult() {
        let successResult = PartialPaymentResult(
            mintURL: "https://mint.example.com",
            success: true,
            change: [Proof(amount: 5, id: "test", secret: "secret", C: "C")],
            feePaid: 2
        )
        
        #expect(successResult.success == true)
        #expect(successResult.error == nil)
        #expect(successResult.change?.count == 1)
        #expect(successResult.feePaid == 2)
        
        let errorResult = PartialPaymentResult(
            mintURL: "https://mint.example.com",
            success: false,
            error: CashuError.networkError("Connection failed")
        )
        
        #expect(errorResult.success == false)
        #expect(errorResult.error != nil)
    }
    
    @Test("Error handling for MPP")
    func testMPPErrorHandling() {
        let error = CashuError.nutNotImplemented("15")
        #expect(error.isMPPNotSupported == true)
        
        let otherError = CashuError.networkError("test")
        #expect(otherError.isMPPNotSupported == false)
    }
    
    @Test("Request validation")
    func testRequestValidation() {
        // Valid request
        let validRequest = PostMeltQuoteBolt11Request(
            request: "lnbc100n1p3ehk5pp5xgxzcks5jtpj9xw7ugeheyt6ccnz4fkjp03",
            unit: "sat",
            options: MeltQuoteOptions(mpp: MPPOptions(amount: 50000))
        )
        
        #expect(validRequest.validate() == true)
        
        // Invalid - empty invoice
        let emptyInvoice = PostMeltQuoteBolt11Request(
            request: "",
            unit: "sat"
        )
        
        #expect(emptyInvoice.validate() == false)
        
        // Invalid - empty unit
        let emptyUnit = PostMeltQuoteBolt11Request(
            request: "lnbc100n1p3ehk5pp5xgxzcks5jtpj9xw7ugeheyt6ccnz4fkjp03",
            unit: ""
        )
        
        #expect(emptyUnit.validate() == false)
        
        // Invalid - negative MPP amount
        let negativeAmount = PostMeltQuoteBolt11Request(
            request: "lnbc100n1p3ehk5pp5xgxzcks5jtpj9xw7ugeheyt6ccnz4fkjp03",
            unit: "sat",
            options: MeltQuoteOptions(mpp: MPPOptions(amount: -100))
        )
        
        #expect(negativeAmount.validate() == false)
    }
}