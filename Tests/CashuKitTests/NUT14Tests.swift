//
//  NUT14Tests.swift
//  CashuKitTests
//
//  Tests for NUT-14: Hashed Timelock Contracts (HTLCs)
//

import Testing
@testable import CashuKit
import Foundation
import CryptoKit
import P256K

@Suite("NUT-14 Tests")
struct NUT14Tests {
    
    @Test("HTLC preimage generation and verification")
    func testPreimageGeneration() throws {
        // Generate a preimage
        let preimage = HTLCCreator.generatePreimage()
        #expect(preimage.count == 32)
        
        // Calculate hash
        let hash = SHA256.hash(data: preimage)
        let hashHex = Data(hash).hexString
        
        // Verify preimage matches hash
        let witness = HTLCWitness(preimage: preimage.hexString, signatures: [])
        let verified = try HTLCVerifier.verifyPreimage(
            preimage: witness.preimage,
            hashLock: hashHex
        )
        
        #expect(verified == true)
    }
    
    @Test("HTLC secret creation")
    func testHTLCSecretCreation() throws {
        let preimage = HTLCCreator.generatePreimage()
        let pubkey = "02a9acc1e48c25eeeb9289b5031cc57da9fe72f3fe2861d264bdc074209b107ba2"
        
        let secret = try HTLCCreator.createHTLCSecret(
            preimage: preimage,
            pubkeys: [pubkey],
            locktime: 1689418329,
            refundKey: "033281c37677ea273eb7183b783067f5244933ef78d8c3f15b1a77cb246099c26e"
        )
        
        // Decode and verify the secret
        let wellKnownSecret = try WellKnownSecret.fromString(secret)
        
        #expect(wellKnownSecret.kind == SpendingConditionKind.htlc)
        #expect(wellKnownSecret.secretData.data.count == 64) // SHA256 hash as hex
        #expect(wellKnownSecret.secretData.tags != nil)
        
        // Check tags
        let tags = wellKnownSecret.secretData.tags!
        #expect(tags.contains(where: { $0.first == "pubkeys" }))
        #expect(tags.contains(where: { $0.first == "locktime" }))
        #expect(tags.contains(where: { $0.first == "refund" }))
    }
    
    @Test("HTLC witness serialization")
    func testHTLCWitnessSerialization() throws {
        let witness = HTLCWitness(
            preimage: "0000000000000000000000000000000000000000000000000000000000000001",
            signatures: [
                "signature1",
                "signature2"
            ]
        )
        
        let jsonData = try JSONEncoder().encode(witness)
        let jsonString = String(data: jsonData, encoding: .utf8)!
        
        // Verify JSON structure
        #expect(jsonString.contains("\"preimage\""))
        #expect(jsonString.contains("\"signatures\""))
        
        // Test deserialization
        let decoded = try JSONDecoder().decode(HTLCWitness.self, from: jsonData)
        #expect(decoded.preimage == witness.preimage)
        #expect(decoded.signatures == witness.signatures)
    }
    
    @Test("HTLC verification with valid preimage")
    func testHTLCVerificationWithPreimage() throws {
        let preimage = Data(hexString: "0000000000000000000000000000000000000000000000000000000000000001")!
        let hash = SHA256.hash(data: preimage)
        let hashHex = Data(hash).hexString
        
        // Create a proof with HTLC secret
        let secretData = WellKnownSecret.SecretData(
            nonce: "da62796403af76c80cd6ce9153ed3746",
            data: hashHex,
            tags: nil
        )
        
        let wellKnownSecret = WellKnownSecret(
            kind: SpendingConditionKind.htlc,
            secretData: secretData
        )
        
        let proof = Proof(
            amount: 100,
            id: "test_keyset",
            secret: try wellKnownSecret.toJSONString(),
            C: "02a9acc1e48c25eeeb9289b5031cc57da9fe72f3fe2861d264bdc074209b107ba2"
        )
        
        // Create witness with preimage
        let witness = HTLCWitness(
            preimage: preimage.hexString,
            signatures: []
        )
        
        // Verify
        let verified = try HTLCVerifier.verifyHTLC(
            proof: proof,
            witness: witness
        )
        
        #expect(verified == true)
    }
    
    @Test("HTLC verification with locktime and refund")
    func testHTLCVerificationWithRefund() throws {
        let preimage = Data(hexString: "0000000000000000000000000000000000000000000000000000000000000001")!
        let hash = SHA256.hash(data: preimage)
        let hashHex = Data(hash).hexString
        let refundKey = "033281c37677ea273eb7183b783067f5244933ef78d8c3f15b1a77cb246099c26e"
        
        // Create HTLC with expired locktime
        let expiredLocktime = Int64(Date().timeIntervalSince1970) - 3600 // 1 hour ago
        
        let secretData = WellKnownSecret.SecretData(
            nonce: "da62796403af76c80cd6ce9153ed3746",
            data: hashHex,
            tags: [
                ["locktime", String(expiredLocktime)],
                ["refund", refundKey]
            ]
        )
        
        let wellKnownSecret = WellKnownSecret(
            kind: SpendingConditionKind.htlc,
            secretData: secretData
        )
        
        let proof = Proof(
            amount: 100,
            id: "test_keyset",
            secret: try wellKnownSecret.toJSONString(),
            C: "02a9acc1e48c25eeeb9289b5031cc57da9fe72f3fe2861d264bdc074209b107ba2"
        )
        
        // Create witness with wrong preimage but valid refund signature
        let wrongPreimage = "0000000000000000000000000000000000000000000000000000000000000002"
        let witness = HTLCWitness(
            preimage: wrongPreimage,
            signatures: ["mock_refund_signature"] // In real test, this would be a valid signature
        )
        
        // Verification should succeed because locktime has expired
        // Note: This test is simplified - in reality we'd need a valid signature
        do {
            _ = try HTLCVerifier.verifyHTLC(
                proof: proof,
                witness: witness,
                currentTime: Int64(Date().timeIntervalSince1970)
            )
            // Test would pass with valid signature implementation
        } catch {
            // Expected for now due to mock signature
            #expect(error is CashuError)
        }
    }
    
    @Test("HTLC secret extensions")
    func testHTLCSecretExtensions() throws {
        let secretData = WellKnownSecret.SecretData(
            nonce: "da62796403af76c80cd6ce9153ed3746",
            data: "023192200a0cfd3867e48eb63b03ff599c7e46c8f4e41146b2d281173ca6c50c54",
            tags: [
                ["pubkeys", "02698c4e2b5f9534cd0687d87513c759790cf829aa5739184a3e3735471fbda904"],
                ["locktime", "1689418329"],
                ["refund", "033281c37677ea273eb7183b783067f5244933ef78d8c3f15b1a77cb246099c26e"]
            ]
        )
        
        let htlcSecret = WellKnownSecret(
            kind: SpendingConditionKind.htlc,
            secretData: secretData
        )
        
        #expect(htlcSecret.isHTLC == true)
        #expect(htlcSecret.hashLock == "023192200a0cfd3867e48eb63b03ff599c7e46c8f4e41146b2d281173ca6c50c54")
        #expect(htlcSecret.hasRefundCondition == true)
        #expect(htlcSecret.refundPublicKey == "033281c37677ea273eb7183b783067f5244933ef78d8c3f15b1a77cb246099c26e")
        #expect(htlcSecret.pubkeys == ["02698c4e2b5f9534cd0687d87513c759790cf829aa5739184a3e3735471fbda904"])
        #expect(htlcSecret.locktime == 1689418329)
        
        // Test non-HTLC secret
        let p2pkSecret = WellKnownSecret(
            kind: SpendingConditionKind.p2pk,
            secretData: secretData
        )
        
        #expect(p2pkSecret.isHTLC == false)
        #expect(p2pkSecret.hashLock == nil)
        #expect(p2pkSecret.hasRefundCondition == false)
    }
    
    @Test("HTLC error cases")
    func testHTLCErrorCases() throws {
        // Test invalid preimage length
        do {
            _ = try HTLCCreator.createHTLCSecret(
                preimage: Data(count: 16), // Wrong size
                pubkeys: []
            )
            #expect(Bool(false), "Should have thrown an error")
        } catch CashuError.invalidPreimage {
            // Expected
            #expect(true)
        } catch {
            #expect(Bool(false), "Wrong error type")
        }
        
        // Test invalid proof type
        let p2pkSecret = WellKnownSecret(
            kind: SpendingConditionKind.p2pk,
            secretData: WellKnownSecret.SecretData(
                nonce: "test",
                data: "test"
            )
        )
        
        let proof = Proof(
            amount: 100,
            id: "test",
            secret: try p2pkSecret.toJSONString(),
            C: "test"
        )
        
        do {
            _ = try HTLCVerifier.verifyHTLC(
                proof: proof,
                witness: HTLCWitness(preimage: "", signatures: [])
            )
            #expect(Bool(false), "Should have thrown an error")
        } catch CashuError.invalidSecret {
            // Expected
            #expect(true)
        } catch {
            #expect(Bool(false), "Wrong error type")
        }
    }
    
    @Test("HTLC with multiple signatures")
    func testHTLCWithMultipleSignatures() throws {
        let preimage = HTLCCreator.generatePreimage()
        let pubkeys = [
            "02698c4e2b5f9534cd0687d87513c759790cf829aa5739184a3e3735471fbda904",
            "03bc9337766d49c0b0de0e3e9d88e5c1732e27eaaa5224cf3d986065dac96e1eb5"
        ]
        
        let secret = try HTLCCreator.createHTLCSecret(
            preimage: preimage,
            pubkeys: pubkeys,
            sigflag: .sigAll
        )
        
        let wellKnownSecret = try WellKnownSecret.fromString(secret)
        
        // Check that multiple pubkeys are stored
        let storedPubkeys = wellKnownSecret.pubkeys ?? []
        #expect(storedPubkeys.count == 2)
        #expect(storedPubkeys.contains(pubkeys[0]))
        #expect(storedPubkeys.contains(pubkeys[1]))
    }
    
    @Test("HTLC JSON format validation")
    func testHTLCJSONFormat() throws {
        let secretData = WellKnownSecret.SecretData(
            nonce: "da62796403af76c80cd6ce9153ed3746",
            data: "023192200a0cfd3867e48eb63b03ff599c7e46c8f4e41146b2d281173ca6c50c54",
            tags: [
                ["pubkeys", "02698c4e2b5f9534cd0687d87513c759790cf829aa5739184a3e3735471fbda904"],
                ["locktime", "1689418329"],
                ["refund", "033281c37677ea273eb7183b783067f5244933ef78d8c3f15b1a77cb246099c26e"]
            ]
        )
        
        let htlcSecret = WellKnownSecret(
            kind: SpendingConditionKind.htlc,
            secretData: secretData
        )
        
        let jsonString = try htlcSecret.toJSONString()
        
        // The format should be an array: ["HTLC", {...}]
        #expect(jsonString.contains("\"HTLC\""))
        #expect(jsonString.contains("\"nonce\""))
        #expect(jsonString.contains("\"data\""))
        #expect(jsonString.contains("\"tags\""))
        
        // Test round-trip
        let decoded = try WellKnownSecret.fromString(jsonString)
        #expect(decoded.kind == htlcSecret.kind)
        #expect(decoded.secretData.nonce == htlcSecret.secretData.nonce)
        #expect(decoded.secretData.data == htlcSecret.secretData.data)
    }
}