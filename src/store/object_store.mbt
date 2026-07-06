// In-memory deduplication store keyed by SHA-256 digest.
// Files are stored by their SHA-256 digest; duplicate content is stored once.
// The store is a pure in-memory data structure with no IO dependency.

///|
/// In-memory deduplication map: content is stored once per unique SHA-256 digest.
pub struct ObjectStore {
  objects : Map[String, Bytes]
}

///|
pub fn ObjectStore::new() -> ObjectStore {
  { objects: {} }
}

///|
/// Stores content and returns its SHA-256 digest key.
/// If the content already exists, this is a no-op (idempotent).
pub fn ObjectStore::put(self : ObjectStore, content : Bytes) -> String {
  let hash = "sha256:\{@digest.sha256_hex(content)}"
  if self.objects.get(hash) is None {
    self.objects[hash] = content
  }
  hash
}

///|
/// Retrieves content by its hash key.
pub fn ObjectStore::get(self : ObjectStore, hash : String) -> Bytes? {
  self.objects.get(hash)
}

///|
pub fn ObjectStore::has(self : ObjectStore, hash : String) -> Bool {
  self.objects.get(hash) is Some(_)
}

///|
pub fn ObjectStore::count(self : ObjectStore) -> Int {
  self.objects.length()
}

///|
/// Lists all stored object hashes.
pub fn ObjectStore::list_hashes(self : ObjectStore) -> Array[String] {
  let result : Array[String] = []
  for hash, _ in self.objects {
    result.push(hash)
  }
  result
}

///|
/// Removes an object by its hash. Returns true if it existed.
pub fn ObjectStore::remove(self : ObjectStore, hash : String) -> Bool {
  match self.objects.get(hash) {
    Some(_) => {
      self.objects.remove(hash)
      true
    }
    None => false
  }
}

///|
/// Deduplication result for a set of files.
pub(all) struct DeduplicateResult {
  index : Map[String, String]
  store : ObjectStore
  total_files : Int
  unique_objects : Int
  bytes_saved : Int64
}

///|
/// Takes a map of path -> content, stores all unique content in a new
/// ObjectStore, and returns an index mapping path -> hash plus stats.
pub fn deduplicate(files : Map[String, Bytes]) -> DeduplicateResult {
  let store = ObjectStore::new()
  let index : Map[String, String] = {}
  // Int64 accumulators: content.length() returns Int, but sums over many
  // files can exceed 2^31 (~2 GiB). Int64 gives headroom up to ~8 EiB.
  let mut total_bytes : Int64 = 0L
  let mut unique_bytes : Int64 = 0L
  for path, content in files {
    total_bytes = total_bytes + content.length().to_int64()
    let hash = store.put(content)
    index[path] = hash
  }
  for _, content in store.objects {
    unique_bytes = unique_bytes + content.length().to_int64()
  }
  {
    index,
    store,
    total_files: files.length(),
    unique_objects: store.count(),
    bytes_saved: total_bytes - unique_bytes,
  }
}

///|
/// Serializes the deduplication index as canonical JSON.
pub fn DeduplicateResult::to_json(self : DeduplicateResult) -> String {
  let entries : Map[String, Json] = {}
  for path, hash in self.index {
    entries[path] = Json::string(hash)
  }
  let doc = Json::object({
    "index": Json::object(entries),
    "stats": Json::object({
      "total_files": Json::number(self.total_files.to_double()),
      "unique_objects": Json::number(self.unique_objects.to_double()),
      "bytes_saved": Json::number(self.bytes_saved.to_double()),
    }),
  })
  // Canonicalize so Map iteration order never affects the output bytes.
  @canonjson.canonicalize(doc.stringify()) catch {
    _ => doc.stringify()
  }
}

///|
/// Verifies that all index entries have their content in the store AND
/// that each stored content's SHA-256 digest matches the key it was
/// stored under. This catches content tampering that a mere key-existence
/// check would miss.
pub fn DeduplicateResult::verify_integrity(self : DeduplicateResult) -> Bool {
  for _path, hash in self.index {
    match self.store.get(hash) {
      Some(content) => {
        // Re-hash the stored content and compare to the key.
        let recomputed = "sha256:\{@digest.sha256_hex(content)}"
        if recomputed != hash {
          return false
        }
      }
      None => return false
    }
  }
  true
}

///|
/// Reconstructs original files from the index and store.
///
/// Silently skips entries whose content is missing from the store, but
/// emits a warning log for each missing path. Callers who need to detect
/// missing content programmatically should use `reconstruct_strict`.
pub fn DeduplicateResult::reconstruct(
  self : DeduplicateResult,
) -> Map[String, Bytes] {
  let result : Map[String, Bytes] = {}
  for path, hash in self.index {
    match self.store.get(hash) {
      Some(content) => result[path] = content
      None =>
        println(
          "warning: reconstruct: object missing for path '\{path}' (hash: \{hash})",
        )
    }
  }
  result
}

///|
/// Strict variant of `reconstruct`: returns `Err(missing_paths)` listing
/// every path whose content is absent from the store, instead of silently
/// skipping them. Returns `Ok(result)` when all entries are present.
pub fn DeduplicateResult::reconstruct_strict(
  self : DeduplicateResult,
) -> Result[Map[String, Bytes], Array[String]] {
  let result : Map[String, Bytes] = {}
  let missing : Array[String] = []
  for path, hash in self.index {
    match self.store.get(hash) {
      Some(content) => result[path] = content
      None => missing.push(path)
    }
  }
  if missing.length() > 0 {
    Err(missing)
  } else {
    Ok(result)
  }
}
