# CI Workflows

- `ci.yml`: runs `moon check`, `moon test`, `moon build --target native,js`,
  and the CLI black-box suite (`tools/cli-test.ps1`) against both targets on
  every push and pull request to `main`. The wasm-gc matrix entry will be
  added when the multi-backend delivery step lands (master plan step 9).

All commands in the workflow must pass locally before being added here, so a
red main branch always signals a real regression instead of CI drift.

Documented exception (step 6): the local machine has no system C compiler, so
`moon build --target native` cannot link the CLI executable locally and the
native black-box run is delegated to CI (ubuntu runners ship gcc). The native
step runs the exact script and cases that pass locally 12/12 on the js target,
and the artifact-discovery logic was dry-run against the native build layout;
see RESULTS_LOG step 6 for details.
