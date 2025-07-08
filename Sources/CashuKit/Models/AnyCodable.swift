//
//  AnyCodable.swift
//  CashuKit
//
//  Created by Thomas Rademaker on 7/8/25.
//

/// Simple codable value wrapper for flexible options
public enum AnyCodable: CashuCodabale {
    case int(Int)
    case double(Double)
    case string(String)
    case bool(Bool)
    
    public init<T: Codable>(_ value: T) {
        if let intValue = value as? Int {
            self = .int(intValue)
        } else if let doubleValue = value as? Double {
            self = .double(doubleValue)
        } else if let stringValue = value as? String {
            self = .string(stringValue)
        } else if let boolValue = value as? Bool {
            self = .bool(boolValue)
        } else {
            self = .string(String(describing: value))
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch self {
        case .int(let value):
            try container.encode(value)
        case .double(let value):
            try container.encode(value)
        case .string(let value):
            try container.encode(value)
        case .bool(let value):
            try container.encode(value)
        }
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if let intValue = try? container.decode(Int.self) {
            self = .int(intValue)
        } else if let doubleValue = try? container.decode(Double.self) {
            self = .double(doubleValue)
        } else if let stringValue = try? container.decode(String.self) {
            self = .string(stringValue)
        } else if let boolValue = try? container.decode(Bool.self) {
            self = .bool(boolValue)
        } else {
            throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Unsupported type"))
        }
    }
}
