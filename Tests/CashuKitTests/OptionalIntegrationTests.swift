import Testing
@testable import CashuKit
import Foundation

@Suite("Optional Live Integration Tests")
struct OptionalIntegrationTests {

    // Runs only if CASHUKIT_TEST_MINT is set (e.g., https://mint.example.com)
    @Test
    func liveMintInitializationSmoke() async throws {
        guard let mintURL = ProcessInfo.processInfo.environment["CASHUKIT_TEST_MINT"], !mintURL.isEmpty else {
            // Not configured; skip silently
            return
        }

        let config = WalletConfiguration(mintURL: mintURL, unit: "sat")
        let wallet = await CashuWallet(configuration: config)

        do {
            try await wallet.initialize()
            #expect(await wallet.isReady)
        } catch {
            // If user opted-in to live tests, surface meaningful failure
            #expect(Bool(false), "Live mint initialization failed: \(error)")
        }
    }
}


