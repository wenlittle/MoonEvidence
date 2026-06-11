# CI Workflows

- `ci.yml`: runs `moon check`, `moon test --target wasm-gc,js`, builds all
  three backends (`native`, `wasm-gc`, `js`), runs the CLI black-box suite
  (`tools/cli-test.ps1`) against native and js, and smoke-tests the browser
  adapter (`tools/smoke-api.mjs`) over the js artifact on every push and
  pull request to `main`. Native test behaviour is covered by the black-box
  suite; unit tests run on the two portable backends.

All commands in the workflow must pass locally before being added here, so a
red main branch always signals a real regression instead of CI drift.

Documented exception (step 6): the local machine has no system C compiler, so
`moon build --target native` cannot link the CLI executable locally and the
native black-box run is delegated to CI (ubuntu runners ship gcc). The native
step runs the exact script and cases that pass locally 12/12 on the js target,
and the artifact-discovery logic was dry-run against the native build layout;
see RESULTS_LOG step 6 for details.
