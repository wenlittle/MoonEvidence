# Environment Setup

This file records prerequisites and current local state.

## Required Tools

| Tool | Purpose | Current local state |
| --- | --- | --- |
| Git | Repository, commits, GitHub/GitLink sync | Found: `D:\Git\cmd\git.exe` |
| MoonBit CLI (`moon`) | Build, check, test, package docs | Relocated to `D:\Programming_Language\MoonBit\bin\moon.exe`; current Codex parent PATH may need restart |
| PowerShell | Local scripts and checks | Available |
| Node.js | Required CI/reference tools, web app, and Fabric Gateway | Found: v24.12.0 at `D:\Programming_Language\Node\node.exe` |
| C compiler | MoonBit native build/test | MSVC 19.44 + Windows SDK 10.0.26100.0 verified |
| Go | Optional Fabric Chaincode build/test | Found: go1.25.0 Windows; chaincode module targets Go 1.23 |
| Docker Desktop | Optional real Fabric integration | Engine 27.4.0 verified |
| Hyperledger Fabric samples | Optional two-organization anchor E2E | Fabric v3.1.4 peer/orderer runtime verified in WSL |
| GitHub account | Public repository and CI | Public `wenlittle/MoonEvidence` configured |
| GitLink account | Competition mirror repository | Public `starlittle/MoonEvidence` configured |

## MoonBit Toolchain

Official download page:

```text
https://www.moonbitlang.com/download/
```

After installation, verify:

```powershell
moon version
moon check
moon test
```

If `moon` is installed but not found, restart the terminal and check PATH.
Direct invocation works:

```powershell
& "D:\Programming_Language\MoonBit\bin\moon.exe" version
```

## Local Environment Check

Run:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\env-check.ps1
```

The script is read-only. It checks tool availability and Mooncakes API reachability.

## Current State

As of 2026-07-11 Asia/Shanghai, MoonBit portable and native backends, Node.js,
Go, Docker Desktop, and the Fabric two-organization integration have all been
exercised locally. The MoonBit version remains `moon 0.1.20260529`.

Current toolchain generates `moon.mod` and `moon.pkg`, not `moon.mod.json` and `moon.pkg.json`.

Fabric credentials and Gateway profiles are local runtime material. Keep them
under `integrations/fabric/gateway/.local/` (Git ignored); use
`integrations/fabric/gateway/profiles/test-network-org1.example.json` only as a
shape template. Full setup is in `integrations/fabric/README.md`.

## PATH

Recommended user PATH entry:

```text
D:\Programming_Language\MoonBit\bin
```

The old entry `C:\Users\starlittle\.moon\bin` should be removed or placed after the D-drive entry.
