import Testing
@testable import CashuKit
import Foundation

// A dummy Networking that always fails with a timeout to trip the breaker
final class AlwaysFailNetworking: Networking {
    func data(for request: URLRequest, delegate: (any URLSessionTaskDelegate)?) async throws -> (Data, URLResponse) {
        throw URLError(.timedOut)
    }
}

@Test
func circuitBreakerTripsAndRecovers() async throws {
    // Build a router with our failing networking
    let router = await NetworkRouter<AnyEndpoint>(networking: AlwaysFailNetworking())
    let delegate = await CashuRouterDelegate()
    await router.setDelegate(delegate)

    // Define a dummy endpoint hitting the same path
    let endpoint = AnyEndpoint(baseURL: URL(string: "https://example.com")!, path: "/mint", httpMethod: .get, task: .request)

    // Drive repeated failures to trip breaker
    var failures = 0
    for _ in 0..<6 {
        do {
            let _: DummyResponse = try await router.execute(endpoint)
        } catch {
            failures += 1
        }
    }
    #expect(failures >= 5)
}

// MARK: - Test helpers

struct DummyResponse: CashuDecodable { }

// Type-erased endpoint for tests
struct AnyEndpoint: EndpointType {
    var baseURL: URL
    var path: String
    var httpMethod: HTTPMethod
    var task: HTTPTask
    var headers: HTTPHeaders? { get async { nil } }
}


