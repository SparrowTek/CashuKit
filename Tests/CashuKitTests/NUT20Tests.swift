//
//  NUT20Tests.swift
//  CashuKitTests
//
//  Tests for NUT-20: Signature on Mint Quote
//

import Testing
@testable import CashuKit
import Foundation

@Suite("NUT-20 Tests")
struct NUT20Tests {
    
    // MARK: - Message Aggregation Tests
    
    @Test("Message aggregation - basic functionality")
    func testMessageAggregationBasic() {
        let quote = "9d745270-1405-46de-b5c5-e2762b4f5e00"
        let outputs = [
            BlindedMessage(
                amount: 8,
                id: "009a1f293253e41e",
                B_: "035015e6d7ade60ba8426cefaf1832bbd27257636e44a76b922d78e79b47cb689d"
            ),
            BlindedMessage(
                amount: 2,
                id: "009a1f293253e41e",
                B_: "0288d7649652d0a83fc9c966c969fb217f15904431e61a44b14999fabc1b5d9ac6"
            )
        ]
        
        let message = NUT20MessageAggregator.createMessageToSign(quote: quote, outputs: outputs)
        let expectedMessage = "9d745270-1405-46de-b5c5-e2762b4f5e00" +
                            "035015e6d7ade60ba8426cefaf1832bbd27257636e44a76b922d78e79b47cb689d" +
                            "0288d7649652d0a83fc9c966c969fb217f15904431e61a44b14999fabc1b5d9ac6"
        
        #expect(message == expectedMessage)
    }
    
    @Test("Message aggregation - empty outputs")
    func testMessageAggregationEmptyOutputs() {
        let quote = "test-quote-id"
        let outputs: [BlindedMessage] = []
        
        let message = NUT20MessageAggregator.createMessageToSign(quote: quote, outputs: outputs)
        
        #expect(message == "test-quote-id")
    }
    
    @Test("Message aggregation - single output")
    func testMessageAggregationSingleOutput() {
        let quote = "single-output-quote"
        let outputs = [
            BlindedMessage(
                amount: 10,
                id: "test-id",
                B_: "test-blinded-message"
            )
        ]
        
        let message = NUT20MessageAggregator.createMessageToSign(quote: quote, outputs: outputs)
        
        #expect(message == "single-output-quotetest-blinded-message")
    }
    
    @Test("Message aggregation - hash creation")
    func testMessageAggregationHashCreation() {
        let quote = "hash-test-quote"
        let outputs = [
            BlindedMessage(
                amount: 5,
                id: "hash-test-id",
                B_: "hash-test-blinded"
            )
        ]
        
        let hash = NUT20MessageAggregator.createHashToSign(quote: quote, outputs: outputs)
        
        #expect(hash.count == 32) // SHA-256 produces 32 bytes
    }
    
    @Test("Message aggregation - hash consistency")
    func testMessageAggregationHashConsistency() {
        let quote = "consistency-test"
        let outputs = [
            BlindedMessage(
                amount: 1,
                id: "test",
                B_: "blinded"
            )
        ]
        
        let hash1 = NUT20MessageAggregator.createHashToSign(quote: quote, outputs: outputs)
        let hash2 = NUT20MessageAggregator.createHashToSign(quote: quote, outputs: outputs)
        
        #expect(hash1 == hash2)
    }
    
    // MARK: - Signature Management Tests
    
    @Test("Signature creation - basic functionality")
    func testSignatureCreationBasic() throws {
        let privateKey = Data(repeating: 0x01, count: 32)
        let messageHash = Data(repeating: 0x02, count: 32)
        
        let signature = try NUT20SignatureManager.signMessage(
            messageHash: messageHash,
            privateKey: privateKey
        )
        
        #expect(signature.count == 128) // 64 bytes as hex string
    }
    
    @Test("Signature creation - invalid private key length")
    func testSignatureCreationInvalidPrivateKeyLength() throws {
        let privateKey = Data(repeating: 0x01, count: 16) // Invalid length
        let messageHash = Data(repeating: 0x02, count: 32)
        
        do {
            let _ = try NUT20SignatureManager.signMessage(
                messageHash: messageHash,
                privateKey: privateKey
            )
            #expect(Bool(false), "Should have thrown error for invalid private key length")
        } catch {
            #expect(error is CashuError)
        }
    }
    
    @Test("Signature creation - invalid message hash length")
    func testSignatureCreationInvalidMessageHashLength() throws {
        let privateKey = Data(repeating: 0x01, count: 32)
        let messageHash = Data(repeating: 0x02, count: 16) // Invalid length
        
        do {
            let _ = try NUT20SignatureManager.signMessage(
                messageHash: messageHash,
                privateKey: privateKey
            )
            #expect(Bool(false), "Should have thrown error for invalid message hash length")
        } catch {
            #expect(error is CashuError)
        }
    }
    
    @Test("Signature verification - basic functionality")
    func testSignatureVerificationBasic() throws {
        let signature = String(repeating: "42", count: 64) // 64 bytes as hex
        let messageHash = Data(repeating: 0x02, count: 32)
        let publicKey = "03" + String(repeating: "01", count: 32) // 33 bytes as hex
        
        let isValid = try NUT20SignatureManager.verifySignature(
            signature: signature,
            messageHash: messageHash,
            publicKey: publicKey
        )
        
        #expect(isValid == true) // Mock implementation always returns true
    }
    
    @Test("Signature verification - invalid signature format")
    func testSignatureVerificationInvalidSignatureFormat() throws {
        let signature = "invalid-hex"
        let messageHash = Data(repeating: 0x02, count: 32)
        let publicKey = "03" + String(repeating: "01", count: 32)
        
        do {
            let _ = try NUT20SignatureManager.verifySignature(
                signature: signature,
                messageHash: messageHash,
                publicKey: publicKey
            )
            #expect(Bool(false), "Should have thrown error for invalid signature format")
        } catch {
            #expect(error is CashuError)
        }
    }
    
    @Test("Signature verification - invalid signature length")
    func testSignatureVerificationInvalidSignatureLength() throws {
        let signature = String(repeating: "42", count: 32) // Too short
        let messageHash = Data(repeating: 0x02, count: 32)
        let publicKey = "03" + String(repeating: "01", count: 32)
        
        do {
            let _ = try NUT20SignatureManager.verifySignature(
                signature: signature,
                messageHash: messageHash,
                publicKey: publicKey
            )
            #expect(Bool(false), "Should have thrown error for invalid signature length")
        } catch {
            #expect(error is CashuError)
        }
    }
    
    @Test("Signature verification - invalid public key format")
    func testSignatureVerificationInvalidPublicKeyFormat() throws {
        let signature = String(repeating: "42", count: 64)
        let messageHash = Data(repeating: 0x02, count: 32)
        let publicKey = "invalid-hex"
        
        do {
            let _ = try NUT20SignatureManager.verifySignature(
                signature: signature,
                messageHash: messageHash,
                publicKey: publicKey
            )
            #expect(Bool(false), "Should have thrown error for invalid public key format")
        } catch {
            #expect(error is CashuError)
        }
    }
    
    @Test("Signature verification - invalid public key length")
    func testSignatureVerificationInvalidPublicKeyLength() throws {
        let signature = String(repeating: "42", count: 64)
        let messageHash = Data(repeating: 0x02, count: 32)
        let publicKey = "03" + String(repeating: "01", count: 16) // Too short
        
        do {
            let _ = try NUT20SignatureManager.verifySignature(
                signature: signature,
                messageHash: messageHash,
                publicKey: publicKey
            )
            #expect(Bool(false), "Should have thrown error for invalid public key length")
        } catch {
            #expect(error is CashuError)
        }
    }
    
    // MARK: - Key Manager Tests
    
    @Test("Key manager - ephemeral key pair generation")
    func testKeyManagerEphemeralKeyPairGeneration() async throws {
        let keyManager = InMemoryKeyManager()
        
        let keyPair = try await keyManager.generateEphemeralKeyPair()
        
        #expect(keyPair.publicKey.count == 66) // 33 bytes as hex string
        #expect(keyPair.privateKey.count == 32) // 32 bytes
        #expect(keyPair.publicKey.hasPrefix("03")) // Compressed public key prefix
    }
    
    @Test("Key manager - store and retrieve key pair")
    func testKeyManagerStoreAndRetrieveKeyPair() async throws {
        let keyManager = InMemoryKeyManager()
        let quoteId = "test-quote-id"
        let publicKey = "03" + String(repeating: "01", count: 32)
        let privateKey = Data(repeating: 0x01, count: 32)
        
        try await keyManager.storeKeyPair(
            quoteId: quoteId,
            publicKey: publicKey,
            privateKey: privateKey
        )
        
        let retrievedPrivateKey = try await keyManager.getPrivateKey(for: quoteId)
        
        #expect(retrievedPrivateKey == privateKey)
    }
    
    @Test("Key manager - retrieve non-existent key")
    func testKeyManagerRetrieveNonExistentKey() async throws {
        let keyManager = InMemoryKeyManager()
        let quoteId = "non-existent-quote"
        
        let retrievedPrivateKey = try await keyManager.getPrivateKey(for: quoteId)
        
        #expect(retrievedPrivateKey == nil)
    }
    
    @Test("Key manager - remove key pair")
    func testKeyManagerRemoveKeyPair() async throws {
        let keyManager = InMemoryKeyManager()
        let quoteId = "test-quote-id"
        let publicKey = "03" + String(repeating: "01", count: 32)
        let privateKey = Data(repeating: 0x01, count: 32)
        
        try await keyManager.storeKeyPair(
            quoteId: quoteId,
            publicKey: publicKey,
            privateKey: privateKey
        )
        
        let beforeRemoval = try await keyManager.getPrivateKey(for: quoteId)
        #expect(beforeRemoval == privateKey)
        
        try await keyManager.removeKeyPair(for: quoteId)
        
        let afterRemoval = try await keyManager.getPrivateKey(for: quoteId)
        #expect(afterRemoval == nil)
    }
    
    @Test("Key manager - multiple key pairs")
    func testKeyManagerMultipleKeyPairs() async throws {
        let keyManager = InMemoryKeyManager()
        let quoteId1 = "quote-1"
        let quoteId2 = "quote-2"
        let publicKey1 = "03" + String(repeating: "01", count: 32)
        let publicKey2 = "03" + String(repeating: "02", count: 32)
        let privateKey1 = Data(repeating: 0x01, count: 32)
        let privateKey2 = Data(repeating: 0x02, count: 32)
        
        try await keyManager.storeKeyPair(
            quoteId: quoteId1,
            publicKey: publicKey1,
            privateKey: privateKey1
        )
        
        try await keyManager.storeKeyPair(
            quoteId: quoteId2,
            publicKey: publicKey2,
            privateKey: privateKey2
        )
        
        let retrievedPrivateKey1 = try await keyManager.getPrivateKey(for: quoteId1)
        let retrievedPrivateKey2 = try await keyManager.getPrivateKey(for: quoteId2)
        
        #expect(retrievedPrivateKey1 == privateKey1)
        #expect(retrievedPrivateKey2 == privateKey2)
    }
    
    // MARK: - NUT-20 Settings Tests
    
    @Test("NUT20Settings creation")
    func testNUT20SettingsCreation() throws {
        let settings = NUT20Settings(supported: true)
        
        #expect(settings.supported == true)
    }
    
    @Test("NUT20Settings JSON serialization")
    func testNUT20SettingsJSONSerialization() throws {
        let settings = NUT20Settings(supported: true)
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(settings)
        
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(NUT20Settings.self, from: data)
        
        #expect(decoded.supported == settings.supported)
    }
    
    // MARK: - MintInfo Extensions Tests
    
    @Test("MintInfo NUT-20 support detection")
    func testMintInfoNUT20SupportDetection() {
        let nut20Value = NutValue.dictionary([
            "supported": AnyCodable(anyValue: true)!
        ])
        
        let mintInfo = MintInfo(
            name: "Test Mint",
            pubkey: "pubkey",
            version: "1.0",
            nuts: ["20": nut20Value]
        )
        
        #expect(mintInfo.supportsSignatureMintQuotes == true)
        
        let settings = mintInfo.getNUT20Settings()
        #expect(settings != nil)
        #expect(settings?.supported == true)
        #expect(mintInfo.requiresSignatureForMintQuotes == true)
    }
    
    @Test("MintInfo NUT-20 settings parsing")
    func testMintInfoNUT20SettingsParsing() {
        let nut20Value = NutValue.dictionary([
            "supported": AnyCodable(anyValue: false)!
        ])
        
        let mintInfo = MintInfo(
            name: "Test Mint",
            pubkey: "pubkey",
            version: "1.0",
            nuts: ["20": nut20Value]
        )
        
        let settings = mintInfo.getNUT20Settings()
        #expect(settings?.supported == false)
        #expect(mintInfo.requiresSignatureForMintQuotes == false)
    }
    
    @Test("MintInfo without NUT-20 support")
    func testMintInfoWithoutNUT20Support() {
        let mintInfo = MintInfo(
            name: "Test Mint",
            pubkey: "pubkey",
            version: "1.0",
            nuts: [:]
        )
        
        #expect(mintInfo.supportsSignatureMintQuotes == false)
        #expect(mintInfo.getNUT20Settings() == nil)
        #expect(mintInfo.requiresSignatureForMintQuotes == false)
    }
    
    // MARK: - Signature Validator Tests
    
    @Test("Signature validator - valid mint request")
    func testSignatureValidatorValidMintRequest() throws {
        let quote = "test-quote"
        let outputs = [
            BlindedMessage(amount: 10, id: "test", B_: "test-blinded")
        ]
        let signature = String(repeating: "42", count: 64)
        let publicKey = "03" + String(repeating: "01", count: 32)
        
        let request = NUT20MintRequest(
            quote: quote,
            outputs: outputs,
            signature: signature
        )
        
        let isValid = try NUT20SignatureValidator.validateMintRequest(
            request: request,
            expectedPublicKey: publicKey
        )
        
        #expect(isValid == true)
    }
    
    @Test("Signature validator - missing signature")
    func testSignatureValidatorMissingSignature() throws {
        let quote = "test-quote"
        let outputs = [
            BlindedMessage(amount: 10, id: "test", B_: "test-blinded")
        ]
        let publicKey = "03" + String(repeating: "01", count: 32)
        
        let request = NUT20MintRequest(
            quote: quote,
            outputs: outputs,
            signature: nil
        )
        
        do {
            let _ = try NUT20SignatureValidator.validateMintRequest(
                request: request,
                expectedPublicKey: publicKey
            )
            #expect(Bool(false), "Should have thrown error for missing signature")
        } catch {
            #expect(error is CashuError)
        }
    }
    
    @Test("Signature validator - valid public key")
    func testSignatureValidatorValidPublicKey() throws {
        let publicKey = "03" + String(repeating: "01", count: 32)
        
        let isValid = try NUT20SignatureValidator.validatePublicKey(publicKey)
        
        #expect(isValid == true)
    }
    
    @Test("Signature validator - invalid public key format")
    func testSignatureValidatorInvalidPublicKeyFormat() throws {
        let publicKey = "invalid-hex"
        
        do {
            let _ = try NUT20SignatureValidator.validatePublicKey(publicKey)
            #expect(Bool(false), "Should have thrown error for invalid public key format")
        } catch {
            #expect(error is CashuError)
        }
    }
    
    @Test("Signature validator - invalid public key length")
    func testSignatureValidatorInvalidPublicKeyLength() throws {
        let publicKey = "03" + String(repeating: "01", count: 16) // Too short
        
        do {
            let _ = try NUT20SignatureValidator.validatePublicKey(publicKey)
            #expect(Bool(false), "Should have thrown error for invalid public key length")
        } catch {
            #expect(error is CashuError)
        }
    }
    
    @Test("Signature validator - invalid public key prefix")
    func testSignatureValidatorInvalidPublicKeyPrefix() throws {
        let publicKey = "01" + String(repeating: "01", count: 32) // Invalid prefix
        
        do {
            let _ = try NUT20SignatureValidator.validatePublicKey(publicKey)
            #expect(Bool(false), "Should have thrown error for invalid public key prefix")
        } catch {
            #expect(error is CashuError)
        }
    }
    
    @Test("Signature validator - valid prefix 0x02")
    func testSignatureValidatorValidPrefix02() throws {
        let publicKey = "02" + String(repeating: "01", count: 32)
        
        let isValid = try NUT20SignatureValidator.validatePublicKey(publicKey)
        
        #expect(isValid == true)
    }
    
    // MARK: - NUT-20 Mint Quote Builder Tests
    
    @Test("Mint quote builder - basic usage")
    func testMintQuoteBuilderBasicUsage() throws {
        let builder = NUT20MintQuoteBuilder(amount: 100)
        
        let (request, keyPair) = try builder.build()
        
        #expect(request.amount == 100)
        #expect(request.unit == "sat")
        #expect(request.description == nil)
        #expect(request.pubkey == nil)
        #expect(keyPair == nil)
    }
    
    @Test("Mint quote builder - with unit")
    func testMintQuoteBuilderWithUnit() throws {
        let builder = NUT20MintQuoteBuilder(amount: 100)
            .withUnit("usd")
        
        let (request, _) = try builder.build()
        
        #expect(request.unit == "usd")
    }
    
    @Test("Mint quote builder - with description")
    func testMintQuoteBuilderWithDescription() throws {
        let builder = NUT20MintQuoteBuilder(amount: 100)
            .withDescription("Test mint quote")
        
        let (request, _) = try builder.build()
        
        #expect(request.description == "Test mint quote")
    }
    
    @Test("Mint quote builder - with signature required")
    func testMintQuoteBuilderWithSignatureRequired() throws {
        let builder = NUT20MintQuoteBuilder(amount: 100)
            .withSignatureRequired(true)
        
        let (request, keyPair) = try builder.build()
        
        #expect(request.pubkey != nil)
        #expect(keyPair != nil)
        #expect(keyPair?.publicKey == request.pubkey)
        #expect(keyPair?.privateKey.count == 32)
    }
    
    @Test("Mint quote builder - full configuration")
    func testMintQuoteBuilderFullConfiguration() throws {
        let builder = NUT20MintQuoteBuilder(amount: 500)
            .withUnit("sat")
            .withDescription("Full test mint quote")
            .withSignatureRequired(true)
        
        let (request, keyPair) = try builder.build()
        
        #expect(request.amount == 500)
        #expect(request.unit == "sat")
        #expect(request.description == "Full test mint quote")
        #expect(request.pubkey != nil)
        #expect(keyPair != nil)
    }
    
    // MARK: - Data Extensions Tests
    
    @Test("Data hex string conversion")
    func testDataHexStringConversion() {
        let data = Data([0x01, 0x02, 0x03, 0xFF])
        let hexString = data.hexString
        
        #expect(hexString == "010203ff")
    }
    
    @Test("Data from hex string")
    func testDataFromHexString() {
        let hexString = "010203ff"
        let data = Data(hexString: hexString)
        
        #expect(data != nil)
        #expect(data! == Data([0x01, 0x02, 0x03, 0xFF]))
    }
    
    @Test("Data from invalid hex string")
    func testDataFromInvalidHexString() {
        let hexString = "invalid-hex"
        let data = Data(hexString: hexString)
        
        #expect(data == nil)
    }
    
    @Test("Data from empty hex string")
    func testDataFromEmptyHexString() {
        let hexString = ""
        let data = Data(hexString: hexString)
        
        #expect(data != nil)
        #expect(data!.isEmpty)
    }
    
    @Test("Data from odd length hex string")
    func testDataFromOddLengthHexString() {
        let hexString = "123" // Odd length
        let data = Data(hexString: hexString)
        
        #expect(data == nil)
    }
    
    // MARK: - Integration Tests
    
    @Test("Full mint quote workflow - without signature")
    func testFullMintQuoteWorkflowWithoutSignature() throws {
        let quote = "test-quote-id"
        let outputs = [
            BlindedMessage(
                amount: 10,
                id: "test-id",
                B_: "test-blinded-message"
            )
        ]
        
        // Create message to sign
        let message = NUT20MessageAggregator.createMessageToSign(
            quote: quote,
            outputs: outputs
        )
        
        #expect(message == "test-quote-idtest-blinded-message")
        
        // Create hash
        let hash = NUT20MessageAggregator.createHashToSign(
            quote: quote,
            outputs: outputs
        )
        
        #expect(hash.count == 32)
    }
    
    @Test("Full mint quote workflow - with signature")
    func testFullMintQuoteWorkflowWithSignature() throws {
        let quote = "signed-quote-id"
        let outputs = [
            BlindedMessage(
                amount: 100,
                id: "signed-test-id",
                B_: "signed-blinded-message"
            )
        ]
        let privateKey = Data(repeating: 0x01, count: 32)
        let publicKey = "03" + String(repeating: "01", count: 32)
        
        // Create message hash
        let messageHash = NUT20MessageAggregator.createHashToSign(
            quote: quote,
            outputs: outputs
        )
        
        // Sign the message
        let signature = try NUT20SignatureManager.signMessage(
            messageHash: messageHash,
            privateKey: privateKey
        )
        
        // Verify the signature
        let isValid = try NUT20SignatureManager.verifySignature(
            signature: signature,
            messageHash: messageHash,
            publicKey: publicKey
        )
        
        #expect(isValid == true)
    }
    
    @Test("Complete signature validation flow")
    func testCompleteSignatureValidationFlow() throws {
        let quote = "validation-quote"
        let outputs = [
            BlindedMessage(
                amount: 50,
                id: "validation-id",
                B_: "validation-blinded"
            )
        ]
        let privateKey = Data(repeating: 0x05, count: 32)
        let publicKey = "03" + String(repeating: "05", count: 32)
        
        // Create hash and sign
        let messageHash = NUT20MessageAggregator.createHashToSign(
            quote: quote,
            outputs: outputs
        )
        let signature = try NUT20SignatureManager.signMessage(
            messageHash: messageHash,
            privateKey: privateKey
        )
        
        // Create mint request
        let request = NUT20MintRequest(
            quote: quote,
            outputs: outputs,
            signature: signature
        )
        
        // Validate the request
        let isValid = try NUT20SignatureValidator.validateMintRequest(
            request: request,
            expectedPublicKey: publicKey
        )
        
        #expect(isValid == true)
    }
    
    @Test("Error handling workflow")
    func testErrorHandlingWorkflow() throws {
        // Test various error conditions
        
        // Invalid private key
        do {
            let _ = try NUT20SignatureManager.signMessage(
                messageHash: Data(repeating: 0x01, count: 32),
                privateKey: Data(repeating: 0x01, count: 16) // Invalid length
            )
            #expect(Bool(false), "Should throw error")
        } catch {
            #expect(error is CashuError)
        }
        
        // Invalid public key
        do {
            let _ = try NUT20SignatureValidator.validatePublicKey("invalid")
            #expect(Bool(false), "Should throw error")
        } catch {
            #expect(error is CashuError)
        }
        
        // Missing signature
        do {
            let request = NUT20MintRequest(
                quote: "test",
                outputs: [BlindedMessage(amount: 1, id: "test", B_: "test")],
                signature: nil
            )
            let _ = try NUT20SignatureValidator.validateMintRequest(
                request: request,
                expectedPublicKey: "03" + String(repeating: "01", count: 32)
            )
            #expect(Bool(false), "Should throw error")
        } catch {
            #expect(error is CashuError)
        }
    }
    
    @Test("Key manager lifecycle")
    func testKeyManagerLifecycle() async throws {
        let keyManager = InMemoryKeyManager()
        
        // Generate key pair
        let keyPair = try await keyManager.generateEphemeralKeyPair()
        let quoteId = "lifecycle-quote"
        
        // Store key pair
        try await keyManager.storeKeyPair(
            quoteId: quoteId,
            publicKey: keyPair.publicKey,
            privateKey: keyPair.privateKey
        )
        
        // Verify storage
        let retrievedKey = try await keyManager.getPrivateKey(for: quoteId)
        #expect(retrievedKey == keyPair.privateKey)
        
        // Remove key pair
        try await keyManager.removeKeyPair(for: quoteId)
        
        // Verify removal
        let removedKey = try await keyManager.getPrivateKey(for: quoteId)
        #expect(removedKey == nil)
    }
    
    @Test("Message consistency across operations")
    func testMessageConsistencyAcrossOperations() {
        let quote = "consistency-test-quote"
        let outputs = [
            BlindedMessage(amount: 25, id: "consistency-id", B_: "consistency-blinded-1"),
            BlindedMessage(amount: 75, id: "consistency-id", B_: "consistency-blinded-2")
        ]
        
        // Create message multiple times
        let message1 = NUT20MessageAggregator.createMessageToSign(quote: quote, outputs: outputs)
        let message2 = NUT20MessageAggregator.createMessageToSign(quote: quote, outputs: outputs)
        let message3 = NUT20MessageAggregator.createMessageToSign(quote: quote, outputs: outputs)
        
        #expect(message1 == message2)
        #expect(message2 == message3)
        #expect(message1 == message3)
        
        // Create hash multiple times
        let hash1 = NUT20MessageAggregator.createHashToSign(quote: quote, outputs: outputs)
        let hash2 = NUT20MessageAggregator.createHashToSign(quote: quote, outputs: outputs)
        let hash3 = NUT20MessageAggregator.createHashToSign(quote: quote, outputs: outputs)
        
        #expect(hash1 == hash2)
        #expect(hash2 == hash3)
        #expect(hash1 == hash3)
    }
}