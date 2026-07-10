# Architecture

MoonEvidence is designed as a pure verification library with thin adapters.

## Layering

```text
src/canonjson  -> deterministic JSON serialization (RFC 8785)
src/digest     -> digest types, algorithm enum, hex/base64 helpers, SHA-256/SHA-512/HMAC
src/merkle     -> Merkle root and proof verification
src/model      -> manifest, file entry, proof, version node models
src/verify     -> pack/file/manifest/version verification orchestration
src/diag       -> structured diagnostics and explain output
src/create     -> evidence pack creation from raw files
src/store      -> content-addressed object store (Git-like)
src/audit      -> hash-chained append-only audit log
src/crypto     -> Ed25519 digital signatures (pure MoonBit)
src/cmd/main   -> native CLI adapter
src/api        -> browser ESM adapter (string-in/string-out)
showcase/      -> React/Three.js trust observatory using src/api in a Web Worker
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
@verify.verify_manifest(manifest_json : String, files : Map[String, Bytes], ~expected_manifest_digest? : String) -> @diag.VerifyReport
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

## Public API Shape (frozen v2, 2026-07-04)

The v2 freeze extends the v1 contract with the four extension packages
(`create` / `store` / `audit` / `crypto`) and the browser adapter (`api`).
These signatures are the implementation contract for the second milestone
(post-MVP expansion: evidence pack creation, content-addressed storage,
audit log, Ed25519 signatures). Changing them requires a `DECISION_LOG.md`
entry.

```text
// create — build an evidence pack from raw file bytes
@create.create_manifest(files : Map[String, Bytes], options : CreateOptions) -> String

// store — content-addressed object store (Git-like, SHA-256 deduplication)
@store.ObjectStore::new() -> ObjectStore
@store.ObjectStore::put(self : ObjectStore, content : Bytes) -> String       // returns sha256:<hex>
@store.ObjectStore::get(self : ObjectStore, hash : String) -> Bytes?
@store.ObjectStore::has(self : ObjectStore, hash : String) -> Bool
@store.ObjectStore::count(self : ObjectStore) -> Int
@store.ObjectStore::list_hashes(self : ObjectStore) -> Array[String]
@store.deduplicate(files : Map[String, Bytes]) -> DeduplicateResult          // dedup + integrity stats
@store.DeduplicateResult::reconstruct(self : DeduplicateResult, ...) -> ...  // rebuild files from store

// audit — hash-chained append-only audit log (optional Ed25519 signatures)
@audit.AuditLog::new() -> AuditLog
@audit.AuditLog::append(self : AuditLog, action : AuditAction, target : String) -> Unit
@audit.AuditLog::verify_chain(self : AuditLog) -> Bool
@audit.AuditLog::sign_last(self : AuditLog, sk : Bytes) -> Unit
@audit.AuditLog::verify_signatures(self : AuditLog, pk : Bytes) -> Bool
@audit.AuditLog::to_json(self : AuditLog) -> String

// crypto — pure MoonBit Ed25519 (RFC 8032), no external crypto dependency
@crypto.ed25519_public_key(sk : Bytes) -> Bytes
@crypto.ed25519_sign(sk : Bytes, message : Bytes) -> Bytes
@crypto.ed25519_verify(pk : Bytes, message : Bytes, sig : Bytes) -> Bool

// api — browser ESM adapter; the only cross-boundary type is String
@api.digest_compute(request_json : String) -> String
@api.verify_evidence(request_json : String) -> String
@api.compute_merkle_tree(request_json : String) -> String
@api.create_evidence_pack(request_json : String) -> String
@api.generate_proof(request_json : String) -> String
@api.verify_proof(request_json : String) -> String
@api.audit_append(request_json : String) -> String
@api.audit_verify(request_json : String) -> String
@api.audit_sign(request_json : String) -> String
@api.ed25519_keypair(request_json : String) -> String
@api.ed25519_sign(request_json : String) -> String
@api.ed25519_verify(request_json : String) -> String
```

Notes on the v2 extensions:

- `create_manifest` returns the serialized `manifest.json` string; file bytes
  are injected by the caller, keeping the create path IO-free like the verify
  path. `CreateOptions` carries the subject metadata, hash algorithm, and an
  optional parent version id.
- `ObjectStore` is a pure in-memory store; persistence is the adapter's job.
  `deduplicate` returns a `DeduplicateResult` that bundles per-file hash,
  store hit/miss stats, and a `reconstruct` path to rebuild files from the
  store — the integrity check (`verify_integrity`) re-reads stored bytes and
  re-hashes them.
- `AuditLog::append` chains each entry's hash to the previous entry's hash;
  `verify_chain` recomputes the chain. Signatures are layered on top:
  `sign_last` signs the most recent entry with an Ed25519 secret key,
  `verify_signatures` checks every signed entry against the public key.
- `crypto` is implemented from the field up (`field25519` -> `point25519` ->
  `ed25519`); the three functions above are the only public surface.
- Every `api` export takes a JSON request string and returns a JSON response
  string, so any JS host integrates with zero MoonBit types crossing the
  boundary. `verify_evidence` remains the main Evidence Pack verifier; the
  other exports expose digest, Merkle, creation, proof, audit, and Ed25519
  workflows to the browser demo and smoke tests.

The v1 signatures above remain valid; `verify_manifest` gained an optional
labeled parameter `~expected_manifest_digest?` (manifest-digest assertion,
E2004) and its return type is spelled `@diag.VerifyReport` to match the
actual code.

## 0.3.1 Root-Cause Hardening Notes (2026-07-04)

The 2026-07-04 second-round root-cause fix tightened the crypto and
verify/create paths without changing any frozen v2 signature. The notes
below record the behavioural changes; see `CHANGELOG.md` 0.3.1 and
`DECISION_LOG.md` for the full rationale.

### Crypto hardening (Ed25519)

- `ed25519_verify` now performs binary quotient decomposition for the scalar modulus
  step (replacing the previous subtractive loop). `point_decode` rejects
  non-canonical encodings, and verification rejects low-order public keys with
  an explicit identity check plus `8*A` cofactor check. These are internal
  changes; the three public `crypto` signatures above are unchanged.
- Audit-log signatures (`audit.sign_last` / `verify_signatures`) now sign the
  RFC 8785 canonical JSON form of the entry, so the signed byte sequence is
  stable and unambiguous. Again the v2 signatures are unchanged.

### E3002 error-code contract

E3002 (proof format invalid) is reserved in the error-code contract. The
MVP CLI ships no `proofs/` consumer, so no test fires E3002; the incremental
path was corrected to surface E3003 (root mismatch), not E3002. The final
disposition of E3002 (implement an inclusion-proof CLI exposing
`prove` / `check-proof`, or remove the reserved code) is recorded in the
latest `DECISION_LOG.md` entry. If the decision is "implement", the merkle
inclusion-proof API (`@merkle.verify_inclusion` already exists in the v1
freeze) will be surfaced as CLI subcommands; if "remove", the error-code
table in `docs/spec/EVIDENCE_PACK_SPEC.md` will drop E3002. Either way the
frozen v2 signatures above are not loosened.
