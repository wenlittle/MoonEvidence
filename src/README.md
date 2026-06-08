# Source Package Plan

The source tree is intentionally split by responsibility:

- `canonjson`: deterministic JSON serialization.
- `digest`: hash algorithm abstraction and digest comparison.
- `merkle`: Merkle root/proof verification.
- `model`: evidence pack data models.
- `verify`: verification orchestration.
- `diag`: diagnostics and explain output.
- `cmd/main`: native CLI adapter.

Actual MoonBit package files should be generated or validated after the `moon` CLI is installed.

