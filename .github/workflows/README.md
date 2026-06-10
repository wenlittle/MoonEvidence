# CI Workflows

- `ci.yml`: runs `moon check`, `moon test`, and `moon build --target native` on
  every push and pull request to `main`. The wasm-gc/js build matrix will be
  added when the multi-backend delivery step lands (master plan step 9).

All commands in the workflow must pass locally before being added here, so a
red main branch always signals a real regression instead of CI drift.
