//
//  NUT16Tests.swift
//  CashuKitTests
//
//  Tests for NUT-16: Animated QR codes
//

import Testing
@testable import CashuKit
import Foundation

@Suite("NUT-16 Tests")
struct NUT16Tests {
    
    // Helper function to create test tokens
    func createTestToken(proofCount: Int, secretLength: Int = 50) -> CashuToken {
        var proofs: [Proof] = []
        for i in 0..<proofCount {
            let secret = String(repeating: "a", count: secretLength)
            proofs.append(Proof(
                amount: 100,
                id: "test_keyset",
                secret: secret,
                C: "02\(String(repeating: "0", count: 62))\(i)"
            ))
        }
        
        let tokenEntry = TokenEntry(
            mint: "https://mint.example.com",
            proofs: proofs
        )
        
        return CashuToken(
            token: [tokenEntry],
            unit: "sat",
            memo: "Test token"
        )
    }
    
    @Test("QR code type determination - static")
    func testStaticQRCodeDetermination() throws {
        let analyzer = QRCodeAnalyzer()
        
        // Small token with 2 proofs should be static
        let smallToken = createTestToken(proofCount: 2)
        let qrType = try analyzer.analyzeToken(smallToken)
        
        #expect(qrType == .static)
    }
    
    @Test("QR code type determination - animated")
    func testAnimatedQRCodeDetermination() throws {
        let analyzer = QRCodeAnalyzer()
        
        // Token with more than 2 proofs should be animated
        let largeToken = createTestToken(proofCount: 5)
        let qrType = try analyzer.analyzeToken(largeToken)
        
        #expect(qrType == .animated)
    }
    
    @Test("QR code type determination - large secret")
    func testLargeSecretQRCodeDetermination() throws {
        let analyzer = QRCodeAnalyzer()
        
        // Token with very long secret should be animated
        let tokenWithLongSecret = createTestToken(proofCount: 1, secretLength: 3000)
        let qrType = try analyzer.analyzeToken(tokenWithLongSecret)
        
        #expect(qrType == .animated)
    }
    
    @Test("Large feature detection")
    func testLargeFeatureDetection() {
        let analyzer = QRCodeAnalyzer()
        
        // Token with long secret
        let tokenWithLongSecret = createTestToken(proofCount: 1, secretLength: 150)
        #expect(analyzer.hasLargeFeatures(tokenWithLongSecret) == true)
        
        // Token with long memo
        let tokenEntry = TokenEntry(
            mint: "https://mint.example.com",
            proofs: [Proof(amount: 100, id: "test", secret: "secret", C: "C1")]
        )
        let tokenWithLongMemo = CashuToken(
            token: [tokenEntry],
            unit: "sat",
            memo: String(repeating: "memo", count: 30)
        )
        #expect(analyzer.hasLargeFeatures(tokenWithLongMemo) == true)
        
        // Normal token
        let normalToken = createTestToken(proofCount: 1, secretLength: 50)
        #expect(analyzer.hasLargeFeatures(normalToken) == false)
    }
    
    @Test("QR error correction capacity")
    func testErrorCorrectionCapacity() {
        #expect(QRErrorCorrectionLevel.low.capacityFactor == 1.0)
        #expect(QRErrorCorrectionLevel.medium.capacityFactor == 0.85)
        #expect(QRErrorCorrectionLevel.quartile.capacityFactor == 0.65)
        #expect(QRErrorCorrectionLevel.high.capacityFactor == 0.5)
    }
    
    @Test("UR fragment creation")
    func testURFragmentCreation() throws {
        let testData = "Hello, Cashu!".data(using: .utf8)!
        let fragments = try CashuUR.createFragments(data: testData)
        
        #expect(fragments.count == 1) // Small data should fit in one fragment
        #expect(fragments[0].hasPrefix("ur:cashu-token/"))
        
        // Test larger data requiring multiple fragments
        let largeData = Data(repeating: 0xFF, count: 500)
        let largeFragments = try CashuUR.createFragments(data: largeData)
        
        #expect(largeFragments.count > 1)
        
        // Verify fragment format
        for (index, fragment) in largeFragments.enumerated() {
            #expect(fragment.hasPrefix("ur:cashu-token/"))
            #expect(fragment.contains("/\(index + 1)-\(largeFragments.count)/"))
        }
    }
    
    @Test("QR code generator - static")
    func testStaticQRCodeGeneration() throws {
        let generator = QRCodeGenerator()
        let token = createTestToken(proofCount: 1, secretLength: 50)
        
        let qrDisplay = try generator.generateQRCode(for: token)
        
        #expect(qrDisplay.type == .static)
        
        switch qrDisplay.data {
        case .static(let data):
            #expect(data.hasPrefix("cashu")) // Should include URI prefix
            #expect(data.contains("A")) // Contains token version
        case .animated:
            #expect(Bool(false), "Should be static QR code")
        }
    }
    
    @Test("QR code generator - animated")
    func testAnimatedQRCodeGeneration() throws {
        let generator = QRCodeGenerator()
        let token = createTestToken(proofCount: 5, secretLength: 100)
        
        let qrDisplay = try generator.generateQRCode(for: token)
        
        #expect(qrDisplay.type == .animated)
        
        switch qrDisplay.data {
        case .static:
            #expect(Bool(false), "Should be animated QR code")
        case .animated(let frames):
            #expect(frames.count > 0)
            for frame in frames {
                #expect(frame.hasPrefix("ur:cashu-token/"))
            }
        }
    }
    
    @Test("QR code scanner - static")
    func testStaticQRCodeScanning() throws {
        var scanner = QRCodeScanner()
        let token = createTestToken(proofCount: 1, secretLength: 50)
        let serialized = try CashuTokenUtils.serializeToken(token, includeURI: true)
        
        let result = try scanner.processQRCode(serialized)
        
        #expect(result.type == .static)
        #expect(result.isComplete == true)
        #expect(result.progress == 1.0)
        #expect(result.token != nil)
        #expect(result.token?.token.count == 1)
    }
    
    @Test("QR code scanner - animated single fragment")
    func testAnimatedQRCodeScanningSingleFragment() throws {
        var scanner = QRCodeScanner()
        
        // Create a valid token and serialize it
        let token = createTestToken(proofCount: 1)
        let tokenData = try CashuTokenUtils.serializeToken(token, includeURI: false).data(using: .utf8)!
        let messageID = Data([0x01, 0x02, 0x03, 0x04])
        let fragment = "ur:cashu-token/1-1/\(messageID.hexString)/\(tokenData.hexString)"
        
        let result = try scanner.processQRCode(fragment)
        
        #expect(result.type == .animated)
        #expect(result.progress == 1.0)
        #expect(result.isComplete == true)
        #expect(result.token != nil)
    }
    
    @Test("QR code scanner - animated multiple fragments")
    func testAnimatedQRCodeScanningMultipleFragments() throws {
        var scanner = QRCodeScanner()
        let messageID = Data([0x01, 0x02, 0x03, 0x04])
        
        // Create a valid token and split it into fragments
        let token = createTestToken(proofCount: 1)
        let tokenData = try CashuTokenUtils.serializeToken(token, includeURI: false).data(using: .utf8)!
        
        // Split data into 3 parts for testing
        let chunkSize = tokenData.count / 3
        let chunk1 = tokenData.subdata(in: 0..<chunkSize)
        let chunk2 = tokenData.subdata(in: chunkSize..<(chunkSize * 2))
        let chunk3 = tokenData.subdata(in: (chunkSize * 2)..<tokenData.count)
        
        let fragment1 = "ur:cashu-token/1-3/\(messageID.hexString)/\(chunk1.hexString)"
        let fragment2 = "ur:cashu-token/2-3/\(messageID.hexString)/\(chunk2.hexString)"
        let fragment3 = "ur:cashu-token/3-3/\(messageID.hexString)/\(chunk3.hexString)"
        
        let result1 = try scanner.processQRCode(fragment1)
        #expect(result1.isComplete == false)
        #expect(result1.progress > 0 && result1.progress < 1)
        
        let result2 = try scanner.processQRCode(fragment2)
        #expect(result2.isComplete == false)
        #expect(result2.progress > result1.progress)
        
        let result3 = try scanner.processQRCode(fragment3)
        #expect(result3.isComplete == true)
        #expect(result3.progress == 1.0)
        #expect(result3.token != nil)
    }
    
    @Test("QR code scanner reset")
    func testQRCodeScannerReset() throws {
        var scanner = QRCodeScanner()
        let messageID = Data([0x01, 0x02, 0x03, 0x04])
        
        // Add a fragment
        let fragment = "ur:cashu-token/1-2/\(messageID.hexString)/48656c6c6f"
        _ = try scanner.processQRCode(fragment)
        
        // Reset scanner
        scanner.reset()
        
        // Add a different message fragment - should start fresh
        let newMessageID = Data([0x05, 0x06, 0x07, 0x08])
        let newFragment = "ur:cashu-token/1-2/\(newMessageID.hexString)/48656c6c6f"
        let result = try scanner.processQRCode(newFragment)
        
        #expect(result.progress == 0.5) // 1 of 2 fragments
    }
    
    @Test("QR configuration")
    func testQRConfiguration() {
        let defaultConfig = QRCodeConfiguration.default
        #expect(defaultConfig.maxProofsForStatic == 2)
        #expect(defaultConfig.maxBytesForStatic == 2953)
        #expect(defaultConfig.animationFrameDuration == 200)
        #expect(defaultConfig.errorCorrectionLevel == .medium)
        
        let customConfig = QRCodeConfiguration(
            maxProofsForStatic: 5,
            maxBytesForStatic: 5000,
            animationFrameDuration: 100,
            errorCorrectionLevel: .high
        )
        
        #expect(customConfig.maxProofsForStatic == 5)
        #expect(customConfig.animationFrameDuration == 100)
    }
    
    @Test("Data chunking")
    func testDataChunking() {
        let data = Data(repeating: 0xFF, count: 100)
        let chunks = data.chunked(into: 30)
        
        #expect(chunks.count == 4) // 100 / 30 = 3.33, so 4 chunks
        #expect(chunks[0].count == 30)
        #expect(chunks[1].count == 30)
        #expect(chunks[2].count == 30)
        #expect(chunks[3].count == 10) // Remaining bytes
        
        // Verify reconstruction
        let reconstructed = chunks.reduce(Data()) { $0 + $1 }
        #expect(reconstructed == data)
    }
    
    @Test("TokenUtils QR extensions")
    func testTokenUtilsQRExtensions() throws {
        let smallToken = createTestToken(proofCount: 1)
        let largeToken = createTestToken(proofCount: 5)
        
        #expect(try CashuTokenUtils.requiresAnimatedQR(for: smallToken) == false)
        #expect(try CashuTokenUtils.requiresAnimatedQR(for: largeToken) == true)
        
        let qrDisplay = try CashuTokenUtils.generateQRCode(for: smallToken)
        #expect(qrDisplay.type == .static)
    }
    
    @Test("QR code data frames")
    func testQRCodeDataFrames() {
        let staticData = QRCodeData.static("test data")
        #expect(staticData.frames.count == 1)
        #expect(staticData.frameCount == 1)
        #expect(staticData.frames[0] == "test data")
        
        let animatedData = QRCodeData.animated(["frame1", "frame2", "frame3"])
        #expect(animatedData.frames.count == 3)
        #expect(animatedData.frameCount == 3)
        #expect(animatedData.frames[1] == "frame2")
    }
    
    @Test("Multiple mint tokens")
    func testMultipleMintTokens() throws {
        let analyzer = QRCodeAnalyzer()
        
        // Create token with multiple mints
        let proofs1 = [Proof(amount: 100, id: "test", secret: "secret1", C: "C1")]
        let proofs2 = [Proof(amount: 200, id: "test", secret: "secret2", C: "C2")]
        
        let tokenEntry1 = TokenEntry(mint: "https://mint1.example.com", proofs: proofs1)
        let tokenEntry2 = TokenEntry(mint: "https://mint2.example.com", proofs: proofs2)
        
        let multiMintToken = CashuToken(
            token: [tokenEntry1, tokenEntry2],
            unit: "sat",
            memo: "Multi-mint token"
        )
        
        #expect(analyzer.hasLargeFeatures(multiMintToken) == true)
    }
}