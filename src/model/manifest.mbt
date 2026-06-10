// Strongly typed evidence-pack manifest with full field validation,
// implementing the frozen "Manifest Fields" section of
// docs/spec/EVIDENCE_PACK_SPEC.md. Parsing is strict: anything the spec
// requires is checked here so downstream verification can assume a
// well-formed model. Unknown extra fields are ignored for forward
// compatibility.

// ---------------------------------------------------------------------------
// Model types
// ---------------------------------------------------------------------------

/// What the evidence pack is about. JSON key `type` is a MoonBit keyword,
/// hence the field name `kind`.
pub(all) struct Subject {
  id : String
  kind : String
} derive(Eq, @debug.Debug)

/// One `files[]` entry. `digest` is stored pre-validated: the manifest text
/// must already be in canonical `<algo>:<lowercase-hex>` form (spec E2002),
/// so re-rendering the entry for Merkle leaf hashing reproduces the original
/// bytes exactly.
pub(all) struct FileEntry {
  path : String
  size : Int64
  digest : @digest.Digest
} derive(Eq, @debug.Debug)

/// The manifest's own version stamp (`version` object).
pub(all) struct VersionRef {
  id : String
  parent : String?
} derive(Eq, @debug.Debug)

/// Parsed and validated manifest.
pub(all) struct Manifest {
  schema : String
  subject : Subject
  algorithm : @digest.HashAlgorithm
  files : Array[FileEntry]
  merkle_root : @digest.Digest?
  version : VersionRef
} derive(Eq, @debug.Debug)

// ---------------------------------------------------------------------------
// Parsing
// ---------------------------------------------------------------------------

/// Supported schema identifier (frozen v1 scope).
const SUPPORTED_SCHEMA : String = "moon-evidence/v0"

/// Parses and validates a manifest document. Every spec rule is enforced:
/// schema id, supported algorithm, non-empty unique file paths, canonical
/// digest strings (matching the manifest algorithm), non-negative integer
/// sizes, and a well-formed version stamp.
pub fn Manifest::parse(input : String) -> Manifest raise ModelError {
  let document = @json.parse(input) catch {
    error => raise ModelError::ParseFailed(error.to_json().stringify())
  }
  let root = expect_object(document, "manifest")

  // schema
  let schema = expect_string(root, "schema", "schema")
  if schema != SUPPORTED_SCHEMA {
    raise ModelError::UnsupportedSchema("schema", schema)
  }

  // subject
  let subject_fields = expect_object(
    expect_present(root, "subject", "subject"),
    "subject",
  )
  let subject = Subject::{
    id: expect_string(subject_fields, "id", "subject.id"),
    kind: expect_string(subject_fields, "type", "subject.type"),
  }

  // hash_algorithm
  let algorithm_name = expect_string(root, "hash_algorithm", "hash_algorithm")
  guard @digest.normalize_algorithm(algorithm_name) is Some(algorithm) else {
    raise ModelError::UnsupportedAlgorithm("hash_algorithm", algorithm_name)
  }

  // files
  let files_value = expect_present(root, "files", "files")
  guard files_value is Array(file_items) else {
    raise ModelError::InvalidField("files", "expected an array")
  }
  let files : Array[FileEntry] = []
  let seen_paths : Map[String, Bool] = {}
  for index in 0..<file_items.length() {
    let entry_path = "files[\{index}]"
    let entry_fields = expect_object(file_items[index], entry_path)
    let path = expect_string(entry_fields, "path", "\{entry_path}.path")
    if seen_paths.get(path) is Some(_) {
      raise ModelError::InvalidField(
        "\{entry_path}.path",
        "duplicate path \"\{path}\"",
      )
    }
    seen_paths[path] = true
    let size = expect_size(entry_fields, "size", "\{entry_path}.size")
    let digest = expect_digest(
      expect_string(entry_fields, "digest", "\{entry_path}.digest"),
      algorithm,
      "\{entry_path}.digest",
    )
    files.push({ path, size, digest })
  }

  // merkle_root: optional here; presence rules versus files[] (E3001) are
  // verification semantics, but WHEN present the string must be a canonical
  // digest under the manifest algorithm.
  let merkle_root : @digest.Digest? = match root.get("merkle_root") {
    None | Some(Null) => None
    Some(String(text)) => Some(expect_digest(text, algorithm, "merkle_root"))
    Some(_) =>
      raise ModelError::InvalidField("merkle_root", "expected a string")
  }

  // version
  let version_fields = expect_object(
    expect_present(root, "version", "version"),
    "version",
  )
  let version = VersionRef::{
    id: expect_string(version_fields, "id", "version.id"),
    parent: expect_optional_string(version_fields, "parent", "version.parent"),
  }
  { schema, subject, algorithm, files, merkle_root, version }
}

// ---------------------------------------------------------------------------
// Field extraction helpers (shared with version.mbt)
// ---------------------------------------------------------------------------

/// Requires `value` to be a JSON object; returns its fields.
fn expect_object(
  value : Json,
  path : String,
) -> Map[String, Json] raise ModelError {
  guard value is Object(fields) else {
    raise ModelError::InvalidField(path, "expected an object")
  }
  fields
}

/// Requires the key to be present (any JSON value).
fn expect_present(
  fields : Map[String, Json],
  key : String,
  path : String,
) -> Json raise ModelError {
  guard fields.get(key) is Some(value) else {
    raise ModelError::MissingField(path)
  }
  value
}

/// Requires a present, non-empty string field.
fn expect_string(
  fields : Map[String, Json],
  key : String,
  path : String,
) -> String raise ModelError {
  match fields.get(key) {
    None | Some(Null) => raise ModelError::MissingField(path)
    Some(String(text)) => {
      if text.length() == 0 {
        raise ModelError::MissingField(path)
      }
      text
    }
    Some(_) => raise ModelError::InvalidField(path, "expected a string")
  }
}

/// Optional string field: absent or `null` is `None`; an empty string is
/// rejected (an empty parent id would silently break chain semantics).
fn expect_optional_string(
  fields : Map[String, Json],
  key : String,
  path : String,
) -> String? raise ModelError {
  match fields.get(key) {
    None | Some(Null) => None
    Some(String(text)) => {
      if text.length() == 0 {
        raise ModelError::InvalidField(path, "must not be empty when present")
      }
      Some(text)
    }
    Some(_) => raise ModelError::InvalidField(path, "expected a string or null")
  }
}

/// Requires a non-negative integer field exactly representable in a double
/// (the JSON parser's native number type), per the L1 number policy.
fn expect_size(
  fields : Map[String, Json],
  key : String,
  path : String,
) -> Int64 raise ModelError {
  match fields.get(key) {
    None | Some(Null) => raise ModelError::MissingField(path)
    Some(Number(value, repr~)) => {
      if repr is Some(_) {
        // Parser preserves the source text only for overflow-to-infinity.
        raise ModelError::InvalidField(path, "size out of range")
      }
      if @double.trunc(value) != value {
        raise ModelError::InvalidField(path, "size must be an integer")
      }
      if value < 0 {
        raise ModelError::InvalidField(path, "size must be >= 0")
      }
      if value > 9007199254740991 {
        raise ModelError::InvalidField(path, "size out of range")
      }
      value.to_int64()
    }
    Some(_) => raise ModelError::InvalidField(path, "expected a number")
  }
}

/// Validates a digest string: must parse as `<algo>:<hex>`, must already be
/// in canonical lowercase form (so byte-exact re-rendering is possible), and
/// must use the manifest's declared algorithm.
fn expect_digest(
  text : String,
  algorithm : @digest.HashAlgorithm,
  path : String,
) -> @digest.Digest raise ModelError {
  guard @digest.parse_digest(text) is Some(digest) else {
    raise ModelError::InvalidDigest(
      path,
      "expected <algo>:<lowercase-hex>, got \"\{text}\"",
    )
  }
  if digest.to_string() != text {
    raise ModelError::InvalidDigest(
      path,
      "digest must be canonical lowercase, got \"\{text}\"",
    )
  }
  if digest.algorithm != algorithm {
    raise ModelError::InvalidDigest(
      path,
      "digest algorithm does not match manifest hash_algorithm",
    )
  }
  digest
}
