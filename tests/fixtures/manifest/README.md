# Manifest validation fixtures

Table-driven samples for `@model.Manifest::parse`. `valid.json` passes every
rule; each `invalid-*.json` violates exactly one rule and the table below is
the expected error contract (asserted exactly in
`src/model/manifest_wbtest.mbt`, reused by the step-7 CLI black-box tests).

| Fixture | Expected code | Field path |
| --- | --- | --- |
| invalid-json.json | E1001 | manifest |
| missing-schema.json | E1002 | schema |
| unsupported-schema.json | E1003 | schema |
| missing-subject-id.json | E1002 | subject.id |
| empty-subject-type.json | E1002 | subject.type |
| unsupported-algorithm.json | E2001 | hash_algorithm |
| files-not-array.json | E1002 (invalid field) | files |
| duplicate-file-path.json | E1002 (invalid field) | files[1].path |
| negative-size.json | E1002 (invalid field) | files[0].size |
| fractional-size.json | E1002 (invalid field) | files[0].size |
| bad-digest-format.json | E2002 | files[0].digest |
| uppercase-digest.json | E2002 | files[0].digest |
| bad-merkle-root.json | E2002 | merkle_root |
| empty-version-parent.json | E1002 (invalid field) | version.parent |
| path-traversal.json | E1002 (invalid field) | files[0].path |
| path-absolute.json | E1002 (invalid field) | files[0].path |
| path-drive-letter.json | E1002 (invalid field) | files[0].path |
| path-backslash.json | E1002 (invalid field) | files[0].path |
