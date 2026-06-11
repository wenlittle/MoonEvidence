// Native CLI adapter. Thin by design: all verification logic lives in the
// pure library packages; this file only parses arguments, performs IO
// (E5xxx territory), injects file bytes, and renders reports.
//
// Exit codes (frozen): 0 verification passed, 1 verification failed,
// 2 usage or IO error.

///|
/// Kept in sync with moon.mod at release time.
const CLI_VERSION : String = "0.1.0"

///|
let usage_text : String =
  #|moon-evidence - trusted evidence pack verification
  #|
  #|Usage:
  #|  moon-evidence verify [--json] <pack-dir | manifest.json>
  #|  moon-evidence explain <pack-dir | manifest.json>
  #|  moon-evidence --version
  #|  moon-evidence --help
  #|
  #|Commands:
  #|  verify    Verify an evidence pack; --json emits the canonical JSON report
  #|  explain   Verify and print the human-readable findings report
  #|
  #|Exit codes:
  #|  0  verification passed
  #|  1  verification failed
  #|  2  usage or IO error

///|
fn main {
  @sys.exit(run(@env.args()))
}

// ---------------------------------------------------------------------------
// Argument handling
// ---------------------------------------------------------------------------

///|
/// Drops the runtime-dependent argv prefix (native: program path; js: node
/// path + script path) by scanning for the first recognized token. Returns
/// the empty array when no known command is present.
fn strip_runtime_prefix(raw : Array[String]) -> Array[String] {
  let known = [
    "verify", "explain", "--version", "-v", "--help", "-h", "version", "help",
  ]
  for index in 0..<raw.length() {
    if known.contains(raw[index]) {
      let rest : Array[String] = []
      for cursor in index..<raw.length() {
        rest.push(raw[cursor])
      }
      return rest
    }
  }
  []
}

///|
fn run(raw_args : Array[String]) -> Int {
  let args = strip_runtime_prefix(raw_args)
  if args.length() == 0 {
    println(usage_text)
    return 2
  }
  match args[0] {
    "--version" | "-v" | "version" => {
      println("moon-evidence \{CLI_VERSION}")
      0
    }
    "--help" | "-h" | "help" => {
      println(usage_text)
      0
    }
    "verify" => run_verify(args, json_allowed=true)
    "explain" => run_verify(args, json_allowed=false)
    _ => {
      println(usage_text)
      2
    }
  }
}

// ---------------------------------------------------------------------------
// verify / explain
// ---------------------------------------------------------------------------

///|
fn run_verify(args : Array[String], json_allowed~ : Bool) -> Int {
  let mut json_mode = false
  let mut path : String? = None
  for index in 1..<args.length() {
    let arg = args[index]
    if arg == "--json" && json_allowed {
      json_mode = true
    } else if !arg.has_prefix("-") && path is None {
      path = Some(arg)
    } else {
      println(usage_text)
      return 2
    }
  }
  guard path is Some(pack_path) else {
    println(usage_text)
    return 2
  }

  // Resolve pack layout (E5001 when the path itself is absent).
  if !@fs.path_exists(pack_path) {
    println("[E5001] \{pack_path}: path does not exist")
    return 2
  }
  let is_directory = @fs.is_dir(pack_path) catch { _ => false }
  let (manifest_path, pack_root) = if is_directory {
    ("\{pack_path}/manifest.json", pack_path)
  } else {
    (pack_path, parent_dir(pack_path))
  }
  if !@fs.path_exists(manifest_path) {
    println("[E5001] \{manifest_path}: path does not exist")
    return 2
  }

  // Read the manifest (E5002 when unreadable).
  let manifest_text = @fs.read_file_to_string(manifest_path) catch {
    _ => {
      println("[E5002] \{manifest_path}: file read failed")
      return 2
    }
  }

  // Load listed files per the manifest; read failures become E5002 findings
  // and the entry is left out so verification also reports it as E2003.
  let io_findings : Array[@diag.Finding] = []
  let files : Map[String, Bytes] = {}
  try @model.Manifest::parse(manifest_text) catch {
    // Parse errors are reported by verify_manifest itself.
    _ => ()
  } noraise {
    manifest => {
      for entry in manifest.files {
        let file_path = "\{pack_root}/\{entry.path}"
        if @fs.path_exists(file_path) {
          try @fs.read_file_to_bytes(file_path) catch {
            _ =>
              io_findings.push({
                code: "E5002",
                severity: Error,
                path: entry.path,
                message: "file read failed",
              })
          } noraise {
            content => files[entry.path] = content
          }
        }
        // Absent files surface as E2003 from the pure pipeline.
      }
      // Pack-dir mode: also walk files/ so payloads the manifest does not
      // list reach the pure pipeline, which reports them as W1001.
      if is_directory {
        let listed : Map[String, Bool] = {}
        for entry in manifest.files {
          listed[entry.path] = true
        }
        let on_disk : Array[String] = []
        collect_pack_files(pack_root, "files", on_disk)
        for rel_path in on_disk {
          if listed.get(rel_path) is None {
            try @fs.read_file_to_bytes("\{pack_root}/\{rel_path}") catch {
              _ => () // unreadable unlisted file: nothing to attest
            } noraise {
              content => files[rel_path] = content
            }
          }
        }
      }
    }
  }

  // Pure verification.
  let report = @verify.verify_manifest(manifest_text, files)

  // Version chain is optional; verify it when the pack ships one.
  let chain_findings : Array[@diag.Finding] = []
  let mut chain_ok = true
  let chain_path = "\{pack_root}/versions/version_chain.json"
  if @fs.path_exists(chain_path) {
    try @fs.read_file_to_string(chain_path) catch {
      _ => {
        chain_ok = false
        chain_findings.push({
          code: "E5002",
          severity: Error,
          path: chain_path,
          message: "file read failed",
        })
      }
    } noraise {
      chain_text =>
        try @model.parse_version_chain(chain_text) catch {
          error => {
            chain_ok = false
            chain_findings.push({
              code: error.error_code(),
              severity: Error,
              path: "versions/version_chain.json",
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
    }
  }

  // Merge IO findings + pipeline report + chain findings into one report.
  let merged_findings : Array[@diag.Finding] = []
  for finding in io_findings {
    merged_findings.push(finding)
  }
  for finding in report.findings {
    merged_findings.push(finding)
  }
  for finding in chain_findings {
    merged_findings.push(finding)
  }
  let merged : @diag.VerifyReport = {
    ok: report.ok && chain_ok && io_findings.length() == 0,
    findings: merged_findings,
    checked: report.checked,
  }

  println(if json_mode { @diag.to_json(merged) } else { @diag.explain(merged) })
  if merged.ok {
    0
  } else {
    1
  }
}

///|
/// Recursively collects files under `<root>/<rel_dir>` as pack-relative
/// paths (`files/...`). Missing or unreadable directories yield nothing:
/// a pack without a files/ tree is legal.
fn collect_pack_files(
  root : String,
  rel_dir : String,
  out : Array[String],
) -> Unit {
  let full_dir = "\{root}/\{rel_dir}"
  if !@fs.path_exists(full_dir) {
    return
  }
  let entries = @fs.read_dir(full_dir) catch { _ => return }
  for name in entries {
    let rel_path = "\{rel_dir}/\{name}"
    let is_subdir = @fs.is_dir("\{root}/\{rel_path}") catch { _ => false }
    if is_subdir {
      collect_pack_files(root, rel_path, out)
    } else {
      out.push(rel_path)
    }
  }
}

///|
/// Parent directory of a file path, handling both separators; `.` when the
/// path has no directory component.
fn parent_dir(path : String) -> String {
  let mut cut = -1
  for index in 0..<path.length() {
    let unit = path[index].to_int()
    if unit == 0x2f || unit == 0x5c {
      cut = index
    }
  }
  if cut <= 0 {
    "."
  } else {
    path[0:cut].to_owned()
  }
}
