//
//  CheckStateService.swift
//  CashuKit
//
//  NUT-07: Token state check service
//  https://github.com/cashubtc/nuts/blob/main/07.md
//

import Foundation

// MARK: - NUT-07: Token state check service

@CashuActor
public struct CheckStateService: Sendable {
    private let router: NetworkRouter<CheckStateAPI>
    
    public init() async {
        self.router = NetworkRouter<CheckStateAPI>(decoder: .cashuDecoder)
        self.router.delegate = CashuEnvironment.current.routerDelegate
    }
    
    /// Check the state of proofs by their Y values
    /// - Parameters:
    ///   - yValues: Array of Y values to check
    ///   - mintURL: The base URL of the mint
    /// - Returns: PostCheckStateResponse with state information
    public func checkStates(yValues: [String], from mintURL: String) async throws -> PostCheckStateResponse {
        // Validate and normalize the mint URL
        let normalizedURL = try normalizeMintURL(mintURL)
        
        // Set the base URL for this request
        CashuEnvironment.current.setup(baseURL: normalizedURL)
        
        let request = PostCheckStateRequest(Ys: yValues)
        return try await router.execute(.checkState(request))
    }
    
    /// Check the state of specific proofs
    /// - Parameters:
    ///   - proofs: Array of proofs to check
    ///   - mintURL: The base URL of the mint
    /// - Returns: PostCheckStateResponse with state information
    public func checkStates(proofs: [Proof], from mintURL: String) async throws -> PostCheckStateResponse {
        let yValues = try proofs.map { try $0.calculateY() }
        return try await checkStates(yValues: yValues, from: mintURL)
    }
    
    /// Check the state of a single proof
    /// - Parameters:
    ///   - proof: The proof to check
    ///   - mintURL: The base URL of the mint
    /// - Returns: ProofStateInfo for the proof
    public func checkState(proof: Proof, from mintURL: String) async throws -> ProofStateInfo {
        let response = try await checkStates(proofs: [proof], from: mintURL)
        guard let stateInfo = response.states.first else {
            throw NUT07Error.stateCheckFailed("No state returned for proof")
        }
        return stateInfo
    }
    
    /// Check if mint supports NUT-07 token state checking
    /// - Parameter mintURL: The mint URL to check
    /// - Returns: True if NUT-07 is supported
    public func supportsStateCheck(at mintURL: String) async throws -> Bool {
        let mintInfoService = await MintInfoService()
        return try await mintInfoService.supportsTokenStateCheck(at: mintURL)
    }
    
    // MARK: - Private helper methods
    
    /// Normalize a mint URL (add scheme if missing, remove trailing slash)
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
        
        // Basic validation
        guard let url = URL(string: normalizedURL),
              let scheme = url.scheme,
              ["http", "https"].contains(scheme.lowercased()),
              let host = url.host,
              !host.isEmpty else {
            throw CashuError.invalidMintURL
        }
        
        return normalizedURL
    }
}

// MARK: - CheckState API Endpoint

enum CheckStateAPI {
    case checkState(PostCheckStateRequest)
}

extension CheckStateAPI: EndpointType {
    public var baseURL: URL {
        guard let baseURL = CashuEnvironment.current.baseURL, let url = URL(string: baseURL) else { 
            fatalError("The baseURL for the mint must be set") 
        }
        return url
    }
    
    var path: String {
        switch self {
        case .checkState:
            return "/v1/checkstate"
        }
    }
    
    var httpMethod: HTTPMethod {
        switch self {
        case .checkState:
            return .post
        }
    }
    
    var task: HTTPTask {
        switch self {
        case .checkState(let request):
            return .requestParameters(encoding: .jsonEncodableEncoding(encodable: request))
        }
    }
    
    var headers: HTTPHeaders? {
        return [
            "Accept": "application/json",
            "Content-Type": "application/json"
        ]
    }
}