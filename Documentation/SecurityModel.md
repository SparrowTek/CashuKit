# CashuKit Security Model and Threat Considerations

## Goals
- Protect user funds (proofs) against loss and theft
- Maintain cryptographic correctness (BDHKE, DLEQ, P2PK, HTLC)
- Avoid leakage of sensitive data in logs and telemetry
- Support secure recovery and rotation

## Assets
- Proofs (amount, id, secret, C)
- Mnemonic and seed (NUT-13 deterministic secrets)
- Ephemeral keys and blinding secrets/factors
- Access tokens (NUT-22), OAuth tokens (NUT-21)

## Storage
- Mnemonic/seed: Keychain via `KeychainManager`
- Ephemeral keys: Keychain; purge on session end when possible
- Access tokens (NUT-22): Deterministic, per-mint list in Keychain
- Proofs: App storage via `ProofStorage` abstraction; default in-memory for SDK consumers

## Logging and Metrics
- Redaction: Logger scrubs long hex, mnemonic/seed/secret/private key patterns, invoices, Authorization headers
- Metrics: Optional sink, no sensitive values; only aggregate counts/durations

## Network Resilience and Safety
- Retry with exponential backoff for transient errors
- Per-endpoint rate limiting
- Circuit breaker per host+path (open/half-open/closed)
- Transaction safety: pending/finalize/rollback semantics ensure no proof loss

## Threat Model
- Malicious mint: Validate signatures, enforce DLEQ proofs, verify HTLC conditions; never trust unverified data
- Compromised device: Store secrets in Keychain; redact logs; avoid printing secrets; consider Secure Enclave if available
- Replay/Double-spend: Track spent and pending-spent proofs; exclude during selection
- MITM/network faults: TLS, endpoint validation, timeouts, retries, breaker

## Recovery
- Restore via mnemonic (NUT-13) and NUT-09 restore signatures where supported
- Document gaps where mint does not support NUT-09

## Hardening Checklist
- [x] Deterministic unblinding and secret handling
- [x] Redacted logging; Authorization header redaction
- [x] Deterministic access token storage per mint
- [x] Circuit breaker and retries
- [x] Transaction rollback/idempotency
- [ ] Optional: Secure Enclave-backed private keys (where available)
- [ ] Optional: At-rest encryption for on-disk proof stores

## Security Review
- Dependency audit before release
- External crypto review for BDHKE/DLEQ/P2PK/HTLC implementations
