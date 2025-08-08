//
//  Networking.swift
//  CashuKit
//
//  Created by Thomas Rademaker on 6/27/25.
//

import Foundation

extension JSONDecoder {
    static var cashuDecoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let timestampInSeconds = try container.decode(Int.self)
            return Date(timeIntervalSince1970: TimeInterval(timestampInSeconds))
        }
        
        return decoder
    }
}

extension JSONEncoder {
    static var cashuEncoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        
        return encoder
    }
}

@CashuActor
class CashuRouterDelegate: NetworkRouterDelegate {
    private let maxRetries = 3
    private let baseDelay: TimeInterval = 0.2
    private let rateLimiter = EndpointRateLimiter(defaultConfiguration: .default)

    func shouldRetry(error: any Error, attempts: Int) async throws -> Bool {
        // Simple exponential backoff for transient network errors
        guard attempts < maxRetries else { return false }

        if let urlError = error as? URLError {
            switch urlError.code {
            case .timedOut, .cannotFindHost, .cannotConnectToHost, .networkConnectionLost, .dnsLookupFailed, .notConnectedToInternet:
                try await Task.sleep(nanoseconds: UInt64((baseDelay * pow(2.0, Double(attempts))) * 1_000_000_000))
                return true
            default:
                return false
            }
        }

        return false
    }

    func intercept(_ request: inout URLRequest) async {
        // Basic rate limiting per endpoint path
        let path = request.url?.path ?? ""
        _ = await rateLimiter.shouldAllowRequest(for: path)
        await rateLimiter.recordRequest(for: path)
    }
}
