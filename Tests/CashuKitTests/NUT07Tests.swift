//
//  NUT07Tests.swift
//  CashuKit
//
//  Tests for NUT-07: Token state check
//

import Testing
import Foundation
@testable import CashuKit

@Suite("NUT07 tests")
struct NUT07Tests {
    
    // MARK: - ProofState Tests
    
    @Test
    func proofStateProperties() {
        #expect(ProofState.unspent.isSpendable)
        #expect(!ProofState.pending.isSpendable)
        #expect(!ProofState.spent.isSpendable)
        
        #expect(!ProofState.unspent.isInTransaction)
        #expect(ProofState.pending.isInTransaction)
        #expect(!ProofState.spent.isInTransaction)
        
        #expect(!ProofState.unspent.isRedeemed)
        #expect(!ProofState.pending.isRedeemed)
        #expect(ProofState.spent.isRedeemed)
    }
    
    // MARK: - PostCheckStateRequest Tests
    
    @Test
    func postCheckStateRequestCreation() throws {
        let yValues = [
            "02599b9ea0a1ad4143706c2a5a4a568ce442dd4313e1cf1f7f0b58a317c1a355ee",
            "03a1b2c3d4e5f6789abcdef0123456789abcdef0123456789abcdef0123456789a"
        ]
        
        let request = PostCheckStateRequest(Ys: yValues)
        #expect(request.Ys.count == 2)
        #expect(request.Ys[0] == yValues[0])
        #expect(request.Ys[1] == yValues[1])
    }
    
    @Test
    func postCheckStateRequestFromProofs() throws {
        let proof1 = Proof(amount: 64, id: "keyset123", secret: "secret1", C: "signature1")
        let proof2 = Proof(amount: 32, id: "keyset123", secret: "secret2", C: "signature2")
        
        let request = try PostCheckStateRequest(proofs: [proof1, proof2])
        #expect(request.Ys.count == 2)
        
        // Verify Y values match the proofs
        let y1 = try proof1.calculateY()
        let y2 = try proof2.calculateY()
        #expect(request.Ys.contains(y1))
        #expect(request.Ys.contains(y2))
    }
    
    @Test
    func postCheckStateRequestFromSingleProof() throws {
        let proof = Proof(amount: 64, id: "keyset123", secret: "testsecret", C: "signature1")
        
        let request = try PostCheckStateRequest(proof: proof)
        #expect(request.Ys.count == 1)
        
        let expectedY = try proof.calculateY()
        #expect(request.Ys[0] == expectedY)
    }
    
    // MARK: - ProofStateInfo Tests
    
    @Test
    func proofStateInfoCreation() {
        let stateInfo = ProofStateInfo(
            Y: "02599b9ea0a1ad4143706c2a5a4a568ce442dd4313e1cf1f7f0b58a317c1a355ee",
            state: .spent,
            witness: "{\"signatures\": [\"test\"]}"
        )
        
        #expect(stateInfo.Y == "02599b9ea0a1ad4143706c2a5a4a568ce442dd4313e1cf1f7f0b58a317c1a355ee")
        #expect(stateInfo.state == .spent)
        #expect(stateInfo.hasWitness)
        #expect(stateInfo.witness == "{\"signatures\": [\"test\"]}")
    }
    
    @Test
    func proofStateInfoWithoutWitness() {
        let stateInfo = ProofStateInfo(
            Y: "02599b9ea0a1ad4143706c2a5a4a568ce442dd4313e1cf1f7f0b58a317c1a355ee",
            state: .unspent
        )
        
        #expect(!stateInfo.hasWitness)
        #expect(stateInfo.witness == nil)
    }
    
    // MARK: - PostCheckStateResponse Tests
    
    @Test
    func postCheckStateResponseAnalysis() {
        let states = [
            ProofStateInfo(Y: "Y1", state: .unspent),
            ProofStateInfo(Y: "Y2", state: .spent),
            ProofStateInfo(Y: "Y3", state: .pending),
            ProofStateInfo(Y: "Y4", state: .unspent)
        ]
        
        let response = PostCheckStateResponse(states: states)
        
        #expect(response.states.count == 4)
        #expect(response.spendableProofs.count == 2)
        #expect(response.spentProofs.count == 1)
        #expect(response.pendingProofs.count == 1)
        
        let summary = response.stateSummary
        #expect(summary[.unspent] == 2)
        #expect(summary[.spent] == 1)
        #expect(summary[.pending] == 1)
        
        #expect(!response.allProofsInState(.unspent))
        #expect(!response.allProofsInState(.spent))
        #expect(!response.allProofsInState(.pending))
        
        // Test getting state for specific Y
        let stateForY2 = response.getState(for: "Y2")
        #expect(stateForY2?.state == .spent)
        
        let stateForNonExistent = response.getState(for: "YNonExistent")
        #expect(stateForNonExistent == nil)
    }
    
    @Test
    func postCheckStateResponseAllSameState() {
        let states = [
            ProofStateInfo(Y: "Y1", state: .spent),
            ProofStateInfo(Y: "Y2", state: .spent),
            ProofStateInfo(Y: "Y3", state: .spent)
        ]
        
        let response = PostCheckStateResponse(states: states)
        #expect(response.allProofsInState(.spent))
        #expect(!response.allProofsInState(.unspent))
        #expect(!response.allProofsInState(.pending))
    }
    
    // MARK: - Proof Extension Tests
    
    @Test
    func proofYCalculation() throws {
        let proof = Proof(amount: 64, id: "keyset123", secret: "testsecret", C: "signature1")
        
        let y = try proof.calculateY()
        #expect(!y.isEmpty)
        #expect(y.count == 66) // 33 bytes * 2 hex chars = 66 characters
        #expect(y.hasPrefix("02") || y.hasPrefix("03")) // Compressed public key format
        
        // Test that same secret produces same Y
        let proof2 = Proof(amount: 32, id: "keyset456", secret: "testsecret", C: "signature2")
        let y2 = try proof2.calculateY()
        #expect(y == y2) // Same secret should produce same Y regardless of other fields
    }
    
    @Test
    func proofYMatching() throws {
        let proof = Proof(amount: 64, id: "keyset123", secret: "testsecret", C: "signature1")
        let y = try proof.calculateY()
        
        #expect(try proof.matchesY(y))
        #expect(try proof.matchesY(y.uppercased()))
        #expect(try proof.matchesY(y.lowercased()))
        #expect(try !proof.matchesY("invalid_y_value"))
    }
    
    // MARK: - StateCheckResult Tests
    
    @Test
    func stateCheckResultProperties() {
        let proof = Proof(amount: 64, id: "keyset123", secret: "testsecret", C: "signature1")
        let stateInfo = ProofStateInfo(Y: "Y1", state: .unspent)
        
        let result = StateCheckResult(proof: proof, stateInfo: stateInfo)
        
        #expect(result.state == .unspent)
        #expect(result.isSpendable)
        #expect(!result.isInTransaction)
        #expect(!result.isRedeemed)
        
        // Test different states
        let spentStateInfo = ProofStateInfo(Y: "Y1", state: .spent)
        let spentResult = StateCheckResult(proof: proof, stateInfo: spentStateInfo)
        
        #expect(spentResult.state == .spent)
        #expect(!spentResult.isSpendable)
        #expect(!spentResult.isInTransaction)
        #expect(spentResult.isRedeemed)
        
        let pendingStateInfo = ProofStateInfo(Y: "Y1", state: .pending)
        let pendingResult = StateCheckResult(proof: proof, stateInfo: pendingStateInfo)
        
        #expect(pendingResult.state == .pending)
        #expect(!pendingResult.isSpendable)
        #expect(pendingResult.isInTransaction)
        #expect(!pendingResult.isRedeemed)
    }
    
    // MARK: - BatchStateCheckResult Tests
    
    @Test
    func batchStateCheckResultAnalysis() {
        let proof1 = Proof(amount: 64, id: "keyset123", secret: "secret1", C: "signature1")
        let proof2 = Proof(amount: 32, id: "keyset123", secret: "secret2", C: "signature2")
        let proof3 = Proof(amount: 16, id: "keyset123", secret: "secret3", C: "signature3")
        
        let results = [
            StateCheckResult(proof: proof1, stateInfo: ProofStateInfo(Y: "Y1", state: .unspent)),
            StateCheckResult(proof: proof2, stateInfo: ProofStateInfo(Y: "Y2", state: .spent)),
            StateCheckResult(proof: proof3, stateInfo: ProofStateInfo(Y: "Y3", state: .pending))
        ]
        
        let batchResult = BatchStateCheckResult(results: results)
        
        #expect(batchResult.results.count == 3)
        #expect(batchResult.spendableProofs.count == 1)
        #expect(batchResult.spentProofs.count == 1)
        #expect(batchResult.pendingProofs.count == 1)
        
        #expect(batchResult.spendableProofs[0].amount == 64)
        #expect(batchResult.spentProofs[0].amount == 32)
        #expect(batchResult.pendingProofs[0].amount == 16)
        
        let summary = batchResult.summary
        #expect(summary[.unspent] == 1)
        #expect(summary[.spent] == 1)
        #expect(summary[.pending] == 1)
        
        // Test filtering by state
        let unspentResults = batchResult.getResults(withState: .unspent)
        #expect(unspentResults.count == 1)
        #expect(unspentResults[0].proof.amount == 64)
    }
    
    // MARK: - Error Tests
    
    @Test
    func nut07Errors() {
        let invalidYError = NUT07Error.invalidYValue("invalid_y")
        #expect(invalidYError.localizedDescription.contains("Invalid Y value"))
        
        let mismatchError = NUT07Error.proofYMismatch(expected: "expected", actual: "actual")
        #expect(mismatchError.localizedDescription.contains("Proof Y mismatch"))
        
        let stateCheckError = NUT07Error.stateCheckFailed("reason")
        #expect(stateCheckError.localizedDescription.contains("State check failed"))
        
        let witnessError = NUT07Error.invalidWitnessData("reason")
        #expect(witnessError.localizedDescription.contains("Invalid witness data"))
    }
    
    // MARK: - Integration Tests
    
    @Test
    func fullWorkflowSimulation() throws {
        // Create some test proofs
        let proofs = [
            Proof(amount: 64, id: "keyset123", secret: "secret1", C: "signature1"),
            Proof(amount: 32, id: "keyset123", secret: "secret2", C: "signature2"),
            Proof(amount: 16, id: "keyset123", secret: "secret3", C: "signature3")
        ]
        
        // Create request
        let request = try PostCheckStateRequest(proofs: proofs)
        #expect(request.Ys.count == 3)
        
        // Simulate response
        let responseStates = [
            ProofStateInfo(Y: request.Ys[0], state: .unspent),
            ProofStateInfo(Y: request.Ys[1], state: .spent, witness: "{\"sig\":\"test\"}"),
            ProofStateInfo(Y: request.Ys[2], state: .pending)
        ]
        let response = PostCheckStateResponse(states: responseStates)
        
        // Verify response matches request order
        #expect(response.states.count == 3)
        for (index, state) in response.states.enumerated() {
            #expect(state.Y == request.Ys[index])
        }
        
        // Create batch result
        var results: [StateCheckResult] = []
        for (index, proof) in proofs.enumerated() {
            let stateInfo = response.states[index]
            results.append(StateCheckResult(proof: proof, stateInfo: stateInfo))
        }
        
        let batchResult = BatchStateCheckResult(results: results)
        
        // Verify analysis
        #expect(batchResult.spendableProofs.count == 1)
        #expect(batchResult.spendableProofs[0].amount == 64)
        
        #expect(batchResult.spentProofs.count == 1)
        #expect(batchResult.spentProofs[0].amount == 32)
        
        #expect(batchResult.pendingProofs.count == 1)
        #expect(batchResult.pendingProofs[0].amount == 16)
    }
    
    // MARK: - Codable Tests
    
    @Test
    func requestResponseCodable() throws {
        // Test request encoding/decoding
        let request = PostCheckStateRequest(Ys: [
            "02599b9ea0a1ad4143706c2a5a4a568ce442dd4313e1cf1f7f0b58a317c1a355ee",
            "03a1b2c3d4e5f6789abcdef0123456789abcdef0123456789abcdef0123456789a"
        ])
        
        let requestData = try JSONEncoder().encode(request)
        let decodedRequest = try JSONDecoder().decode(PostCheckStateRequest.self, from: requestData)
        #expect(decodedRequest.Ys == request.Ys)
        
        // Test response encoding/decoding
        let response = PostCheckStateResponse(states: [
            ProofStateInfo(Y: "Y1", state: .unspent),
            ProofStateInfo(Y: "Y2", state: .spent, witness: "{\"test\":\"data\"}")
        ])
        
        let responseData = try JSONEncoder().encode(response)
        let decodedResponse = try JSONDecoder().decode(PostCheckStateResponse.self, from: responseData)
        #expect(decodedResponse.states.count == 2)
        #expect(decodedResponse.states[0].state == .unspent)
        #expect(decodedResponse.states[1].state == .spent)
        #expect(decodedResponse.states[1].witness == "{\"test\":\"data\"}")
    }
}