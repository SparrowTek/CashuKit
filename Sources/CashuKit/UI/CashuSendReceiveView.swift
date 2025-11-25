//
//  CashuSendReceiveView.swift
//  CashuKit
//
//  SwiftUI view for sending and receiving Cashu tokens
//

import SwiftUI
import CoreCashu
import CoreImage.CIFilterBuiltins

/// SwiftUI view for sending and receiving tokens
public struct CashuSendReceiveView: View {
    @ObservedObject private var wallet: AppleCashuWallet
    @State private var selectedTab: Tab = .send
    @State private var amount: String = ""
    @State private var memo: String = ""
    @State private var tokenToReceive: String = ""
    @State private var generatedToken: String = ""
    @State private var showingQRCode = false
    @State private var showingScanner = false
    @State private var showingError = false
    @State private var errorMessage = ""
    
    private enum Tab {
        case send
        case receive
    }
    
    public init(wallet: AppleCashuWallet) {
        self.wallet = wallet
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Tab selector
            Picker("Transaction type", selection: $selectedTab) {
                Text("Send").tag(Tab.send)
                Text("Receive").tag(Tab.receive)
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding()
            .accessibilityLabel("Select transaction type")

            ScrollView {
                VStack(spacing: 20) {
                    switch selectedTab {
                    case .send:
                        sendView
                    case .receive:
                        receiveView
                    }
                }
                .padding()
            }
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
        .sheet(isPresented: $showingQRCode) {
            QRCodeView(data: generatedToken)
        }
    }
    
    // MARK: - Send View
    
    @ViewBuilder
    private var sendView: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Amount input
            VStack(alignment: .leading, spacing: 8) {
                Text("Amount (sats)")
                    .font(.caption)
                    .foregroundColor(.secondary)

                TextField("0", text: $amount)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .accessibilityLabel("Amount to send in satoshis")
                    .accessibilityHint("Enter the number of satoshis to send")
                    #if os(iOS)
                    .keyboardType(.numberPad)
                    #endif
            }

            // Memo input
            VStack(alignment: .leading, spacing: 8) {
                Text("Memo (optional)")
                    .font(.caption)
                    .foregroundColor(.secondary)

                TextField("What's this for?", text: $memo)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .accessibilityLabel("Memo")
                    .accessibilityHint("Optional description for this transaction")
            }

            // Available balance
            HStack {
                Text("Available:")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text("\(wallet.balance) sats")
                    .font(.caption)
                    .fontWeight(.medium)

                Spacer()
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Available balance: \(wallet.balance) satoshis")

            // Send button
            Button(action: sendTokens) {
                HStack {
                    if wallet.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                            .scaleEffect(0.8)
                            .accessibilityLabel("Loading")
                    } else {
                        Image(systemName: "paperplane.fill")
                            .accessibilityHidden(true)
                    }

                    Text("Generate Token")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(sendButtonDisabled ? Color.gray : Color.accentColor)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .disabled(sendButtonDisabled)
            .accessibilityLabel("Generate token")
            .accessibilityHint(sendButtonDisabled ? "Enter a valid amount to enable" : "Tap to generate a Cashu token for the entered amount")

            // Generated token display
            if !generatedToken.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Token Generated")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Spacer()

                        Button(action: { showingQRCode = true }) {
                            Image(systemName: "qrcode")
                                .foregroundColor(.accentColor)
                        }
                        .accessibilityLabel("Show QR code")
                        .accessibilityHint("Display the token as a QR code")
                    }

                    Text(generatedToken)
                        .font(.system(.caption, design: .monospaced))
                        .padding()
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(8)
                        .onTapGesture {
                            copyToClipboard(generatedToken)
                        }
                        .accessibilityLabel("Generated Cashu token")
                        .accessibilityHint("Tap to copy to clipboard")

                    Button(action: { copyToClipboard(generatedToken) }) {
                        Label("Copy to Clipboard", systemImage: "doc.on.doc")
                            .font(.caption)
                    }
                    .accessibilityLabel("Copy token to clipboard")
                }
                .accessibilityElement(children: .contain)
            }
        }
    }
    
    // MARK: - Receive View
    
    @ViewBuilder
    private var receiveView: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Token input
            VStack(alignment: .leading, spacing: 8) {
                Text("Cashu Token")
                    .font(.caption)
                    .foregroundColor(.secondary)

                TextEditor(text: $tokenToReceive)
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 100)
                    .padding(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                    )
                    .accessibilityLabel("Token input field")
                    .accessibilityHint("Paste or enter a Cashu token to receive")
            }

            // Scan QR button
            Button(action: { showingScanner = true }) {
                Label("Scan QR Code", systemImage: "qrcode.viewfinder")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(12)
            }
            .accessibilityLabel("Scan QR code")
            .accessibilityHint("Open camera to scan a Cashu token QR code")

            // Receive button
            Button(action: receiveTokens) {
                HStack {
                    if wallet.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                            .scaleEffect(0.8)
                            .accessibilityLabel("Loading")
                    } else {
                        Image(systemName: "arrow.down.circle.fill")
                            .accessibilityHidden(true)
                    }

                    Text("Receive Token")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(tokenToReceive.isEmpty ? Color.gray : Color.accentColor)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .disabled(tokenToReceive.isEmpty || wallet.isLoading)
            .accessibilityLabel("Receive token")
            .accessibilityHint(tokenToReceive.isEmpty ? "Enter a token first to enable" : "Tap to receive the entered Cashu token")
        }
    }
    
    // MARK: - Helper Methods
    
    private var sendButtonDisabled: Bool {
        guard let amountInt = Int(amount), amountInt > 0 else { return true }
        return amountInt > wallet.balance || wallet.isLoading
    }
    
    private func sendTokens() {
        guard let amountInt = Int(amount), amountInt > 0 else {
            showError("Please enter a valid amount")
            return
        }
        
        Task {
            do {
                let token = try await wallet.send(
                    amount: amountInt,
                    memo: memo.isEmpty ? nil : memo
                )
                
                await MainActor.run {
                    // Convert token to string representation
                    if let tokenData = try? JSONEncoder().encode(token),
                       let tokenString = String(data: tokenData, encoding: .utf8) {
                        generatedToken = "cashu" + tokenString.data(using: .utf8)!.base64EncodedString()
                    }
                    amount = ""
                    memo = ""
                }
            } catch {
                await MainActor.run {
                    showError(error.localizedDescription)
                }
            }
        }
    }
    
    private func receiveTokens() {
        guard !tokenToReceive.isEmpty else {
            showError("Please enter a token")
            return
        }
        
        Task {
            do {
                let _ = try await wallet.receive(token: tokenToReceive)
                
                await MainActor.run {
                    tokenToReceive = ""
                    // Could show success message
                }
            } catch {
                await MainActor.run {
                    showError(error.localizedDescription)
                }
            }
        }
    }
    
    private func copyToClipboard(_ text: String) {
        #if os(iOS)
        UIPasteboard.general.string = text
        #elseif os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        #endif
    }
    
    private func showError(_ message: String) {
        errorMessage = message
        showingError = true
    }
}

// MARK: - QR Code View

struct QRCodeView: View {
    let data: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                if let qrImage = generateQRCode(from: data) {
                    #if os(iOS)
                    Image(uiImage: qrImage)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 250, height: 250)
                        .padding()
                        .background(Color.white)
                        .cornerRadius(12)
                        .accessibilityLabel("QR code for Cashu token")
                        .accessibilityHint("Scan this QR code with another device to receive the token")
                    #else
                    Image(nsImage: qrImage)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 250, height: 250)
                        .padding()
                        .background(Color.white)
                        .cornerRadius(12)
                        .accessibilityLabel("QR code for Cashu token")
                        .accessibilityHint("Scan this QR code with another device to receive the token")
                    #endif
                } else {
                    Text("Failed to generate QR code")
                        .foregroundColor(.secondary)
                        .accessibilityLabel("Error: Failed to generate QR code")
                }

                Text("Scan this code to receive the token")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding()
            .navigationTitle("QR Code")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button("Done") {
                        dismiss()
                    }
                    .accessibilityLabel("Close QR code view")
                }
            }
        }
    }
    
    private func generateQRCode(from string: String) -> PlatformImage? {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        
        filter.message = Data(string.utf8)
        
        if let outputImage = filter.outputImage {
            let transform = CGAffineTransform(scaleX: 10, y: 10)
            let scaledImage = outputImage.transformed(by: transform)
            
            if let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) {
                #if os(iOS)
                return UIImage(cgImage: cgImage)
                #else
                return NSImage(cgImage: cgImage, size: NSSize(width: 250, height: 250))
                #endif
            }
        }
        
        return nil
    }
}

// MARK: - Preview Helpers

#if os(iOS)
import UIKit
typealias PlatformImage = UIImage
#elseif os(macOS)
import AppKit
typealias PlatformImage = NSImage
#endif