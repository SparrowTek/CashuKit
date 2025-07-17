//
//  NUT00Tests.swift
//  CashuKit
//
//  Created by Thomas Rademaker on 7/5/25.
//

import Testing
import Foundation
import P256K
@testable import CashuKit

@Suite("NUT00 tests")
struct NUT00Tests {
    
    @Test
    func blindDiffieHellmanKeyExchange() async throws {
        let secret = CashuKeyUtils.generateRandomSecret()
        let (token, isValid) = try CashuBDHKEProtocol.executeProtocol(secret: secret)
        #expect(isValid)
        
        // Verify token has expected properties
        #expect(!token.secret.isEmpty)
        #expect(!token.signature.isEmpty)
    }
    
    @Test("Hash-to-curve function test vectors")
    func hashToCurveTestVectors() throws {
        // Test vectors from NUT-00 specification
        struct TestVector {
            let message: String
            let expectedPoint: String
        }
        
        let testVectors = [
            TestVector(
                message: "0000000000000000000000000000000000000000000000000000000000000000",
                expectedPoint: "024cce997d3b518f739663b757deaec95bcd9473c30a14ac2fd04023a739d1a725"
            ),
            TestVector(
                message: "0000000000000000000000000000000000000000000000000000000000000001",
                expectedPoint: "022e7158e11c9506f1aa4248bf531298daa7febd6194f003edcd9b93ade6253acf"
            ),
            TestVector(
                message: "0000000000000000000000000000000000000000000000000000000000000002",
                expectedPoint: "026cdbe15362df59cd1dd3c9c11de8aedac2106eca69236ecd9fbe117af897be4f"
            )
        ]
        
        for testVector in testVectors {
            guard let messageData = Data(hexString: testVector.message) else {
                throw CashuError.invalidHexString
            }
            
            let point = try hashToCurve(messageData)
            let pointHex = point.dataRepresentation.hexString
            
            #expect(pointHex == testVector.expectedPoint, "Hash-to-curve failed for message: \(testVector.message)")
        }
    }
    
    @Test("Blinded messages test vectors")
    func blindedMessagesTestVectors() throws {
        // Test vectors for blinded messages (B_) from NUT-00 specification
        struct TestVector {
            let secret: String  // x: hex encoded byte array
            let blindingFactor: String  // r: hex encoded private key
            let expectedBlindedPoint: String  // B_: hex encoded public key
        }
        
        let testVectors = [
            TestVector(
                secret: "d341ee4871f1f889041e63cf0d3823c713eea6aff01e80f1719f08f9e5be98f6",
                blindingFactor: "99fce58439fc37412ab3468b73db0569322588f62fb3a49182d67e23d877824a",
                expectedBlindedPoint: "033b1a9737a40cc3fd9b6af4b723632b76a67a36782596304612a6c2bfb5197e6d"
            ),
            TestVector(
                secret: "f1aaf16c2239746f369572c0784d9dd3d032d952c2d992175873fb58fae31a60",
                blindingFactor: "f78476ea7cc9ade20f9e05e58a804cf19533f03ea805ece5fee88c8e2874ba50",
                expectedBlindedPoint: "029bdf2d716ee366eddf599ba252786c1033f47e230248a4612a5670ab931f1763"
            )
        ]
        
        for testVector in testVectors {
            guard let secretData = Data(hexString: testVector.secret),
                  let blindingFactorData = Data(hexString: testVector.blindingFactor) else {
                throw CashuError.invalidHexString
            }
            
            // Create blinding factor private key
            let blindingFactorKey = try P256K.KeyAgreement.PrivateKey(dataRepresentation: blindingFactorData)
            
            // Y = hash_to_curve(secret)
            // Note: In the test vectors, secrets are hex-encoded and should be treated as raw bytes
            let Y = try hashToCurve(secretData)
            
            // Calculate B_ = Y + r*G
            let generatorPoint = try getGeneratorPoint()
            let rG = try multiplyPoint(generatorPoint, by: blindingFactorKey)
            let B_ = try addPoints(Y, rG)
            let B_Hex = B_.dataRepresentation.hexString
            
            #expect(B_Hex == testVector.expectedBlindedPoint, "Blinded message calculation failed for secret: \(testVector.secret)")
        }
    }
    
    @Test("Blinded signatures test vectors")
    func blindedSignaturesTestVectors() throws {
        // Test vectors for blinded signatures (C_) from NUT-00 specification
        struct TestVector {
            let mintPrivateKey: String  // k: hex encoded private key
            let blindedMessage: String  // B_: hex encoded public key
            let expectedBlindedSignature: String  // C_: hex encoded public key
        }
        
        let testVectors = [
            TestVector(
                mintPrivateKey: "0000000000000000000000000000000000000000000000000000000000000001",
                blindedMessage: "02a9acc1e48c25eeeb9289b5031cc57da9fe72f3fe2861d264bdc074209b107ba2",
                expectedBlindedSignature: "02a9acc1e48c25eeeb9289b5031cc57da9fe72f3fe2861d264bdc074209b107ba2"
            ),
            TestVector(
                mintPrivateKey: "7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f",
                blindedMessage: "02a9acc1e48c25eeeb9289b5031cc57da9fe72f3fe2861d264bdc074209b107ba2",
                expectedBlindedSignature: "0398bc70ce8184d27ba89834d19f5199c84443c31131e48d3c1214db24247d005d"
            )
        ]
        
        for testVector in testVectors {
            guard let mintPrivateKeyData = Data(hexString: testVector.mintPrivateKey),
                  let blindedMessageData = Data(hexString: testVector.blindedMessage) else {
                throw CashuError.invalidHexString
            }
            
            // Create mint with the specific private key
            let mintKey = try P256K.KeyAgreement.PrivateKey(dataRepresentation: mintPrivateKeyData)
            let mint = try Mint(privateKey: mintKey)
            
            // Sign the blinded message
            let C_Data = try mint.signBlindedMessage(blindedMessageData)
            let C_Hex = C_Data.hexString
            
            #expect(C_Hex == testVector.expectedBlindedSignature, "Blinded signature calculation failed for mint key: \(testVector.mintPrivateKey)")
        }
    }
}
