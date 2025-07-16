//
//  NUT16.swift
//  CashuKit
//
//  NUT-16: Animated QR codes
//  https://github.com/cashubtc/nuts/blob/main/16.md
//

import Foundation

// MARK: - NUT-16: Animated QR codes

/// NUT-16: Animated QR codes
/// This NUT defines how tokens should be displayed as QR codes for sending them between wallets

// MARK: - QR Code Types

/// Type of QR code for token display
public enum QRCodeType: String, CaseIterable, Sendable {
    /// Static QR code for small tokens
    case `static` = "static"
    
    /// Animated QR code using UR protocol for large tokens
    case animated = "animated"
    
    /// Human-readable description
    public var description: String {
        switch self {
        case .static:
            return "Static QR Code"
        case .animated:
            return "Animated QR Code (UR)"
        }
    }
}

/// Configuration for QR code generation
public struct QRCodeConfiguration: Sendable {
    /// Maximum number of proofs for static QR code
    public let maxProofsForStatic: Int
    
    /// Maximum data size in bytes for static QR code
    public let maxBytesForStatic: Int
    
    /// Frame duration for animated QR codes in milliseconds
    public let animationFrameDuration: Int
    
    /// Error correction level for QR codes
    public let errorCorrectionLevel: QRErrorCorrectionLevel
    
    public init(
        maxProofsForStatic: Int = 2,
        maxBytesForStatic: Int = 2953, // QR code version 40 with low error correction
        animationFrameDuration: Int = 200,
        errorCorrectionLevel: QRErrorCorrectionLevel = .medium
    ) {
        self.maxProofsForStatic = maxProofsForStatic
        self.maxBytesForStatic = maxBytesForStatic
        self.animationFrameDuration = animationFrameDuration
        self.errorCorrectionLevel = errorCorrectionLevel
    }
    
    /// Default configuration as specified in NUT-16
    public static let `default` = QRCodeConfiguration()
}

/// QR code error correction levels
public enum QRErrorCorrectionLevel: String, CaseIterable, Sendable {
    case low = "L"      // ~7% correction
    case medium = "M"   // ~15% correction
    case quartile = "Q" // ~25% correction
    case high = "H"     // ~30% correction
    
    /// Maximum data capacity adjustment factor
    public var capacityFactor: Double {
        switch self {
        case .low: return 1.0
        case .medium: return 0.85
        case .quartile: return 0.65
        case .high: return 0.5
        }
    }
}

// MARK: - QR Code Analysis

/// Analyzer for determining QR code requirements
public struct QRCodeAnalyzer: Sendable {
    private let configuration: QRCodeConfiguration
    
    public init(configuration: QRCodeConfiguration = .default) {
        self.configuration = configuration
    }
    
    /// Determine the type of QR code needed for a token
    /// - Parameter token: The token to analyze
    /// - Returns: The recommended QR code type
    public func analyzeToken(_ token: CashuToken) throws -> QRCodeType {
        // Check proof count
        let totalProofs = token.token.reduce(0) { $0 + $1.proofs.count }
        if totalProofs > configuration.maxProofsForStatic {
            return .animated
        }
        
        // Serialize token to check size
        let serialized = try CashuTokenUtils.serializeToken(token, includeURI: true)
        let dataSize = serialized.data(using: .utf8)?.count ?? 0
        
        // Adjust for error correction
        let adjustedMaxSize = Int(Double(configuration.maxBytesForStatic) * configuration.errorCorrectionLevel.capacityFactor)
        
        if dataSize > adjustedMaxSize {
            return .animated
        }
        
        return .static
    }
    
    /// Check if token has characteristics that increase size
    /// - Parameter token: The token to check
    /// - Returns: True if token has size-increasing features
    public func hasLargeFeatures(_ token: CashuToken) -> Bool {
        for entry in token.token {
            for proof in entry.proofs {
                // Check for long scripts in secrets
                if proof.secret.count > 100 {
                    return true
                }
            }
        }
        
        // Check for long memo
        if let memo = token.memo, memo.count > 100 {
            return true
        }
        
        // Check for multiple mints or long mint URLs
        if token.token.count > 1 || token.token.contains(where: { $0.mint.count > 50 }) {
            return true
        }
        
        return false
    }
}

// MARK: - UR Protocol Support

/// UR (Uniform Resource) type for Cashu tokens
public struct CashuUR: Sendable {
    /// UR type identifier for Cashu tokens
    public static let urType = "cashu-token"
    
    /// Maximum fragment size for UR encoding
    public static let maxFragmentSize = 200
    
    /// Encode a token for UR protocol
    /// - Parameter token: The token to encode
    /// - Returns: UR encoded data
    public static func encodeToken(_ token: CashuToken) throws -> Data {
        let serialized = try CashuTokenUtils.serializeToken(token, includeURI: false)
        guard let data = serialized.data(using: .utf8) else {
            throw CashuError.serializationFailed
        }
        return data
    }
    
    /// Create UR fragments for animated QR codes
    /// - Parameters:
    ///   - data: The data to fragment
    ///   - messageID: Unique identifier for this message
    /// - Returns: Array of UR fragment strings
    public static func createFragments(
        data: Data,
        messageID: Data? = nil
    ) throws -> [String] {
        // This is a simplified implementation
        // In a real implementation, you would use the bc-ur library
        
        let fragments = data.chunked(into: maxFragmentSize)
        let totalFragments = fragments.count
        let id = messageID ?? Data.random(count: 4)
        
        return fragments.enumerated().map { index, fragment in
            // Simplified UR format: ur:cashu-token/<index>-<total>/<id>/<data>
            let fragmentHex = fragment.hexString
            return "ur:\(urType)/\(index + 1)-\(totalFragments)/\(id.hexString)/\(fragmentHex)"
        }
    }
}

// MARK: - QR Code Display

/// Container for QR code display data
public struct QRCodeDisplay: Sendable {
    /// Type of QR code
    public let type: QRCodeType
    
    /// Data to encode in QR code(s)
    public let data: QRCodeData
    
    /// Configuration used
    public let configuration: QRCodeConfiguration
    
    public init(type: QRCodeType, data: QRCodeData, configuration: QRCodeConfiguration = .default) {
        self.type = type
        self.data = data
        self.configuration = configuration
    }
}

/// Data for QR code generation
public enum QRCodeData: Sendable {
    /// Single static QR code data
    case `static`(String)
    
    /// Multiple frames for animated QR code
    case animated([String])
    
    /// Get all frames (1 for static, multiple for animated)
    public var frames: [String] {
        switch self {
        case .static(let data):
            return [data]
        case .animated(let frames):
            return frames
        }
    }
    
    /// Total number of frames
    public var frameCount: Int {
        switch self {
        case .static:
            return 1
        case .animated(let frames):
            return frames.count
        }
    }
}

// MARK: - QR Code Generator

/// Generator for creating QR codes from tokens
public struct QRCodeGenerator: Sendable {
    private let configuration: QRCodeConfiguration
    private let analyzer: QRCodeAnalyzer
    
    public init(configuration: QRCodeConfiguration = .default) {
        self.configuration = configuration
        self.analyzer = QRCodeAnalyzer(configuration: configuration)
    }
    
    /// Generate QR code display data for a token
    /// - Parameter token: The token to encode
    /// - Returns: QR code display data
    public func generateQRCode(for token: CashuToken) throws -> QRCodeDisplay {
        let qrType = try analyzer.analyzeToken(token)
        
        switch qrType {
        case .static:
            let serialized = try CashuTokenUtils.serializeToken(token, includeURI: true)
            return QRCodeDisplay(
                type: .static,
                data: .static(serialized),
                configuration: configuration
            )
            
        case .animated:
            let data = try CashuUR.encodeToken(token)
            let fragments = try CashuUR.createFragments(data: data)
            return QRCodeDisplay(
                type: .animated,
                data: .animated(fragments),
                configuration: configuration
            )
        }
    }
    
    /// Check if a token should use animated QR code
    /// - Parameter token: The token to check
    /// - Returns: True if animated QR code is recommended
    public func shouldUseAnimated(for token: CashuToken) throws -> Bool {
        return try analyzer.analyzeToken(token) == .animated
    }
}

// MARK: - QR Code Scanner

/// Result from scanning a QR code
public struct QRCodeScanResult: Sendable {
    /// Type of QR code scanned
    public let type: QRCodeType
    
    /// Decoded token if complete
    public let token: CashuToken?
    
    /// Progress for animated QR codes (0.0 to 1.0)
    public let progress: Double
    
    /// Whether scanning is complete
    public let isComplete: Bool
    
    public init(
        type: QRCodeType,
        token: CashuToken? = nil,
        progress: Double = 0.0,
        isComplete: Bool = false
    ) {
        self.type = type
        self.token = token
        self.progress = progress
        self.isComplete = isComplete
    }
}

/// Scanner for decoding QR codes
public struct QRCodeScanner: Sendable {
    /// Decoder state for animated QR codes
    public struct URDecoderState: Sendable {
        var fragments: [Int: String] = [:]
        var totalFragments: Int?
        var messageID: String?
        
        /// Check if all fragments have been received
        public var isComplete: Bool {
            guard let total = totalFragments else { return false }
            return fragments.count == total
        }
        
        /// Progress from 0.0 to 1.0
        public var progress: Double {
            guard let total = totalFragments, total > 0 else { return 0.0 }
            return Double(fragments.count) / Double(total)
        }
    }
    
    private var urDecoderState = URDecoderState()
    
    public init() {}
    
    /// Process a scanned QR code
    /// - Parameter qrData: The data from the QR code
    /// - Returns: Scan result
    public mutating func processQRCode(_ qrData: String) throws -> QRCodeScanResult {
        // Check if it's a UR fragment
        if qrData.hasPrefix("ur:") {
            return try processURFragment(qrData)
        } else {
            // Try to decode as static QR code
            let token = try CashuTokenUtils.deserializeToken(qrData)
            return QRCodeScanResult(
                type: .static,
                token: token,
                progress: 1.0,
                isComplete: true
            )
        }
    }
    
    /// Process a UR fragment
    private mutating func processURFragment(_ fragment: String) throws -> QRCodeScanResult {
        // Parse UR fragment (simplified)
        // Format: ur:cashu-token/<index>-<total>/<id>/<data>
        
        // Remove "ur:" prefix and split by "/"
        guard fragment.hasPrefix("ur:") else {
            throw CashuError.invalidTokenFormat
        }
        
        let withoutPrefix = String(fragment.dropFirst(3))
        let components = withoutPrefix.components(separatedBy: "/")
        guard components.count >= 4,
              components[0] == CashuUR.urType else {
            throw CashuError.invalidTokenFormat
        }
        
        let sequenceInfo = components[1].components(separatedBy: "-")
        guard sequenceInfo.count == 2,
              let index = Int(sequenceInfo[0]),
              let total = Int(sequenceInfo[1]) else {
            throw CashuError.invalidTokenFormat
        }
        
        let messageID = components[2]
        let dataHex = components[3]
        
        // Initialize or validate decoder state
        if urDecoderState.messageID == nil {
            urDecoderState.messageID = messageID
            urDecoderState.totalFragments = total
        } else if urDecoderState.messageID != messageID {
            // New message, reset state
            urDecoderState = URDecoderState()
            urDecoderState.messageID = messageID
            urDecoderState.totalFragments = total
        }
        
        // Store fragment
        urDecoderState.fragments[index] = dataHex
        
        // Check if complete
        if urDecoderState.isComplete {
            // Reconstruct data
            var completeData = Data()
            for i in 1...total {
                guard let fragmentHex = urDecoderState.fragments[i],
                      let fragmentData = Data(hexString: fragmentHex) else {
                    throw CashuError.deserializationFailed
                }
                completeData.append(fragmentData)
            }
            
            // Decode token
            guard let serialized = String(data: completeData, encoding: .utf8) else {
                throw CashuError.deserializationFailed
            }
            
            let token = try CashuTokenUtils.deserializeToken(serialized)
            
            // Reset state
            urDecoderState = URDecoderState()
            
            return QRCodeScanResult(
                type: .animated,
                token: token,
                progress: 1.0,
                isComplete: true
            )
        } else {
            return QRCodeScanResult(
                type: .animated,
                token: nil,
                progress: urDecoderState.progress,
                isComplete: false
            )
        }
    }
    
    /// Reset the scanner state
    public mutating func reset() {
        urDecoderState = URDecoderState()
    }
}

// MARK: - Helper Extensions

extension Data {
    /// Split data into chunks
    func chunked(into size: Int) -> [Data] {
        var chunks: [Data] = []
        var offset = 0
        
        while offset < count {
            let chunkSize = Swift.min(size, count - offset)
            let chunk = subdata(in: offset..<offset + chunkSize)
            chunks.append(chunk)
            offset += chunkSize
        }
        
        return chunks
    }
}

// MARK: - CashuTokenUtils Extensions

extension CashuTokenUtils {
    /// Generate QR code for a token
    /// - Parameter token: The token to encode
    /// - Returns: QR code display data
    public static func generateQRCode(for token: CashuToken) throws -> QRCodeDisplay {
        let generator = QRCodeGenerator()
        return try generator.generateQRCode(for: token)
    }
    
    /// Check if a token requires animated QR code
    /// - Parameter token: The token to check
    /// - Returns: True if animated QR code is needed
    public static func requiresAnimatedQR(for token: CashuToken) throws -> Bool {
        let generator = QRCodeGenerator()
        return try generator.shouldUseAnimated(for: token)
    }
}