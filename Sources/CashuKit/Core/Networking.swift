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
    func shouldRetry(error: any Error, attempts: Int) async throws -> Bool {
        false
    }
    
    func intercept(_ request: inout URLRequest) async {
        // no-op
    }
}
