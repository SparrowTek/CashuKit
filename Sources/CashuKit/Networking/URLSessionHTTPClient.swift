import Foundation
import CoreCashu

/// Apple platform HTTP client backed by URLSession.
///
/// Thread Safety Analysis:
/// - URLSession is documented as thread-safe by Apple
/// - All operations use async/await which properly handles concurrency
/// - The session property is immutable after initialization
/// - @unchecked Sendable is justified as URLSession handles its own synchronization
public struct URLSessionHTTPClient: HTTPClientProtocol, @unchecked Sendable {
    private let session: URLSession
    
    public init(configuration: URLSessionConfiguration = .default, delegate: (any URLSessionDelegate)? = nil) {
        self.session = URLSession(configuration: configuration, delegate: delegate, delegateQueue: nil)
    }
    
    public func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        try await session.data(for: request)
    }
}

