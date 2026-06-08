# Architecture

MoonEvidence is designed as a pure verification library with thin adapters.

## Layering

```text
src/canonjson  -> deterministic JSON serialization
src/digest     -> digest types, algorithm enum, hex/base64 helpers
src/merkle     -> Merkle root and proof verification
src/model      -> manifest, file entry, proof, version node models
src/verify     -> pack/file/manifest/version verification orchestration
src/diag       -> structured diagnostics and explain output
src/cmd/main   -> native CLI adapter
examples/      -> valid and tampered evidence packs
tests/         -> fixtures and black-box regression tests
```

## Dependency Rules

- Pure packages must not depend on file system or process APIs.
- `cmd/main` may perform file IO and CLI parsing, but should call library APIs for all verification logic.
- `verify` may depend on `model`, `canonjson`, `digest`, `merkle`, and `diag`.
- `diag` should not depend on `cmd/main`.
- Crypto primitives should be wrapped behind `digest` so dependencies can change without rewriting verification logic.

## MVP Verification Flow

```text
evidence-pack path
  -> load manifest
  -> canonicalize manifest
  -> verify manifest digest
  -> verify file digests
  -> verify Merkle proofs
  -> verify linear version chain
  -> emit VerifyReport
  -> explain report for CLI users
```

## Public API Shape

The API should stay small at first:

```text
verify_manifest(manifest_json) -> VerifyReport
verify_pack(path) -> VerifyReport
verify_membership(file_digest, proof, root) -> Bool
verify_version_chain(nodes) -> ChainReport
explain(report) -> String
```

`seal(directory, options)` is useful, but it is not part of the first implementation checkpoint.

