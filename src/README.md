# Source Packages

The source tree is intentionally split by responsibility:

- `canonjson`: deterministic JSON serialization.
- `digest`: hash algorithm abstraction and digest comparison.
- `merkle`: Merkle root/proof verification.
- `model`: evidence pack data models.
- `verify`: verification orchestration.
- `diag`: diagnostics and explain output.
- `create`, `store`, `audit`, `crypto`: creation and optional integrity,
  audit-chain, and signature capabilities.
- `cmd/main`: JS/native filesystem and machine-JSON CLI adapter.
- `api`: string-in/string-out browser adapter.
- `timing`: native-only Ed25519 timing experiment.

Cross-system adapters live under `integrations/`; they consume the public
MoonBit process contract and are excluded from the Mooncakes package.
