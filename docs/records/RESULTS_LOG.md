# Results Log

This file records measured results, source checks, and environment status. Keep entries timestamped and source-linked.

## 2026-06-08 Asia/Shanghai

### Competition Requirement Check

| Field | Result |
| --- | --- |
| Source | `E:\大学\交作业\区块链技术与应用\大项目\比赛要求.txt` |
| Method | Read local requirement file |
| Key result | Competition focuses on MoonBit open-source ecosystem projects with clear function, real use scenario, reusable value, 4-10k effective MoonBit LOC, README, CI, tests, GitHub and GitLink repositories |
| Impact | MoonEvidence should be framed as a reusable MoonBit library/CLI, not a vertical business system |
| Confidence | High for the local requirement file |

### Mooncakes Collision Check

| Field | Result |
| --- | --- |
| Source | `https://mooncakes.io/api/v0/modules` |
| Method | Queried modules API and filtered keywords |
| Key result | API returned 1310 modules; `evidence`, `provenance`, `attestation`, `notarization`, and `moonevidence` had no direct hit; `merkle` and `content-addressed` hit `zploc/loci` |
| Impact | Avoid Merkle-only positioning; emphasize evidence pack schema, version chain, and explainable diagnostics |
| Confidence | Medium-high. API was reachable but occasionally disconnected, so rerun before final submission |

### External Research Report Review

| Field | Result |
| --- | --- |
| Source | `E:\edge_download\deep-research-report (3).md` |
| Method | Reviewed project positioning, scope, package plan, and risk section |
| Key result | Recommendation aligns with current plan: MoonEvidence should be a MoonBit trusted evidence pack verification library and CLI |
| Adjustment | Treat `0Ayachi0/MerkleTree` as unconfirmed on Mooncakes unless revalidated; only `zploc/loci` was confirmed via Mooncakes API in this session |
| Confidence | Medium-high |

### Local Toolchain Check

| Tool | Result |
| --- | --- |
| Git | Found: `D:\Git\cmd\git.exe`, version `git version 2.52.0.windows.1` |
| Node.js | Found: `D:\Programming_Language\Node\node.exe`, version `v24.12.0` |
| npm | Found: `D:\Programming_Language\Node\npm.ps1`, version `11.6.2` |
| MoonBit CLI | Initially not found in Codex parent PATH; installed to `C:\Users\starlittle\.moon\bin\moon.exe` and direct invocation works |
| Git repository | Current course root is not a Git repository |

### Environment Script Check

| Field | Result |
| --- | --- |
| Source | `tools/env-check.ps1` |
| Method | Ran `powershell -ExecutionPolicy Bypass -File .\tools\env-check.ps1` |
| Network result | `https://mooncakes.io/api/v0/modules` returned HTTP 200; `https://www.moonbitlang.com/download/` returned HTTP 200 |
| Tool result | Git, Node.js, and npm found; MoonBit CLI not found |
| Impact | Environment can reach required project websites, but MoonBit toolchain installation remains the first blocker |

### MoonBit CLI Installation

| Field | Result |
| --- | --- |
| Source | Official MoonBit download page command: `https://www.moonbitlang.com/download/` |
| Method | Ran `Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force; irm https://cli.moonbitlang.com/install/powershell.ps1 \| iex` |
| Installed path | `C:\Users\starlittle\.moon\bin` |
| Version | `moon 0.1.20260529 (3e1c753 2026-05-29)` |
| Important observation | Current toolchain feature flags include `rr_moon_mod` and `rr_moon_pkg`; `moon new` generates `moon.mod` and `moon.pkg`, not JSON-named config files |
| Impact | Project config should use `moon.mod` / `moon.pkg` and be validated with the real CLI |

### MoonBit CLI Relocation to D Drive

| Field | Result |
| --- | --- |
| Source | Local filesystem and user PATH |
| Method | Copied `C:\Users\starlittle\.moon` to `D:\Programming_Language\MoonBit`; replaced user PATH entry `C:\Users\starlittle\.moon\bin` with `D:\Programming_Language\MoonBit\bin` |
| Verification | `D:\Programming_Language\MoonBit\bin\moon.exe version` works; `moon test` passed with 9/9 tests after relocation |
| Backup | Old `C:\Users\starlittle\.moon` directory is still present as backup |
| Note | Existing Codex app child processes may not inherit the changed user PATH until terminal/app restart |

### First MoonBit Package Implementation

| Field | Result |
| --- | --- |
| Source | Local implementation under `src/canonjson` and `src/digest` |
| Method | Added real MoonBit module config and first package files |
| Scope | `canonjson` compact canonical payload helpers; `digest` algorithm/hex normalization and digest parsing |
| Verification | `moon check` passed; `moon test` passed with 9/9 tests; `moon build --target native` passed |
| Important fix | `core/json.stringify()` preserves object order, so `canonjson` now recursively sorts object keys before rendering |


## 2026-06-10 Asia/Shanghai (master plan step 0)

### Local CI Gate Verification

| Field | Result |
| --- | --- |
| Source | Local toolchain `moon 0.1.20260529` at `D:\Programming_Language\MoonBit\bin` |
| Method | Ran the exact three commands used by `.github/workflows/ci.yml` |
| Key result | `moon check` exit 0; `moon test` 9/9 passed; `moon build --target native` exit 0 |
| Impact | CI workflow committed only after local green, per workflows/README rule |
| Confidence | High |

### Mooncakes Collision Recheck (application gate)

| Field | Result |
| --- | --- |
| Source | `https://mooncakes.io/api/v0/modules` |
| Method | Matched `name + description + keywords` over 1315 modules with positive control `loci` (hit confirmed, validating the matcher) |
| Key result | All evidence/provenance/attestation/notary keywords: no hit; `merkle` / `content-addressed` still only `zploc/loci` (runtime substrate, no scope overlap); new keywords `jcs` / `canonical` / `8785` / `integrity` / `manifest`: no hit |
| Impact | Differentiation claim holds; "first RFC 8785 implementation in ecosystem" claim now has recorded evidence; details in `docs/research/MOONCAKES_COLLISION_CHECK.md` |
| Confidence | High (positive control validated; API stable this session) |

### Step 0 Deliverable Status

| Task | Status |
| --- | --- |
| 0.1 spec v1 freeze (merkle boundary) | Done earlier (commit 7f9674d) |
| 0.2 error code table freeze | Done earlier (commit ac9455f) |
| 0.3 public API freeze in ARCHITECTURE | Done earlier (commit c7252dd) |
| 0.4 GitHub Actions CI + README badge | Done (commit 9f4227f); badge turns green after next push |
| 0.5 Gitlink mirror | Blocked on user account action |
| 0.6 application draft | Done (commit fceed07, `docs/application/OSC2026_APPLICATION.md`); personal info + PDF export pending user |
| 0.7 Mooncakes collision recheck | Done (commit c6a8d3f) |
| Acceptance: commits >= 10 | Met (11 commits on main) |

## 2026-06-11 Asia/Shanghai (master plan step 1)

### NIST Vector Verification (SHA-256)

| Field | Result |
| --- | --- |
| Source | FIPS 180-4 appendix examples + NIST CAVP SHA256ShortMsg, encoded in `src/digest/sha256_wbtest.mbt` |
| Method | `moon test` runs every vector as an `inspect` assertion against the official lowercase hex digest |
| Vectors passed | empty string, `"abc"`, 448-bit two-block message, 896-bit three-block message, one million `'a'` (streamed in 1000-byte chunks), chunk-size invariance across 64-byte block boundaries (sizes 1/7/63/64/65/129) |
| Cross-check | UTF-8 transcoding digests cross-validated against .NET `System.Text.Encoding.UTF8` + SHA256 golden values (`src/digest/utf8_wbtest.mbt`) |
| Confidence | High (official vectors plus independent reference implementation) |

### Step 1 Deliverable Status

| Task | Status |
| --- | --- |
| 1.1 FIPS 180-4 SHA-256 (one-shot + streaming `Sha256Ctx`) | Done (commits b3f3c4c, c3ddde9) |
| 1.2 NIST vector test suite | Done (commit b3f3c4c, extended by c3ddde9) |
| 1.3 `Digest::of_bytes(algorithm, data)` factory | Done this session: wraps `sha256_hex` under the tagged `Digest` type, with NIST-vector and text-form round-trip tests |
| 1.4 UTF-8 helper `string_to_utf8_bytes` | Done (commit f8e5c52) with surrogate-pair and boundary tests |
| Acceptance: `moon test` all green | Met: `moon check` 0 warnings 0 errors; `moon test` 29/29 passed; `moon build --target native` exit 0 |

### Toolchain Observation: Show derivation deprecated

| Field | Result |
| --- | --- |
| Source | `moon 0.1.20260529` warning on `derive(Show)` |
| Method | `assert_eq` in tests requires `Show`; tried `derive(Show)` (deprecated warning) and `derive(Debug)` (does not satisfy `Show`) |
| Resolution | Implement `Show` manually for `HashAlgorithm` (renders `sha256`) and `Digest` (renders `algorithm:hex`), matching evidence-pack text form |
| Impact | Future packages (model, diag) should implement `Show` manually instead of deriving it |

## 2026-06-11 Asia/Shanghai (master plan step 2)

### Critical Finding: MoonBit String compare is shortlex, not RFC 8785 order

| Field | Result |
| --- | --- |
| Source | `D:\Programming_Language\MoonBit\lib\core\builtin\string.mbt` (`impl Compare for String`, doc comment "shortlex order by their charcodes") |
| Method | Read core source before implementing key ordering |
| Key result | Builtin compare sorts by length first, then code units; it would order `"b" < "aa"`, violating RFC 8785 section 3.2.3 pure lexicographic code-unit order |
| Impact | The master plan assumption "UTF-16 code unit order matches MoonBit default comparison" is WRONG; the previous canonjson sort (using `left_key.compare(right_key)`) produced non-JCS output for keys of different lengths. Step 2 replaced it with a custom `compare_code_units` and pinned regression tests (`"b"/"aa"`, surrogate-pair vs BMP key) |
| Confidence | High (core source + failing-order test would have caught it) |

### JCS Vector Verification (canonjson)

| Field | Result |
| --- | --- |
| Source | RFC 8785 section 3.2.3 sorting example; cyberphone/json-canonicalization testdata (french, structures, arrays), mirrored in `tests/fixtures/jcs/` and inlined in `src/canonjson/canonjson_jcs_wbtest.mbt` |
| Method | `moon test` asserts canonical output equals the official expected bytes, plus a fixed-point (idempotency) assertion per vector |
| Vectors passed | rfc8785-sorting (surrogate pair before U+FB33), french (locale ignored), structures (empty key, string-not-number key order, 56.0 -> 56), arrays |
| Skipped | Number-formatting vectors requiring L2 shortest-form rendering; documented with reasons in `tests/fixtures/jcs/SKIPPED.md`, each guarded by an `UnsupportedNumber` negative test |
| Confidence | High for the implemented scope |

### Step 2 Deliverable Status

| Task | Status |
| --- | --- |
| 2.1 self-implemented JCS string escaping | Done (commit baacdab): exact escape set `\" \\ \b \f \n \r \t` + lowercase `\u00xx` below U+0020; `/`, U+007F, non-ASCII verbatim |
| 2.2 UTF-16 code-unit key ordering | Done (commit baacdab) via custom comparator (see critical finding above), surrogate-pair test included |
| 2.3 number policy L1 safe subset | Done (commit baacdab): exact integers within 2^53-1 render plain (`-0 -> 0`, `5.0 -> 5`, `1e2 -> 100`); fractions, lossy integers, overflow all raise `CanonError::UnsupportedNumber` |
| 2.4 official JCS vectors | Done this session: 4 vectors green, skip list documented |
| 2.5 idempotency tests | Done: fixed-point assertion on every vector plus a mixed-document case |
| Acceptance | `moon check` exit 0 (0 warnings); `moon test` 52/52 passed; `moon build --target native` exit 0 |

### API Change Note

`@canonjson.canonicalize` now raises `CanonError` (ParseFailed / UnsupportedNumber) instead of leaking `@json.ParseError`, matching the frozen signature in `docs/ARCHITECTURE.md`. `canonicalize_or_none` and `same_canonical_payload` keep their shapes.

## 2026-06-11 Asia/Shanghai (master plan step 3)

### Merkle Cross-Validation Against Independent Reference

| Field | Result |
| --- | --- |
| Source | `tools/gen-merkle-fixtures.mjs` (Node.js v24, `node:crypto`) implementing the same frozen boundary; output committed as `tests/fixtures/merkle/golden.json` |
| Method | Reference generates roots and inclusion proofs for shapes 1/2/3/4/5/8 over payloads `leaf-0..n`; MoonBit tests assert byte-identical roots (all shapes) and proof structures (8-leaf index 3, 5-leaf promoted index 4) |
| Key result | All golden roots and pinned proofs match; promotion semantics independently confirmed (5th leaf joins the 4-leaf subtree root LEFT-side in a single step) |
| Confidence | High (two independent codebases agree) |

### Step 3 Deliverable Status

| Task | Status |
| --- | --- |
| 3.1 merkle.mbt API (leaf_hash / node_hash / compute_root / ProofStep / verify_inclusion) | Done (commit 27e06ca) per frozen ARCHITECTURE signatures; `compute_proof` added as a documented helper beyond the minimum set (needed by round-trip tests, step-8 property tests, and the step-9 demo) |
| 3.2 odd-level promotion policy | Done: unpaired nodes promoted as-is, never self-paired; CVE-2012-2459 cited in code and pinned by a test asserting the self-paired root differs |
| 3.3 defensive test matrix | Done: empty/1/2/3/4/5/8 shapes, forged sibling, flipped side, truncated/extended proof, wrong leaf, domain-separation collision checks |
| 3.4 reference cross-check | Done this session (see above) |
| Acceptance | `moon check` exit 0 (0 warnings); `moon test` 70/70 passed; `moon build --target native` exit 0 |

### Toolchain Observation: assert_eq Show deprecation for user types

| Field | Result |
| --- | --- |
| Source | `moon 0.1.20260529` warning [0020] on builtin `assert_eq` over `Array[ProofStep]` |
| Method | Builtin `assert_eq` requires `Eq + Show` (deprecated for debugging); `@debug.assert_eq` requires `Eq + Debug` |
| Resolution | Custom structs derive `@debug.Debug` (requires importing `moonbitlang/core/debug` in moon.pkg) and tests use `@debug.assert_eq` for struct comparisons; manual `Show` impls kept for wire-form rendering (`Side` prints `left`/`right`) |
| Impact | Same pattern applies to model/diag packages in steps 4-5 |

## 2026-06-11 Asia/Shanghai (master plan step 4)

### Step 4 Deliverable Status

| Task | Status |
| --- | --- |
| 4.1 manifest model + validation | Done: `Manifest/Subject/FileEntry/VersionRef` with full rule set (schema id, supported algorithm, non-empty unique paths, canonical digest form, integer size bounds, version stamp); `subject.type` maps to field `kind` (MoonBit keyword) |
| 4.2 version chain model | Done: `VersionNode` + `parse_version_chain` over a bare-array file shape (spec gap pinned; see DECISION_LOG 2026-06-11) |
| 4.3 ModelError <-> error code map | Done: six variants -> E1001/E1002/E1003/E2001/E2002 via `error_code()`; every variant carries field-path context (e.g. `files[1].path`); Show renders `[code] path: detail` |
| 4.4 table-driven tests + fixtures | Done: valid sample + 14 invalid manifest samples + 4 chain samples in `tests/fixtures/{manifest,version-chain}/` (expected-code table in fixtures README), mirrored inline in wbtests with exact code AND message assertions |
| Acceptance | `moon check` exit 0 (0 warnings); `moon test` 95/95 passed; `moon build --target native` exit 0 |

### Design Note: canonical digest strings enforced at parse time

| Field | Result |
| --- | --- |
| Source | `src/model/manifest.mbt` `expect_digest` |
| Method | Digest strings must round-trip (`parse_digest(text).to_string() == text`), forcing lowercase canonical form at the model boundary |
| Impact | Merkle leaf hashing re-renders `files[]` entries byte-exactly from the model, so an uppercase digest in a manifest cannot silently produce a different leaf hash than the packer computed; it is rejected as E2002 instead |
| Note | Digest algorithm must also match `hash_algorithm`; the mismatch branch is untestable while only sha256 is supported and will activate when a second algorithm lands |

## 2026-06-11 Asia/Shanghai (master plan step 5)

### End-to-End Golden Pack Cross-Check

| Field | Result |
| --- | --- |
| Source | `tools/gen-pack-fixture.mjs` (independent Node implementation of digests, canonical entries, and the Merkle root) |
| Method | Node computes the golden pack's file digests, canonical manifest digest, and Merkle root; MoonBit `verify_manifest` must return ok with zero findings against those values |
| Key result | Valid pack verifies green end to end, including the optional `expected_manifest_digest` (E2004) path - the full pipeline (canonjson -> digest -> merkle -> model -> verify) agrees with the reference implementation |
| Confidence | High |

### Step 5 Deliverable Status

| Task | Status |
| --- | --- |
| 5.1 diag package | Done: `Severity/Finding/CheckStats/VerifyReport` + `explain` + `to_json` (canonical JSON via canonjson, digest-stable report bytes); CheckStats pinned as files_total/files_passed/merkle_checked with error/warning counts derived |
| 5.2 verify pipeline | Done: parse -> canonicalize (E1004) -> recorded manifest digest (E2004, optional arg) -> file digests (E2003, exhaustive) -> unlisted files (W1001, warning keeps ok) -> Merkle root (E3001/E3003); pure core, files injected as `Map[String, Bytes]` |
| 5.3 version chain verification | Done: E4001 empty, E4002 broken parent, E4003 cycle (no-root and detached), E4004 duplicate id / multiple roots / fork; `ChainReport.ordered_ids` holds the walked prefix on failure |
| 5.4 explain format frozen | Done: verdict line + one finding per line + summary tail; README "Diagnostics Preview" section added |
| Acceptance | Every frozen code E1001-E4004 plus W1001 has a triggering test; valid pack = ok with zero findings; `moon check` 0 warnings; `moon test` 125/125; native build exit 0 |

### Semantics Note: what the Merkle root attests

Content tampering alone trips E2003 but NOT E3003: the tree is built over
canonical manifest entries, which are unchanged. Editing a digest inside the
manifest trips both (entry changed -> root drifts; file no longer matches the
edited digest). A test pins each behavior so the demo narrative ("which line
of defense caught what") stays accurate.

## Logging Rule

Whenever a result is used in README, report, or application material, add or update an entry here with source, method, result, and confidence.
