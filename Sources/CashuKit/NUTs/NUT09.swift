//
//  NUT09.swift
//  CashuKit
//
//  NUT-09: Restore signatures
//  https://github.com/cashubtc/nuts/blob/main/09.md
//

import Foundation

// MARK: - NUT-09: Restore signatures

/// NUT-09: Restore signatures
/// This NUT defines how wallets can recover blind signatures for backup recovery
/// or for recovering responses from interrupted swap requests.

// MARK: - Core Functionality

/// Service for managing restore signature operations for NUT-09
@CashuActor
public struct RestoreSignatureService: Sendable {
    private let router: NetworkRouter<RestoreAPI>
    
    public init() async {
        self.router = NetworkRouter<RestoreAPI>(decoder: .cashuDecoder)
        self.router.delegate = CashuEnvironment.current.routerDelegate
    }
    
    /// Restore blind signatures from the mint
    /// - Parameter request: PostRestoreRequest containing BlindedMessages to restore
    /// - Returns: PostRestoreResponse containing matching outputs and signatures
    /// - Throws: CashuError if the request fails or response is invalid
    public func restoreSignatures(request: PostRestoreRequest, mintURL: String) async throws -> PostRestoreResponse {
        // Validate and set the mint URL
        let normalizedURL = try normalizeMintURL(mintURL)
        CashuEnvironment.current.setup(baseURL: normalizedURL)
        
        let response: PostRestoreResponse = try await router.execute(.restore(request))
        
        // Validate response integrity
        guard response.isValid else {
            throw CashuError.networkError("Restore response has mismatched outputs and signatures count")
        }
        
        return response
    }
    
    /// Restore signatures for specific blinded messages
    /// - Parameter blindedMessages: Array of BlindedMessages to restore
    /// - Parameter mintURL: The mint URL to query
    /// - Returns: Array of tuples containing the original BlindedMessage and corresponding BlindSignature
    /// - Throws: CashuError if the request fails
    public func restoreSignatures(for blindedMessages: [BlindedMessage], mintURL: String) async throws -> [(output: BlindedMessage, signature: BlindSignature)] {
        let request = PostRestoreRequest(outputs: blindedMessages)
        let response = try await restoreSignatures(request: request, mintURL: mintURL)
        return response.signaturePairs
    }
    
    /// Restore a single signature
    /// - Parameter blindedMessage: The BlindedMessage to restore
    /// - Parameter mintURL: The mint URL to query
    /// - Returns: The corresponding BlindSignature if found, nil otherwise
    /// - Throws: CashuError if the request fails
    public func restoreSignature(for blindedMessage: BlindedMessage, mintURL: String) async throws -> BlindSignature? {
        let pairs = try await restoreSignatures(for: [blindedMessage], mintURL: mintURL)
        return pairs.first?.signature
    }
    
    // MARK: - Utility Methods (Non-isolated)
    
    /// Normalize a mint URL (add scheme if missing, remove trailing slash)
    /// - Parameter mintURL: The URL to normalize
    /// - Returns: Normalized URL
    private nonisolated func normalizeMintURL(_ mintURL: String) throws -> String {
        var normalizedURL = mintURL.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Add https:// if no scheme is present
        if !normalizedURL.contains("://") {
            normalizedURL = "https://" + normalizedURL
        }
        
        // Remove trailing slash
        if normalizedURL.hasSuffix("/") {
            normalizedURL = String(normalizedURL.dropLast())
        }
        
        // Validate the normalized URL
        guard URL(string: normalizedURL) != nil else {
            throw CashuError.invalidMintURL
        }
        
        return normalizedURL
    }
}

// MARK: - API Endpoint Definition

enum RestoreAPI {
    case restore(PostRestoreRequest)
}

extension RestoreAPI: EndpointType {
    public var baseURL: URL {
        guard let baseURL = CashuEnvironment.current.baseURL, let url = URL(string: baseURL) else { 
            fatalError("The baseURL for the mint must be set") 
        }
        return url
    }
    
    var path: String {
        switch self {
        case .restore:
            return "/v1/restore"
        }
    }
    
    var httpMethod: HTTPMethod {
        switch self {
        case .restore:
            return .post
        }
    }
    
    var task: HTTPTask {
        switch self {
        case .restore(let request):
            return .requestParameters(encoding: .jsonEncodableEncoding(encodable: request))
        }
    }
    
    var headers: HTTPHeaders? {
        return [
            "Content-Type": "application/json",
            "Accept": "application/json"
        ]
    }
}

// MARK: - Error Handling Extensions

extension CashuError {
    /// Error for when restore operation fails
    static func restoreSignatureFailed(_ message: String) -> CashuError {
        return .networkError("Restore signature failed: \(message)")
    }
    
    /// Error for when blinded message was not previously signed by mint
    static func blindedMessageNotSigned(_ blindedMessage: BlindedMessage) -> CashuError {
        return .networkError("Blinded message with B_=\(blindedMessage.B_) was not previously signed by this mint")
    }
}