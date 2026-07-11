# cmd/main

Filesystem/process adapter for the MoonEvidence library. It is compiled for JS
and native targets while delegating manifest, digest, Merkle, version-chain,
and diagnostic semantics to pure MoonBit packages.

```text
moon-evidence pack <source-dir> -o <pack-dir> [--json]
moon-evidence inspect <pack-path> [--json]
moon-evidence verify <pack-path> [--json]
                              [--expected-manifest-digest <digest>]
moon-evidence explain <pack-path>
moon-evidence create <existing-dir> --subject-id <id> [--json]
```

`seal` is an exact alias for `pack`. `pack`, `create`, and `inspect` expose
versioned JSON envelopes for automation. Exit codes are frozen: 0 success, 1
verification rejection, 2 usage or IO failure.

Directory-mode verification treats `<pack-path>/files/` as the complete
payload inventory. A missing or unreadable tree, an unreadable listed file or
version chain, or a depth/file cap stops the command with exit 2. A listed file
that is genuinely absent remains an evidence rejection (`E2003`, exit 1).
`create` keeps its manifest-in-place compatibility layout; verify that output
by passing its manifest path. `pack` is the self-contained handoff format.

The process contract consumed by external ledger adapters is frozen in
`docs/spec/CLI_MACHINE_CONTRACT.md`. The CLI remains thin: external adapters
must consume its digest instead of reimplementing evidence canonicalization.
