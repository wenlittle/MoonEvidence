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

## Public API Shape (frozen v1, 2026-06-10)

These signatures are the implementation contract for the first milestone.
Changing them requires a `DECISION_LOG.md` entry.

```text
// canonjson
@canonjson.canonicalize(input : String) -> String raise CanonError

// digest
@digest.sha256(data : Bytes) -> Bytes
@digest.sha256_hex(data : Bytes) -> String
@digest.Digest::of_bytes(algorithm : HashAlgorithm, data : Bytes) -> Digest

// merkle (operates on raw 32-byte hashes; Digest wrapping happens above)
@merkle.leaf_hash(data : Bytes) -> Bytes
@merkle.node_hash(left : Bytes, right : Bytes) -> Bytes
@merkle.compute_root(leaves : Array[Bytes]) -> Bytes?          // None for empty input
@merkle.verify_inclusion(leaf : Bytes, proof : Array[ProofStep], root : Bytes) -> Bool

// model
@model.Manifest::parse(input : String) -> Manifest raise ModelError
@model.parse_version_chain(input : String) -> Array[VersionNode] raise ModelError

// verify (pure: file contents injected by the caller, no IO inside)
@verify.verify_manifest(manifest_json : String, files : Map[String, Bytes]) -> VerifyReport
@verify.verify_version_chain(nodes : Array[VersionNode]) -> ChainReport

// diag
@diag.explain(report : VerifyReport) -> String
@diag.to_json(report : VerifyReport) -> String
```

Notes on two deliberate deviations from earlier drafts:

- `compute_root` returns `Bytes?` instead of `Digest` so the merkle package
  stays free of algorithm-tagging concerns and the empty tree is expressed as
  `None` instead of a sentinel value.
- `verify_manifest` takes an explicit `files` map because pure packages must
  not read the file system; the CLI adapter loads file bytes and injects them.

`seal(directory, options)` is useful, but it is not part of the first implementation checkpoint.

