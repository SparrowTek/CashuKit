import Foundation

public struct WellKnownSecret: Codable, Equatable, Sendable {
    public let kind: String
    public let secretData: SecretData
    
    public struct SecretData: Codable, Equatable, Sendable {
        public let nonce: String
        public let data: String
        public let tags: [[String]]?
        
        public init(nonce: String, data: String, tags: [[String]]? = nil) {
            self.nonce = nonce
            self.data = data
            self.tags = tags
        }
    }
    
    public init(kind: String, secretData: SecretData) {
        self.kind = kind
        self.secretData = secretData
    }
    
    public init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        self.kind = try container.decode(String.self)
        self.secretData = try container.decode(SecretData.self)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(kind)
        try container.encode(secretData)
    }
    
    public func toJSONString() throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let data = try encoder.encode(self)
        guard let string = String(data: data, encoding: .utf8) else {
            throw CashuError.serializationFailed
        }
        return string
    }
    
    public static func fromString(_ string: String) throws -> WellKnownSecret {
        guard let data = string.data(using: .utf8) else {
            throw CashuError.deserializationFailed
        }
        return try JSONDecoder().decode(WellKnownSecret.self, from: data)
    }
}

public extension WellKnownSecret {
    static func generateNonce() -> String {
        return UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased()
    }
}

public enum SpendingConditionKind {
    public static let p2pk = "P2PK"
    public static let htlc = "HTLC"
}