@preconcurrency import Foundation


@CashuActor
protocol Networking {
    func data(for request: URLRequest, delegate: (any URLSessionTaskDelegate)?) async throws -> (Data, URLResponse)
}

extension URLSession: Networking { }
