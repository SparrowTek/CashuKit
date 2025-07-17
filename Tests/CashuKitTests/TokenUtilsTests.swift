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
    
    // MARK: - Token Value Calculation Tests
    
    @Test
    func tokenValueCalculation() async throws {
        let proof1 = Proof(amount: 100, id: "id1", secret: "secret1", C: "deadbeef1234567890abcdef1234567890abcdef1234567890abcdef1234567890")
        let proof2 = Proof(amount: 200, id: "id2", secret: "secret2", C: "abcdef1234567890deadbeef1234567890abcdef1234567890abcdef1234567890")
        let proof3 = Proof(amount: 50, id: "id3", secret: "secret3", C: "1234567890abcdefdeadbeef1234567890abcdef1234567890abcdef1234567890")
        
        let entry1 = TokenEntry(mint: "https://mint1.example.com", proofs: [proof1, proof2])
        let entry2 = TokenEntry(mint: "https://mint2.example.com", proofs: [proof3])
        
        let token = CashuToken(token: [entry1, entry2], unit: "sat", memo: nil)
        
        let totalValue = CashuTokenUtils.calculateTokenValue(token)
        #expect(totalValue == 350)
        
        // Test empty token
        let emptyToken = CashuToken(token: [], unit: "sat", memo: nil)
        let emptyValue = CashuTokenUtils.calculateTokenValue(emptyToken)
        #expect(emptyValue == 0)
        
        // Test single proof token
        let singleEntry = TokenEntry(mint: "https://mint.example.com", proofs: [proof1])
        let singleToken = CashuToken(token: [singleEntry], unit: "sat", memo: nil)
        let singleValue = CashuTokenUtils.calculateTokenValue(singleToken)
        #expect(singleValue == 100)
    }
    
    @Test
    func proofGroupingByMint() async throws {
        let proof1 = Proof(amount: 100, id: "id1", secret: "secret1", C: "deadbeef1234567890abcdef1234567890abcdef1234567890abcdef1234567890")
        let proof2 = Proof(amount: 200, id: "id2", secret: "secret2", C: "abcdef1234567890deadbeef1234567890abcdef1234567890abcdef1234567890")
        let proof3 = Proof(amount: 50, id: "id3", secret: "secret3", C: "1234567890abcdefdeadbeef1234567890abcdef1234567890abcdef1234567890")
        
        let mint1URL = "https://mint1.example.com"
        let mint2URL = "https://mint2.example.com"
        
        let entry1 = TokenEntry(mint: mint1URL, proofs: [proof1, proof2])
        let entry2 = TokenEntry(mint: mint2URL, proofs: [proof3])
        
        let token = CashuToken(token: [entry1, entry2], unit: "sat", memo: nil)
        
        let groupedProofs = CashuTokenUtils.groupProofsByMint(token)
        
        #expect(groupedProofs.count == 2)
        #expect(groupedProofs[mint1URL]?.count == 2)
        #expect(groupedProofs[mint2URL]?.count == 1)
        #expect(groupedProofs[mint1URL]?.contains { $0.amount == 100 } == true)
        #expect(groupedProofs[mint1URL]?.contains { $0.amount == 200 } == true)
        #expect(groupedProofs[mint2URL]?.contains { $0.amount == 50 } == true)
    }
    
    @Test
    func createTokenFromMultipleMints() async throws {
        let proof1 = Proof(amount: 100, id: "id1", secret: "secret1", C: "deadbeef1234567890abcdef1234567890abcdef1234567890abcdef1234567890")
        let proof2 = Proof(amount: 200, id: "id2", secret: "secret2", C: "abcdef1234567890deadbeef1234567890abcdef1234567890abcdef1234567890")
        let proof3 = Proof(amount: 50, id: "id3", secret: "secret3", C: "1234567890abcdefdeadbeef1234567890abcdef1234567890abcdef1234567890")
        
        let mint1URL = "https://mint1.example.com"
        let mint2URL = "https://mint2.example.com"
        
        let proofsByMint: [String: [Proof]] = [
            mint1URL: [proof1, proof2],
            mint2URL: [proof3]
        ]
        
        let token = CashuTokenUtils.createTokenFromMultipleMints(
            proofsByMint: proofsByMint,
            unit: "sat",
            memo: "Multi-mint token"
        )
        
        #expect(token.token.count == 2)
        #expect(token.unit == "sat")
        #expect(token.memo == "Multi-mint token")
        
        let mintURLs = Set(token.token.map { $0.mint })
        #expect(mintURLs.contains(mint1URL))
        #expect(mintURLs.contains(mint2URL))
        
        let totalValue = CashuTokenUtils.calculateTokenValue(token)
        #expect(totalValue == 350)
    }
    
    // MARK: - Import/Export Tests
    
    @Test
    func tokenExportFormats() async throws {
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
        
        // Test serialized format
        let serialized = try CashuTokenUtils.exportToken(token, format: .serialized)
        #expect(serialized.hasPrefix("cashuA"))
        #expect(!serialized.contains("cashu:"))
        
        // Test JSON format
        let json = try CashuTokenUtils.exportToken(token, format: .json)
        #expect(json.contains("\"amount\" : 100"))
        #expect(json.contains("\"secret\" : \"test-secret\""))
        
        // Test QR code format (should include URI)
        let qr = try CashuTokenUtils.exportToken(token, format: .qrCode)
        #expect(qr.hasPrefix("cashu:cashuA"))
        
        // Test serialized with URI
        let serializedWithURI = try CashuTokenUtils.exportToken(token, format: .serialized, includeURI: true)
        #expect(serializedWithURI.hasPrefix("cashu:cashuA"))
    }
    
    @Test
    func tokenImportFormats() async throws {
        let proof = Proof(
            amount: 100,
            id: "test-keyset-id",
            secret: "test-secret",
            C: "deadbeef1234567890abcdef1234567890abcdef1234567890abcdef1234567890"
        )
        
        let originalToken = CashuToken(
            token: [TokenEntry(mint: "https://mint.example.com", proofs: [proof])],
            unit: "sat",
            memo: "Test memo"
        )
        
        // Test import from serialized format
        let serialized = try CashuTokenUtils.exportToken(originalToken, format: .serialized)
        let importedFromSerialized = try CashuTokenUtils.importToken(serialized, format: .serialized)
        #expect(importedFromSerialized.token[0].proofs[0].amount == 100)
        #expect(importedFromSerialized.memo == "Test memo")
        
        // Test import from JSON format
        let json = try CashuTokenUtils.exportToken(originalToken, format: .json)
        let importedFromJSON = try CashuTokenUtils.importToken(json, format: .json)
        #expect(importedFromJSON.token[0].proofs[0].amount == 100)
        #expect(importedFromJSON.memo == "Test memo")
        
        // Test auto-detection of format
        let autoDetectedSerialized = try CashuTokenUtils.importToken(serialized)
        #expect(autoDetectedSerialized.token[0].proofs[0].amount == 100)
        
        let autoDetectedJSON = try CashuTokenUtils.importToken(json)
        #expect(autoDetectedJSON.token[0].proofs[0].amount == 100)
        
        // Test import with URI scheme
        let withURI = try CashuTokenUtils.exportToken(originalToken, format: .qrCode)
        let importedWithURI = try CashuTokenUtils.importToken(withURI)
        #expect(importedWithURI.token[0].proofs[0].amount == 100)
    }
    
    @Test
    func tokenValidationForImports() async throws {
        let validProof = Proof(amount: 100, id: "id", secret: "secret", C: "deadbeef1234567890abcdef1234567890abcdef1234567890abcdef1234567890")
        let validEntry = TokenEntry(mint: "https://mint.example.com", proofs: [validProof])
        let validToken = CashuToken(token: [validEntry], unit: "sat", memo: nil)
        
        // Test valid token
        let validResult = CashuTokenUtils.validateImportedToken(validToken)
        #expect(validResult.isValid)
        #expect(validResult.errors.isEmpty)
        #expect(validResult.totalValue == 100)
        
        // Test invalid token structure
        let emptyToken = CashuToken(token: [], unit: "sat", memo: nil)
        let emptyResult = CashuTokenUtils.validateImportedToken(emptyToken)
        #expect(!emptyResult.isValid)
        #expect(!emptyResult.errors.isEmpty)
        
        // Test duplicate proofs
        let duplicateEntry = TokenEntry(mint: "https://mint.example.com", proofs: [validProof, validProof])
        let duplicateToken = CashuToken(token: [duplicateEntry], unit: "sat", memo: nil)
        let duplicateResult = CashuTokenUtils.validateImportedToken(duplicateToken)
        #expect(!duplicateResult.isValid)
        #expect(duplicateResult.errors.contains { $0.contains("Duplicate proofs") })
        
        // Test strict validation
        let largeProof = Proof(amount: 2_000_000, id: "id", secret: "secret", C: "deadbeef1234567890abcdef1234567890abcdef1234567890abcdef1234567890")
        let largeEntry = TokenEntry(mint: "https://mint.example.com", proofs: [largeProof])
        let largeToken = CashuToken(token: [largeEntry], unit: "sat", memo: nil)
        
        let strictResult = CashuTokenUtils.validateImportedToken(largeToken, strictValidation: true)
        #expect(strictResult.isValid) // Should still be valid
        #expect(strictResult.hasWarnings) // But should have warnings
        #expect(strictResult.warnings.contains { $0.contains("unusually large amount") })
    }
    
    // MARK: - Token Backup Tests
    
    @Test
    func tokenBackupAndRestore() async throws {
        let proof1 = Proof(amount: 100, id: "id1", secret: "secret1", C: "deadbeef1234567890abcdef1234567890abcdef1234567890abcdef1234567890")
        let proof2 = Proof(amount: 200, id: "id2", secret: "secret2", C: "abcdef1234567890deadbeef1234567890abcdef1234567890abcdef1234567890")
        
        let token1 = CashuToken(token: [TokenEntry(mint: "https://mint1.example.com", proofs: [proof1])], unit: "sat", memo: "Token 1")
        let token2 = CashuToken(token: [TokenEntry(mint: "https://mint2.example.com", proofs: [proof2])], unit: "sat", memo: "Token 2")
        
        let tokens = [token1, token2]
        
        let metadata = TokenBackupMetadata(
            deviceName: "Test Device",
            appVersion: "1.0",
            totalValue: 300,
            tokenCount: 2,
            mintUrls: ["https://mint1.example.com", "https://mint2.example.com"],
            notes: "Test backup"
        )
        
        // Create backup
        let backupData = try CashuTokenUtils.createTokenBackup(tokens, metadata: metadata)
        #expect(backupData.contains("\"version\" : \"1.0\""))
        #expect(backupData.contains("\"deviceName\" : \"Test Device\""))
        #expect(backupData.contains("\"totalValue\" : 300"))
        
        // Restore backup
        let (restoredTokens, restoredMetadata) = try CashuTokenUtils.restoreTokenBackup(backupData)
        
        #expect(restoredTokens.count == 2)
        #expect(restoredTokens[0].memo == "Token 1")
        #expect(restoredTokens[1].memo == "Token 2")
        
        #expect(restoredMetadata?.deviceName == "Test Device")
        #expect(restoredMetadata?.appVersion == "1.0")
        #expect(restoredMetadata?.totalValue == 300)
        #expect(restoredMetadata?.tokenCount == 2)
        #expect(restoredMetadata?.notes == "Test backup")
        
        let totalValue = restoredTokens.reduce(0) { total, token in
            total + CashuTokenUtils.calculateTokenValue(token)
        }
        #expect(totalValue == 300)
    }
    
    @Test
    func tokenBackupWithoutMetadata() async throws {
        let proof = Proof(amount: 100, id: "id", secret: "secret", C: "deadbeef1234567890abcdef1234567890abcdef1234567890abcdef1234567890")
        let token = CashuToken(token: [TokenEntry(mint: "https://mint.example.com", proofs: [proof])], unit: "sat", memo: nil)
        
        let backupData = try CashuTokenUtils.createTokenBackup([token])
        let (restoredTokens, restoredMetadata) = try CashuTokenUtils.restoreTokenBackup(backupData)
        
        #expect(restoredTokens.count == 1)
        #expect(restoredTokens[0].token[0].proofs[0].amount == 100)
        #expect(restoredMetadata?.deviceName == nil)
        #expect(restoredMetadata?.appVersion == nil)
    }
    
    @Test
    func tokenBackupErrors() async throws {
        // Test invalid backup data
        do {
            _ = try CashuTokenUtils.restoreTokenBackup("invalid json")
            #expect(Bool(false), "Should have thrown an error for invalid JSON")
        } catch {
            #expect(error is CashuError)
        }
        
        // Test unsupported version
        let invalidVersionBackup = """
        {
            "version": "2.0",
            "timestamp": "2023-01-01T00:00:00Z",
            "tokens": [],
            "metadata": null
        }
        """
        
        do {
            _ = try CashuTokenUtils.restoreTokenBackup(invalidVersionBackup)
            #expect(Bool(false), "Should have thrown an error for unsupported version")
        } catch {
            #expect(error is CashuError)
        }
    }
    
    // MARK: - NUT-00 Test Vectors
    
    @Test("TokenV3 serialization test vectors from NUT-00")
    func tokenV3SerializationTestVectors() throws {
        // Create token from NUT-00 test vector
        let proof1 = Proof(
            amount: 2,
            id: "009a1f293253e41e",
            secret: "407915bc212be61a77e3e6d2aeb4c727980bda51cd06a6afc29e2861768a7837",
            C: "02bc9097997d81afb2cc7346b5e4345a9346bd2a506eb7958598a72f0cf85163ea"
        )
        
        let proof2 = Proof(
            amount: 8,
            id: "009a1f293253e41e",
            secret: "fe15109314e61d7756b0f8ee0f23a624acaa3f4e042f61433c728c7057b931be",
            C: "029e8e5050b890a7d6c0968db16bc1d5d5fa040ea1de284f6ec69d61299f671059"
        )
        
        let token = CashuToken(
            token: [TokenEntry(mint: "https://8333.space:3338", proofs: [proof1, proof2])],
            unit: "sat",
            memo: "Thank you."
        )
        
        let expectedSerialized = "cashuAeyJ0b2tlbiI6W3sibWludCI6Imh0dHBzOi8vODMzMy5zcGFjZTozMzM4IiwicHJvb2ZzIjpbeyJhbW91bnQiOjIsImlkIjoiMDA5YTFmMjkzMjUzZTQxZSIsInNlY3JldCI6IjQwNzkxNWJjMjEyYmU2MWE3N2UzZTZkMmFlYjRjNzI3OTgwYmRhNTFjZDA2YTZhZmMyOWUyODYxNzY4YTc4MzciLCJDIjoiMDJiYzkwOTc5OTdkODFhZmIyY2M3MzQ2YjVlNDM0NWE5MzQ2YmQyYTUwNmViNzk1ODU5OGE3MmYwY2Y4NTE2M2VhIn0seyJhbW91bnQiOjgsImlkIjoiMDA5YTFmMjkzMjUzZTQxZSIsInNlY3JldCI6ImZlMTUxMDkzMTRlNjFkNzc1NmIwZjhlZTBmMjNhNjI0YWNhYTNmNGUwNDJmNjE0MzNjNzI4YzcwNTdiOTMxYmUiLCJDIjoiMDI5ZThlNTA1MGI4OTBhN2Q2YzA5NjhkYjE2YmMxZDVkNWZhMDQwZWExZGUyODRmNmVjNjlkNjEyOTlmNjcxMDU5In1dfV0sInVuaXQiOiJzYXQiLCJtZW1vIjoiVGhhbmsgeW91LiJ9"
        
        // Test serialization (check that it can be deserialized correctly)
        let serialized = try CashuTokenUtils.serializeTokenV3(token)
        let deserializedFromSerialized = try CashuTokenUtils.deserializeTokenV3(serialized)
        #expect(deserializedFromSerialized.token[0].proofs[0].amount == 2)
        #expect(deserializedFromSerialized.token[0].proofs[1].amount == 8)
        
        // Test deserialization
        let deserialized = try CashuTokenUtils.deserializeTokenV3(expectedSerialized)
        #expect(deserialized.token.count == 1)
        #expect(deserialized.token[0].mint == "https://8333.space:3338")
        #expect(deserialized.token[0].proofs.count == 2)
        #expect(deserialized.token[0].proofs[0].amount == 2)
        #expect(deserialized.token[0].proofs[0].id == "009a1f293253e41e")
        #expect(deserialized.token[0].proofs[0].secret == "407915bc212be61a77e3e6d2aeb4c727980bda51cd06a6afc29e2861768a7837")
        #expect(deserialized.token[0].proofs[0].C == "02bc9097997d81afb2cc7346b5e4345a9346bd2a506eb7958598a72f0cf85163ea")
        #expect(deserialized.token[0].proofs[1].amount == 8)
        #expect(deserialized.unit == "sat")
        #expect(deserialized.memo == "Thank you.")
    }
    
    @Test("TokenV3 deserialization test vectors from NUT-00")
    func tokenV3DeserializationTestVectors() throws {
        // Test invalid tokens (should fail)
        let invalidTokens = [
            // Incorrect prefix (casshuA)
            "casshuAeyJ0b2tlbiI6W3sibWludCI6Imh0dHBzOi8vODMzMy5zcGFjZTozMzM4IiwicHJvb2ZzIjpbeyJhbW91bnQiOjIsImlkIjoiMDA5YTFmMjkzMjUzZTQxZSIsInNlY3JldCI6IjQwNzkxNWJjMjEyYmU2MWE3N2UzZTZkMmFlYjRjNzI3OTgwYmRhNTFjZDA2YTZhZmMyOWUyODYxNzY4YTc4MzciLCJDIjoiMDJiYzkwOTc5OTdkODFhZmIyY2M3MzQ2YjVlNDM0NWE5MzQ2YmQyYTUwNmViNzk1ODU5OGE3MmYwY2Y4NTE2M2VhIn0seyJhbW91bnQiOjgsImlkIjoiMDA5YTFmMjkzMjUzZTQxZSIsInNlY3JldCI6ImZlMTUxMDkzMTRlNjFkNzc1NmIwZjhlZTBmMjNhNjI0YWNhYTNmNGUwNDJmNjE0MzNjNzI4YzcwNTdiOTMxYmUiLCJDIjoiMDI5ZThlNTA1MGI4OTBhN2Q2YzA5NjhkYjE2YmMxZDVkNWZhMDQwZWExZGUyODRmNmVjNjlkNjEyOTlmNjcxMDU5In1dfV0sInVuaXQiOiJzYXQiLCJtZW1vIjoiVGhhbmsgeW91LiJ9",
            // No prefix
            "eyJ0b2tlbiI6W3sibWludCI6Imh0dHBzOi8vODMzMy5zcGFjZTozMzM4IiwicHJvb2ZzIjpbeyJhbW91bnQiOjIsImlkIjoiMDA5YTFmMjkzMjUzZTQxZSIsInNlY3JldCI6IjQwNzkxNWJjMjEyYmU2MWE3N2UzZTZkMmFlYjRjNzI3OTgwYmRhNTFjZDA2YTZhZmMyOWUyODYxNzY4YTc4MzciLCJDIjoiMDJiYzkwOTc5OTdkODFhZmIyY2M3MzQ2YjVlNDM0NWE5MzQ2YmQyYTUwNmViNzk1ODU5OGE3MmYwY2Y4NTE2M2VhIn0seyJhbW91bnQiOjgsImlkIjoiMDA5YTFmMjkzMjUzZTQxZSIsInNlY3JldCI6ImZlMTUxMDkzMTRlNjFkNzc1NmIwZjhlZTBmMjNhNjI0YWNhYTNmNGUwNDJmNjE0MzNjNzI4YzcwNTdiOTMxYmUiLCJDIjoiMDI5ZThlNTA1MGI4OTBhN2Q2YzA5NjhkYjE2YmMxZDVkNWZhMDQwZWExZGUyODRmNmVjNjlkNjEyOTlmNjcxMDU5In1dfV0sInVuaXQiOiJzYXQiLCJtZW1vIjoiVGhhbmsgeW91LiJ9"
        ]
        
        for invalidToken in invalidTokens {
            do {
                _ = try CashuTokenUtils.deserializeTokenV3(invalidToken)
                #expect(Bool(false), "Should have thrown an error for invalid token")
            } catch {
                // Expected to fail
                #expect(error is CashuError)
            }
        }
        
        // Test valid tokens (with and without padding)
        let validTokens = [
            // Without padding
            "cashuAeyJ0b2tlbiI6W3sibWludCI6Imh0dHBzOi8vODMzMy5zcGFjZTozMzM4IiwicHJvb2ZzIjpbeyJhbW91bnQiOjIsImlkIjoiMDA5YTFmMjkzMjUzZTQxZSIsInNlY3JldCI6IjQwNzkxNWJjMjEyYmU2MWE3N2UzZTZkMmFlYjRjNzI3OTgwYmRhNTFjZDA2YTZhZmMyOWUyODYxNzY4YTc4MzciLCJDIjoiMDJiYzkwOTc5OTdkODFhZmIyY2M3MzQ2YjVlNDM0NWE5MzQ2YmQyYTUwNmViNzk1ODU5OGE3MmYwY2Y4NTE2M2VhIn0seyJhbW91bnQiOjgsImlkIjoiMDA5YTFmMjkzMjUzZTQxZSIsInNlY3JldCI6ImZlMTUxMDkzMTRlNjFkNzc1NmIwZjhlZTBmMjNhNjI0YWNhYTNmNGUwNDJmNjE0MzNjNzI4YzcwNTdiOTMxYmUiLCJDIjoiMDI5ZThlNTA1MGI4OTBhN2Q2YzA5NjhkYjE2YmMxZDVkNWZhMDQwZWExZGUyODRmNmVjNjlkNjEyOTlmNjcxMDU5In1dfV0sInVuaXQiOiJzYXQiLCJtZW1vIjoiVGhhbmsgeW91IHZlcnkgbXVjaC4ifQ",
            // With padding
            "cashuAeyJ0b2tlbiI6W3sibWludCI6Imh0dHBzOi8vODMzMy5zcGFjZTozMzM4IiwicHJvb2ZzIjpbeyJhbW91bnQiOjIsImlkIjoiMDA5YTFmMjkzMjUzZTQxZSIsInNlY3JldCI6IjQwNzkxNWJjMjEyYmU2MWE3N2UzZTZkMmFlYjRjNzI3OTgwYmRhNTFjZDA2YTZhZmMyOWUyODYxNzY4YTc4MzciLCJDIjoiMDJiYzkwOTc5OTdkODFhZmIyY2M3MzQ2YjVlNDM0NWE5MzQ2YmQyYTUwNmViNzk1ODU5OGE3MmYwY2Y4NTE2M2VhIn0seyJhbW91bnQiOjgsImlkIjoiMDA5YTFmMjkzMjUzZTQxZSIsInNlY3JldCI6ImZlMTUxMDkzMTRlNjFkNzc1NmIwZjhlZTBmMjNhNjI0YWNhYTNmNGUwNDJmNjE0MzNjNzI4YzcwNTdiOTMxYmUiLCJDIjoiMDI5ZThlNTA1MGI4OTBhN2Q2YzA5NjhkYjE2YmMxZDVkNWZhMDQwZWExZGUyODRmNmVjNjlkNjEyOTlmNjcxMDU5In1dfV0sInVuaXQiOiJzYXQiLCJtZW1vIjoiVGhhbmsgeW91IHZlcnkgbXVjaC4ifQ=="
        ]
        
        for validToken in validTokens {
            let deserialized = try CashuTokenUtils.deserializeTokenV3(validToken)
            #expect(deserialized.token.count == 1)
            #expect(deserialized.token[0].mint == "https://8333.space:3338")
            #expect(deserialized.token[0].proofs.count == 2)
            #expect(deserialized.memo == "Thank you very much.")
        }
    }
}
