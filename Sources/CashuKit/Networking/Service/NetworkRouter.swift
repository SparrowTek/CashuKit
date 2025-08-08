import Foundation

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

@CashuActor
protocol NetworkRouterDelegate: AnyObject {
    func intercept(_ request: inout URLRequest) async
    func shouldRetry(error: any Error, attempts: Int) async throws -> Bool
    // Circuit breaker hooks
    func breakerRecordSuccess(forKey key: String) async
    func breakerRecordFailure(forKey key: String) async
}

/// Describes the implementation details of a NetworkRouter
///
/// ``NetworkRouter`` is the only implementation of this protocol available to the end user, but they can create their own
/// implementations that can be used for testing for instance.
@CashuActor
protocol NetworkRouterProtocol: AnyObject {
    associatedtype Endpoint: EndpointType
    var delegate: (any NetworkRouterDelegate)? { get set }
    func execute<T: CashuDecodable>(_ route: Endpoint) async throws -> T
}

public enum NetworkError : Error, Sendable {
    case encodingFailed
    case missingURL
    case statusCode(_ statusCode: StatusCode?, data: Data)
    case noStatusCode
    case noData
    case tokenRefresh
    case circuitOpen
}

typealias HTTPHeaders = [String:String]

/// The NetworkRouter is a generic class that has an ``EndpointType`` and it conforms to ``NetworkRouterProtocol`
@CashuActor
internal class NetworkRouter<Endpoint: EndpointType>: NetworkRouterProtocol {
    
    weak var delegate: (any NetworkRouterDelegate)?
    let networking: any Networking
    let urlSessionTaskDelegate: (any URLSessionTaskDelegate)?
    var decoder: JSONDecoder
    
    init(networking: (any Networking)? = nil, urlSessionDelegate: (any URLSessionDelegate)? = nil, urlSessionTaskDelegate: (any URLSessionTaskDelegate)? = nil, decoder: JSONDecoder? = nil) {
        if let networking = networking {
            self.networking = networking
        } else {
            self.networking = URLSession(configuration: URLSessionConfiguration.default, delegate: urlSessionDelegate, delegateQueue: nil)
        }
        
        self.urlSessionTaskDelegate = urlSessionTaskDelegate
        
        if let decoder = decoder {
            self.decoder = decoder
        } else {
            self.decoder = JSONDecoder()
            self.decoder.keyDecodingStrategy = .convertFromSnakeCase
        }
    }
    
    /// This generic method will take a route and return the desired type via a network call
    /// This method is async and it can throw errors
    /// - Returns: The generic type is returned
    func execute<T: CashuDecodable>(_ route: Endpoint) async throws -> T {
        guard var request = try? await buildRequest(from: route) else { throw NetworkError.encodingFailed }

        // Attempt loop with delegate retry and circuit breaker feedback
        var attempts = 0
        var lastError: (any Error)?
        while attempts <= 5 { // hard max attempts
            attempts += 1
            await delegate?.intercept(&request)
            // If circuit breaker denied, short-circuit
            if request.value(forHTTPHeaderField: "X-Cashu-CB-Denied") == "1" {
                lastError = NetworkError.circuitOpen
                // Do not retry when breaker is open
                throw NetworkError.circuitOpen
            }
            do {
                let (data, response) = try await networking.data(for: request, delegate: urlSessionTaskDelegate)
                guard let httpResponse = response as? HTTPURLResponse else { throw NetworkError.noStatusCode }
                switch httpResponse.statusCode {
                case 200...299:
                    // Success path
                    if let url = request.url {
                        let key = url.host.map { $0 + url.path } ?? url.absoluteString
                        await delegate?.breakerRecordSuccess(forKey: key)
                    }
                    return try decoder.decode(T.self, from: data)
                default:
                    // HTTP error
                    let statusCode = StatusCode(rawValue: httpResponse.statusCode)
                    let error = NetworkError.statusCode(statusCode, data: data)
                    lastError = error
                    if let url = request.url {
                        let key = url.host.map { $0 + url.path } ?? url.absoluteString
                        await delegate?.breakerRecordFailure(forKey: key)
                    }
                    let shouldRetry = try await delegate?.shouldRetry(error: error, attempts: attempts) ?? false
                    if !shouldRetry { throw error }
                }
            } catch {
                lastError = error
                if let url = request.url {
                    let key = url.host.map { $0 + url.path } ?? url.absoluteString
                    await delegate?.breakerRecordFailure(forKey: key)
                }
                let shouldRetry = try await delegate?.shouldRetry(error: error, attempts: attempts) ?? false
                if !shouldRetry { throw error }
            }
        }
        throw lastError ?? NetworkError.noData
    }

    // Convenience isolated setter for tests/consumers
    func setDelegate(_ delegate: (any NetworkRouterDelegate)?) {
        self.delegate = delegate
    }
    
    func buildRequest(from route: Endpoint) async throws -> URLRequest {
        
        var request = URLRequest(url: route.baseURL.appendingPathComponent(route.path),
                                       cachePolicy: .reloadIgnoringLocalAndRemoteCacheData,
                                       timeoutInterval: 10.0)
        
        request.httpMethod = route.httpMethod.rawValue
        do {
            switch route.task {
            case .request:
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                await addAdditionalHeaders(route.headers, request: &request)
            case .requestParameters(let parameterEncoding):
                await addAdditionalHeaders(route.headers, request: &request)
                try configureParameters(parameterEncoding: parameterEncoding, request: &request)
            }
            return request
        } catch {
            throw error
        }
    }
    
    private func configureParameters(parameterEncoding: ParameterEncoding, request: inout URLRequest) throws {
        try parameterEncoding.encode(urlRequest: &request)
    }
    
    private func addAdditionalHeaders(_ additionalHeaders: HTTPHeaders?, request: inout URLRequest) {
        guard let headers = additionalHeaders else { return }
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
    }
}
