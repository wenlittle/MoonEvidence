# Branch Coverage Audit

> Last updated: 2026-07-06 Asia/Shanghai. Scope for this first pass:
> `verify`, `incremental`, and `merkle` trust boundaries.

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

The current audited surface has no open `gap` items. This does not mean the
whole project is fully covered; it means these three trust boundaries now have
an explicit branch map. The next pass should extend the same table to
`digest`, `crypto`, `create`, `store`, and `audit`.

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

## Open Follow-Ups

| Priority | Item | Reason |
| --- | --- | --- |
| P1 | Extend this audit to `digest`, `crypto`, `create`, `store`, and `audit`. | The current pass covers the main verification/Merkle trust boundary, not every package. |
| P1 | Add a lightweight script or checklist gate that fails when this file is stale after touching audited files. | Manual branch maps can drift unless the workflow names the update requirement. |
| P2 | Add fuzz/property tests for malformed public JS API requests. | CLI/API shape errors are user-facing and broader than the pure core. |
