# Branch Coverage Audit

> Last updated: 2026-07-06 Asia/Shanghai. Scope covered so far:
> `verify`, `incremental`, `merkle`, `digest`, `crypto`, `create`, `store`,
> `audit`, and public `api` adapter trust boundaries.

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
| `create` | 12 | 0 | Direct/oracle coverage for manifest creation validation, ordering, empty roots, SHA-512, and tamper detection; defensive fallbacks recorded. |
| `store` | 16 | 0 | Direct/oracle coverage for content-addressed storage, dedup stats, integrity rejection, strict and lenient reconstruction. |
| `audit` | 24 | 0 | Direct coverage for hash-chain validation, signing, signature rejection, JSON round-trip, and parser shape errors. |
| `api` | 49 | 0 | Direct/fuzz/property/smoke coverage for the public JS string adapter envelope, malformed inputs, closed-loop workflows, and defensive fallbacks. |

The current audited surface has no open `gap` items. This does not mean the
whole project is fully covered; it means these trust boundaries now have an
explicit branch map. `tools/check-branch-coverage-stale.mjs` now gates the map:
edits to audited source files must touch this file in the same diff.

Format review 2026-07-06: `moon fmt` mechanically reformatted audited source
files in `api`, `audit`, `create`, and `store`. Branch conditions, public
contracts, and evidence mappings above were reviewed as unchanged; this entry
is the required stale-check touch for the formatting-only diff.

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

## Create

File: `src/create/create.mbt`

| ID | Branch / Invariant | Source | Evidence | Status | Notes |
| --- | --- | --- | --- | --- | --- |
| CR-01 | Empty `subject.id` aborts before producing an unverifiable manifest | `create.mbt:41` | `create_wbtest`: panic rejects empty subject id | `covered` | |
| CR-02 | Empty `subject.kind` aborts | `create.mbt:44` | `create_wbtest`: panic rejects empty subject kind | `covered` | |
| CR-03 | Empty `version_id` aborts | `create.mbt:47` | `create_wbtest`: panic rejects empty version id | `covered` | |
| CR-04 | Present-but-empty `version_parent` aborts | `create.mbt:50` | `create_wbtest`: panic rejects empty version parent | `covered` | |
| CR-05 | Hostile file paths are rejected before inclusion in the manifest | `create.mbt:69` | `create_wbtest`: `../escape.txt` panic | `covered` | Mirrors verify-side path validation. |
| CR-06 | File paths are sorted by UTF-16/code-unit order, not MoonBit shortlex | `create.mbt:59` | `create_wbtest`: `"aa"` before `"b"` plus pinned Merkle root from Node | `oracle-covered` | Protects cross-tool reproducibility. |
| CR-07 | Per-file digest and Merkle root use the selected algorithm | `create.mbt:78`, `create.mbt:91` | `create_wbtest`: SHA-256 and SHA-512 create->verify; SHA-512 prefix assertions | `covered` | |
| CR-08 | Empty file set produces empty `files[]` and `merkle_root: null` | `create.mbt:89` | `create_wbtest`: empty files emits null root and empty files | `covered` | New explicit branch pin. |
| CR-09 | Version parent serializes as string when present and null when absent | `create.mbt:101` | `create_wbtest`: version parent round-trip; empty/no-parent tests parse JSON | `covered` | |
| CR-10 | Created manifest is RFC 8785 canonical JSON | `create.mbt:122` | `create_wbtest`: canonicalization idempotence | `covered` | |
| CR-11 | Tampered file content is rejected by downstream verification | `create_wbtest` | `create_wbtest`: create->tamper->verify detects mismatch, including SHA-512 E2003 | `covered` | Cross-package lifecycle invariant. |
| CR-12 | `files.get(path)` miss and canonicalization fallback branches | `create.mbt:72`, `create.mbt:85`, `create.mbt:122` | No direct public trigger for the miss/fallback cases | `accepted-risk` | The loop iterates over keys from the same map, and constructed JSON uses strings/numbers that canonicalize under current policy. |

## Store

File: `src/store/object_store.mbt`

| ID | Branch / Invariant | Source | Evidence | Status | Notes |
| --- | --- | --- | --- | --- | --- |
| S-01 | New store starts empty | `object_store.mbt:14` | `object_store_wbtest`: empty store has zero count | `covered` | |
| S-02 | First `put` stores content under SHA-256 key | `object_store.mbt:21` | `object_store_wbtest`: put/get round-trip with byte comparison | `covered` | |
| S-03 | Duplicate `put` is idempotent and does not add a second object | `object_store.mbt:21` | `object_store_wbtest`: duplicate content stored once | `covered` | |
| S-04 | `get`/`has` positive and negative paths | `object_store.mbt:29`, `object_store.mbt:34` | `object_store_wbtest`: put/get, has true and false | `covered` | |
| S-05 | `remove` returns true and deletes existing object | `object_store.mbt:56` | `object_store_wbtest`: remove deletes object | `covered` | |
| S-06 | `remove` returns false for missing object | `object_store.mbt:61` | `object_store_wbtest`: second remove returns false | `covered` | |
| S-07 | `list_hashes` exposes all stored keys | `object_store.mbt:45` | `object_store_wbtest`: two hashes listed | `covered` | |
| S-08 | Deduplicate records duplicate savings and unique object count | `object_store.mbt:78` | `object_store_wbtest`: duplicate file set produces two unique objects and positive bytes saved | `covered` | |
| S-09 | Deduplicate JSON output is canonical independent of map insertion order | `object_store.mbt:118` | `object_store_wbtest`: two differently inserted maps serialize identically | `covered` | New explicit branch pin for the canonicalize path. |
| S-10 | `verify_integrity` accepts untampered content with independent SHA-256 keys | `object_store.mbt:128` | `object_store_wbtest`: Node-computed hash constants | `oracle-covered` | Breaks the old put()/sha256 self-cycle. |
| S-11 | `verify_integrity` rejects content whose recomputed digest differs from its key | `object_store.mbt:132` | `object_store_wbtest`: tampered content returns false | `oracle-covered` | |
| S-12 | `verify_integrity` rejects missing content | `object_store.mbt:136` | `object_store_wbtest`: missing object returns false | `oracle-covered` | |
| S-13 | Lenient `reconstruct` restores present objects byte-for-byte | `object_store.mbt:153` | `object_store_wbtest`: reconstruct recovers original files; strict oracle checks bytes | `covered` | |
| S-14 | Lenient `reconstruct` skips missing objects without failing | `object_store.mbt:155` | `object_store_wbtest`: missing content skipped in lenient mode | `oracle-covered` | New explicit trust-boundary pin. |
| S-15 | `reconstruct_strict` returns `Err` and accumulates all missing paths | `object_store.mbt:174`, `object_store.mbt:179` | `object_store_wbtest`: one missing and two missing paths | `oracle-covered` | |
| S-16 | `reconstruct_strict` returns `Ok` when all entries are present | `object_store.mbt:181` | `object_store_wbtest`: strict success with byte checks | `oracle-covered` | |

## Audit

File: `src/audit/audit_log.mbt`

| ID | Branch / Invariant | Source | Evidence | Status | Notes |
| --- | --- | --- | --- | --- | --- |
| A-01 | `AuditAction::to_string` renders builtins and custom values | `audit_log.mbt:17` | `audit_log_wbtest`: custom action and normal append tests | `covered` | |
| A-02 | `AuditAction::parse` recognizes builtins and preserves unknown custom values | `audit_log.mbt:29` | `audit_log_wbtest`: parse recognizes builtins and custom action | `covered` | New explicit branch pin. |
| A-03 | Entry hashing is deterministic and includes optional digest/previous hash fields | `audit_log.mbt:55` | `audit_log_wbtest`: deterministic hash, multi-entry chain, from_json round-trips | `covered` | |
| A-04 | Entry/log JSON serialization is canonical and parseable | `audit_log.mbt:111`, `audit_log.mbt:233` | `audit_log_wbtest`: entry/log JSON parse tests; from_json round-trips | `covered` | |
| A-05 | New/empty log verifies and has zero length | `audit_log.mbt:126`, `audit_log.mbt:174` | `audit_log_wbtest`: empty audit log verifies | `covered` | |
| A-06 | Append links the first entry to `None` and later entries to previous hash | `audit_log.mbt:139` | `audit_log_wbtest`: single and multi-entry chains verify | `covered` | |
| A-07 | `verify_chain` rejects wrong `prev_hash` | `audit_log.mbt:164` | `audit_log_wbtest`: broken middle prev_hash and forked chain rejected | `covered` | |
| A-08 | `verify_chain` rejects tampered content or stored hash mismatch | `audit_log.mbt:168` | `audit_log_wbtest`: tampered chain, tampered hash field, from_json tamper | `covered` | |
| A-09 | `sign_last` on an empty log is a no-op | `audit_log.mbt:184` | `audit_log_wbtest`: sign_last on empty log | `covered` | New explicit branch pin. |
| A-10 | `sign_last` signs the last entry and preserves chain validity | `audit_log.mbt:189` | `audit_log_wbtest`: sign and verify audit entry, multi-entry signed log | `covered` | |
| A-11 | Unsigned entries are skipped by signature verification | `audit_log.mbt:217` | `audit_log_wbtest`: unsigned entries are skipped | `covered` | New explicit branch pin. |
| A-12 | Valid signatures verify with the right public key | `audit_log.mbt:204` | `audit_log_wbtest`: sign and verify, signed round-trip | `covered` | |
| A-13 | Wrong public key or invalid Ed25519 signature returns false | `audit_log.mbt:210` | `audit_log_wbtest`: signed log rejects wrong public key | `covered` | |
| A-14 | Invalid signature hex returns false | `audit_log.mbt:213` | `audit_log_wbtest`: odd-length hex and non-hex signature strings rejected | `covered` | |
| A-15 | `from_json` rejects unparsable JSON | `audit_log.mbt:248` | `audit_log_wbtest`: `"not json"` returns None | `covered` | |
| A-16 | `from_json` rejects non-array top-level values | `audit_log.mbt:249` | `audit_log_wbtest`: `{}` returns None | `covered` | |
| A-17 | `from_json` rejects non-object array elements | `audit_log.mbt:252` | `audit_log_wbtest`: `[42]` returns None | `covered` | |
| A-18 | `from_json` rejects missing required fields | `audit_log.mbt:254` | `audit_log_wbtest`: missing required fields returns None | `covered` | |
| A-19 | `from_json` rejects malformed `hash` format | `audit_log.mbt:264` | `audit_log_wbtest`: bad prefix and bad length | `covered` | |
| A-20 | `from_json` maps optional `manifest_digest`, `prev_hash`, and `signature` strings and null/missing to optionals | `audit_log.mbt:268`, `audit_log.mbt:272`, `audit_log.mbt:284` | `audit_log_wbtest`: empty log, unsigned log, signed log, and chain round-trips | `covered` | |
| A-21 | `from_json` rejects malformed `prev_hash` format | `audit_log.mbt:277` | `audit_log_wbtest`: malformed prev_hash field | `covered` | |
| A-22 | `from_json` preserves empty logs | `audit_log.mbt:291` | `audit_log_wbtest`: empty log round-trip | `covered` | |
| A-23 | `from_json` rebuilds last hash so subsequent chain/signature checks work | `audit_log.mbt:291` | `audit_log_wbtest`: chain and signature round-trips verify | `covered` | |
| A-24 | Long chains still verify and detect middle breaks | `audit_log.mbt:162` | `audit_log_wbtest`: 1000-entry positive and middle-break tests | `covered` | |

## API

File: `src/api/api.mbt`

The API package is a public string-in/string-out adapter for JS/browser
callers. Its main trust boundary is request-envelope validation: malformed
caller input must not throw across the JS boundary, and every response must be
parseable JSON with a boolean `ok` field. Semantic success paths are covered by
MoonBit wbtests and `tools/smoke-api.mjs`; broad malformed-shape coverage is
covered by `tools/fuzz-api-malformed.mjs`; valid randomized closed-loop
semantics and tamper rejection are covered by `tools/property-api-semantic.mjs`.

| ID | Branch / Invariant | Source | Evidence | Status | Notes |
| --- | --- | --- | --- | --- | --- |
| API-01 | Every exported adapter rejects invalid JSON without throwing | `api.mbt` parse catches | `api_wbtest`: non-json verify request; `fuzz-api-malformed.mjs`: invalid JSON across all 12 exports | `covered` | Shared boundary contract. |
| API-02 | Every exported adapter rejects top-level non-object JSON | `api.mbt` object guards | `api_wbtest`: non-object verify request; `fuzz-api-malformed.mjs`: null/boolean/number/array/string across all exports | `covered` | |
| API-03 | Malformed request errors use the stable `{ ok:false, error }` envelope | `api.mbt:134` | `fuzz-api-malformed.mjs`: asserts JSON object, boolean `ok`, and error string for deterministic malformed cases | `covered` | |
| API-04 | `digest_compute` rejects missing/wrong `algorithm` | `api.mbt:38` | `fuzz-api-malformed.mjs`: missing and non-string algorithm | `covered` | |
| API-05 | `digest_compute` rejects missing/wrong/non-hex `data` | `api.mbt:41`, `api.mbt:44` | `fuzz-api-malformed.mjs`: missing data, wrong type, odd/non-hex strings | `covered` | |
| API-06 | `digest_compute` enforces HMAC key presence and hex validity | `api.mbt:51`, `api.mbt:54` | `fuzz-api-malformed.mjs`: missing and invalid key | `covered` | |
| API-07 | `digest_compute` rejects unknown algorithms | `api.mbt:60` | `fuzz-api-malformed.mjs`: `unknown`; `api_wbtest`/differential suite cover supported algorithms | `covered` | |
| API-08 | `digest_compute` SHA-256/SHA-512/HMAC success agrees with Node.js | `api.mbt:48` | `smoke-api.mjs`; `differential-digest.mjs` random oracle | `oracle-covered` | |
| API-09 | `verify_evidence` requires string `manifest` | `api.mbt:82` | `api_wbtest`: missing/non-string manifest; fuzz malformed cases | `covered` | |
| API-10 | `verify_evidence` accepts absent/null files and rejects non-object files | `api.mbt:88`, `api.mbt:100` | `api_wbtest`: null files accepted, non-object files rejected; fuzz malformed cases | `covered` | |
| API-11 | `verify_evidence` rejects non-string or non-hex file payloads | `api.mbt:92`, `api.mbt:95` | `api_wbtest`: non-string, odd-length, non-hex file values; fuzz malformed cases | `covered` | |
| API-12 | `verify_evidence` rejects non-string `version_chain` | `api.mbt:108` | `api_wbtest`: non-string version chain; fuzz malformed cases | `covered` | |
| API-13 | `verify_evidence` merges version-chain findings into the report | `api.mbt:107` | `api_wbtest`: valid chain stays ok, broken parent E4002, invalid chain E1001 | `covered` | |
| API-14 | `verify_evidence` success/failure mirrors core verification | `api.mbt:104` | `api_wbtest`: golden pack ok, tampered file E2003, invalid manifest E1001; `smoke-api.mjs` valid/tampered examples | `oracle-covered` | Golden fixture digests are Node-generated. |
| API-15 | Embedded report JSON parse fallback is defensive only | `api.mbt:123` | No direct trigger | `accepted-risk` | Parses `@diag.to_json` output generated in-process. |
| API-16 | `compute_merkle_tree` requires string `manifest` | `api.mbt:173` | `api_wbtest`: bad request; fuzz missing/non-string manifest | `covered` | |
| API-17 | `compute_merkle_tree` validates optional files object and hex payloads | `api.mbt:179` | `fuzz-api-malformed.mjs`: non-object files, non-string value, invalid hex | `covered` | |
| API-18 | `compute_merkle_tree` reports manifest parse failure as request error | `api.mbt:195` | `fuzz-api-malformed.mjs`: malformed manifest text | `covered` | |
| API-19 | `compute_merkle_tree` represents empty file sets with null root | `api.mbt:205` | `api_wbtest`: empty files returns null tree | `covered` | |
| API-20 | `compute_merkle_tree` reports recorded-vs-actual root match/mismatch | `api.mbt:239` | `api_wbtest`: golden root matches, tampered manifest root mismatches | `covered` | |
| API-21 | `compute_merkle_tree` emits an example path for rendered tree focus | `api.mbt:266` | `api_wbtest`: path covers tree height and ends at root | `covered` | |
| API-22 | API-local canonical file entry fallback is defensive only | `api.mbt:302` | No direct trigger | `accepted-risk` | Constructed JSON uses strings/numbers; verified separately by proof round-trips. |
| API-23 | `create_evidence_pack` requires object `files` and hex string values | `api.mbt:334` | `api_wbtest`: missing files; fuzz null/non-object/non-string/non-hex file cases | `covered` | |
| API-24 | `create_evidence_pack` requires `subject.id` string | `api.mbt:350` | `fuzz-api-malformed.mjs`: subject wrong shape and non-string id | `covered` | |
| API-25 | `create_evidence_pack` accepts `subject.type` or `subject.kind` and rejects missing/wrong type | `api.mbt:358` | `api_wbtest`: kind alias; fuzz non-string/missing type | `covered` | |
| API-26 | `create_evidence_pack` defaults to SHA-256, accepts SHA-512, rejects unknown algorithms | `api.mbt:373` | `api_wbtest`: SHA-512 success; fuzz `md5`; smoke create uses SHA-256 | `covered` | |
| API-27 | `create_evidence_pack` requires string `version_id` and string/null `version_parent` | `api.mbt:381`, `api.mbt:384` | `fuzz-api-malformed.mjs`: wrong version_id and version_parent types | `covered` | |
| API-28 | `create_evidence_pack` output verifies through the normal verifier | `api.mbt:392` | `api_wbtest`: create then verify succeeds; `smoke-api.mjs` closed loop; `property-api-semantic.mjs` randomized create→verify loops | `covered` | |
| API-29 | `generate_proof` validates manifest/files/index request shape | `api.mbt:419`, `api.mbt:425`, `api.mbt:441` | `api_wbtest`: out-of-range index; fuzz missing/wrong manifest, files, and index | `covered` | |
| API-30 | `generate_proof` reports manifest parse errors | `api.mbt:446` | `fuzz-api-malformed.mjs`: malformed manifest text | `covered` | |
| API-31 | `generate_proof` rejects empty/out-of-range tree indexes | `api.mbt:458` | `api_wbtest`: out-of-range index rejected | `covered` | |
| API-32 | `generate_proof` returns proof/leaf/root metadata for valid inputs | `api.mbt:460` | `api_wbtest`: generate then verify proof round-trip; `smoke-api.mjs` proof closed loop; `property-api-semantic.mjs` randomized proof loops | `covered` | |
| API-33 | `generate_proof` root fallback is defensive only | `api.mbt:472` | No direct trigger | `accepted-risk` | `Some(proof)` requires a non-empty tree, so `compute_root` should also be `Some`. |
| API-34 | `verify_proof` validates leaf hex, proof shape, and root hex | `api.mbt:504`, `api.mbt:512`, `api.mbt:534` | `api_wbtest`: valid/tampered proof; fuzz leaf/proof/root malformed cases | `covered` | |
| API-35 | `verify_proof` validates each proof side and sibling hex | `api.mbt:516`, `api.mbt:521`, `api.mbt:527` | `fuzz-api-malformed.mjs`: missing fields, bad sibling hex, invalid side | `covered` | |
| API-36 | `verify_proof` validates optional algorithm and defaults to SHA-256 | `api.mbt:544` | `fuzz-api-malformed.mjs`: invalid algorithm; `api_wbtest`/smoke default SHA-256 proof | `covered` | |
| API-37 | `verify_proof` accepts valid inclusion proofs and rejects tampered leaves | `api.mbt:557` | `api_wbtest`: round-trip succeeds and tampered proof fails; `smoke-api.mjs` closed loop; `property-api-semantic.mjs` randomized valid/tampered leaves | `covered` | |
| API-38 | `audit_append` creates/loads logs and rejects invalid log JSON/type | `api.mbt:587` | `api_wbtest`: append/verify round-trip; fuzz invalid log type/text | `covered` | |
| API-39 | `audit_append` requires actor/action/subject strings and validates optional digest/timestamp | `api.mbt:598`, `api.mbt:607`, `api.mbt:613` | `fuzz-api-malformed.mjs`: wrong required and optional field types | `covered` | |
| API-40 | `audit_append` returns updated log and entry hash after append | `api.mbt:624` | `api_wbtest`: multi-entry append round-trip; `smoke-api.mjs` two-entry log; `property-api-semantic.mjs` randomized audit chains | `covered` | |
| API-41 | `audit_append` empty-log last-hash fallback is defensive only | `api.mbt:624` | No direct trigger | `accepted-risk` | A successful append makes length non-zero before reading the last hash. |
| API-42 | `audit_verify` validates log JSON/type and reports chain validity | `api.mbt:654` | `api_wbtest`: tampered log invalid; fuzz invalid log type/text; `property-api-semantic.mjs` randomized tampered chain rejection | `covered` | |
| API-43 | `audit_verify` defaults signature verification off | `api.mbt:665` | `api_wbtest`: verify_signatures false/default | `covered` | |
| API-44 | `audit_verify` requires a valid 32-byte public key when signature verification is enabled | `api.mbt:670` | `api_wbtest`: valid signed log; fuzz missing/wrong/invalid/short public key | `covered` | |
| API-45 | `audit_verify` validates signatures and detects tampering | `api.mbt:684` | `api_wbtest`: valid signature and tampered signature cases; `smoke-api.mjs` signed audit loop; `property-api-semantic.mjs` randomized signed audit tamper rejection | `covered` | |
| API-46 | `audit_sign` validates log JSON/type and 32-byte secret key | `api.mbt:721`, `api.mbt:730`, `api.mbt:736` | `api_wbtest`: sign last entry; fuzz invalid log, secret key type/hex/length | `covered` | |
| API-47 | `ed25519_keypair` validates optional 32-byte seed and warns on demo seed | `api.mbt:765`, `api.mbt:785` | `api_wbtest`: explicit seed round-trip and demo warning; fuzz seed type/hex/length | `covered` | |
| API-48 | `ed25519_sign` validates secret key and message hex before signing | `api.mbt:815`, `api.mbt:824` | `api_wbtest`: sign/verify round-trip; fuzz bad secret key/message cases | `covered` | |
| API-49 | `ed25519_verify` validates public key/message/signature hex and lengths, then returns semantic validity | `api.mbt:848`, `api.mbt:866` | `api_wbtest`: valid signature and wrong message; fuzz bad pk/message/signature type/hex/length; `property-api-semantic.mjs` randomized valid/tampered message checks | `covered` | |
| API-50 | `verify_evidence` accepts an absent/null external digest without changing existing semantics | `verify_evidence` external-anchor parse | Existing golden/tampered tests plus API smoke without the field | `covered` | Additive compatibility branch. |
| API-51 | `verify_evidence` rejects non-string or non-canonical external digests at the adapter boundary | `verify_evidence` external-anchor parse | `api_wbtest` malformed digest; `fuzz-api-malformed.mjs` wrong type and uppercase/truncated form; smoke malformed-anchor assertion | `covered` | Prevents ambiguous ledger keys. |
| API-52 | A canonical matching external digest passes and a canonical mismatch produces exactly E2004 | `verify_evidence` call into `verify_manifest` | `api_wbtest` match/mismatch; smoke exact E2004; `property-api-semantic.mjs` uses independent Node hash for randomized match/reject loops | `oracle-covered` | External oracle breaks create/verify self-cycle. |

## CLI Machine Adapter

File: `src/cmd/main/main.mbt`

| ID | Branch / Invariant | Source | Evidence | Status | Notes |
| --- | --- | --- | --- | --- | --- |
| CM-01 | `inspect` emits the independently fixed golden manifest digest | `run_inspect` | PowerShell/bash machine case `inspect golden digest` | `oracle-covered` | Golden digest was computed outside MoonBit. |
| CM-02 | External digest match passes; canonical mismatch returns exactly E2004; malformed form exits 2 | `run_verify` / `run_verify_single` | Three exact machine cases in both CLI suites | `oracle-covered` | Exercises full process boundary. |
| CM-03 | `pack` copies every nested input, including a source file named `manifest.json`, into a new `files/` tree and its returned digest verifies | `run_pack` | `pack nested source` case in both shells | `covered` | Tests layout, reserved-name preservation, and pack->verify loop. |
| CM-04 | Existing output is rejected without changing its manifest | `run_pack` overwrite guard | Before/after SHA-256 assertion in both shells | `oracle-covered` | Prevents destructive retries. |
| CM-05 | `seal` behaves as an exact alias | command dispatch | `seal alias` in both shells | `covered` | |
| CM-06 | `create --json` is additive and returns a digest accepted by verify | `run_create` JSON branch | `create JSON metadata` in both shells | `covered` | Legacy layout remains available. |
| CM-07 | Depth/file caps abort before silent partial packaging | `collect_create_files` / `run_pack` | Existing create depth-cap black-box plus pack shares the same collector | `covered` | Pack output is created only after collection and manifest construction. |
| CM-08 | A write failure rolls back only the newly created output tree | `remove_created_tree` | Source review + output-ownership guard; no portable deterministic filesystem failure injection | `accepted-risk` | Existing output is rejected before rollback can run, so pre-existing user data is outside rollback ownership. |

## Fabric Adapter

Files: `integrations/fabric/chaincode-go`, `integrations/fabric/gateway`

| ID | Branch / Invariant | Evidence | Status | Notes |
| --- | --- | --- | --- | --- |
| F-01 | Chaincode rejects non-canonical SHA-256/SHA-512 digests | Go unit boundary table | `covered` | |
| F-02 | First create stores schema/digest/tx/MSP and emits one event | Go first-write test | `covered` | State derives from Fabric context. |
| F-03 | Sequential duplicate preserves state and emits no second event | Go idempotency test + real Org2 duplicate | `protocol-covered` | Original anchor tx remains unchanged. |
| F-04 | Missing, read/write/event, empty identity, and empty tx ID paths fail with stable prefixes | Go failure tests | `covered` | |
| F-05 | Corrupt existing state is rejected and never overwritten | Go corrupt-state table | `covered` | |
| F-06 | Gateway profile rejects bad schema, missing files, invalid timeout values, and a malformed timeout section | Node profile tests | `covered` | Real credentials remain local/ignored. |
| F-07 | Commit receipt preserves tx ID, block, status code, and success | Node submit tests + real block 6 receipt | `protocol-covered` | |
| F-08 | Only validation code 11 (MVCC read conflict) can normalize after a matching ledger query; all other rejected commits remain errors | Node conflict positive/negative/non-MVCC tests | `covered` | Actual race outcome is nondeterministic, so branch is deterministic at adapter unit level. |
| F-09 | Org1 and Org2 query the same immutable anchor | Real Fabric v3.1.4 record | `protocol-covered` | `transactions.json` records equality. |
| F-10 | Ledger-backfed verification distinguishes payload tamper E2003 from regenerated-manifest E2004 | Real Fabric E2E `verification.json` | `protocol-covered` | Closes the actual user trust loop. |
| F-11 | The Gateway rejects incomplete MoonBit inspect/verify envelopes and inconsistent process exit status | Node fake-process contract tests | `covered` | Prevents adapter success on a drifted or malformed local CLI response. |
| F-12 | A first-write chaincode response must record the same transaction ID as the successful commit | Node response/receipt test | `covered` | Sequential duplicates may correctly preserve an earlier transaction ID. |

## Open Follow-Ups

| Priority | Item | Reason |
| --- | --- | --- |
| P2 | Run and record stress randomized-hardening profile before a final tag. | Done 2026-07-06 as captured split run: 10000 malformed, 1000 semantic, 5000 Ed25519 differential, 5000 digest differential all passed. |
