# CLI Machine Contract

Status: frozen for the Fabric anchor v1 integration.

This contract defines the process boundary used by automation and ledger
adapters. MoonBit remains the only component that creates, canonicalizes, and
verifies evidence manifests. External adapters consume the fields below and
must not recompute evidence digests.

## Commands

### `pack`

```text
moon-evidence pack <source-dir> [-o <pack-dir>] [--subject-id <id>]
                       [--subject-type <type>] [--algorithm sha256|sha512]
                       [--version-id <id>] [--version-parent <id>] [--json]
```

`seal` is an exact alias. The command creates a new evidence-pack directory:

```text
<pack-dir>/
  manifest.json
  files/...
```

The output directory must not already exist. On failure after directory
creation, the command removes the partial output. If `--subject-id` is absent,
the source directory basename is used. If `-o` is absent, the output is
`<source-basename>-evidence-pack` in the current directory. Every regular input
path is copied below `files/`; a source file named `manifest.json` becomes
`files/manifest.json` and is not confused with the generated root manifest.

With `--json`, success emits exactly one JSON object on stdout:

```json
{
  "algorithm": "sha256",
  "files_total": 2,
  "manifest_digest": "sha256:<lowercase-hex>",
  "manifest_path": "my-pack/manifest.json",
  "merkle_root": "sha256:<lowercase-hex>",
  "ok": true,
  "pack_path": "my-pack",
  "schema": "moon-evidence-pack-result/v1",
  "subject": { "id": "dataset-001", "type": "dataset" },
  "version": { "id": "v1", "parent": null }
}
```

### `inspect`

```text
moon-evidence inspect [--json] <pack-or-manifest>
```

`inspect` parses and canonicalizes the manifest, then reports its anchor
metadata. It does not replace payload verification; ledger adapters must run
`verify --json` successfully before submitting this digest.

The JSON success envelope uses schema `moon-evidence-inspect/v1` and contains
the same manifest metadata fields as `pack`, plus `manifest_path` and
`pack_path`.

### External digest verification

```text
moon-evidence verify --json \
  --expected-manifest-digest sha256:<lowercase-hex> <pack>
```

The supplied digest must be canonical. A well-formed value that differs from
the canonical manifest digest produces verification finding `E2004` and exit
code `1`. A malformed value is a usage error and produces exit code `2`.

## Errors And Exit Codes

Exit codes remain compatible with the existing CLI:

| Exit | Meaning |
| --- | --- |
| `0` | Command succeeded or verification passed |
| `1` | Verification completed and rejected the evidence |
| `2` | Usage or IO failure |

For `pack --json` and `inspect --json`, an exit-2 failure emits exactly one
JSON object:

```json
{
  "error": { "code": "E5002", "message": "...", "path": "..." },
  "ok": false,
  "schema": "moon-evidence-cli-error/v1"
}
```

Progress and warnings are written to stderr. Consumers branch on `ok`,
`schema`, `error.code`, and process exit code; human-readable messages are not
stable API fields.

## Compatibility

- Existing `create` behavior remains available for callers that intentionally
  create a manifest in an existing directory.
- `create --json` is additive and uses the pack-result envelope with
  `pack_path` set to the input directory.
- Existing `verify` report fields remain unchanged. The external digest flag
  only activates the already-public `verify_manifest` E2004 assertion.
- Unknown response fields must be ignored by consumers.
