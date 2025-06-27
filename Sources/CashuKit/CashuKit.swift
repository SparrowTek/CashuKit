// The Swift Programming Language
// https://docs.swift.org/swift-book

import Foundation
import K1
import CryptoKit

// MARK: - Cashu Cryptographic Foundation (NUT-00)

/// Domain separator for hash-to-curve operations in Cashu
private let DOMAIN_SEPARATOR = "Secp256k1_HashToCurve_Cashu_".data(using: .utf8)!

/// Errors that can occur during cryptographic operations
enum CashuCryptoError: Error {
    case invalidPoint
    case invalidSecretLength
    case hashToCurveFailed
    case blindingFailed
    case unblindingFailed
    case verificationFailed
    case invalidHexString
    case keyGenerationFailed
    case invalidSignature
}

// MARK: - Hash to Curve Implementation (NUT-00 Specification)

/// Maps a message to a public key point on the secp256k1 curve
/// Y = hash_to_curve(x) where x is the secret message
/// Implementation follows NUT-00: Y = PublicKey('02' || SHA256(msg_hash || counter))
func hashToCurve(_ message: Data) throws -> K1.Group.Point {
    // Create message hash: SHA256(DOMAIN_SEPARATOR || x)
    let msgHash = SHA256.hash(data: DOMAIN_SEPARATOR + message)
    
    // Try different counter values until we find a valid point
    for counter in 0..<UInt32.max {
        // Convert counter to little-endian bytes
        let counterBytes = withUnsafeBytes(of: counter.littleEndian) { Data($0) }
        
        // Create candidate: SHA256(msg_hash || counter)
        let candidate = SHA256.hash(data: Data(msgHash) + counterBytes)
        
        // Try to create a public key with prefix '02' (compressed format)
        let candidateWithPrefix = Data([0x02]) + candidate
        
        do {
            let publicKey = try K1.KeyAgreement.PublicKey(compressedRepresentation: candidateWithPrefix)
            return try K1.Group.Point(publicKey: publicKey)
        } catch {
            // This candidate doesn't form a valid point, try next counter
            continue
        }
    }
    
    throw CashuCryptoError.hashToCurveFailed
}

/// Convenience function for string messages
func hashToCurve(_ message: String) throws -> K1.Group.Point {
    guard let data = message.data(using: .utf8) else {
        throw CashuCryptoError.invalidSecretLength
    }
    return try hashToCurve(data)
}

// MARK: - Generator Point

/// Get the secp256k1 generator point G
func getGeneratorPoint() throws -> K1.Group.Point {
    // Create a private key with value 1 to get G = 1*G
    let oneData = Data([
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01
    ])
    
    let privateKeyOne = try K1.KeyAgreement.PrivateKey(rawRepresentation: oneData)
    let generatorPublicKey = privateKeyOne.publicKey
    return try K1.Group.Point(publicKey: generatorPublicKey)
}

// MARK: - Scalar Multiplication

/// Multiply a point by a scalar (private key): scalar * point
/// This implements k * P where k is a private key and P is a point
func multiplyPoint(_ point: K1.Group.Point, by scalar: K1.KeyAgreement.PrivateKey) throws -> K1.Group.Point {
    // Convert point to public key for scalar multiplication
    let publicKey = try point.toPublicKey()
    
    // Use ECDH point function to get scalar * point without hashing
    let resultData = try scalar.ecdhPoint(with: publicKey)
    
    // Parse the uncompressed point data (65 bytes: 0x04 + 32 bytes x + 32 bytes y)
    guard resultData.count == 65 && resultData[0] == 0x04 else {
        throw CashuCryptoError.invalidPoint
    }
    
    let x = resultData[1..<33]
    let y = resultData[33..<65]
    
    return try K1.Group.Point(x: Data(x), y: Data(y))
}

// MARK: - Mint Implementation

/// Represents a mint's cryptographic keys for one amount
/// Each amount has its own key pair in Cashu
struct MintKeypair {
    /// k: private key of mint (one for each amount)
    let privateKey: K1.KeyAgreement.PrivateKey
    /// K: public key corresponding to k (K = k*G)
    let publicKey: K1.KeyAgreement.PublicKey
    let publicKeyPoint: K1.Group.Point
    
    init() throws {
        self.privateKey = K1.KeyAgreement.PrivateKey()
        self.publicKey = privateKey.publicKey
        self.publicKeyPoint = try K1.Group.Point(publicKey: publicKey)
    }
    
    init(privateKey: K1.KeyAgreement.PrivateKey) throws {
        self.privateKey = privateKey
        self.publicKey = privateKey.publicKey
        self.publicKeyPoint = try K1.Group.Point(publicKey: publicKey)
    }
}

/// Mint operations in the BDHKE protocol
struct Mint {
    let keypair: MintKeypair
    
    init() throws {
        self.keypair = try MintKeypair()
    }
    
    init(privateKey: K1.KeyAgreement.PrivateKey) throws {
        self.keypair = try MintKeypair(privateKey: privateKey)
    }
    
    /// Step 2 of BDHKE: Mint signs the blinded message
    /// Input: B_ (blinded message from wallet)
    /// Output: C_ = k * B_ (blinded signature)
    func signBlindedMessage(_ blindedMessage: Data) throws -> Data {
        // Parse B_ as a compressed public key
        let blindedMessagePublicKey = try K1.KeyAgreement.PublicKey(compressedRepresentation: blindedMessage)
        let blindedMessagePoint = try K1.Group.Point(publicKey: blindedMessagePublicKey)
        
        // Sign: C_ = k * B_
        let blindedSignature = try multiplyPoint(blindedMessagePoint, by: keypair.privateKey)
        
        // Return C_ as compressed public key data
        let signaturePublicKey = try blindedSignature.toPublicKey()
        return signaturePublicKey.compressedRepresentation
    }
    
    /// Step 4 of BDHKE: Verify an unblinded signature
    /// Check that k * hash_to_curve(x) == C
    /// This is how the mint verifies a token is valid when it's spent
    func verifyToken(secret: String, signature: Data) throws -> Bool {
        // Parse the signature as a compressed public key
        let signaturePublicKey = try K1.KeyAgreement.PublicKey(compressedRepresentation: signature)
        let signaturePoint = try K1.Group.Point(publicKey: signaturePublicKey)
        
        // Compute k * hash_to_curve(x)
        let secretPoint = try hashToCurve(secret)
        let expectedSignature = try multiplyPoint(secretPoint, by: keypair.privateKey)
        
        // Compare the points
        let expectedPublicKey = try expectedSignature.toPublicKey()
        return signaturePublicKey.compressedRepresentation == expectedPublicKey.compressedRepresentation
    }
}

// MARK: - Wallet Implementation

/// Represents wallet's blinding data for one token
struct WalletBlindingData {
    /// x: UTF-8-encoded secret message
    let secret: String
    /// r: blinding factor (private key)
    let blindingFactor: K1.KeyAgreement.PrivateKey
    /// Y: hash_to_curve(x)
    let secretPoint: K1.Group.Point
    /// B_: blinded message (Y + r*G)
    let blindedMessage: K1.Group.Point
    
    init(secret: String) throws {
        self.secret = secret
        self.blindingFactor = K1.KeyAgreement.PrivateKey()
        self.secretPoint = try hashToCurve(secret)
        
        // Create blinded message: B_ = Y + r*G
        let generatorPoint = try getGeneratorPoint()
        let rG = try multiplyPoint(generatorPoint, by: self.blindingFactor)
        self.blindedMessage = try K1.Group.add(self.secretPoint, rG)
    }
}

/// Represents an unblinded token
struct UnblindedToken {
    /// x: the original secret
    let secret: String
    /// C: unblinded signature
    let signature: Data
    
    init(secret: String, signature: Data) {
        self.secret = secret
        self.signature = signature
    }
}

/// Wallet operations in the BDHKE protocol
struct Wallet {
    
    /// Step 1 of BDHKE: Create a blinded message for the mint to sign
    /// Input: x (secret)
    /// Output: B_ = Y + r*G where Y = hash_to_curve(x) and r is random
    static func createBlindedMessage(secret: String) throws -> (blindingData: WalletBlindingData, blindedMessage: Data) {
        let blindingData = try WalletBlindingData(secret: secret)
        
        // Convert B_ to compressed public key format for transmission
        let blindedPublicKey = try blindingData.blindedMessage.toPublicKey()
        let blindedMessage = blindedPublicKey.compressedRepresentation
        
        return (blindingData, blindedMessage)
    }
    
    /// Step 3 of BDHKE: Unblind the signature received from the mint
    /// Input: C_ (blinded signature), blinding data, K (mint public key)
    /// Output: C = C_ - r*K (unblinded signature)
    static func unblindSignature(
        blindedSignature: Data,
        blindingData: WalletBlindingData,
        mintPublicKey: K1.KeyAgreement.PublicKey
    ) throws -> UnblindedToken {
        // Parse C_ as a compressed public key
        let blindedSigPublicKey = try K1.KeyAgreement.PublicKey(compressedRepresentation: blindedSignature)
        let blindedSigPoint = try K1.Group.Point(publicKey: blindedSigPublicKey)
        
        // Unblind: C = C_ - r*K
        let mintPublicKeyPoint = try K1.Group.Point(publicKey: mintPublicKey)
        let rK = try multiplyPoint(mintPublicKeyPoint, by: blindingData.blindingFactor)
        let unblindedSignaturePoint = try K1.Group.subtract(blindedSigPoint, rK)
        
        // Convert to data for storage/transmission
        let unblindedSignaturePublicKey = try unblindedSignaturePoint.toPublicKey()
        let signatureData = unblindedSignaturePublicKey.compressedRepresentation
        
        return UnblindedToken(secret: blindingData.secret, signature: signatureData)
    }
    
    /// Verify a token locally (same logic as mint verification)
    static func verifyToken(_ token: UnblindedToken, mintPublicKey: K1.KeyAgreement.PublicKey) throws -> Bool {
        let mint = try Mint(privateKey: K1.KeyAgreement.PrivateKey()) // This won't work for verification
        // Note: This method can't work without the mint's private key
        // Token verification must be done by the mint
        throw CashuCryptoError.verificationFailed
    }
}

// MARK: - Protocol Flow Implementation

/// Complete BDHKE protocol flow following NUT-00
struct CashuBDHKEProtocol {
    
    /// Execute the complete BDHKE protocol
    /// This demonstrates the full flow from NUT-00
    static func executeProtocol(secret: String) throws -> (token: UnblindedToken, isValid: Bool) {
        print("=== Executing Cashu BDHKE Protocol (NUT-00) ===\n")
        
        // Setup: Mint publishes public key K = k*G
        let mint = try Mint()
        let mintPublicKey = mint.keypair.publicKey
        print("1. Mint publishes public key K: \(mintPublicKey.compressedRepresentation.hexString)")
        
        // Step 1: Wallet picks secret x and computes Y = hash_to_curve(x)
        //         Wallet sends B_ = Y + r*G to mint (blinding)
        let (blindingData, blindedMessage) = try Wallet.createBlindedMessage(secret: secret)
        print("2. Wallet creates secret x: \(secret)")
        print("   Wallet computes Y = hash_to_curve(x)")
        print("   Wallet sends B_ = Y + r*G: \(blindedMessage.hexString)")
        
        // Step 2: Mint signs the blinded message and sends back C_ = k*B_ (signing)
        let blindedSignature = try mint.signBlindedMessage(blindedMessage)
        print("3. Mint signs and returns C_ = k*B_: \(blindedSignature.hexString)")
        
        // Step 3: Wallet unblinds the signature: C = C_ - r*K (unblinding)
        let token = try Wallet.unblindSignature(
            blindedSignature: blindedSignature,
            blindingData: blindingData,
            mintPublicKey: mintPublicKey
        )
        print("4. Wallet unblinds to get C = C_ - r*K: \(token.signature.hexString)")
        
        // Step 4: Verification - Mint checks k*hash_to_curve(x) == C
        let isValid = try mint.verifyToken(secret: token.secret, signature: token.signature)
        print("5. Mint verifies k*hash_to_curve(x) == C: \(isValid)")
        
        print("\n=== Protocol Complete ===")
        return (token, isValid)
    }
}

// MARK: - Utility Extensions

extension Data {
    /// Convert hex string to Data
    init?(hexString: String) {
        let cleanHex = hexString.replacingOccurrences(of: " ", with: "")
        guard cleanHex.count % 2 == 0 else { return nil }
        
        var data = Data()
        var index = cleanHex.startIndex
        
        while index < cleanHex.endIndex {
            let nextIndex = cleanHex.index(index, offsetBy: 2)
            let byteString = cleanHex[index..<nextIndex]
            
            guard let byte = UInt8(byteString, radix: 16) else { return nil }
            data.append(byte)
            
            index = nextIndex
        }
        
        self = data
    }
    
    /// Convert Data to hex string
    var hexString: String {
        return map { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - Key Management Utilities

/// Utility functions for Cashu key management
struct CashuKeyUtils {
    /// Generate a random 32-byte secret as hex string (recommended format)
    static func generateRandomSecret() -> String {
        let randomBytes = (0..<32).map { _ in UInt8.random(in: 0...255) }
        return Data(randomBytes).hexString
    }
    
    /// Generate a new mint keypair
    static func generateMintKeypair() throws -> MintKeypair {
        return try MintKeypair()
    }
    
    /// Convert private key to hex string for storage
    static func privateKeyToHex(_ privateKey: K1.KeyAgreement.PrivateKey) -> String {
        return privateKey.rawRepresentation.hexString
    }
    
    /// Load private key from hex string
    static func privateKeyFromHex(_ hexString: String) throws -> K1.KeyAgreement.PrivateKey {
        guard let data = Data(hexString: hexString) else {
            throw CashuCryptoError.invalidHexString
        }
        return try K1.KeyAgreement.PrivateKey(rawRepresentation: data)
    }
    
    /// Validate that a secret can be hashed to a valid curve point
    static func validateSecret(_ secret: String) throws -> Bool {
        do {
            _ = try hashToCurve(secret)
            return true
        } catch {
            return false
        }
    }
}

// MARK: - Testing and Examples

/// Examples and tests for the Cashu implementation
struct CashuExamples {
    
    /// Run the complete BDHKE protocol with a test secret
    static func runCompleteProtocol() throws {
        let secret = CashuKeyUtils.generateRandomSecret()
        let (token, isValid) = try CashuBDHKEProtocol.executeProtocol(secret: secret)
        
        print("\nFinal Results:")
        print("Token Secret: \(token.secret)")
        print("Token Signature: \(token.signature.hexString)")
        print("Verification Result: \(isValid)")
        
        // Test with a fixed secret from NUT-00 example
        let fixedSecret = "407915bc212be61a77e3e6d2aeb4c727980bda51cd06a6afc29e2861768a7837"
        let (fixedToken, fixedValid) = try CashuBDHKEProtocol.executeProtocol(secret: fixedSecret)
        print("Fixed secret verification: \(fixedValid)")
    }
    
    /// Test point arithmetic operations
    static func testPointArithmetic() throws {
        print("\n=== Testing Point Arithmetic ===\n")
        
        let G = try getGeneratorPoint()
        let privateKey = K1.KeyAgreement.PrivateKey()
        let publicKeyPoint = try K1.Group.Point(publicKey: privateKey.publicKey)
        
        print("Generator G: \(try G.toPublicKey().compressedRepresentation.hexString)")
        print("Random point P: \(try publicKeyPoint.toPublicKey().compressedRepresentation.hexString)")
        
        // Test addition: P + G
        let sum = try K1.Group.add(publicKeyPoint, G)
        print("P + G: \(try sum.toPublicKey().compressedRepresentation.hexString)")
        
        // Test subtraction: P - G
        let difference = try K1.Group.subtract(publicKeyPoint, G)
        print("P - G: \(try difference.toPublicKey().compressedRepresentation.hexString)")
        
        // Test that (P + G) - G = P
        let reconstructed = try K1.Group.subtract(sum, G)
        let originalHex = try publicKeyPoint.toPublicKey().compressedRepresentation.hexString
        let reconstructedHex = try reconstructed.toPublicKey().compressedRepresentation.hexString
        
        print("Original P: \(originalHex)")
        print("(P + G) - G: \(reconstructedHex)")
        print("Arithmetic consistent: \(originalHex == reconstructedHex)")
    }
    
    /// Test hash-to-curve function
    static func testHashToCurve() throws {
        print("\n=== Testing Hash-to-Curve ===\n")
        
        let testSecret = "test_secret_123"
        let point1 = try hashToCurve(testSecret)
        let point2 = try hashToCurve(testSecret)
        
        let hex1 = try point1.toPublicKey().compressedRepresentation.hexString
        let hex2 = try point2.toPublicKey().compressedRepresentation.hexString
        
        print("Secret: \(testSecret)")
        print("Point 1: \(hex1)")
        print("Point 2: \(hex2)")
        print("Deterministic: \(hex1 == hex2)")
        
        // Test different secrets produce different points
        let differentPoint = try hashToCurve("different_secret")
        let differentHex = try differentPoint.toPublicKey().compressedRepresentation.hexString
        print("Different secret point: \(differentHex)")
        print("Different results: \(hex1 != differentHex)")
    }
}
