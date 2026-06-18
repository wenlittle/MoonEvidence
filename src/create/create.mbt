// Evidence pack creation: given raw files and metadata, produce a complete
// manifest JSON with per-file digests, a Merkle root, and a version stamp.
//
// Mirror of the verify pipeline: what verify tears apart and checks, create
// assembles from scratch. The round-trip property (create → verify = OK) is
// the primary correctness invariant.

///|
/// Metadata for the evidence subject.
pub(all) struct SubjectInfo {
  id : String
  kind : String
}

///|
/// Options for creating an evidence pack manifest.
pub(all) struct CreateOptions {
  subject : SubjectInfo
  algorithm : @digest.HashAlgorithm
  version_id : String
  version_parent : String?
}

///|
/// Creates a canonical manifest JSON string from raw file contents.
///
/// Files are sorted by path (Unicode code-point order) before computing
/// digests and the Merkle root, matching the verification pipeline's
/// expectations. The returned JSON is RFC 8785 canonical, so its SHA-256
/// digest is stable and reproducible.
pub fn create_manifest(
  files : Map[String, Bytes],
  options : CreateOptions,
) -> String {
  let sorted_paths : Array[String] = files.keys().collect()
  sorted_paths.sort()

  let file_entries : Array[Json] = []
  let leaf_payloads : Array[Bytes] = []

  for path in sorted_paths {
    let data = match files.get(path) {
      Some(d) => d
      None => continue
    }
    let digest = @digest.Digest::of_bytes(options.algorithm, data)
    let digest_str = digest.to_string()

    let entry = Json::object(
      {
        "path": Json::string(path),
        "size": Json::number(data.length().to_double()),
        "digest": Json::string(digest_str),
      },
    )
    file_entries.push(entry)
    let canonical_entry = try {
      @canonjson.canonicalize(entry.stringify())
    } catch {
      _ => entry.stringify()
    }
    let leaf_bytes = @digest.string_to_utf8_bytes(canonical_entry)
    leaf_payloads.push(leaf_bytes)
  }

  let merkle_root : Json = match @merkle.compute_root(leaf_payloads) {
    Some(root_bytes) => {
      let hex = @digest.bytes_to_lower_hex(root_bytes)
      Json::string("\{options.algorithm.label()}:\{hex}")
    }
    None => Json::null()
  }

  let version_parent_json : Json = match options.version_parent {
    Some(parent) => Json::string(parent)
    None => Json::null()
  }

  let manifest = Json::object(
    {
      "schema": Json::string("moon-evidence/v0"),
      "subject": Json::object(
        {
          "id": Json::string(options.subject.id),
          "type": Json::string(options.subject.kind),
        },
      ),
      "hash_algorithm": Json::string(options.algorithm.label()),
      "files": Json::array(file_entries),
      "merkle_root": merkle_root,
      "version": Json::object(
        {
          "id": Json::string(options.version_id),
          "parent": version_parent_json,
        },
      ),
    },
  )

  let raw_json = manifest.stringify()
  try {
    @canonjson.canonicalize(raw_json)
  } catch {
    _ => raw_json
  }
}
