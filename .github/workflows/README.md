# CI Workflows

## `ci.yml`

Runs on every push and pull request to `main`. Two jobs:

### `check-test-build` (required, ubuntu-latest)

1. Install MoonBit CLI (`moon 0.1.20260529` via the official unix installer).
2. `moon version --all` - record the toolchain in the log.
3. **Metric drift guard** - `node tools/check-metrics.mjs`.
4. **Fixture rot guard** - regenerate `tests/fixtures/packs` with
   `node tools/gen-fixtures.mjs` and `git diff --exit-code`. Any byte change
   means a generator/fixture mismatch and fails CI.
5. **Cross-verify / Wycheproof guards** - Node.js independent verification and
   Ed25519 vector inventory checks.
6. `moon check` - type check, 0 warnings required.
7. **`moon fmt --check`** - format gate. The codebase was once normalized by
   `moon fmt` across all 38 source files (RESULTS_LOG "moon fmt
   Normalization"); this step makes any future fmt drift fail CI instead of
   silently accumulating. Run `moon fmt` locally to fix.
8. `moon test --target wasm-gc,js` - unit tests on the two portable backends.
9. `moon build --target native` - native build (ubuntu runners ship gcc, so
   linking succeeds where the local Windows machine cannot).
10. **`moon test --target native`** - native unit tests now run on ubuntu CI.
   Unit tests live in the pure packages (canonjson/digest/merkle/model/
   diag/verify) and are backend-agnostic; the `cmd/main` FFI paths stay
   covered by the black-box suite below. If a native-only failure surfaces,
   relax with `continue-on-error: true` and file an issue.
11. CLI black-box tests (native) - `tools/cli-test.ps1 -Target native`.
12. `moon build --target wasm-gc` / `moon build --target js`.
13. CLI black-box tests (js) - `tools/cli-test.ps1 -Target js`.
14. Browser adapter smoke - `node tools/smoke-api.mjs` over the js artifact.
15. Differential crypto - `node tools/differential-crypto.mjs --rounds 64`.
16. Mutation testing - `node tools/mutation-check.mjs`.

All commands in the workflow must pass locally before being added here, so a
red main branch always signals a real regression instead of CI drift.

### `bench` (non-blocking, `continue-on-error: true`)

Depends on `check-test-build`. Runs `moon bench --target js` to track SHA-256
throughput and end-to-end verify cost (RESULTS_LOG step 8 task 4). Benchmark
timing is inherently noisy on shared runners, so a regression here must not
break the main CI flow - the job is informational. `moon bench` exists and
was run locally on the js target; if a future toolchain removes it, this job
simply fails soft.

### Documented native exception (step 6, historical)

The local development machine has no system C compiler, so `moon build
--target native` cannot link the CLI executable locally. The native build,
native unit tests, and native black-box run are all delegated to CI (ubuntu
runners ship gcc). The native black-box step runs the exact script and cases
that pass 12/12 on the js target; see RESULTS_LOG step 6 for details.

## `release.yml`

Triggered by pushing a version tag matching `v*` (e.g. `v0.3.0`). On tag:

1. Install MoonBit CLI.
2. `moon check` - ensure the tagged revision type-checks.
3. `moon package` - produce the publish zip under `_build/publish/`
   (`<owner>-<Module>-<version>.zip`, e.g. `starlittle-MoonEvidence-0.3.0.zip`).
4. Compute the SHA256 of the zip and write it alongside (`.sha256` sidecar).
5. Create a GitHub Release (via `gh release create`) attaching both the zip
   and the `.sha256` digest, with auto-generated release notes.

The SHA256 sidecar lets downstream consumers verify the published package was
not tampered with in transit - mirroring the integrity contract the CLI
itself enforces on evidence packs. Requires `permissions: contents: write`
and the default `GITHUB_TOKEN`.

> Note: the version in `moon.mod` must match the tag (tag `v0.3.0` ships
> `moon.mod` version `0.3.0`). Mismatched versions will still package but the
> release title and artifact name will not line up.
