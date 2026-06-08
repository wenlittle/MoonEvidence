# Environment Setup

This file records prerequisites and current local state.

## Required Tools

| Tool | Purpose | Current local state |
| --- | --- | --- |
| Git | Repository, commits, GitHub/GitLink sync | Found: `D:\Git\cmd\git.exe` |
| MoonBit CLI (`moon`) | Build, check, test, package docs | Not found in current PATH |
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

## Local Environment Check

Run:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\env-check.ps1
```

The script is read-only. It checks tool availability and Mooncakes API reachability.

## Current Blocker

As of 2026-06-08 Asia/Shanghai, `moon version` fails locally because `moon` is not recognized. Do not claim the project builds until this is fixed and logged.

