//
//  ParameterEncoding.swift
//  CashuKit
//
//  Created by Thomas Rademaker on 6/27/25.
//

import Foundation

typealias Parameters = [URLQueryItem]

protocol ParameterEncoder {
    func encode(urlRequest: inout URLRequest, with parameters: Parameters) throws
}

@CashuActor
enum ParameterEncoding: Sendable {
    
    case urlEncoding(parameters: Parameters)
    case jsonEncoding(parameters: Parameters)
    case jsonDataEncoding(data: Data?)
    case jsonEncodableEncoding(encodable: any CashuEncodable)
    case urlAndJsonEncoding(urlParameters: Parameters, bodyParameters: Parameters)
    
    func encode(urlRequest: inout URLRequest) throws {
        do {
            switch self {
            case .urlEncoding(let parameters):
                try URLParameterEncoder().encode(urlRequest: &urlRequest, with: parameters)
            case .jsonEncoding(let parameters):
                try JSONParameterEncoder().encode(urlRequest: &urlRequest, with: parameters)
            case .jsonDataEncoding(let data):
                JSONParameterEncoder().encode(urlRequest: &urlRequest, with: data)
            case .jsonEncodableEncoding(let encodable):
                try JSONParameterEncoder().encode(urlRequest: &urlRequest, with: encodable)
            case .urlAndJsonEncoding(let urlParameters, let bodyParameters):
                try URLParameterEncoder().encode(urlRequest: &urlRequest, with: urlParameters)
                try JSONParameterEncoder().encode(urlRequest: &urlRequest, with: bodyParameters)
            }
        } catch {
            throw NetworkError.encodingFailed
        }
    }
}
