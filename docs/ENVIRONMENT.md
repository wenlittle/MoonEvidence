# Environment Setup

This file records prerequisites and current local state.

## Required Tools

| Tool | Purpose | Current local state |
| --- | --- | --- |
| Git | Repository, commits, GitHub/GitLink sync | Found: `D:\Git\cmd\git.exe` |
| MoonBit CLI (`moon`) | Build, check, test, package docs | Relocated to `D:\Programming_Language\MoonBit\bin\moon.exe`; current Codex parent PATH may need restart |
| PowerShell | Local scripts and checks | Available |
| Node.js | Optional comparison scripts and demo helpers | Found: `D:\Programming_Language\Node\node.exe` |
| GitHub account | Public repository and CI | To be prepared |
| GitLink account | Competition mirror repository | To be prepared |

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

## Current Blocker

As of 2026-06-08 Asia/Shanghai, MoonBit CLI is installed, relocated to D drive, and direct invocation works. The first local version observed is `moon 0.1.20260529`.

Current toolchain generates `moon.mod` and `moon.pkg`, not `moon.mod.json` and `moon.pkg.json`.

## PATH

Recommended user PATH entry:

```text
D:\Programming_Language\MoonBit\bin
```

The old entry `C:\Users\starlittle\.moon\bin` should be removed or placed after the D-drive entry.
