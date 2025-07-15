import Testing
@testable import CashuKit
import Foundation

@Suite("NUT10 - Spending conditions")
struct NUT10Tests {
    
    @Test("Well-known secret serialization")
    func testWellKnownSecretSerialization() throws {
        let secretData = WellKnownSecret.SecretData(
            nonce: "1234567890abcdef",
            data: "testdata",
            tags: [["key1", "value1"], ["key2", "value2", "value3"]]
        )
        
        let secret = WellKnownSecret(kind: "P2PK", secretData: secretData)
        
        let jsonString = try secret.toJSONString()
        let decoded = try WellKnownSecret.fromString(jsonString)
        
        #expect(decoded.kind == secret.kind)
        #expect(decoded.secretData.nonce == secret.secretData.nonce)
        #expect(decoded.secretData.data == secret.secretData.data)
        #expect(decoded.secretData.tags == secret.secretData.tags)
    }
    
    @Test("Well-known secret without tags")
    func testWellKnownSecretWithoutTags() throws {
        let secretData = WellKnownSecret.SecretData(
            nonce: "abcdef1234567890",
            data: "somedata"
        )
        
        let secret = WellKnownSecret(kind: "HTLC", secretData: secretData)
        
        let jsonString = try secret.toJSONString()
        let decoded = try WellKnownSecret.fromString(jsonString)
        
        #expect(decoded.kind == secret.kind)
        #expect(decoded.secretData.nonce == secret.secretData.nonce)
        #expect(decoded.secretData.data == secret.secretData.data)
        #expect(decoded.secretData.tags == nil)
    }
    
    @Test("Generate nonce")
    func testGenerateNonce() {
        let nonce1 = WellKnownSecret.generateNonce()
        let nonce2 = WellKnownSecret.generateNonce()
        
        #expect(nonce1.count == 32)
        #expect(nonce2.count == 32)
        #expect(nonce1 != nonce2)
        #expect(nonce1 == nonce1.lowercased())
        #expect(!nonce1.contains("-"))
    }
    
    @Test("Proof with spending condition")
    func testProofWithSpendingCondition() throws {
        let secretData = WellKnownSecret.SecretData(
            nonce: WellKnownSecret.generateNonce(),
            data: "pubkey123"
        )
        let wellKnownSecret = WellKnownSecret(kind: SpendingConditionKind.p2pk, secretData: secretData)
        let secretString = try wellKnownSecret.toJSONString()
        
        let proof = Proof(
            amount: 100,
            id: "00ad268c4d1f5826",
            secret: secretString,
            C: "02c020067db727d586bc3183aecf97fcb800c3f4cc4759f69c626c9db5d8f5b5d4"
        )
        
        #expect(proof.hasSpendingCondition() == true)
        
        let extractedSecret = proof.getWellKnownSecret()
        #expect(extractedSecret != nil)
        #expect(extractedSecret?.kind == SpendingConditionKind.p2pk)
        #expect(extractedSecret?.secretData.data == "pubkey123")
    }
    
    @Test("Proof without spending condition")
    func testProofWithoutSpendingCondition() {
        let proof = Proof(
            amount: 100,
            id: "00ad268c4d1f5826",
            secret: "randomsecret123",
            C: "02c020067db727d586bc3183aecf97fcb800c3f4cc4759f69c626c9db5d8f5b5d4"
        )
        
        #expect(proof.hasSpendingCondition() == false)
        #expect(proof.getWellKnownSecret() == nil)
    }
    
    @Test("JSON format validation")
    func testJSONFormatValidation() throws {
        let secretData = WellKnownSecret.SecretData(
            nonce: "test123",
            data: "data456"
        )
        let secret = WellKnownSecret(kind: "TEST", secretData: secretData)
        
        let jsonString = try secret.toJSONString()
        let jsonData = jsonString.data(using: .utf8)!
        let jsonArray = try JSONSerialization.jsonObject(with: jsonData) as! [Any]
        
        #expect(jsonArray.count == 2)
        #expect(jsonArray[0] as? String == "TEST")
        
        let innerDict = jsonArray[1] as! [String: Any]
        #expect(innerDict["nonce"] as? String == "test123")
        #expect(innerDict["data"] as? String == "data456")
    }
    
    @Test("Mint info supports NUT10")
    func testMintInfoSupportsNUT10() {
        let mintInfo = MintInfo(
            name: "Test Mint",
            pubkey: "testpubkey",
            nuts: [
                "10": .dictionary(["supported": AnyCodable(true)])
            ]
        )
        
        #expect(mintInfo.supportsSpendingConditions() == true)
        #expect(mintInfo.isNUTSupported("10") == true)
    }
    
    @Test("Mint info does not support NUT10")
    func testMintInfoDoesNotSupportNUT10() {
        let mintInfo = MintInfo(
            name: "Test Mint",
            pubkey: "testpubkey",
            nuts: [
                "1": .string("active"),
                "2": .string("active")
            ]
        )
        
        #expect(mintInfo.supportsSpendingConditions() == false)
        #expect(mintInfo.isNUTSupported("10") == false)
    }
}