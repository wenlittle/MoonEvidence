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


## Logging Rule

Whenever a result is used in README, report, or application material, add or update an entry here with source, method, result, and confidence.
