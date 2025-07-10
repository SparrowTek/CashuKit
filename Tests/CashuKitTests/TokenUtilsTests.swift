import Testing
@testable import CashuKit
import Foundation

@Suite("Token Utils")
struct TokenUtilsTests {
    
    // MARK: - Token Serialization Tests
    
    @Test
    func tokenVersionEnum() async throws {
        // Test version enumeration
        #expect(TokenVersion.v3.rawValue == "A")
        #expect(TokenVersion.v4.rawValue == "B")
        
        #expect(TokenVersion.v3.description == "V3 (JSON base64)")
        #expect(TokenVersion.v4.description == "V4 (CBOR binary)")
        
        // Test all cases
        let allVersions = TokenVersion.allCases
        #expect(allVersions.count == 2)
        #expect(allVersions.contains(.v3))
        #expect(allVersions.contains(.v4))
    }
    
    @Test
    func tokenSerializationV3() async throws {
        let proof = Proof(
            amount: 100,
            id: "test-keyset-id",
            secret: "test-secret",
            C: "deadbeef1234567890abcdef1234567890abcdef1234567890abcdef1234567890"
        )
        
        let token = CashuToken(
            token: [TokenEntry(mint: "https://mint.example.com", proofs: [proof])],
            unit: "sat",
            memo: "Test memo"
        )
        
        // Test V3 serialization
        let serialized = try CashuTokenUtils.serializeTokenV3(token)
        #expect(serialized.hasPrefix("cashuA"))
        #expect(!serialized.contains("cashu:"))
        
        // Test V3 serialization with URI
        let serializedWithURI = try CashuTokenUtils.serializeTokenV3(token, includeURI: true)
        #expect(serializedWithURI.hasPrefix("cashu:cashuA"))
        
        // Test V3 deserialization
        let deserialized = try CashuTokenUtils.deserializeTokenV3(serialized)
        #expect(deserialized.token.count == 1)
        #expect(deserialized.token[0].mint == "https://mint.example.com")
        #expect(deserialized.token[0].proofs.count == 1)
        #expect(deserialized.token[0].proofs[0].amount == 100)
        #expect(deserialized.token[0].proofs[0].secret == "test-secret")
        #expect(deserialized.unit == "sat")
        #expect(deserialized.memo == "Test memo")
        
        // Test V3 deserialization with URI
        let deserializedWithURI = try CashuTokenUtils.deserializeTokenV3(serializedWithURI)
        #expect(deserializedWithURI.token.count == 1)
        #expect(deserializedWithURI.token[0].proofs[0].amount == 100)
    }
    
    @Test
    func tokenSerializationV4() async throws {
        let proof = Proof(
            amount: 100,
            id: "test-keyset-id",
            secret: "test-secret",
            C: "deadbeef1234567890abcdef1234567890abcdef1234567890abcdef1234567890"
        )
        
        let token = CashuToken(
            token: [TokenEntry(mint: "https://mint.example.com", proofs: [proof])],
            unit: "sat",
            memo: "Test memo"
        )
        
        // Test V4 serialization (currently falls back to V3)
        let serialized = try CashuTokenUtils.serializeTokenV4(token)
        #expect(serialized.hasPrefix("cashuA")) // Falls back to V3
        
        // Test V4 deserialization (currently falls back to V3)
        let deserialized = try CashuTokenUtils.deserializeTokenV4(serialized)
        #expect(deserialized.token.count == 1)
        #expect(deserialized.token[0].proofs[0].amount == 100)
    }
    
    @Test
    func genericTokenSerialization() async throws {
        let proof = Proof(
            amount: 100,
            id: "test-keyset-id",
            secret: "test-secret",
            C: "deadbeef1234567890abcdef1234567890abcdef1234567890abcdef1234567890"
        )
        
        let token = CashuToken(
            token: [TokenEntry(mint: "https://mint.example.com", proofs: [proof])],
            unit: "sat",
            memo: "Test memo"
        )
        
        // Test default serialization (V3)
        let defaultSerialized = try CashuTokenUtils.serializeToken(token)
        #expect(defaultSerialized.hasPrefix("cashuA"))
        
        // Test explicit V3 serialization
        let v3Serialized = try CashuTokenUtils.serializeToken(token, version: .v3)
        #expect(v3Serialized.hasPrefix("cashuA"))
        
        // Test V4 serialization
        let v4Serialized = try CashuTokenUtils.serializeToken(token, version: .v4)
        #expect(v4Serialized.hasPrefix("cashuA")) // Falls back to V3
        
        // Test with URI
        let withURI = try CashuTokenUtils.serializeToken(token, includeURI: true)
        #expect(withURI.hasPrefix("cashu:cashuA"))
        
        // Test auto-deserialization
        let deserialized = try CashuTokenUtils.deserializeToken(defaultSerialized)
        #expect(deserialized.token.count == 1)
        #expect(deserialized.token[0].proofs[0].amount == 100)
        
        // Test auto-deserialization with URI
        let deserializedWithURI = try CashuTokenUtils.deserializeToken(withURI)
        #expect(deserializedWithURI.token.count == 1)
        #expect(deserializedWithURI.token[0].proofs[0].amount == 100)
    }
    
    @Test
    func jsonSerialization() async throws {
        let proof = Proof(
            amount: 100,
            id: "test-keyset-id",
            secret: "test-secret",
            C: "deadbeef1234567890abcdef1234567890abcdef1234567890abcdef1234567890"
        )
        
        let token = CashuToken(
            token: [TokenEntry(mint: "https://mint.example.com", proofs: [proof])],
            unit: "sat",
            memo: "Test memo"
        )
        
        // Test JSON serialization
        let jsonString = try CashuTokenUtils.serializeTokenJSON(token)
        #expect(jsonString.contains("\"amount\" : 100"))
        #expect(jsonString.contains("\"secret\" : \"test-secret\""))
        #expect(jsonString.contains("\"memo\" : \"Test memo\""))
        
        // Test JSON deserialization
        let deserialized = try CashuTokenUtils.deserializeTokenJSON(jsonString)
        #expect(deserialized.token.count == 1)
        #expect(deserialized.token[0].proofs[0].amount == 100)
        #expect(deserialized.token[0].proofs[0].secret == "test-secret")
        #expect(deserialized.memo == "Test memo")
    }
    
    // MARK: - Token Creation Tests
    
    @Test
    func tokenCreation() async throws {
        let unblindedToken = UnblindedToken(
            secret: "test-secret",
            signature: Data("deadbeef1234567890abcdef1234567890abcdef1234567890abcdef1234567890".utf8)
        )
        
        let token = CashuTokenUtils.createToken(
            from: unblindedToken,
            mintURL: "https://mint.example.com",
            amount: 100,
            unit: "sat",
            memo: "Test memo"
        )
        
        #expect(token.token.count == 1)
        #expect(token.token[0].mint == "https://mint.example.com")
        #expect(token.token[0].proofs.count == 1)
        #expect(token.token[0].proofs[0].amount == 100)
        #expect(token.token[0].proofs[0].secret == "test-secret")
        #expect(token.unit == "sat")
        #expect(token.memo == "Test memo")
        
        // Test without optional parameters
        let simpleToken = CashuTokenUtils.createToken(
            from: unblindedToken,
            mintURL: "https://mint.example.com",
            amount: 100
        )
        
        #expect(simpleToken.token.count == 1)
        #expect(simpleToken.unit == nil)
        #expect(simpleToken.memo == nil)
    }
    
    @Test
    func proofExtraction() async throws {
        let proof1 = Proof(amount: 100, id: "id1", secret: "secret1", C: "deadbeef1234567890abcdef1234567890abcdef1234567890abcdef1234567890")
        let proof2 = Proof(amount: 200, id: "id2", secret: "secret2", C: "abcdef1234567890deadbeef1234567890abcdef1234567890abcdef1234567890")
        let proof3 = Proof(amount: 50, id: "id3", secret: "secret3", C: "1234567890abcdefdeadbeef1234567890abcdef1234567890abcdef1234567890")
        
        let entry1 = TokenEntry(mint: "https://mint1.example.com", proofs: [proof1, proof2])
        let entry2 = TokenEntry(mint: "https://mint2.example.com", proofs: [proof3])
        
        let token = CashuToken(token: [entry1, entry2], unit: "sat", memo: nil)
        
        let extractedProofs = CashuTokenUtils.extractProofs(from: token)
        #expect(extractedProofs.count == 3)
        #expect(extractedProofs.contains { $0.amount == 100 })
        #expect(extractedProofs.contains { $0.amount == 200 })
        #expect(extractedProofs.contains { $0.amount == 50 })
        
        let totalAmount = extractedProofs.reduce(0) { $0 + $1.amount }
        #expect(totalAmount == 350)
    }
    
    // MARK: - Token Validation Tests
    
    @Test
    func tokenValidation() async throws {
        // Valid token
        let validProof = Proof(amount: 100, id: "id", secret: "secret", C: "deadbeef1234567890abcdef1234567890abcdef1234567890abcdef1234567890")
        let validEntry = TokenEntry(mint: "https://mint.example.com", proofs: [validProof])
        let validToken = CashuToken(token: [validEntry], unit: "sat", memo: nil)
        
        let validResult = CashuTokenUtils.validateToken(validToken)
        #expect(validResult)
        
        // Empty token
        let emptyToken = CashuToken(token: [], unit: "sat", memo: nil)
        let emptyResult = CashuTokenUtils.validateToken(emptyToken)
        #expect(!emptyResult)
        
        // Token with empty proofs
        let emptyProofEntry = TokenEntry(mint: "https://mint.example.com", proofs: [])
        let emptyProofToken = CashuToken(token: [emptyProofEntry], unit: "sat", memo: nil)
        let emptyProofResult = CashuTokenUtils.validateToken(emptyProofToken)
        #expect(!emptyProofResult)
        
        // Token with invalid proof
        let invalidProof = Proof(amount: 0, id: "id", secret: "secret", C: "deadbeef1234567890abcdef1234567890abcdef1234567890abcdef1234567890")
        let invalidEntry = TokenEntry(mint: "https://mint.example.com", proofs: [invalidProof])
        let invalidToken = CashuToken(token: [invalidEntry], unit: "sat", memo: nil)
        let invalidResult = CashuTokenUtils.validateToken(invalidToken)
        #expect(!invalidResult)
        
        // Token with empty secret
        let emptySecretProof = Proof(amount: 100, id: "id", secret: "", C: "deadbeef1234567890abcdef1234567890abcdef1234567890abcdef1234567890")
        let emptySecretEntry = TokenEntry(mint: "https://mint.example.com", proofs: [emptySecretProof])
        let emptySecretToken = CashuToken(token: [emptySecretEntry], unit: "sat", memo: nil)
        let emptySecretResult = CashuTokenUtils.validateToken(emptySecretToken)
        #expect(!emptySecretResult)
        
        // Token with invalid hex
        let invalidHexProof = Proof(amount: 100, id: "id", secret: "secret", C: "invalid-hex")
        let invalidHexEntry = TokenEntry(mint: "https://mint.example.com", proofs: [invalidHexProof])
        let invalidHexToken = CashuToken(token: [invalidHexEntry], unit: "sat", memo: nil)
        let invalidHexResult = CashuTokenUtils.validateToken(invalidHexToken)
        #expect(!invalidHexResult)
    }
    
    // MARK: - Serialization Error Tests
    
    @Test
    func serializationErrors() async throws {
        // Test invalid token format
        do {
            _ = try CashuTokenUtils.deserializeToken("invalid-token")
            #expect(Bool(false), "Should have thrown an error for invalid token format")
        } catch {
            #expect(error is CashuError)
        }
        
        // Test invalid prefix
        do {
            _ = try CashuTokenUtils.deserializeToken("invalid-prefix")
            #expect(Bool(false), "Should have thrown an error for invalid prefix")
        } catch {
            #expect(error is CashuError)
        }
        
        // Test invalid version
        do {
            _ = try CashuTokenUtils.deserializeToken("cashuX")
            #expect(Bool(false), "Should have thrown an error for invalid version")
        } catch {
            #expect(error is CashuError)
        }
        
        // Test invalid base64
        do {
            _ = try CashuTokenUtils.deserializeToken("cashuA!!!invalid-base64!!!")
            #expect(Bool(false), "Should have thrown an error for invalid base64")
        } catch {
            #expect(error is CashuError)
        }
    }
    
    @Test
    func jsonSerializationErrors() async throws {
        // Test invalid JSON
        do {
            _ = try CashuTokenUtils.deserializeTokenJSON("invalid-json")
            #expect(Bool(false), "Should have thrown an error for invalid JSON")
        } catch {
            #expect(error is CashuError)
        }
        
        // Test empty JSON
        do {
            _ = try CashuTokenUtils.deserializeTokenJSON("")
            #expect(Bool(false), "Should have thrown an error for empty JSON")
        } catch {
            #expect(error is CashuError)
        }
    }
    
    // MARK: - Base64 URL-Safe Encoding Tests
    
    @Test
    func base64URLSafeEncoding() async throws {
        let proof = Proof(
            amount: 100,
            id: "test-keyset-id",
            secret: "test-secret-with-special-chars!@#$%^&*()",
            C: "deadbeef1234567890abcdef1234567890abcdef1234567890abcdef1234567890"
        )
        
        let token = CashuToken(
            token: [TokenEntry(mint: "https://mint.example.com", proofs: [proof])],
            unit: "sat",
            memo: "Test memo with special chars: !@#$%^&*()"
        )
        
        let serialized = try CashuTokenUtils.serializeTokenV3(token)
        
        // Check that URL-safe base64 encoding is used (no + or / characters)
        let base64Part = String(serialized.dropFirst(6)) // Remove "cashuA" prefix
        #expect(!base64Part.contains("+"))
        #expect(!base64Part.contains("/"))
        
        // Ensure it can be deserialized correctly
        let deserialized = try CashuTokenUtils.deserializeTokenV3(serialized)
        #expect(deserialized.token[0].proofs[0].secret == "test-secret-with-special-chars!@#$%^&*()")
        #expect(deserialized.memo == "Test memo with special chars: !@#$%^&*()")
    }
    
    // MARK: - Multiple Token Entries Tests
    
    @Test
    func multipleTokenEntries() async throws {
        let proof1 = Proof(amount: 100, id: "id1", secret: "secret1", C: "deadbeef1234567890abcdef1234567890abcdef1234567890abcdef1234567890")
        let proof2 = Proof(amount: 200, id: "id2", secret: "secret2", C: "abcdef1234567890deadbeef1234567890abcdef1234567890abcdef1234567890")
        
        let entry1 = TokenEntry(mint: "https://mint1.example.com", proofs: [proof1])
        let entry2 = TokenEntry(mint: "https://mint2.example.com", proofs: [proof2])
        
        let token = CashuToken(token: [entry1, entry2], unit: "sat", memo: "Multi-mint token")
        
        let serialized = try CashuTokenUtils.serializeToken(token)
        let deserialized = try CashuTokenUtils.deserializeToken(serialized)
        
        #expect(deserialized.token.count == 2)
        #expect(deserialized.token[0].mint == "https://mint1.example.com")
        #expect(deserialized.token[1].mint == "https://mint2.example.com")
        #expect(deserialized.token[0].proofs[0].amount == 100)
        #expect(deserialized.token[1].proofs[0].amount == 200)
        #expect(deserialized.memo == "Multi-mint token")
    }
    
    // MARK: - Edge Cases Tests
    
    @Test
    func edgeCases() async throws {
        // Test token with no memo
        let proof = Proof(amount: 100, id: "id", secret: "secret", C: "deadbeef1234567890abcdef1234567890abcdef1234567890abcdef1234567890")
        let entry = TokenEntry(mint: "https://mint.example.com", proofs: [proof])
        let tokenWithoutMemo = CashuToken(token: [entry], unit: "sat", memo: nil)
        
        let serialized = try CashuTokenUtils.serializeToken(tokenWithoutMemo)
        let deserialized = try CashuTokenUtils.deserializeToken(serialized)
        
        #expect(deserialized.memo == nil)
        
        // Test token with empty memo
        let tokenWithEmptyMemo = CashuToken(token: [entry], unit: "sat", memo: "")
        let serializedEmpty = try CashuTokenUtils.serializeToken(tokenWithEmptyMemo)
        let deserializedEmpty = try CashuTokenUtils.deserializeToken(serializedEmpty)
        
        #expect(deserializedEmpty.memo == "")
        
        // Test token with very long memo
        let longMemo = String(repeating: "a", count: 1000)
        let tokenWithLongMemo = CashuToken(token: [entry], unit: "sat", memo: longMemo)
        let serializedLong = try CashuTokenUtils.serializeToken(tokenWithLongMemo)
        let deserializedLong = try CashuTokenUtils.deserializeToken(serializedLong)
        
        #expect(deserializedLong.memo == longMemo)
    }
}
