//
//  NUT09Tests.swift
//  CashuKit
//
//  Tests for NUT-09: Restore signatures
//

import Testing
import Foundation
@testable import CashuKit

@Suite("NUT09 tests")
struct NUT09Tests {
    
    // MARK: - PostRestoreRequest Tests
    
    @Test
    func postRestoreRequestCreation() throws {
        let blindedMessage1 = BlindedMessage(amount: 64, id: "keyset123", B_: "03a1b2c3d4e5f6789abcdef0123456789abcdef0123456789abcdef0123456789a")
        let blindedMessage2 = BlindedMessage(amount: 32, id: "keyset123", B_: "02599b9ea0a1ad4143706c2a5a4a568ce442dd4313e1cf1f7f0b58a317c1a355ee")
        
        let request = PostRestoreRequest(outputs: [blindedMessage1, blindedMessage2])
        
        #expect(request.outputs.count == 2)
        #expect(request.outputs[0].amount == 64)
        #expect(request.outputs[0].id == "keyset123")
        #expect(request.outputs[0].B_ == "03a1b2c3d4e5f6789abcdef0123456789abcdef0123456789abcdef0123456789a")
        #expect(request.outputs[1].amount == 32)
        #expect(request.outputs[1].B_ == "02599b9ea0a1ad4143706c2a5a4a568ce442dd4313e1cf1f7f0b58a317c1a355ee")
    }
    
    @Test
    func postRestoreRequestWithEmptyOutputs() throws {
        let request = PostRestoreRequest(outputs: [])
        #expect(request.outputs.isEmpty)
    }
    
    // MARK: - PostRestoreResponse Tests
    
    @Test
    func postRestoreResponseCreation() throws {
        let blindedMessage = BlindedMessage(amount: 64, id: "keyset123", B_: "03a1b2c3d4e5f6789abcdef0123456789abcdef0123456789abcdef0123456789a")
        let blindSignature = BlindSignature(amount: 64, id: "keyset123", C_: "02a1b2c3d4e5f6789abcdef0123456789abcdef0123456789abcdef0123456789a")
        
        let response = PostRestoreResponse(outputs: [blindedMessage], signatures: [blindSignature])
        
        #expect(response.outputs.count == 1)
        #expect(response.signatures.count == 1)
        #expect(response.isValid)
        #expect(response.outputs[0].amount == 64)
        #expect(response.signatures[0].amount == 64)
        #expect(response.outputs[0].id == response.signatures[0].id)
    }
    
    @Test
    func postRestoreResponseValidation() throws {
        let blindedMessage = BlindedMessage(amount: 64, id: "keyset123", B_: "03a1b2c3d4e5f6789abcdef0123456789abcdef0123456789abcdef0123456789a")
        let blindSignature1 = BlindSignature(amount: 64, id: "keyset123", C_: "02a1b2c3d4e5f6789abcdef0123456789abcdef0123456789abcdef0123456789a")
        let blindSignature2 = BlindSignature(amount: 32, id: "keyset123", C_: "03b1c2d3e4f5g6789abcdef0123456789abcdef0123456789abcdef0123456789b")
        
        // Valid response: equal array lengths
        let validResponse = PostRestoreResponse(outputs: [blindedMessage], signatures: [blindSignature1])
        #expect(validResponse.isValid)
        
        // Invalid response: mismatched array lengths
        let invalidResponse = PostRestoreResponse(outputs: [blindedMessage], signatures: [blindSignature1, blindSignature2])
        #expect(!invalidResponse.isValid)
        
        // Empty response is valid
        let emptyResponse = PostRestoreResponse(outputs: [], signatures: [])
        #expect(emptyResponse.isValid)
    }
    
    @Test
    func postRestoreResponseSignaturePairs() throws {
        let blindedMessage1 = BlindedMessage(amount: 64, id: "keyset123", B_: "03a1b2c3d4e5f6789abcdef0123456789abcdef0123456789abcdef0123456789a")
        let blindedMessage2 = BlindedMessage(amount: 32, id: "keyset123", B_: "02599b9ea0a1ad4143706c2a5a4a568ce442dd4313e1cf1f7f0b58a317c1a355ee")
        
        let blindSignature1 = BlindSignature(amount: 64, id: "keyset123", C_: "02a1b2c3d4e5f6789abcdef0123456789abcdef0123456789abcdef0123456789a")
        let blindSignature2 = BlindSignature(amount: 32, id: "keyset123", C_: "03b1c2d3e4f5g6789abcdef0123456789abcdef0123456789abcdef0123456789b")
        
        let response = PostRestoreResponse(
            outputs: [blindedMessage1, blindedMessage2],
            signatures: [blindSignature1, blindSignature2]
        )
        
        let pairs = response.signaturePairs
        
        #expect(pairs.count == 2)
        #expect(pairs[0].output.amount == 64)
        #expect(pairs[0].signature.amount == 64)
        #expect(pairs[1].output.amount == 32)
        #expect(pairs[1].signature.amount == 32)
    }
    
    // MARK: - MintInfo NUT-09 Support Tests
    
    @Test
    func mintInfoSupportsRestoreSignatures() throws {
        // Test mint that supports NUT-09
        let nutsWithSupport: [String: NutValue] = [
            "9": .dictionary(["supported": AnyCodable(true)])
        ]
        let mintInfoWithSupport = MintInfo(nuts: nutsWithSupport)
        #expect(mintInfoWithSupport.supportsRestoreSignatures())
        
        // Test mint that doesn't support NUT-09
        let nutsWithoutSupport: [String: NutValue] = [
            "4": .dictionary(["supported": AnyCodable(true)])
        ]
        let mintInfoWithoutSupport = MintInfo(nuts: nutsWithoutSupport)
        #expect(!mintInfoWithoutSupport.supportsRestoreSignatures())
        
        // Test mint with NUT-09 explicitly disabled
        let nutsDisabled: [String: NutValue] = [
            "9": .dictionary(["supported": AnyCodable(false)])
        ]
        let mintInfoDisabled = MintInfo(nuts: nutsDisabled)
        #expect(!mintInfoDisabled.supportsRestoreSignatures())
    }
    
    // MARK: - MintCapabilities NUT-09 Support Tests
    
    @Test
    func mintCapabilitiesIncludeRestoreSignatures() throws {
        let nutsWithSupport: [String: NutValue] = [
            "9": .dictionary(["supported": AnyCodable(true)])
        ]
        let mintInfo = MintInfo(nuts: nutsWithSupport)
        let capabilities = MintCapabilities(from: mintInfo)
        
        #expect(capabilities.supportsRestoreSignatures)
        #expect(capabilities.summary.contains("Restore Signatures"))
    }
    
    @Test
    func mintCapabilitiesWithoutRestoreSignatures() throws {
        let nutsWithoutSupport: [String: NutValue] = [
            "4": .dictionary(["supported": AnyCodable(true)])
        ]
        let mintInfo = MintInfo(nuts: nutsWithoutSupport)
        let capabilities = MintCapabilities(from: mintInfo)
        
        #expect(!capabilities.supportsRestoreSignatures)
        #expect(!capabilities.summary.contains("Restore Signatures"))
    }
    
    // MARK: - JSON Encoding/Decoding Tests
    
    @Test
    func postRestoreRequestJSONEncoding() throws {
        let blindedMessage = BlindedMessage(amount: 64, id: "keyset123", B_: "03a1b2c3d4e5f6789abcdef0123456789abcdef0123456789abcdef0123456789a")
        let request = PostRestoreRequest(outputs: [blindedMessage])
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(request)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        
        #expect(json != nil)
        let outputs = json?["outputs"] as? [[String: Any]]
        #expect(outputs?.count == 1)
        #expect(outputs?[0]["amount"] as? Int == 64)
        #expect(outputs?[0]["id"] as? String == "keyset123")
        #expect(outputs?[0]["B_"] as? String == "03a1b2c3d4e5f6789abcdef0123456789abcdef0123456789abcdef0123456789a")
    }
    
    @Test
    func postRestoreResponseJSONDecoding() throws {
        let json = """
        {
            "outputs": [
                {
                    "amount": 64,
                    "id": "keyset123",
                    "B_": "03a1b2c3d4e5f6789abcdef0123456789abcdef0123456789abcdef0123456789a"
                }
            ],
            "signatures": [
                {
                    "amount": 64,
                    "id": "keyset123",
                    "C_": "02a1b2c3d4e5f6789abcdef0123456789abcdef0123456789abcdef0123456789a"
                }
            ]
        }
        """
        
        let decoder = JSONDecoder()
        let data = json.data(using: .utf8)!
        let response = try decoder.decode(PostRestoreResponse.self, from: data)
        
        #expect(response.isValid)
        #expect(response.outputs.count == 1)
        #expect(response.signatures.count == 1)
        #expect(response.outputs[0].amount == 64)
        #expect(response.signatures[0].amount == 64)
        #expect(response.outputs[0].id == "keyset123")
        #expect(response.signatures[0].id == "keyset123")
    }
    
    // MARK: - Error Handling Tests
    
    @Test
    func invalidRestoreResponseHandling() throws {
        let json = """
        {
            "outputs": [
                {
                    "amount": 64,
                    "id": "keyset123",
                    "B_": "03a1b2c3d4e5f6789abcdef0123456789abcdef0123456789abcdef0123456789a"
                }
            ],
            "signatures": []
        }
        """
        
        let decoder = JSONDecoder()
        let data = json.data(using: .utf8)!
        let response = try decoder.decode(PostRestoreResponse.self, from: data)
        
        #expect(!response.isValid)
        #expect(response.outputs.count == 1)
        #expect(response.signatures.count == 0)
    }
}

@Test("NUT-09 restoration edge cases")
func testRestorationGapsEdgeCases() throws {
    // Empty outputs/signatures: valid but yields no pairs
    let empty = PostRestoreResponse(outputs: [], signatures: [])
    #expect(empty.isValid)
    #expect(empty.signaturePairs.isEmpty)

    // Mismatched amounts: current implementation considers structure valid; pairs still returned
    let out = BlindedMessage(amount: 2, id: "k1", B_: "02ab")
    let sig = BlindSignature(amount: 4, id: "k1", C_: "03cd")
    let mismatch = PostRestoreResponse(outputs: [out], signatures: [sig])
    #expect(mismatch.isValid)
    #expect(mismatch.signaturePairs.count == 1)
}