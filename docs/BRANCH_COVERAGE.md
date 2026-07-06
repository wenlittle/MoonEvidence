# Branch Coverage Audit

> Last updated: 2026-07-06 Asia/Shanghai. Scope covered so far:
> `verify`, `incremental`, `merkle`, `digest`, and `crypto` trust boundaries.

MoonBit does not currently give this repository a mature line/branch coverage
report, so this file is the manual substitute. It records the security-relevant
branches that can accept, reject, skip, or warn on evidence-pack data, and maps
each branch to the test evidence that would notice a regression.

Status vocabulary:

| Status | Meaning |
| --- | --- |
| `covered` | A direct unit/black-box test triggers the branch. |
| `oracle-covered` | The expected value comes from an independent source such as Node.js, Wycheproof, or a generated fixture. |
| `mutation-covered` | `tools/mutation-check.mjs` deliberately breaks this invariant and the test suite goes red. |
| `accepted-risk` | The branch is defensive/unreachable under current constructors or intentionally outside the current public contract. |
| `gap` | No adequate test evidence yet. |

## Summary

| Package | Branches Audited | Open gaps | Notes |
| --- | ---: | ---: | --- |
| `verify` | 12 | 0 | Direct/oracle coverage for live branches; one defensive accepted-risk guard. |
| `incremental` | 15 | 0 | Direct/oracle/mutation coverage for live branches; explicit cache trust-boundary test; one defensive accepted-risk guard. |
| `merkle` | 18 | 0 | Direct/oracle/mutation coverage for live branches; one defensive accepted-risk guard. |
| `digest` | 24 | 0 | Direct, RFC/NIST, mutation, and Node.js differential coverage for hash/HMAC/digest parsing branches. |
| `crypto` | 24 | 0 | Direct, RFC 8032, Wycheproof, mutation, differential, and static-audit evidence for Ed25519/field/point branches. |

The current audited surface has no open `gap` items. This does not mean the
whole project is fully covered; it means these trust boundaries now have an
explicit branch map. The next pass should extend the same table to `create`,
`store`, and `audit`, then add a stale-check gate.

## Verify

File: `src/verify/verify.mbt`

| ID | Branch / Invariant | Source | Evidence | Status | Notes |
| --- | --- | --- | --- | --- | --- |
| V-01 | Manifest parse/validation failure returns a report and stops before file checks | `verify.mbt:37` | `verify_wbtest`: unparsable manifest, model validation failure; CLI manifest matrix covers E1001/E1002/E1003 | `covered` | Error code comes from `model.Manifest::parse`. |
| V-02 | Canonicalization failure after parse emits E1004 | `verify.mbt:50` | `verify_wbtest`: unsupported ignored number reports E1004 | `covered` | Catches unknown-field JSON values that parse but cannot canonicalize. |
| V-03 | Correct externally recorded manifest digest passes | `verify.mbt:65` | `verify_wbtest`: `GOLDEN_MANIFEST_DIGEST` Node-computed value | `oracle-covered` | Positive oracle prevents a self-generated digest loop. |
| V-04 | Wrong externally recorded manifest digest emits E2004 | `verify.mbt:73` | `verify_wbtest`: wrong recorded manifest digest reports E2004 | `covered` | Incremental E2004 has separate mutation coverage. |
| V-05 | Missing listed file emits E2003 and remaining files still count | `verify.mbt:90` | `verify_wbtest`: missing file content reports E2003 | `covered` | Exhaustive, not fail-fast. |
| V-06 | Tampered listed file emits E2003 with expected/got digest | `verify.mbt:99` | `verify_wbtest`: tampered file content reports E2003 | `covered` | Uses actual digest recomputation. |
| V-07 | Multiple file problems are all reported in one run | `verify.mbt:88` | `verify_wbtest`: all file problems are reported in one run | `covered` | Protects exhaustive reporting behavior. |
| V-08 | Extra provided file emits W1001 but does not fail verification | `verify.mbt:117` | `verify_wbtest`: unlisted file reports W1001 but pack stays ok; CLI matrix `unlisted-file` | `covered` | Warning path must not flip `ok` false. |
| V-09 | Non-empty manifest without Merkle root emits E3001 | `verify.mbt:134` | `verify_wbtest`: missing merkle root with files reports E3001 | `covered` | |
| V-10 | Merkle root present with empty file list emits E3001 | `verify.mbt:150` | `verify_wbtest`: merkle root over empty files reports E3001 | `covered` | |
| V-11 | Merkle root mismatch emits E3003 | `verify.mbt:160` | `verify_wbtest`: tampered merkle root reports E3003; golden pack from Node fixture validates positive path | `oracle-covered` | The positive root is generated independently by `tools/gen-pack-fixture.mjs`. |
| V-12 | `canonical_file_entry` catch fallback | `verify.mbt:199` | No direct trigger | `accepted-risk` | Input is already model-validated strings/integers; branch is a totality guard, not expected public behavior. |

## Incremental

File: `src/verify/incremental.mbt`

| ID | Branch / Invariant | Source | Evidence | Status | Notes |
| --- | --- | --- | --- | --- | --- |
| I-01 | Manifest parse/validation failure returns zero stats | `incremental.mbt:43` | CLI/manifest parse matrix covers parser behavior; incremental code mirrors full verify | `covered` | Direct incremental parse-negative wbtest is not separate because parse behavior is delegated to model. |
| I-02 | Canonicalization failure emits E1004 | `incremental.mbt:63` | `incremental_wbtest`: reports E1004 for unsupported ignored number | `covered` | |
| I-03 | Correct manifest digest passes | `incremental.mbt:84` | `incremental_wbtest`: Node-computed `GOLDEN_MANIFEST_DIGEST` matches | `oracle-covered` | Independent digest source. |
| I-04 | Wrong manifest digest emits E2004 | `incremental.mbt:90` | `incremental_wbtest`: wrong manifest digest rejected; mutation `incremental-e2004-disabled` caught | `mutation-covered` | This is a prior blind spot and now a mutation gate. |
| I-05 | Missing listed file emits E2003 | `incremental.mbt:113` | `incremental_wbtest`: missing manifest file from pack | `covered` | |
| I-06 | Trusted cache hit skips hashing and increments skipped/pass counts | `incremental.mbt:125` | `incremental_wbtest`: all files cached skips rehashing; golden all-cached oracle | `oracle-covered` | Also documents trust boundary. |
| I-07 | Empty/stale cache rehashes file and increments rehashed | `incremental.mbt:129` | `incremental_wbtest`: rehashes changed files; empty cache equals full verify; golden empty-cache oracle | `oracle-covered` | |
| I-08 | Rehashed tampered content emits E2003 | `incremental.mbt:132` | `incremental_wbtest`: detects tampered file with stale cache | `covered` | |
| I-09 | Cache trust boundary: matching compromised cache can hide file tamper | `incremental.mbt:125` | `incremental_wbtest`: trust model boundary test | `covered` | This is an explicit documented limitation, not a bug. |
| I-10 | Extra provided file emits W1001 and stays ok | `incremental.mbt:146` | `incremental_wbtest`: reports W1001 for unlisted file but remains ok | `covered` | |
| I-11 | Merkle root mismatch emits E3003 | `incremental.mbt:159` | `incremental_wbtest`: tampered merkle root reports E3003 | `covered` | |
| I-12 | Merkle root present but empty file list emits E3001 | `incremental.mbt:175` | `incremental_wbtest`: merkle root attests empty files | `covered` | |
| I-13 | Non-empty manifest without Merkle root emits E3001 | `incremental.mbt:183` | `incremental_wbtest`: merkle_root missing | `covered` | |
| I-14 | No expected manifest digest means no E2004 check | `incremental.mbt:84` | `incremental_wbtest`: without expected_manifest_digest skips E2004 | `covered` | Backward-compatible API behavior. |
| I-15 | `canonical_file_entry` catch fallback | `incremental.mbt` helper | No direct trigger | `accepted-risk` | Same totality guard as full verify. |

## Merkle

File: `src/merkle/merkle.mbt`

| ID | Branch / Invariant | Source | Evidence | Status | Notes |
| --- | --- | --- | --- | --- | --- |
| M-01 | Omitted hash algorithm defaults to SHA-256 | `merkle.mbt:17` | Most Merkle tests call without `algorithm`; golden roots are SHA-256 | `covered` | |
| M-02 | SHA-256 leaf prefix is 0x00 | `merkle.mbt:30` | `merkle_wbtest`: domain separation; mutation `merkle-leaf-prefix` caught | `mutation-covered` | |
| M-03 | SHA-256 node prefix is 0x01 | `merkle.mbt:54` | `merkle_wbtest`: domain separation; mutation `merkle-node-prefix` caught | `mutation-covered` | |
| M-04 | SHA-512 leaf prefix is 0x00 | `merkle.mbt:36` | `merkle_wbtest`: SHA-512 leaf direct `Sha512Ctx`; mutation `merkle-sha512-leaf-prefix` caught | `mutation-covered` | This was the mutation slip found and closed. |
| M-05 | SHA-512 node prefix is 0x01 | `merkle.mbt:61` | `merkle_wbtest`: SHA-512 node direct `Sha512Ctx`; mutation `merkle-sha512-node-prefix` caught | `mutation-covered` | This was the mutation slip found and closed. |
| M-06 | Empty root input returns `None` | `merkle.mbt:84` | `merkle_wbtest`: empty tree has no root | `covered` | |
| M-07 | Single-leaf root is the leaf hash | `merkle.mbt:104` | `merkle_wbtest`: single leaf root; golden roots include 1 leaf | `oracle-covered` | |
| M-08 | Odd node is promoted unchanged in `compute_root` | `merkle.mbt:98` | `merkle_wbtest`: 3/5 leaves; golden promoted proof; mutation `merkle-self-pair` caught | `mutation-covered` | CVE-2012-2459 regression guard. |
| M-09 | Empty `compute_tree` input returns `None` | `merkle.mbt:178` | `merkle_wbtest`: compute_tree on empty input returns None | `covered` | |
| M-10 | Odd node is promoted unchanged in `compute_tree` | `merkle.mbt:195` | `merkle_wbtest`: compute_tree 3/5 leaves; mutation `merkle-tree-self-pair` caught | `mutation-covered` | Separate materialization path from `compute_root`. |
| M-11 | `MerkleTree::level` out-of-bounds returns empty | `merkle.mbt:156` | `merkle_wbtest`: out-of-bounds level returns empty array | `covered` | Defensive renderer behavior. |
| M-12 | `leaf_path` rejects empty/out-of-range | `merkle.mbt:241` | `merkle_wbtest`: empty and out-of-range path tests | `covered` | |
| M-13 | `leaf_path` follows promoted odd nodes correctly | `merkle.mbt:253` | `merkle_wbtest`: leaf_path covers one step per level and ends at root | `covered` | |
| M-14 | `compute_proof` rejects out-of-range/empty | `merkle.mbt:313` | `merkle_wbtest`: proof for out-of-range index is none | `covered` | |
| M-15 | Proof construction round-trips for boundary shapes and random shapes | `merkle.mbt:321` | `merkle_wbtest`: shapes 1/2/3/4/5/7/8/9/15/16/17; `merkle_prop_wbtest`: random shapes | `covered` | |
| M-16 | Tampered proof/leaf/root is rejected | `merkle.mbt:351` | `merkle_wbtest`: forged sibling, flipped side, truncated/extended proof, wrong leaf; property tamper test | `covered` | |
| M-17 | Golden roots/proofs match independent Node reference | `merkle.mbt:82` | `merkle_golden_wbtest`: roots/proofs from `tests/fixtures/merkle/golden.json` | `oracle-covered` | |
| M-18 | `MerkleTree::root` empty top guard | `merkle.mbt:128` | No direct trigger | `accepted-risk` | `compute_tree([])` returns `None`, and no public constructor creates an empty-top non-empty tree. Defensive branch. |

## Digest

Files: `src/digest/digest.mbt`, `src/digest/sha256.mbt`,
`src/digest/sha512.mbt`, `src/digest/hmac.mbt`

| ID | Branch / Invariant | Source | Evidence | Status | Notes |
| --- | --- | --- | --- | --- | --- |
| D-01 | `HashAlgorithm::label` renders SHA-256 and SHA-512 canonical labels | `digest.mbt:35` | `digest_wbtest`: parse/render round trips for both algorithms | `covered` | |
| D-02 | `normalize_algorithm` accepts `sha256` and `SHA-256` spellings | `digest.mbt:46` | `digest_wbtest`: normalize algorithm accepts sha256 forms | `covered` | |
| D-03 | `normalize_algorithm` accepts `sha512` and `SHA-512` spellings | `digest.mbt:48` | `digest_wbtest`: normalize algorithm accepts sha512 forms | `covered` | |
| D-04 | `normalize_algorithm` rejects unknown algorithms | `digest.mbt:51` | `digest_wbtest`: `md5` and parse-digest unknown algorithm cases | `covered` | |
| D-05 | `is_hex` accepts non-empty ASCII hex | `digest.mbt:61` | `digest_wbtest`: uppercase/lowercase hex normalization and decoding | `covered` | |
| D-06 | `is_hex` rejects empty and non-hex strings | `digest.mbt:61` | `digest_wbtest`: empty, `xyz`, and `zz` rejection cases | `covered` | |
| D-07 | `hex_to_bytes` rejects odd-length input | `digest.mbt:91` | `digest_wbtest`: `hex_to_bytes("abc")` returns `None` | `covered` | |
| D-08 | `hex_to_bytes` rejects non-hex nibbles | `digest.mbt:98` | `digest_wbtest`: `hex_to_bytes("00xz")` returns `None` | `covered` | |
| D-09 | `hex_to_bytes` decodes mixed-case valid nibbles | `digest.mbt:95` | `digest_wbtest`: `0aFf` decodes to `0a ff` | `covered` | |
| D-10 | `normalize_hex` lowercases valid input | `digest.mbt:108` | `digest_wbtest`: `A0B1C2` -> `a0b1c2` | `covered` | |
| D-11 | `normalize_hex` rejects empty/non-hex input | `digest.mbt:111` | `digest_wbtest`: empty and `xyz` return `None` | `covered` | |
| D-12 | `parse_digest` rejects wrong colon shape | `digest.mbt:121` | `digest_wbtest`: no-colon and extra-colon cases return `None` | `covered` | |
| D-13 | `parse_digest` rejects unknown algorithm | `digest.mbt:122` | `digest_wbtest`: `md5:abcd` returns `None` | `covered` | |
| D-14 | `parse_digest` rejects invalid/empty hex | `digest.mbt:125` | `digest_wbtest`: `sha256:` and `sha256:zz` return `None` | `covered` | |
| D-15 | `parse_digest` normalizes valid algorithm and hex | `digest.mbt:120` | `digest_wbtest`: `SHA-256:ABCD` -> `sha256:abcd` | `covered` | |
| D-16 | `Digest::of_bytes` dispatches SHA-256 | `digest.mbt:134` | `digest_wbtest` and `sha256_wbtest`: FIPS/NIST `abc` vector | `oracle-covered` | |
| D-17 | `Digest::of_bytes` dispatches SHA-512 | `digest.mbt:135` | `digest_wbtest` and `sha512_wbtest`: FIPS `abc` and million-`a` vectors | `oracle-covered` | |
| D-18 | `same_digest` compares normalized valid digest strings | `digest.mbt:151` | `digest_wbtest`: mixed-case equivalent strings compare true | `covered` | |
| D-19 | `same_digest` rejects malformed input | `digest.mbt:153` | `digest_wbtest`: malformed right-hand value returns false | `covered` | |
| D-20 | SHA-256 one-shot/streaming padding and block boundaries match NIST | `sha256.mbt` | `sha256_wbtest`: empty, 55/56-class examples, 112-byte class, million-`a`, chunk invariance | `oracle-covered` | Mutations cover H0/K0. |
| D-21 | SHA-512 one-shot/streaming padding and block boundaries match FIPS/Node | `sha512.mbt` | `sha512_wbtest`: empty, `abc`, 112-byte spill boundary, incremental/idempotent finalize | `oracle-covered` | Mutations cover H0/K0. |
| D-22 | HMAC derives short/equal-block keys by zero-padding | `hmac.mbt:38` | `hmac_wbtest`: RFC 4231 cases 1-4 and empty message | `oracle-covered` | |
| D-23 | HMAC hashes keys longer than the block size | `hmac.mbt:38` | `hmac_wbtest`: RFC 4231 case 6; mutation tests catch ipad/opad constants | `mutation-covered` | |
| D-24 | SHA/HMAC JS API agrees with Node.js random differential oracle | `tools/differential-digest.mjs` | CI runs 64 rounds; release candidates can run 1000 | `oracle-covered` | Covers random lengths including padding boundaries. |

## Crypto

Files: `src/crypto/ed25519.mbt`, `src/crypto/field25519.mbt`,
`src/crypto/point25519.mbt`

| ID | Branch / Invariant | Source | Evidence | Status | Notes |
| --- | --- | --- | --- | --- | --- |
| C-01 | Ed25519 public-key derivation matches RFC/Node | `ed25519.mbt:156` | RFC 8032 KATs; `tools/differential-crypto.mjs` | `oracle-covered` | |
| C-02 | Ed25519 signing is deterministic and matches RFC/Node | `ed25519.mbt:165` | RFC 8032 KATs; randomized Node differential oracle | `oracle-covered` | |
| C-03 | Ed25519 verify accepts valid signatures | `ed25519.mbt:244` | RFC 8032 KATs and 88 valid Wycheproof vectors | `oracle-covered` | |
| C-04 | `ed25519_verify` rejects bad public-key/signature lengths | `ed25519.mbt:245` | `ed25519_wbtest`: 31/33-byte pk and 63/65-byte signature | `covered` | |
| C-05 | `scalar_lt_l` rejects non-canonical `S >= l` | `ed25519.mbt:260` | `ed25519_wbtest`, Wycheproof malleability vectors, mutation `ed25519-canonical-s` | `mutation-covered` | |
| C-06 | Invalid public-key point decoding rejects verification | `ed25519.mbt:264` | `ed25519_wbtest`: invalid pk encoding; Wycheproof invalid encodings | `oracle-covered` | |
| C-07 | Identity public key is explicitly rejected | `ed25519.mbt:271` | `ed25519_wbtest`: identity forgery cases | `covered` | |
| C-08 | Low-order public keys are rejected by cofactor check | `ed25519.mbt:280` | `ed25519_wbtest`; mutation `ed25519-low-order-reject` | `mutation-covered` | |
| C-09 | Invalid `R` point decoding rejects verification | `ed25519.mbt:284` | `ed25519_wbtest`: invalid R encoding; Wycheproof invalid encodings | `oracle-covered` | |
| C-10 | Verification equation rejects wrong message/signature | `ed25519.mbt:294` | `ed25519_wbtest`: wrong message, tampered signature; differential tamper checks | `covered` | |
| C-11 | `point_decode` rejects non-32-byte encodings | `ed25519.mbt:335` | `ed25519_wbtest`: 31/33-byte encodings | `covered` | |
| C-12 | `point_decode` rejects non-canonical `y >= p` | `ed25519.mbt:350` | `ed25519_wbtest`; mutation `ed25519-noncanonical-y` | `mutation-covered` | |
| C-13 | `point_decode` handles sqrt(-1) correction path | `ed25519.mbt:362` | `ed25519_wbtest`: `y=0` accepts after correction | `covered` | |
| C-14 | `point_decode` rejects points not on the curve | `ed25519.mbt:365` | `ed25519_wbtest`: small `y=2` rejection | `covered` | |
| C-15 | `point_decode` rejects `x=0` with sign bit set | `ed25519.mbt:375` | `ed25519_wbtest`: identity encoding with sign=1 | `covered` | |
| C-16 | Field add/sub/mul/invert obey basic field laws | `field25519.mbt` | `field25519_wbtest`: identities, inverse, distributive law | `covered` | |
| C-17 | `Fe::to_bytes` canonical reduction handles `p -> 0` | `field25519.mbt:158` | `field25519_wbtest`: direct `p` reduction; point non-canonical-y test | `covered` | |
| C-18 | `Fe::eq` scans all bytes before equality decision | `field25519.mbt:199` | `docs/CONST_TIME_AUDIT.md`; equality used across field/point tests | `covered` | Source-level constant-time audit, not dudect proof. |
| C-19 | `fe_cmov` / `point_cmov` select both scalar bits without branch | `field25519.mbt:214`, `point25519.mbt:129` | `point25519_wbtest`: scalar 2 and 3; `docs/CONST_TIME_AUDIT.md` | `covered` | Source-level audit only. |
| C-20 | Point identity/add/double formulas agree | `point25519.mbt:100` | `point25519_wbtest`: identity + base, base + identity, add equals double | `covered` | |
| C-21 | Scalar multiplication agrees with repeated addition/RFC public keys | `point25519.mbt:143` | `point25519_wbtest`: 2*B/3*B; RFC 8032 public-key KATs | `oracle-covered` | |
| C-22 | Point encoding round-trips through decode | `point25519.mbt:181` | `ed25519_wbtest`: base point and `y=0` round trips | `covered` | |
| C-23 | `reduce_scalar_512` has no source-level secret-dependent compare/borrow branch | `ed25519.mbt:81` | `docs/CONST_TIME_AUDIT.md`; RFC/Node differential signing catches functional drift | `covered` | Backend/timing proof remains outside this claim. |
| C-24 | Ed25519 verify rejects independent negative corpus | `ed25519_wycheproof_wbtest.mbt` | 62 invalid Wycheproof vectors across seven categories | `oracle-covered` | Independent Google Wycheproof expected results. |

## Open Follow-Ups

| Priority | Item | Reason |
| --- | --- | --- |
| P1 | Extend this audit to `create`, `store`, and `audit`. | The current pass covers the main verification/Merkle/digest/crypto trust boundary, not every package. |
| P1 | Add a lightweight script or checklist gate that fails when this file is stale after touching audited files. | Manual branch maps can drift unless the workflow names the update requirement. |
| P2 | Add fuzz/property tests for malformed public JS API requests. | CLI/API shape errors are user-facing and broader than the pure core. |
