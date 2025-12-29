/// # Backup and Restore
///
/// This example demonstrates wallet backup using BIP39 mnemonics and
/// restoration from seed phrases.

import CashuKit
import Foundation

// MARK: - Generating Backup

/// Generate a mnemonic for wallet backup
func generateBackup(wallet: AppleCashuWallet) async throws -> String {
    // Authenticate user before showing sensitive data
    let bioManager = BiometricAuthManager.shared
    
    if await bioManager.isAvailable {
        try await bioManager.authenticateUser(
            reason: "Authenticate to view recovery phrase"
        )
    }
    
    // Generate mnemonic (if wallet doesn't have one)
    let mnemonic = try await wallet.generateMnemonic()
    
    print("=== WALLET BACKUP ===")
    print("\nWrite down these 12 words in order:")
    print("(Store offline, never share or screenshot)")
    print("")
    
    let words = mnemonic.split(separator: " ")
    for (index, word) in words.enumerated() {
        print("\(String(format: "%2d", index + 1)). \(word)")
    }
    
    print("\n=====================")
    
    return mnemonic
}

// MARK: - Displaying Existing Backup

/// Display the wallet's existing mnemonic
func showExistingBackup(wallet: AppleCashuWallet) async throws {
    // Require biometric authentication
    let bioManager = BiometricAuthManager.shared
    await bioManager.checkBiometricAvailability()
    
    if await bioManager.isAvailable {
        try await bioManager.authenticateUser(
            reason: "Authenticate to view recovery phrase"
        )
    }
    
    // Get stored mnemonic
    guard let mnemonic = try await wallet.getMnemonic() else {
        print("No mnemonic stored - this wallet may not be recoverable")
        return
    }
    
    print("Your recovery phrase:")
    print(mnemonic)
    print("\nWord count: \(mnemonic.split(separator: " ").count)")
}

// MARK: - Restoring Wallet

/// Restore a wallet from a mnemonic phrase
func restoreWallet(mnemonic: String, mintURL: URL) async throws -> AppleCashuWallet {
    // Validate mnemonic format
    let words = mnemonic.lowercased().split(separator: " ")
    guard [12, 15, 18, 21, 24].contains(words.count) else {
        throw CashuError.invalidMnemonic
    }
    
    print("Restoring wallet from \(words.count)-word mnemonic...")
    
    // Create new wallet
    let wallet = await AppleCashuWallet()
    
    // Connect to mint
    try await wallet.connect(to: mintURL)
    
    // Restore from mnemonic
    try await wallet.restore(mnemonic: mnemonic)
    
    print("Wallet restored!")
    print("Scanning mint for your tokens...")
    
    // The restore process scans for proofs
    let balance = await wallet.balance
    print("Recovered balance: \(balance) sats")
    
    return wallet
}

// MARK: - SwiftUI Backup Flow

/*
import SwiftUI

struct BackupView: View {
    @ObservedObject var wallet: AppleCashuWallet
    @State private var mnemonic: String?
    @State private var showMnemonic = false
    @State private var copiedConfirmation = false
    
    var body: some View {
        VStack(spacing: 20) {
            if let mnemonic = mnemonic, showMnemonic {
                // Show mnemonic words
                VStack(alignment: .leading, spacing: 8) {
                    let words = mnemonic.split(separator: " ")
                    ForEach(Array(words.enumerated()), id: \.offset) { index, word in
                        HStack {
                            Text("\(index + 1).")
                                .frame(width: 30, alignment: .trailing)
                                .foregroundStyle(.secondary)
                            Text(String(word))
                                .fontWeight(.medium)
                        }
                    }
                }
                .padding()
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                
                Button("Hide Recovery Phrase") {
                    showMnemonic = false
                }
                .buttonStyle(.bordered)
                
            } else {
                // Show backup button
                Image(systemName: "key.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.blue)
                
                Text("Backup Your Wallet")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Your recovery phrase is the only way to restore your wallet if you lose access to this device.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                
                Button("View Recovery Phrase") {
                    Task {
                        do {
                            mnemonic = try await wallet.getMnemonic()
                            showMnemonic = true
                        } catch {
                            // Handle error
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .navigationTitle("Backup")
    }
}

struct RestoreView: View {
    @State private var mnemonicInput = ""
    @State private var isRestoring = false
    @State private var error: String?
    
    let onRestore: (String) async throws -> Void
    
    var body: some View {
        Form {
            Section {
                TextEditor(text: $mnemonicInput)
                    .frame(minHeight: 100)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
            } header: {
                Text("Recovery Phrase")
            } footer: {
                Text("Enter your 12 or 24 word recovery phrase, separated by spaces.")
            }
            
            if let error = error {
                Section {
                    Text(error)
                        .foregroundStyle(.red)
                }
            }
            
            Section {
                Button {
                    Task {
                        isRestoring = true
                        error = nil
                        do {
                            try await onRestore(mnemonicInput)
                        } catch {
                            self.error = error.localizedDescription
                        }
                        isRestoring = false
                    }
                } label: {
                    if isRestoring {
                        ProgressView()
                    } else {
                        Text("Restore Wallet")
                    }
                }
                .disabled(mnemonicInput.isEmpty || isRestoring)
            }
        }
        .navigationTitle("Restore Wallet")
    }
}
*/

// MARK: - Validation Helpers

/// Validate a mnemonic before attempting restore
func validateMnemonic(_ mnemonic: String) -> (valid: Bool, error: String?) {
    let words = mnemonic.lowercased()
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .split(separator: " ")
        .map(String.init)
    
    // Check word count
    guard [12, 15, 18, 21, 24].contains(words.count) else {
        return (false, "Invalid word count: \(words.count). Expected 12, 15, 18, 21, or 24 words.")
    }
    
    // Note: CashuKit/CoreCashu performs full BIP39 validation internally
    // including wordlist check and checksum verification
    
    return (true, nil)
}

// MARK: - Multi-Mint Restoration

/// Restore wallet across multiple mints
func restoreFromMultipleMints(
    mnemonic: String,
    mintURLs: [URL]
) async throws -> Int {
    print("Restoring from \(mintURLs.count) mints...")
    
    var totalBalance = 0
    
    for mintURL in mintURLs {
        print("\nScanning: \(mintURL.host ?? mintURL.absoluteString)")
        
        let wallet = await AppleCashuWallet()
        
        do {
            try await wallet.connect(to: mintURL)
            try await wallet.restore(mnemonic: mnemonic)
            
            let balance = await wallet.balance
            totalBalance += balance
            
            if balance > 0 {
                print("  Found: \(balance) sats")
            } else {
                print("  No tokens found")
            }
        } catch {
            print("  Failed: \(error.localizedDescription)")
        }
    }
    
    print("\n======================")
    print("Total recovered: \(totalBalance) sats")
    
    return totalBalance
}
