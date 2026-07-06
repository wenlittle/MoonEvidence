// Renderer tests: explain text format (frozen for README examples) and
// canonical JSON report bytes.

///|
fn sample_failed_report() -> VerifyReport {
  {
    ok: false,
    findings: [
      {
        code: "E2003",
        severity: Error,
        path: "files/data.csv",
        message: "digest mismatch, expected sha256:ab.. got sha256:cd..",
      },
      {
        code: "W1001",
        severity: Warning,
        path: "files/extra.bin",
        message: "file present in pack but not listed in manifest",
      },
    ],
    checked: { files_total: 12, files_passed: 11, merkle_checked: true },
  }
}

///|
test "explain renders ok report with summary line" {
  let report : VerifyReport = {
    ok: true,
    findings: [],
    checked: { files_total: 2, files_passed: 2, merkle_checked: true },
  }
  inspect(
    explain(report),
    content=(
      #|verification OK
      #|checked 2 files, 2 passed; merkle root verified; 0 errors, 0 warnings
    ),
  )
}

///|
test "explain renders one finding per line with verdict and summary" {
  inspect(
    explain(sample_failed_report()),
    content=(
      #|verification FAILED
      #|  [E2003] files/data.csv: digest mismatch, expected sha256:ab.. got sha256:cd..
      #|  [W1001] files/extra.bin: file present in pack but not listed in manifest
      #|checked 12 files, 11 passed; merkle root verified; 1 error, 1 warning
    ),
  )
}

///|
test "explain pluralizes multiple errors and warnings" {
  let report : VerifyReport = {
    ok: false,
    findings: [
      {
        code: "E1001",
        severity: Error,
        path: "manifest.json",
        message: "parse failed",
      },
      {
        code: "E2003",
        severity: Error,
        path: "files/a.txt",
        message: "digest mismatch",
      },
      {
        code: "W1001",
        severity: Warning,
        path: "files/extra-a.txt",
        message: "unlisted file",
      },
      {
        code: "W1001",
        severity: Warning,
        path: "files/extra-b.txt",
        message: "unlisted file",
      },
    ],
    checked: { files_total: 4, files_passed: 2, merkle_checked: false },
  }
  assert_true(explain(report).contains("2 errors, 2 warnings"))
}

///|
test "explain marks unchecked merkle root" {
  let report : VerifyReport = {
    ok: true,
    findings: [],
    checked: { files_total: 0, files_passed: 0, merkle_checked: false },
  }
  assert_true(explain(report).contains("merkle root not checked"))
}

///|
test "to json renders canonical key order" {
  let report : VerifyReport = {
    ok: true,
    findings: [],
    checked: { files_total: 2, files_passed: 2, merkle_checked: true },
  }
  inspect(
    to_json(report),
    content="{\"findings\":[],\"ok\":true,\"stats\":{\"files_passed\":2,\"files_total\":2,\"merkle_checked\":true}}",
  )
}

///|
test "to json renders findings with severity strings" {
  let json = to_json(sample_failed_report())
  assert_true(json.contains("\"severity\":\"error\""))
  assert_true(json.contains("\"severity\":\"warning\""))
  assert_true(json.contains("\"code\":\"E2003\""))
  // Canonical output is idempotent under canonicalization by construction.
  assert_eq(@canonjson.canonicalize(json) catch { _ => "raised" }, json)
}

///|
test "report severity counters" {
  let report = sample_failed_report()
  assert_eq(report.error_count(), 1)
  assert_eq(report.warning_count(), 1)
}
