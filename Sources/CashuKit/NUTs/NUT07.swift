//
//  NUT07.swift
//  CashuKit
//
//  NUT-07: Token state check
//  https://github.com/cashubtc/nuts/blob/main/07.md
//

import Foundation

// MARK: - NUT-07: Token state check

/// NUT-07: Token state check
/// Allows wallets to check the state of specific proofs (UNSPENT, PENDING, SPENT)

// MARK: - Token States

/// The possible states of a proof
public enum ProofState: String, CashuCodabale, CaseIterable, Sendable {
    case unspent = "UNSPENT"
    case pending = "PENDING" 
    case spent = "SPENT"
    
    /// Check if the proof is available for spending
    public var isSpendable: Bool {
        return self == .unspent
    }
    
    /// Check if the proof is being processed
    public var isInTransaction: Bool {
        return self == .pending
    }
    
    /// Check if the proof has been redeemed
    public var isRedeemed: Bool {
        return self == .spent
    }
}

// MARK: - Request Models

/// Request to check the state of proofs
public struct PostCheckStateRequest: CashuCodabale {
    public let Ys: [String]
    
    public init(Ys: [String]) {
        self.Ys = Ys
    }
    
    /// Create request from array of proofs
    public init(proofs: [Proof]) throws {
        self.Ys = try proofs.map { try $0.calculateY() }
    }
    
    /// Create request from single proof
    public init(proof: Proof) throws {
        self.Ys = [try proof.calculateY()]
    }
}

// MARK: - Response Models

/// State information for a single proof
public struct ProofStateInfo: CashuCodabale {
    public let Y: String
    public let state: ProofState
    public let witness: String?
    
    public init(Y: String, state: ProofState, witness: String? = nil) {
        self.Y = Y
        self.state = state
        self.witness = witness
    }
    
    /// Check if this proof state has witness data
    public var hasWitness: Bool {
        return witness != nil && !(witness?.isEmpty ?? true)
    }
    
    /// Parse witness data if available
    public func parseWitness<T: Codable>(_ type: T.Type) throws -> T? {
        guard let witnessString = witness,
              let witnessData = witnessString.data(using: .utf8) else {
            return nil
        }
        
        return try JSONDecoder().decode(type, from: witnessData)
    }
}

/// Response containing state information for checked proofs
public struct PostCheckStateResponse: CashuCodabale {
    public let states: [ProofStateInfo]
    
    public init(states: [ProofStateInfo]) {
        self.states = states
    }
    
    /// Get state for specific Y value
    public func getState(for Y: String) -> ProofStateInfo? {
        return states.first { $0.Y == Y }
    }
    
    /// Get all states by their status
    public func getStatesByStatus(_ status: ProofState) -> [ProofStateInfo] {
        return states.filter { $0.state == status }
    }
    
    /// Get count of proofs in each state
    public var stateSummary: [ProofState: Int] {
        var summary: [ProofState: Int] = [:]
        for state in ProofState.allCases {
            summary[state] = states.filter { $0.state == state }.count
        }
        return summary
    }
    
    /// Check if all proofs are in the same state
    public func allProofsInState(_ state: ProofState) -> Bool {
        return states.allSatisfy { $0.state == state }
    }
    
    /// Get proofs that are spendable
    public var spendableProofs: [ProofStateInfo] {
        return getStatesByStatus(.unspent)
    }
    
    /// Get proofs that are spent
    public var spentProofs: [ProofStateInfo] {
        return getStatesByStatus(.spent)
    }
    
    /// Get proofs that are pending
    public var pendingProofs: [ProofStateInfo] {
        return getStatesByStatus(.pending)
    }
}

// MARK: - Proof Extensions

extension Proof {
    /// Calculate Y = hash_to_curve(secret) for this proof
    /// This is the Y value used in checkstate requests
    public func calculateY() throws -> String {
        let secretPoint = try hashToCurve(self.secret)
        return secretPoint.dataRepresentation.hexString
    }
    
    /// Check if this proof matches a given Y value
    public func matchesY(_ Y: String) throws -> Bool {
        let calculatedY = try calculateY()
        return calculatedY.lowercased() == Y.lowercased()
    }
}

// MARK: - Convenience Types

/// Result of a state check operation
public struct StateCheckResult: Sendable {
    public let proof: Proof
    public let stateInfo: ProofStateInfo
    
    public init(proof: Proof, stateInfo: ProofStateInfo) {
        self.proof = proof
        self.stateInfo = stateInfo
    }
    
    /// Quick access to the proof state
    public var state: ProofState {
        return stateInfo.state
    }
    
    /// Check if this proof can be spent
    public var isSpendable: Bool {
        return state.isSpendable
    }
    
    /// Check if this proof is being processed
    public var isInTransaction: Bool {
        return state.isInTransaction
    }
    
    /// Check if this proof has been redeemed
    public var isRedeemed: Bool {
        return state.isRedeemed
    }
}

/// Batch result for multiple state checks
public struct BatchStateCheckResult: Sendable {
    public let results: [StateCheckResult]
    
    public init(results: [StateCheckResult]) {
        self.results = results
    }
    
    /// Get results by state
    public func getResults(withState state: ProofState) -> [StateCheckResult] {
        return results.filter { $0.state == state }
    }
    
    /// Get spendable proofs
    public var spendableProofs: [Proof] {
        return getResults(withState: .unspent).map { $0.proof }
    }
    
    /// Get spent proofs
    public var spentProofs: [Proof] {
        return getResults(withState: .spent).map { $0.proof }
    }
    
    /// Get pending proofs
    public var pendingProofs: [Proof] {
        return getResults(withState: .pending).map { $0.proof }
    }
    
    /// Get summary of results
    public var summary: [ProofState: Int] {
        var summary: [ProofState: Int] = [:]
        for state in ProofState.allCases {
            summary[state] = getResults(withState: state).count
        }
        return summary
    }
}

// MARK: - Error Types

/// Errors specific to NUT-07 operations
public enum NUT07Error: Error, LocalizedError, Sendable {
    case invalidYValue(String)
    case proofYMismatch(expected: String, actual: String)
    case stateCheckFailed(String)
    case invalidWitnessData(String)
    
    public var errorDescription: String? {
        switch self {
        case .invalidYValue(let y):
            return "Invalid Y value: \(y)"
        case .proofYMismatch(let expected, let actual):
            return "Proof Y mismatch - expected: \(expected), actual: \(actual)"
        case .stateCheckFailed(let reason):
            return "State check failed: \(reason)"
        case .invalidWitnessData(let reason):
            return "Invalid witness data: \(reason)"
        }
    }
}