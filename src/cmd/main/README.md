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

The process contract consumed by external ledger adapters is frozen in
`docs/spec/CLI_MACHINE_CONTRACT.md`. The CLI remains thin: external adapters
must consume its digest instead of reimplementing evidence canonicalization.
