// Structured diagnostics: the report types every verification step feeds
// and the two output renderers (human-readable explain, machine-readable
// canonical JSON). This package owns no verification logic - it only gives
// failures a stable, explainable shape.

// ---------------------------------------------------------------------------
// Findings
// ---------------------------------------------------------------------------

/// How severe a finding is. `Error` findings fail verification; `Warning`
/// findings (W1xxx) are reported but keep the pack valid.
pub(all) enum Severity {
  Error
  Warning
} derive(Eq, @debug.Debug)

/// Renders `error` / `warning`, the wire spelling used in JSON reports.
pub impl Show for Severity with output(self, logger) {
  match self {
    Error => logger.write_string("error")
    Warning => logger.write_string("warning")
  }
}

/// One verification finding. `code` is a frozen error/warning code
/// (E1xxx..E4xxx, W1xxx), `path` points at the manifest field or pack file
/// the finding is about, and `message` is the human-readable detail.
pub(all) struct Finding {
  code : String
  severity : Severity
  path : String
  message : String
} derive(Eq, @debug.Debug)

/// Renders `[code] path: message` - one finding per line in explain output.
pub impl Show for Finding with output(self, logger) {
  logger.write_string("[")
  logger.write_string(self.code)
  logger.write_string("] ")
  logger.write_string(self.path)
  logger.write_string(": ")
  logger.write_string(self.message)
}

// ---------------------------------------------------------------------------
// Reports
// ---------------------------------------------------------------------------

/// What the verifier actually checked, for the explain summary line and
/// machine consumers that want coverage numbers, not just pass/fail.
pub(all) struct CheckStats {
  files_total : Int
  files_passed : Int
  merkle_checked : Bool
} derive(Eq, @debug.Debug)

/// Outcome of one manifest verification run. `ok` is true when no
/// error-severity finding was produced (warnings alone do not fail a pack).
pub(all) struct VerifyReport {
  ok : Bool
  findings : Array[Finding]
  checked : CheckStats
} derive(Eq, @debug.Debug)

/// Counts findings with `Error` severity.
pub fn VerifyReport::error_count(self : VerifyReport) -> Int {
  count_severity(self.findings, Error)
}

/// Counts findings with `Warning` severity.
pub fn VerifyReport::warning_count(self : VerifyReport) -> Int {
  count_severity(self.findings, Warning)
}

fn count_severity(findings : Array[Finding], severity : Severity) -> Int {
  let mut count = 0
  for finding in findings {
    if finding.severity == severity {
      count = count + 1
    }
  }
  count
}

// ---------------------------------------------------------------------------
// Human-readable output
// ---------------------------------------------------------------------------

/// Renders the report for CLI users. Format (frozen for README examples):
///
/// ```text
/// verification FAILED
///   [E2003] files/data.csv: digest mismatch, expected sha256:ab.. got sha256:cd..
///   [W1001] files/extra.bin: file present in pack but not listed in manifest
/// checked 12 files, 11 passed; merkle root verified; 1 error, 1 warning
/// ```
///
/// The verdict line says `OK` when no error-severity finding exists. The
/// summary line always closes the report so scripts can tail it.
pub fn explain(report : VerifyReport) -> String {
  let out = StringBuilder::new()
  out.write_string(if report.ok { "verification OK" } else { "verification FAILED" })
  for finding in report.findings {
    out.write_string("\n  ")
    out.write_string(finding.to_string())
  }
  out.write_string("\nchecked ")
  out.write_string(report.checked.files_total.to_string())
  out.write_string(" files, ")
  out.write_string(report.checked.files_passed.to_string())
  out.write_string(" passed; merkle root ")
  out.write_string(if report.checked.merkle_checked { "verified" } else { "not checked" })
  out.write_string("; ")
  out.write_string(report.error_count().to_string())
  out.write_string(if report.error_count() == 1 { " error, " } else { " errors, " })
  out.write_string(report.warning_count().to_string())
  out.write_string(if report.warning_count() == 1 { " warning" } else { " warnings" })
  out.to_string()
}

// ---------------------------------------------------------------------------
// Machine-readable output
// ---------------------------------------------------------------------------

/// Renders the report as canonical JSON (RFC 8785 key order via canonjson),
/// so report bytes are themselves digest-stable and diffable:
///
/// ```json
/// {"findings":[...],"ok":false,"stats":{"files_passed":11,"files_total":12,"merkle_checked":true}}
/// ```
pub fn to_json(report : VerifyReport) -> String {
  let findings : Array[Json] = []
  for finding in report.findings {
    findings.push(
      Json::object({
        "code": Json::string(finding.code),
        "severity": Json::string(finding.severity.to_string()),
        "path": Json::string(finding.path),
        "message": Json::string(finding.message),
      }),
    )
  }
  let document = Json::object({
    "ok": Json::boolean(report.ok),
    "findings": Json::array(findings),
    "stats": Json::object({
      "files_total": Json::number(report.checked.files_total.to_double()),
      "files_passed": Json::number(report.checked.files_passed.to_double()),
      "merkle_checked": Json::boolean(report.checked.merkle_checked),
    }),
  })
  // Stats are small integers and all strings round-trip, so canonicalization
  // cannot fail here; the catch arm is pure defense and keeps the frozen
  // no-raise signature.
  @canonjson.canonicalize(document.stringify()) catch {
    _ => document.stringify()
  }
}
