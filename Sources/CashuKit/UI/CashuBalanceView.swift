//
//  CashuBalanceView.swift
//  CashuKit
//
//  SwiftUI view for displaying Cashu wallet balance
//

import SwiftUI
import CoreCashu

/// SwiftUI view for displaying wallet balance
public struct CashuBalanceView: View {
    @ObservedObject private var wallet: AppleCashuWallet
    
    // Customization options
    private let showUnit: Bool
    private let largeFontSize: CGFloat
    private let smallFontSize: CGFloat
    private let accentColor: Color
    
    public init(
        wallet: AppleCashuWallet,
        showUnit: Bool = true,
        largeFontSize: CGFloat = 48,
        smallFontSize: CGFloat = 24,
        accentColor: Color = .orange
    ) {
        self.wallet = wallet
        self.showUnit = showUnit
        self.largeFontSize = largeFontSize
        self.smallFontSize = smallFontSize
        self.accentColor = accentColor
    }
    
    public var body: some View {
        VStack(spacing: 8) {
            // Balance amount
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(formattedBalance)
                    .font(.system(size: largeFontSize, weight: .bold, design: .rounded))
                    .foregroundColor(accentColor)
                    .accessibilityLabel("Balance")
                    .accessibilityValue("\(wallet.balance) satoshis")

                if showUnit {
                    Text("sats")
                        .font(.system(size: smallFontSize, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                        .accessibilityHidden(true)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Wallet balance: \(formattedBalance) satoshis")

            // Bitcoin equivalent (optional)
            if wallet.balance > 0 {
                Text(bitcoinEquivalent)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .accessibilityLabel("Bitcoin equivalent: \(bitcoinEquivalent)")
            }

            // Connection status
            HStack(spacing: 4) {
                Circle()
                    .fill(wallet.isConnected ? Color.green : Color.red)
                    .frame(width: 8, height: 8)
                    .accessibilityHidden(true)

                Text(wallet.isConnected ? "Connected" : "Disconnected")
                    .font(.caption2)
                    .foregroundColor(.secondary)

                if let mintURL = wallet.currentMintURL {
                    Text("•")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .accessibilityHidden(true)

                    Text(mintURL.host ?? "Unknown")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(connectionStatusAccessibilityLabel)
        }
        .padding()
        .accessibilityElement(children: .contain)
    }

    private var connectionStatusAccessibilityLabel: String {
        let status = wallet.isConnected ? "Connected" : "Disconnected"
        if let mintURL = wallet.currentMintURL {
            return "\(status) to \(mintURL.host ?? "unknown mint")"
        }
        return status
    }
    
    // MARK: - Computed Properties
    
    private var formattedBalance: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        formatter.groupingSize = 3
        return formatter.string(from: NSNumber(value: wallet.balance)) ?? "0"
    }
    
    private var bitcoinEquivalent: String {
        let btc = Double(wallet.balance) / 100_000_000
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 8
        formatter.maximumFractionDigits = 8
        let btcString = formatter.string(from: NSNumber(value: btc)) ?? "0"
        return "≈ \(btcString) BTC"
    }
}

// MARK: - Preview

struct CashuBalanceView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            CashuBalanceView(
                wallet: previewWallet()
            )
            .previewDisplayName("Default")
            
            CashuBalanceView(
                wallet: previewWallet(),
                showUnit: false,
                largeFontSize: 36,
                smallFontSize: 18,
                accentColor: .purple
            )
            .previewDisplayName("Custom")
            
            CashuBalanceView(
                wallet: previewWallet()
            )
            .preferredColorScheme(.dark)
            .previewDisplayName("Dark Mode")
        }
        .previewLayout(.sizeThatFits)
    }
    
    static func previewWallet() -> AppleCashuWallet {
        // This would need a proper preview wallet instance
        // For now, returning a placeholder
        Task {
            await AppleCashuWallet()
        }
        fatalError("Preview not fully implemented")
    }
}