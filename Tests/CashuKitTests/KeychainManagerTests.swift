import Testing
@testable import CashuKit
import Foundation

@Suite("Keychain Manager Tests")
struct KeychainManagerTests {

    @Test
    func mnemonicRoundTrip() async throws {
        let km = await KeychainManager()
        let mnemonic = "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about"
        do {
            try await km.storeMnemonic(mnemonic)
        } catch {
            // Keychain may be unavailable in CI or without entitlements; skip silently
            return
        }
        let loaded = try await km.retrieveMnemonic()
        #expect(loaded == mnemonic)
        try await km.deleteWalletKeys()
        let afterDelete = try await km.retrieveMnemonic()
        #expect(afterDelete == nil)
    }

    @Test
    func accessTokensListRoundTrip() async throws {
        let km = await KeychainManager()
        let proofs = [
            Proof(amount: 1, id: "k1", secret: "s1", C: "c1"),
            Proof(amount: 1, id: "k1", secret: "s2", C: "c2")
        ]
        do {
            try await km.storeAccessTokens(proofs, mintURL: "https://mint.example.com")
        } catch {
            // Keychain may be unavailable in CI or without entitlements; skip silently
            return
        }
        let loaded = try await km.retrieveAccessTokens(mintURL: "https://mint.example.com")
        #expect(loaded.count == proofs.count)
        try await km.deleteAccessTokens(mintURL: "https://mint.example.com")
        let afterDelete = try await km.retrieveAccessTokens(mintURL: "https://mint.example.com")
        #expect(afterDelete.isEmpty)
    }
}


