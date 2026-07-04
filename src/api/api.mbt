// Browser/JS adapter: a single string-in / string-out entry point so no
// MoonBit type ever crosses the JS boundary. Mirrors the CLI's merge
// semantics (manifest pipeline + optional version chain) without any IO -
// callers inject file bytes as hex.
//
// Request (JSON):
//   {
//     "manifest": "<manifest.json text>",          // required
//     "files": { "<pack path>": "<hex bytes>" },   // optional
//     "version_chain": "<version_chain.json text>" // optional
//   }
// Response (JSON):
//   { "ok": Bool, "explain": String, "report": <canonical report object> }
// or, when the request itself is malformed:
//   { "ok": false, "error": String }

///|
/// Verifies an evidence pack delivered as a JSON request string and returns
/// a JSON response string. Exported to JS (see moon.pkg).
pub fn verify_evidence(request_json : String) -> String {
  let request = @json.parse(request_json) catch {
    _ => return error_response("request is not valid JSON")
  }
  guard request is Object(fields) else {
    return error_response("request must be a JSON object")
  }

  // manifest (required)
  guard fields.get("manifest") is Some(String(manifest_text)) else {
    return error_response("\"manifest\" must be a string field")
  }

  // files (optional): { path: hex }
  let files : Map[String, Bytes] = {}
  match fields.get("files") {
    None | Some(Null) => ()
    Some(Object(entries)) =>
      for path, value in entries {
        guard value is String(hex) else {
          return error_response("files[\"\{path}\"] must be a hex string")
        }
        guard @digest.hex_to_bytes(hex) is Some(content) else {
          return error_response("files[\"\{path}\"] is not valid hex")
        }
        files[path] = content
      }
    Some(_) => return error_response("\"files\" must be an object")
  }

  // Pure manifest pipeline.
  let report = @verify.verify_manifest(manifest_text, files)

  // Optional version chain, merged exactly like the CLI does.
  let chain_findings : Array[@diag.Finding] = match
    fields.get("version_chain") {
    None | Some(Null) => []
    Some(String(chain_text)) =>
      @verify.verify_chain_text(chain_text, path="version_chain")
    Some(_) => return error_response("\"version_chain\" must be a string")
  }
  let merged_findings = report.findings + chain_findings
  let merged : @diag.VerifyReport = {
    ok: !merged_findings.iter().any(f => f.severity is Error),
    findings: merged_findings,
    checked: report.checked,
  }

  // Response envelope. The report is embedded as a JSON object (parsed back
  // from its canonical rendering, which cannot fail for our own output).
  let report_value = @json.parse(@diag.to_json(merged)) catch {
    _ => Json::null()
  }
  Json::object({
    "ok": Json::boolean(merged.ok),
    "explain": Json::string(@diag.explain(merged)),
    "report": report_value,
  }).stringify()
}

///|
fn error_response(message : String) -> String {
  Json::object({ "ok": Json::boolean(false), "error": Json::string(message) }).stringify()
}
