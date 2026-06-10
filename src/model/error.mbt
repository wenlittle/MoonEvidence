// Model-layer failures. Every variant maps to exactly one frozen error code
// (docs/spec/EVIDENCE_PACK_SPEC.md "Error Codes"); the code string is part
// of the public contract and is what tests and the CLI assert on.

/// Validation failure while parsing a manifest or version chain. The first
/// payload of each variant is the field path context (e.g. `files[3].digest`)
/// except for `ParseFailed`, which carries the parser diagnostic.
pub(all) suberror ModelError {
  /// E1001: input is not valid JSON.
  ParseFailed(String)
  /// E1002: required field missing or empty. Payload: field path.
  MissingField(String)
  /// E1002: field present but malformed (wrong type, negative size,
  /// duplicate path, ...). Payloads: field path, detail.
  InvalidField(String, String)
  /// E1003: schema version not supported. Payloads: field path, got.
  UnsupportedSchema(String, String)
  /// E2001: hash algorithm not supported. Payloads: field path, got.
  UnsupportedAlgorithm(String, String)
  /// E2002: digest string format invalid. Payloads: field path, detail.
  InvalidDigest(String, String)
} derive(Eq, @debug.Debug)

/// Returns the frozen error code for this failure (`E1001`..`E2002`).
pub fn ModelError::error_code(self : ModelError) -> String {
  match self {
    ParseFailed(_) => "E1001"
    MissingField(_) => "E1002"
    InvalidField(_, _) => "E1002"
    UnsupportedSchema(_, _) => "E1003"
    UnsupportedAlgorithm(_, _) => "E2001"
    InvalidDigest(_, _) => "E2002"
  }
}

/// Renders `[code] path: detail`, the same single-line shape diag findings
/// use, so model errors read consistently in CLI output and test failures.
pub impl Show for ModelError with output(self, logger) {
  logger.write_string("[")
  logger.write_string(self.error_code())
  logger.write_string("] ")
  match self {
    ParseFailed(detail) => {
      logger.write_string("manifest: ")
      logger.write_string(detail)
    }
    MissingField(path) => {
      logger.write_string(path)
      logger.write_string(": required field missing or empty")
    }
    InvalidField(path, detail) => {
      logger.write_string(path)
      logger.write_string(": ")
      logger.write_string(detail)
    }
    UnsupportedSchema(path, got) => {
      logger.write_string(path)
      logger.write_string(": unsupported schema \"")
      logger.write_string(got)
      logger.write_string("\" (expected moon-evidence/v0)")
    }
    UnsupportedAlgorithm(path, got) => {
      logger.write_string(path)
      logger.write_string(": unsupported hash algorithm \"")
      logger.write_string(got)
      logger.write_string("\"")
    }
    InvalidDigest(path, detail) => {
      logger.write_string(path)
      logger.write_string(": ")
      logger.write_string(detail)
    }
  }
}
