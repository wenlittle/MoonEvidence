# CI Workflows

## `ci.yml`

Runs on every push and pull request to `main`, and can also be started
manually with `workflow_dispatch`. Two jobs:

### `check-test-build` (required, ubuntu-latest)

1. Install the latest MoonBit CLI via the official unix installer.
2. `moon version --all` - record the toolchain in the log.
3. `moon update` - refresh the MoonBit registry before resolving dependencies
   such as `moonbitlang/x`.
4. **Metric drift guard** - `node tools/check-metrics.mjs`.
5. **Fixture rot guard** - regenerate `tests/fixtures/packs` with
   `node tools/gen-fixtures.mjs` and `git diff --exit-code`. Any byte change
   means a generator/fixture mismatch and fails CI.
6. **Cross-verify / Wycheproof guards** - Node.js independent verification and
   Ed25519 vector inventory checks.
7. **Package content guard** - `node tools/check-package-contents.mjs` confirms
   Mooncakes packages contain the reusable library/docs/examples surface, not
   contest application PDFs, legacy course reports, or local agent files.
8. `moon check --deny-warn --target all` - type check every backend and fail
   on warnings.
9. **`moon fmt --check`** - format gate. The codebase was once normalized by
   `moon fmt` across all 38 source files (RESULTS_LOG "moon fmt
   Normalization"); this step makes any future fmt drift fail CI instead of
   silently accumulating. Run `moon fmt` locally to fix.
10. **`moon info` + `git diff --exit-code -- 'src/**/*.mbti'`** - public
   interface drift gate. Generated `pkg.generated.mbti` files must be checked
   in and stable.
11. `moon test --deny-warn --target wasm,wasm-gc,js` - unit tests on all
    portable backends.
12. `moon build --target native` - native build (ubuntu runners ship gcc, so
   linking succeeds where the local Windows machine cannot).
13. **`moon test --deny-warn --target native`** - native unit tests now run on
   ubuntu CI.
   Unit tests live in the pure packages (canonjson/digest/merkle/model/
   diag/verify) and are backend-agnostic; the `cmd/main` FFI paths stay
   covered by the black-box suite below. If a native-only failure surfaces,
   relax with `continue-on-error: true` and file an issue.
14. CLI black-box tests (native) - `tools/cli-test.ps1 -Target native`.
15. CLI black-box tests (native, bash parity) - `tools/cli-test.sh native`.
16. `moon build --target wasm-gc` / `moon build --target js`, plus
   `moon build --target js --release src/api` for the browser-adapter artifact
   consumed by smoke and differential tools.
17. CLI black-box tests (js) - `tools/cli-test.ps1 -Target js`.
18. CLI black-box tests (js, bash parity) - `tools/cli-test.sh js`.
19. Browser adapter smoke - `node tools/smoke-api.mjs` over the js artifact.
20. Malformed API request fuzz - `node tools/fuzz-api-malformed.mjs --rounds 64`.
21. API semantic property checks - `node tools/property-api-semantic.mjs --rounds 16`.
22. Differential crypto - `node tools/differential-crypto.mjs --rounds 64`.
23. Differential digest - `node tools/differential-digest.mjs --rounds 64`.
24. Mutation testing - `node tools/mutation-check.mjs`.

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

## `showcase-pages.yml`

Runs on every push to `main` and by manual dispatch. It installs MoonBit and
Node.js 22, runs `npm ci`, TypeScript checking, and the production Vite build
inside `showcase/`, then deploys the generated homepage and Evidence Workbench
to GitHub Pages. The build step compiles the release `src/api` artifact and
copies the real example evidence pack before bundling, so a Pages deployment
cannot silently fall back to mocked MoonBit results.

## `release.yml`

Triggered by pushing a version tag matching `v*` (e.g. `v0.3.0`). On tag:

1. Install MoonBit CLI.
2. `moon update` - refresh the MoonBit registry before resolving dependencies.
3. `moon check --deny-warn` - ensure the tagged revision type-checks without
   warnings.
4. `moon info` + `git diff --exit-code -- 'src/**/*.mbti'` - ensure the
   generated public interface files are committed and stable.
5. `node tools/check-package-contents.mjs` - ensure repository-only materials
   are excluded from the Mooncakes package.
6. `moon package` - produce the publish zip under `_build/publish/`
   (`<owner>-<Module>-<version>.zip`, e.g. `starlittle-MoonEvidence-0.3.0.zip`).
7. Compute the SHA256 of the zip and write it alongside (`.sha256` sidecar).
8. Create a GitHub Release (via `gh release create`) attaching both the zip
   and the `.sha256` digest, with auto-generated release notes.

The SHA256 sidecar lets downstream consumers verify the published package was
not tampered with in transit - mirroring the integrity contract the CLI
itself enforces on evidence packs. Requires `permissions: contents: write`
and the default `GITHUB_TOKEN`.

> Note: the version in `moon.mod` must match the tag (tag `v0.3.0` ships
> `moon.mod` version `0.3.0`). Mismatched versions will still package but the
> release title and artifact name will not line up.
