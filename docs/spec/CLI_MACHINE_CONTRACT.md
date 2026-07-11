# CLI Machine Contract

Status: current v0.5.x process contract for automation and Fabric anchor v1.

MoonBit creates, canonicalizes, and verifies evidence manifests. Process
adapters consume the outputs defined here and preserve MoonBit as the single
evidence-semantics authority.

## Contract Surfaces

The CLI exposes two success surfaces. Command failures use the versioned error
envelope where listed below or text for command-level preflight paths:

| Surface | Commands | Version marker |
| --- | --- | --- |
| Manifest receipt | `pack --json`, `seal --json`, `create --json`, `inspect --json` | `schema` field |
| Verification report | single-pack `verify --json` | CLI v0.5.x contract, fields `ok`, `findings`, `stats` |

Consumers combine the JSON shape with the process exit code. Human-readable
text-mode rendering is outside the machine contract.

## Pack

```text
moon-evidence pack <source-dir> [-o <pack-dir>] [--subject-id <id>]
                       [--subject-type <type>] [--algorithm sha256|sha512]
                       [--version-id <id>] [--version-parent <id>] [--json]
```

`seal` is an exact alias. The command creates a new directory:

```text
<pack-dir>/
  manifest.json
  files/...
```

The output path must be absent. The command collects the complete input before
writing and removes its newly created partial tree after a write failure. A
source file named `manifest.json` becomes `files/manifest.json`.

Defaults:

- `subject.id`: source directory basename;
- `subject.type`: `generic`;
- algorithm: `sha256`;
- version ID: `v1`;
- output: `<source-basename>-evidence-pack` in the current directory.

Successful JSON receipt:

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

## Create

```text
moon-evidence create <dir> --subject-id <id> [--subject-type <type>]
                     [--algorithm sha256|sha512] [--version-id <id>]
                     [--version-parent <id>] [-o <manifest-path>] [--json]
```

`create` writes a manifest for files already located in the target directory.
Its JSON success result uses `moon-evidence-pack-result/v1`, with `pack_path`
set to the input directory.

## Inspect

```text
moon-evidence inspect [--json] <pack-or-manifest>
```

`inspect` parses and canonicalizes the manifest, then returns anchor metadata.
Its success receipt uses `moon-evidence-inspect/v1` and the same metadata fields
as `pack`.

`inspect` performs no payload verification. The standard Fabric `anchor-pack`
workflow runs both `inspect --json` and complete `verify --json` before any
network call. Lower-level submitters own the same precondition.

## Verify

```text
moon-evidence verify [--json] [--incremental <cache-dir>]
                     [--expected-manifest-digest <digest>] <pack>
```

For one pack, `--json` emits one canonical `VerifyReport` object:

```json
{
  "findings": [],
  "ok": true,
  "stats": {
    "files_passed": 2,
    "files_total": 2,
    "merkle_checked": true
  }
}
```

A rejected pack keeps the same shape and adds exhaustive findings:

```json
{
  "findings": [
    {
      "code": "E2003",
      "message": "digest mismatch, expected ... got ...",
      "path": "files/a.txt",
      "severity": "error"
    }
  ],
  "ok": false,
  "stats": {
    "files_passed": 1,
    "files_total": 2,
    "merkle_checked": true
  }
}
```

The verification report shares the stable `@diag.VerifyReport` field shape and
has no `schema` discriminator. Consumers branch on process exit code, `ok`, and
`findings[].code`. Long-lived automation checks `moon-evidence --version`
against its tested CLI release before parsing this schema-less report.

Machine consumers invoke one pack per process. Multi-pack mode prints section
headers, one report per pack, and a final summary, so its stdout is a human
batch stream rather than one JSON document.

### External Digest

The expected digest accepts canonical SHA-256 or SHA-512 form:

```text
moon-evidence verify --json \
  --expected-manifest-digest sha256:<64-lowercase-hex> <pack>
```

A canonical mismatch produces exactly `E2004` in the verification report and
exit code `1`. A malformed value is a usage error with exit code `2`.

### Incremental Cache

`--incremental <cache-dir>` keeps the `VerifyReport` JSON unchanged. Text mode
adds rehashed/skipped counters. The cache belongs to a trusted local workflow;
release, external handoff, and pre-anchor checks use complete verification.

## Errors and Exit Codes

| Exit | Meaning | Stdout contract |
| --- | --- | --- |
| `0` | command succeeded or verification passed | success receipt or passing report in JSON mode |
| `1` | verification completed and rejected evidence | failing `VerifyReport` in JSON mode |
| `2` | usage, path, permission, or IO failure | `pack`/`seal`/`inspect` use the error envelope in JSON mode; `create` and `verify` preflight text may be human-readable |

| Command in JSON mode | Exit `0` | Exit `1` | Exit `2` |
| --- | --- | --- | --- |
| `pack` / `seal` / `inspect` | versioned success receipt | not used | versioned error envelope |
| `create` | versioned success receipt | not used | preflight text; modeled late failures use the error envelope |
| single-pack `verify` | passing `VerifyReport` | failing `VerifyReport` | preflight text |

For `pack --json`, `seal --json`, and `inspect --json`, an exit-2 command
failure emits:

```json
{
  "error": { "code": "E5002", "message": "...", "path": "..." },
  "ok": false,
  "schema": "moon-evidence-cli-error/v1"
}
```

Automation checks the process exit code before parsing stdout. For successful
receipt commands it then checks `schema` and `ok`; for completed verification
it checks `ok`, `findings`, and `stats`. `create` emits text for preflight
failures. Unknown response fields are ignored.

## Stability

- Receipt schema changes require a new schema suffix.
- Verification report field changes require a CLI compatibility decision and
  synchronized CLI/API tests.
- `message` text may improve; `code`, `path`, `severity`, `ok`, and `stats`
  carry stable semantics.
- External adapters accept MoonBit results and never recompute manifest,
  digest, or Merkle semantics.
