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
        guard hex_to_bytes(hex) is Some(content) else {
          return error_response("files[\"\{path}\"] is not valid hex")
        }
        files[path] = content
      }
    Some(_) => return error_response("\"files\" must be an object")
  }

  // Pure manifest pipeline.
  let report = @verify.verify_manifest(manifest_text, files)

  // Optional version chain, merged exactly like the CLI does.
  let chain_findings : Array[@diag.Finding] = []
  let mut chain_ok = true
  match fields.get("version_chain") {
    None | Some(Null) => ()
    Some(String(chain_text)) =>
      try @model.parse_version_chain(chain_text) catch {
        error => {
          chain_ok = false
          chain_findings.push({
            code: error.error_code(),
            severity: Error,
            path: "version_chain",
            message: error.detail(),
          })
        }
      } noraise {
        nodes => {
          let chain_report = @verify.verify_version_chain(nodes)
          chain_ok = chain_report.ok
          for finding in chain_report.findings {
            chain_findings.push(finding)
          }
        }
      }
    Some(_) => return error_response("\"version_chain\" must be a string")
  }
  let merged_findings : Array[@diag.Finding] = []
  for finding in report.findings {
    merged_findings.push(finding)
  }
  for finding in chain_findings {
    merged_findings.push(finding)
  }
  let merged : @diag.VerifyReport = {
    ok: report.ok && chain_ok,
    findings: merged_findings,
    checked: report.checked,
  }

  // Response envelope. The report is embedded as a JSON object (parsed back
  // from its canonical rendering, which cannot fail for our own output).
  let report_value = @json.parse(@diag.to_json(merged)) catch { _ => Json::null() }
  Json::object({
    "ok": Json::boolean(merged.ok),
    "explain": Json::string(@diag.explain(merged)),
    "report": report_value,
  }).stringify()
}

fn error_response(message : String) -> String {
  Json::object({
    "ok": Json::boolean(false),
    "error": Json::string(message),
  }).stringify()
}

/// Decodes lowercase/uppercase hex into bytes; `None` on odd length or any
/// non-hex character.
fn hex_to_bytes(hex : String) -> Bytes? {
  if hex.length() % 2 != 0 {
    return None
  }
  let out : Array[Byte] = []
  for index in 0..<(hex.length() / 2) {
    let high = hex_digit(hex[index * 2].to_int())
    let low = hex_digit(hex[index * 2 + 1].to_int())
    guard high is Some(high_value) && low is Some(low_value) else {
      return None
    }
    out.push((high_value * 16 + low_value).to_byte())
  }
  Some(Bytes::from_array(out))
}

fn hex_digit(unit : Int) -> Int? {
  if unit >= 0x30 && unit <= 0x39 {
    Some(unit - 0x30)
  } else if unit >= 0x61 && unit <= 0x66 {
    Some(unit - 0x61 + 10)
  } else if unit >= 0x41 && unit <= 0x46 {
    Some(unit - 0x41 + 10)
  } else {
    None
  }
}
