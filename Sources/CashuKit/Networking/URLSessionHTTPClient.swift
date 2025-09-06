import Foundation
import CoreCashu

/// Apple platform HTTP client backed by URLSession.
public struct URLSessionHTTPClient: HTTPClientProtocol, @unchecked Sendable {
    private let session: URLSession
    
    public init(configuration: URLSessionConfiguration = .default, delegate: (any URLSessionDelegate)? = nil) {
        self.session = URLSession(configuration: configuration, delegate: delegate, delegateQueue: nil)
    }
    
    public func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        try await session.data(for: request)
    }
}

