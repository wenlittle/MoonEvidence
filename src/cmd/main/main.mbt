// Native CLI adapter. Thin by design: all verification logic lives in the
// pure library packages; this file only parses arguments, performs IO
// (E5xxx territory), injects file bytes, and renders reports.
//
// Exit codes (frozen): 0 verification passed, 1 verification failed,
// 2 usage or IO error.

///|
/// Kept in sync with moon.mod at release time.
const CLI_VERSION : String = "0.4.0"

///|
let usage_text : String =
  #|moon-evidence - trusted evidence pack verification
  #|
  #|Usage:
  #|  moon-evidence verify [--json] [--incremental <cache-dir>] <path> [<path> ...]
  #|  moon-evidence explain <path> [<path> ...]
  #|  moon-evidence create <dir> --subject-id <id> [--subject-type <type>]
  #|                          [--algorithm sha256|sha512]
  #|                          [--version-id <id>] [--version-parent <hash>]
  #|                          [-o <out>]
  #|  moon-evidence --version
  #|  moon-evidence --help
  #|
  #|Commands:
  #|  verify    Verify evidence packs; --json emits canonical JSON reports
  #|  explain   Verify and print human-readable findings reports
  #|  create    Create a manifest from files in a directory
  #|
  #|Verify options:
  #|  --json               Emit canonical JSON instead of human-readable text
  #|  --incremental <dir>  Cache file digests in <dir> for fast re-verification;
  #|                       unchanged files are skipped on subsequent runs
  #|
  #|Create options:
  #|  --subject-id <id>       Evidence subject identifier (required)
  #|  --subject-type <type>   Subject type (default: generic)
  #|  --algorithm <name>      Hash algorithm: sha256 or sha512 (default: sha256)
  #|  --version-id <id>       Version identifier (default: v1)
  #|  --version-parent <hash> Parent version hash for chaining (default: none)
  #|  -o, --output <path>     Output manifest path (default: <dir>/manifest.json)
  #|
  #|Batch mode:
  #|  Pass multiple paths to verify/explain several packs in one invocation.
  #|  Exit code is 0 only if ALL packs pass; 1 if any fails; 2 on usage error.
  #|
  #|Exit codes:
  #|  0  verification passed (all packs)
  #|  1  verification failed (at least one pack)
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
    "verify", "explain", "create", "--version", "-v", "--help", "-h", "version",
    "help",
  ]
  for index in 0..<raw.length() {
    if known.contains(raw[index]) {
      return raw[index:].to_owned()
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
    "create" => run_create(args)
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
  let mut incremental_dir : String? = None
  let paths : Array[String] = []
  let mut i = 1
  while i < args.length() {
    let arg = args[i]
    if arg == "--json" && json_allowed {
      json_mode = true
    } else if arg == "--incremental" && i + 1 < args.length() {
      i = i + 1
      incremental_dir = Some(args[i])
    } else if !arg.has_prefix("-") {
      paths.push(arg)
    } else {
      println(usage_text)
      return 2
    }
    i = i + 1
  }
  if paths.is_empty() {
    println(usage_text)
    return 2
  }
  if paths.length() == 1 {
    return run_verify_single(paths[0], json_mode, incremental_dir)
  }
  let mut all_ok = true
  let mut pass_count = 0
  let mut fail_count = 0
  for pack_path in paths {
    if paths.length() > 1 {
      println("--- \{pack_path} ---")
    }
    let code = run_verify_single(pack_path, json_mode, incremental_dir)
    if code == 2 {
      return 2
    }
    if code == 0 {
      pass_count = pass_count + 1
    } else {
      fail_count = fail_count + 1
      all_ok = false
    }
  }
  println(
    "\nbatch: \{pass_count} passed, \{fail_count} failed out of \{paths.length()} packs",
  )
  if all_ok {
    0
  } else {
    1
  }
}

///|
fn run_verify_single(
  pack_path : String,
  json_mode : Bool,
  cache_dir : String?,
) -> Int {
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
  let mut parsed_manifest : @model.Manifest? = None
  try @model.Manifest::parse(manifest_text) catch {
    // Parse errors are reported by verify_manifest itself.
    _ => ()
  } noraise {
    manifest => {
      parsed_manifest = Some(manifest)
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

  // Pure verification: incremental when a cache dir is provided, full
  // otherwise. Incremental skips rehashing files whose (path, digest)
  // match a trusted previous run — the Merkle root is always recomputed,
  // but per-file content integrity depends on cache trustworthiness.
  // See verify/incremental.mbt for the trust model.
  let mut files_rehashed = 0
  let mut files_skipped = 0
  let report = match cache_dir {
    Some(dir) => {
      let (previous, expected_digest) = load_incremental_cache(dir)
      let inc = @verify.verify_manifest_incremental(
        manifest_text,
        files,
        previous,
        expected_manifest_digest=expected_digest,
      )
      files_rehashed = inc.files_rehashed
      files_skipped = inc.files_skipped
      inc.report
    }
    None => @verify.verify_manifest(manifest_text, files)
  }

  // Version chain is optional; verify it when the pack ships one.
  let chain_findings : Array[@diag.Finding] = []
  let chain_path = "\{pack_root}/versions/version_chain.json"
  if @fs.path_exists(chain_path) {
    try @fs.read_file_to_string(chain_path) catch {
      _ =>
        chain_findings.push({
          code: "E5002",
          severity: Error,
          path: chain_path,
          message: "file read failed",
        })
    } noraise {
      chain_text =>
        chain_findings.append(
          @verify.verify_chain_text(
            chain_text,
            path="versions/version_chain.json",
          ),
        )
    }
  }

  // Merge IO findings + pipeline report + chain findings into one report;
  // the pack passes exactly when no error-severity finding survived.
  let merged_findings = io_findings + report.findings + chain_findings
  let merged : @diag.VerifyReport = {
    ok: !merged_findings.iter().any(f => f.severity is Error),
    findings: merged_findings,
    checked: report.checked,
  }

  // Save the incremental cache after a successful verification so the
  // next run can skip unchanged files. The cache stores the manifest's
  // file digests (path → digest) and the manifest's canonical digest
  // (for tamper detection on the next run).
  if cache_dir is Some(dir) && merged.ok {
    save_incremental_cache(dir, manifest_text, parsed_manifest)
  }

  // Output: text mode appends incremental stats; JSON mode stays
  // unchanged to preserve the contract for automated consumers.
  if json_mode {
    println(@diag.to_json(merged))
  } else {
    println(@diag.explain(merged))
    if cache_dir is Some(_) {
      println(
        "incremental: \{files_rehashed} rehashed, \{files_skipped} skipped",
      )
    }
  }
  if merged.ok {
    0
  } else {
    1
  }
}

///|
/// Loads the incremental cache from `<cache_dir>/cache.json`. Returns
/// (previous digests, expected manifest digest); both empty/None when
/// the cache file does not exist or is unreadable (first run).
fn load_incremental_cache(cache_dir : String) -> (Map[String, String], String?) {
  let previous : Map[String, String] = {}
  let mut expected_digest : String? = None
  let cache_file = "\{cache_dir}/cache.json"
  if !@fs.path_exists(cache_file) {
    return (previous, expected_digest)
  }
  let cache_text = @fs.read_file_to_string(cache_file) catch {
    _ => return (previous, expected_digest)
  }
  try @json.parse(cache_text) catch {
    _ => return (previous, expected_digest)
  } noraise {
    parsed =>
      match parsed {
        Object(fields) => {
          match fields.get("manifest_digest") {
            Some(String(d)) => expected_digest = Some(d)
            _ => ()
          }
          match fields.get("files") {
            Some(Object(files_map)) =>
              for path in files_map.keys() {
                match files_map.get(path) {
                  Some(String(d)) => previous[path] = d
                  _ => ()
                }
              }
            _ => ()
          }
        }
        _ => ()
      }
  }
  (previous, expected_digest)
}

///|
/// Saves the incremental cache to `<cache_dir>/cache.json`. Stores the
/// manifest's canonical digest and each file entry's path → digest so
/// the next run can skip rehashing unchanged files and detect manifest
/// tampering.
fn save_incremental_cache(
  cache_dir : String,
  manifest_text : String,
  parsed_manifest : @model.Manifest?,
) -> Unit {
  // Compute the manifest's canonical digest for tamper detection.
  let canonical = @canonjson.canonicalize(manifest_text) catch {
    _ => manifest_text
  }
  let manifest_digest = @digest.Digest::of_bytes(
    @digest.Sha256,
    @digest.string_to_utf8_bytes(canonical),
  ).to_string()
  // Build the files map from the parsed manifest.
  let files_map : Map[String, Json] = {}
  match parsed_manifest {
    Some(manifest) =>
      for entry in manifest.files {
        files_map[entry.path] = Json::string(entry.digest.to_string())
      }
    None => ()
  }
  let cache_json = Json::object({
    "manifest_digest": Json::string(manifest_digest),
    "files": Json::object(files_map),
  })
  let cache_str = cache_json.stringify()
  // Ensure the cache directory exists, then write.
  if !@fs.path_exists(cache_dir) {
    warn_stderr(
      "warning: incremental cache directory '\{cache_dir}' does not exist; cache not saved. Create it beforehand (e.g. `mkdir -p \{cache_dir}`) to enable incremental verification.",
    )
    return
  }
  @fs.write_string_to_file("\{cache_dir}/cache.json", cache_str) catch {
    _ => ()
  }
}

///|
/// Maximum directory recursion depth for `collect_pack_files`.
///
/// Bounds symlink-to-directory cycles that would otherwise cause infinite
/// recursion. 32 is generous for any legitimate evidence pack (the spec
/// recommends a flat `files/` tree) while still terminating malicious
/// cycles quickly.
let max_pack_depth : Int = 32

///|
/// Maximum total file count `collect_pack_files` will collect from a pack
/// directory tree. Bounds resource exhaustion from "symlink bombs" (a small
/// directory of symlinks pointing to `/dev/zero` or similar) and from
/// pathologically deep trees.
let max_pack_files : Int = 10000

///|
/// Recursively collects files under `<root>/<rel_dir>` as pack-relative
/// paths (`files/...`). Missing or unreadable directories yield nothing:
/// a pack without a files/ tree is legal.
///
/// Security mitigation: the `@fs` package (moonbitlang/x/fs) does not
/// expose `lstat`, `is_symlink`, `read_link`, or any other symlink-
/// detection API - its `is_dir`/`is_file` follow symlinks, so a symlink
/// to a directory is indistinguishable from a real directory and a symlink
/// to a file is indistinguishable from a real file. This means a hostile
/// pack directory could use symlinks to (a) create infinite cycles via
/// symlink-to-dir loops, or (b) pull in arbitrary out-of-tree content via
/// symlink-to-file. Since the underlying platform API cannot be queried
/// for link status, this function applies two runtime mitigations instead:
///
/// 1. **Depth cap** (`max_pack_depth`, 32): recursion stops when the
///    directory nesting exceeds 32 levels, terminating any symlink cycle.
/// 2. **File cap** (`max_pack_files`, 10000): collection stops once 10000
///    files have been accumulated, bounding resource use against symlink
///    bombs.
///
/// These are not TODOs or placeholders - they are the actual security
/// boundary enforced at runtime given the `@fs` API available. Pack
/// creators should still ensure the pack tree is symlink-free before
/// sealing (see SECURITY.md), and consumers should run verification in a
/// chroot/container that bounds the reachable filesystem.
fn collect_pack_files(
  root : String,
  rel_dir : String,
  out : Array[String],
  depth? : Int = 0,
) -> Unit {
  // Depth cap: terminate symlink-to-directory cycles.
  if depth >= max_pack_depth {
    return
  }
  // File cap: bound resource use against symlink bombs.
  if out.length() >= max_pack_files {
    return
  }
  let full_dir = "\{root}/\{rel_dir}"
  if !@fs.path_exists(full_dir) {
    return
  }
  let entries = @fs.read_dir(full_dir) catch { _ => return }
  for name in entries {
    // File cap check inside the loop too, so a single huge directory
    // does not blow past the limit before the next recursion.
    if out.length() >= max_pack_files {
      return
    }
    let rel_path = "\{rel_dir}/\{name}"
    let is_subdir = @fs.is_dir("\{root}/\{rel_path}") catch { _ => false }
    if is_subdir {
      collect_pack_files(root, rel_path, out, depth=depth + 1)
    } else {
      out.push(rel_path)
    }
  }
}

///|
/// Recursively collects files under `<root>/<rel_dir>` as input-relative
/// paths. Missing or unreadable directories yield nothing.
///
/// Security mitigation: mirroring `collect_pack_files`, this function
/// applies the same depth and file caps to bound symlink cycles and
/// resource exhaustion.
fn collect_create_files(
  root : String,
  rel_dir : String,
  out : Array[String],
  depth? : Int = 0,
) -> Unit {
  // Depth cap: terminate symlink-to-directory cycles.
  if depth >= max_pack_depth {
    return
  }
  // File cap: bound resource use against symlink bombs.
  if out.length() >= max_pack_files {
    return
  }
  let full_dir = if rel_dir.is_empty() { root } else { "\{root}/\{rel_dir}" }
  if !@fs.path_exists(full_dir) {
    return
  }
  let entries = @fs.read_dir(full_dir) catch { _ => return }
  for name in entries {
    // File cap check inside the loop too, so a single huge directory
    // does not blow past the limit before the next recursion.
    if out.length() >= max_pack_files {
      return
    }
    let rel_path = if rel_dir.is_empty() { name } else { "\{rel_dir}/\{name}" }
    let is_subdir = @fs.is_dir("\{root}/\{rel_path}") catch { _ => false }
    if is_subdir {
      collect_create_files(root, rel_path, out, depth=depth + 1)
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

// ---------------------------------------------------------------------------
// create
// ---------------------------------------------------------------------------

///|
fn run_create(args : Array[String]) -> Int {
  let mut dir_path : String? = None
  let mut subject_id : String? = None
  let mut subject_type : String? = None
  let mut output_path : String? = None
  let mut algorithm_name : String? = None
  let mut version_id : String? = None
  let mut version_parent : String? = None
  let mut i = 1
  while i < args.length() {
    let arg = args[i]
    if arg == "--subject-id" && i + 1 < args.length() {
      i = i + 1
      subject_id = Some(args[i])
    } else if arg == "--subject-type" && i + 1 < args.length() {
      i = i + 1
      subject_type = Some(args[i])
    } else if arg == "--algorithm" && i + 1 < args.length() {
      i = i + 1
      algorithm_name = Some(args[i])
    } else if arg == "--version-id" && i + 1 < args.length() {
      i = i + 1
      version_id = Some(args[i])
    } else if arg == "--version-parent" && i + 1 < args.length() {
      i = i + 1
      version_parent = Some(args[i])
    } else if (arg == "-o" || arg == "--output") && i + 1 < args.length() {
      i = i + 1
      output_path = Some(args[i])
    } else if !arg.has_prefix("-") && dir_path is None {
      dir_path = Some(arg)
    } else {
      println(usage_text)
      return 2
    }
    i = i + 1
  }
  guard dir_path is Some(pack_dir) else {
    println("create: directory path required")
    return 2
  }
  guard subject_id is Some(sid) else {
    println("create: --subject-id required")
    return 2
  }
  let stype = match subject_type {
    Some(t) => t
    None => "generic"
  }
  let algorithm = match algorithm_name {
    Some(name) =>
      match @digest.normalize_algorithm(name) {
        Some(algo) => algo
        None => {
          println(
            "create: unknown algorithm '\{name}' (supported: sha256, sha512)",
          )
          return 2
        }
      }
    None => @digest.Sha256
  }
  let vid = match version_id {
    Some(v) => v
    None => "v1"
  }
  if !@fs.path_exists(pack_dir) {
    println("[E5001] \{pack_dir}: path does not exist")
    return 2
  }
  let is_dir = @fs.is_dir(pack_dir) catch { _ => false }
  if !is_dir {
    println("create: \{pack_dir} is not a directory")
    return 2
  }
  // Recursively collect files, mirroring verify's collect_pack_files
  // semantics: depth cap + file cap bound symlink cycles and bombs.
  // Unlike verify (which reads from an existing files/ subtree), create
  // reads from the raw input directory and uses on-disk relative paths
  // directly — whatever layout create sees is what verify will check.
  let file_paths : Array[String] = []
  collect_create_files(pack_dir, "", file_paths)
  if file_paths.length() >= max_pack_files {
    println(
      "[E5002] \{pack_dir}: too many files (>=\{max_pack_files}), manifest creation aborted to avoid silent truncation",
    )
    return 2
  }
  let files : Map[String, Bytes] = {}
  for rel_path in file_paths {
    // Skip the manifest file itself — it's the output, not evidence.
    // Only the root-level manifest.json is excluded; a nested file of
    // the same name is legitimate evidence.
    if rel_path == "manifest.json" {
      continue
    }
    let full_path = "\{pack_dir}/\{rel_path}"
    let content = @fs.read_file_to_bytes(full_path) catch {
      _ => {
        println("[E5002] \{full_path}: file read failed")
        return 2
      }
    }
    // Use the on-disk relative path directly so create→verify is
    // symmetric: verify resolves each manifest entry as
    // <pack_root>/<entry.path>, which matches the on-disk layout
    // create saw when collecting.
    files[rel_path] = content
  }
  let manifest_json = @create.create_manifest(files, {
    subject: { id: sid, kind: stype },
    algorithm,
    version_id: vid,
    version_parent,
  })
  let out = match output_path {
    Some(p) => p
    None => "\{pack_dir}/manifest.json"
  }
  @fs.write_string_to_file(out, manifest_json) catch {
    _ => {
      println("[E5002] \{out}: write failed")
      return 2
    }
  }
  println("created \{out} (\{files.length()} files, \{algorithm.label()})")
  0
}
