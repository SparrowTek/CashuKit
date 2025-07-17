//
//  JSONParameterEncoder.swift
//  CashuKit
//
//  Created by Thomas Rademaker on 6/27/25.
//

import Foundation

struct JSONParameterEncoder: ParameterEncoder {
    func encode(urlRequest: inout URLRequest, with parameters: Parameters) throws {
        do {
            let jsonAsData = try JSONSerialization.data(withJSONObject: parameters, options: .prettyPrinted)
            encode(urlRequest: &urlRequest, with: jsonAsData)
        } catch {
            throw NetworkError.encodingFailed
        }
    }
    
    func encode(urlRequest: inout URLRequest, with encodable: any CashuEncodable) throws {
        do {
            let data = try encodable.toJSONData()
            encode(urlRequest: &urlRequest, with: data)
        } catch {
            throw NetworkError.encodingFailed
        }
    }
    
    func encode(urlRequest: inout URLRequest, with data: Data?) {
        if let data {
            urlRequest.httpBody = data
        }
        
        if urlRequest.value(forHTTPHeaderField: "Content-Type") == nil {
            urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
    }
}
