//
//  NUT23Tests.swift
//  CashuKit
//
//  Tests for NUT-23: BOLT11 payment method
//

import Testing
@testable import CashuKit
import Foundation

@Suite("NUT-23: BOLT11 Payment Method Tests")
struct NUT23Tests {
    
    // MARK: - Mint Quote Tests
    
    @Test("PostMintQuoteBolt11Request initialization and encoding")
    func testPostMintQuoteBolt11Request() throws {
        let request = PostMintQuoteBolt11Request(
            amount: 1000,
            unit: "sat",
            description: "Test invoice"
        )
        
        #expect(request.amount == 1000)
        #expect(request.unit == "sat")
        #expect(request.description == "Test invoice")
        
        // Test encoding
        let encoded = try JSONEncoder().encode(request)
        let decoded = try JSONDecoder().decode(PostMintQuoteBolt11Request.self, from: encoded)
        
        #expect(decoded.amount == request.amount)
        #expect(decoded.unit == request.unit)
        #expect(decoded.description == request.description)
    }
    
    @Test("PostMintQuoteBolt11Request without description")
    func testPostMintQuoteBolt11RequestNoDescription() throws {
        let request = PostMintQuoteBolt11Request(
            amount: 500,
            unit: "sat"
        )
        
        #expect(request.amount == 500)
        #expect(request.unit == "sat")
        #expect(request.description == nil)
        
        // Test encoding
        let encoded = try JSONEncoder().encode(request)
        let json = try JSONSerialization.jsonObject(with: encoded) as? [String: Any]
        
        #expect(json?["amount"] as? Int == 500)
        #expect(json?["unit"] as? String == "sat")
        #expect(json?["description"] == nil)
    }
    
    @Test("PostMintQuoteBolt11Response initialization and encoding")
    func testPostMintQuoteBolt11Response() throws {
        let response = PostMintQuoteBolt11Response(
            quote: "DSGLX9kevM...",
            request: "lnbc100n1pj4apw9...",
            amount: 1000,
            unit: "sat",
            state: .unpaid,
            expiry: 1701704757
        )
        
        #expect(response.quote == "DSGLX9kevM...")
        #expect(response.request == "lnbc100n1pj4apw9...")
        #expect(response.amount == 1000)
        #expect(response.unit == "sat")
        #expect(response.state == .unpaid)
        #expect(response.expiry == 1701704757)
        
        // Test encoding/decoding
        let encoded = try JSONEncoder().encode(response)
        let decoded = try JSONDecoder().decode(PostMintQuoteBolt11Response.self, from: encoded)
        
        #expect(decoded.quote == response.quote)
        #expect(decoded.request == response.request)
        #expect(decoded.amount == response.amount)
        #expect(decoded.state == response.state)
    }
    
    @Test("Mint quote state transitions")
    func testMintQuoteStates() throws {
        var response = PostMintQuoteBolt11Response(
            quote: "test-quote",
            request: "lnbc...",
            amount: 100,
            unit: "sat",
            state: .unpaid,
            expiry: nil
        )
        
        #expect(response.state == .unpaid)
        
        // Simulate state transitions
        response = PostMintQuoteBolt11Response(
            quote: response.quote,
            request: response.request,
            amount: response.amount,
            unit: response.unit,
            state: .paid,
            expiry: response.expiry
        )
        #expect(response.state == .paid)
        
        response = PostMintQuoteBolt11Response(
            quote: response.quote,
            request: response.request,
            amount: response.amount,
            unit: response.unit,
            state: .issued,
            expiry: response.expiry
        )
        #expect(response.state == .issued)
    }
    
    // MARK: - Melt Quote Tests
    
    @Test("AmountlessOption initialization and encoding")
    func testAmountlessOption() throws {
        let option = AmountlessOption(amountMsat: 10000)
        
        #expect(option.amountMsat == 10000)
        
        // Test encoding
        let encoded = try JSONEncoder().encode(option)
        let json = try JSONSerialization.jsonObject(with: encoded) as? [String: Any]
        
        #expect(json?["amount_msat"] as? Int == 10000)
    }
    
    @Test("PostMeltQuoteBolt11RequestNUT23 with amountless option")
    func testPostMeltQuoteBolt11RequestWithAmountless() throws {
        let amountlessOption = AmountlessOption(amountMsat: 5000)
        let options = Bolt11MeltOptions(amountless: amountlessOption)
        let request = PostMeltQuoteBolt11RequestNUT23(
            request: "lnbc100n1p3kdrv5sp5lpdxzghe5j67q...",
            unit: "sat",
            options: options
        )
        
        #expect(request.request == "lnbc100n1p3kdrv5sp5lpdxzghe5j67q...")
        #expect(request.unit == "sat")
        #expect(request.options?.amountless?.amountMsat == 5000)
        
        // Test encoding
        let encoded = try JSONEncoder().encode(request)
        let decoded = try JSONDecoder().decode(PostMeltQuoteBolt11RequestNUT23.self, from: encoded)
        
        #expect(decoded.options?.amountless?.amountMsat == 5000)
    }
    
    @Test("PostMeltQuoteBolt11RequestNUT23 without options")
    func testPostMeltQuoteBolt11RequestNoOptions() throws {
        let request = PostMeltQuoteBolt11RequestNUT23(
            request: "lnbc...",
            unit: "sat"
        )
        
        #expect(request.options == nil)
        
        // Test encoding
        let encoded = try JSONEncoder().encode(request)
        let json = try JSONSerialization.jsonObject(with: encoded) as? [String: Any]
        
        #expect(json?["options"] == nil)
    }
    
    @Test("PostMeltQuoteBolt11Response initialization and encoding")
    func testPostMeltQuoteBolt11Response() throws {
        let response = PostMeltQuoteBolt11Response(
            quote: "TRmjduhIsPxd...",
            request: "lnbc100n1p3kdrv5sp5lpdxzghe5j67q...",
            amount: 10,
            unit: "sat",
            feeReserve: 2,
            state: .unpaid,
            expiry: 1701704757,
            paymentPreimage: nil
        )
        
        #expect(response.quote == "TRmjduhIsPxd...")
        #expect(response.amount == 10)
        #expect(response.feeReserve == 2)
        #expect(response.state == .unpaid)
        #expect(response.paymentPreimage == nil)
        
        // Test encoding with snake_case
        let encoded = try JSONEncoder().encode(response)
        let json = try JSONSerialization.jsonObject(with: encoded) as? [String: Any]
        
        #expect(json?["fee_reserve"] as? Int == 2)
        #expect(json?["payment_preimage"] == nil)
    }
    
    @Test("PostMeltQuoteBolt11Response with payment preimage")
    func testPostMeltQuoteBolt11ResponseWithPreimage() throws {
        let response = PostMeltQuoteBolt11Response(
            quote: "test-quote",
            request: "lnbc...",
            amount: 100,
            unit: "sat",
            feeReserve: 5,
            state: .paid,
            expiry: 1701704757,
            paymentPreimage: "c5a1ae1f639e1f4a3872e81500fd028bece7bedc1152f740cba5c3417b748c1b"
        )
        
        #expect(response.state == .paid)
        #expect(response.paymentPreimage == "c5a1ae1f639e1f4a3872e81500fd028bece7bedc1152f740cba5c3417b748c1b")
    }
    
    // MARK: - Melt Request/Response Tests
    
    @Test("PostMeltBolt11Request without outputs")
    func testPostMeltBolt11RequestNoOutputs() throws {
        let proofs = [
            Proof(
                amount: 10,
                id: "test-keyset",
                secret: "secret1",
                C: "signature1"
            )
        ]
        
        let request = PostMeltBolt11Request(
            quote: "test-quote",
            inputs: proofs
        )
        
        #expect(request.quote == "test-quote")
        #expect(request.inputs.count == 1)
        #expect(request.outputs == nil)
    }
    
    @Test("PostMeltBolt11Request with outputs for change")
    func testPostMeltBolt11RequestWithOutputs() throws {
        let proofs = [
            Proof(
                amount: 15,
                id: "test-keyset",
                secret: "secret1",
                C: "signature1"
            )
        ]
        
        let outputs = [
            BlindedMessage(
                amount: 3,
                id: "test-keyset",
                B_: "02abc..."
            )
        ]
        
        let request = PostMeltBolt11Request(
            quote: "test-quote",
            inputs: proofs,
            outputs: outputs
        )
        
        #expect(request.outputs?.count == 1)
        #expect(request.outputs?.first?.amount == 3)
    }
    
    @Test("PostMeltBolt11Response with change")
    func testPostMeltBolt11ResponseWithChange() throws {
        let blindSignatures = [
            BlindSignature(
                amount: 3,
                id: "test-keyset",
                C_: "02def..."
            )
        ]
        
        let response = PostMeltBolt11Response(
            quote: "test-quote",
            request: "lnbc...",
            amount: 10,
            unit: "sat",
            feeReserve: 2,
            state: .paid,
            expiry: 1701704757,
            paymentPreimage: "c5a1ae1f639e1f4a3872e81500fd028bece7bedc1152f740cba5c3417b748c1b",
            change: blindSignatures
        )
        
        #expect(response.change?.count == 1)
        #expect(response.change?.first?.amount == 3)
        
        // Test encoding
        let encoded = try JSONEncoder().encode(response)
        let decoded = try JSONDecoder().decode(PostMeltBolt11Response.self, from: encoded)
        
        #expect(decoded.change?.count == 1)
    }
    
    // MARK: - Settings Tests
    
    @Test("Bolt11MintOptions encoding")
    func testBolt11MintOptions() throws {
        let options = Bolt11MintOptions(description: true)
        
        #expect(options.description == true)
        
        let encoded = try JSONEncoder().encode(options)
        let json = try JSONSerialization.jsonObject(with: encoded) as? [String: Any]
        
        #expect(json?["description"] as? Bool == true)
    }
    
    @Test("Bolt11MeltMethodOptions encoding")
    func testBolt11MeltMethodOptions() throws {
        let options = Bolt11MeltMethodOptions(amountless: true)
        
        #expect(options.amountless == true)
        
        let encoded = try JSONEncoder().encode(options)
        let json = try JSONSerialization.jsonObject(with: encoded) as? [String: Any]
        
        #expect(json?["amountless"] as? Bool == true)
    }
    
    // MARK: - Integration Tests
    
    @Test("Payment method extension")
    func testPaymentMethodExtension() {
        let bolt11Method = PaymentMethod.bolt11
        #expect(bolt11Method.rawValue == "bolt11")
    }
    
    @Test("Calculate melt total helper")
    func testCalculateMeltTotal() async throws {
        // Test the MeltFeeCalculation helper
        
        let amount = 1000
        let feeReserve = 50
        let inputFeePPK = 100 // 0.01%
        let numInputs = 3
        
        let calculation = MeltFeeCalculation(
            amount: amount,
            feeReserve: feeReserve,
            inputFeePPK: inputFeePPK,
            numInputs: numInputs
        )
        
        #expect(calculation.amount == 1000)
        #expect(calculation.feeReserve == 50)
        #expect(calculation.inputFees == 1) // (100 * 3 + 999) / 1000 = 1
        #expect(calculation.total == 1051)
    }
    
    @Test("JSON compatibility with spec examples")
    func testSpecExampleCompatibility() throws {
        // Test mint quote response from spec
        let specJSON = """
        {
          "quote": "DSGLX9kevM...",
          "request": "lnbc100n1pj4apw9...",
          "amount": 10,
          "unit": "sat",
          "state": "UNPAID",
          "expiry": 1701704757
        }
        """.data(using: .utf8)!
        
        let response = try JSONDecoder().decode(PostMintQuoteBolt11Response.self, from: specJSON)
        
        #expect(response.quote == "DSGLX9kevM...")
        #expect(response.request == "lnbc100n1pj4apw9...")
        #expect(response.amount == 10)
        #expect(response.unit == "sat")
        #expect(response.state == .unpaid)
        #expect(response.expiry == 1701704757)
    }
}