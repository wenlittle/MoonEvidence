// Tests for content-addressable object store.

///|
test "empty store has zero count" {
  let store = ObjectStore::new()
  assert_eq!(store.count(), 0)
}

///|
test "put and get round-trip" {
  let store = ObjectStore::new()
  let content = @digest.string_to_utf8_bytes("hello world")
  let hash = store.put(content)
  assert_true!(hash.has_prefix("sha256:"))
  let retrieved = store.get(hash)
  match retrieved {
    Some(data) => assert_eq!(data.length(), content.length())
    None => assert_true!(false)
  }
}

///|
test "duplicate content stored once" {
  let store = ObjectStore::new()
  let content = @digest.string_to_utf8_bytes("duplicate")
  let h1 = store.put(content)
  let h2 = store.put(content)
  assert_eq!(h1, h2)
  assert_eq!(store.count(), 1)
}

///|
test "different content gets different hashes" {
  let store = ObjectStore::new()
  let h1 = store.put(@digest.string_to_utf8_bytes("alpha"))
  let h2 = store.put(@digest.string_to_utf8_bytes("beta"))
  assert_true!(h1 != h2)
  assert_eq!(store.count(), 2)
}

///|
test "has returns true for stored objects" {
  let store = ObjectStore::new()
  let hash = store.put(@digest.string_to_utf8_bytes("test"))
  assert_true!(store.has(hash))
  assert_false!(store.has("sha256:nonexistent"))
}

///|
test "remove deletes object" {
  let store = ObjectStore::new()
  let hash = store.put(@digest.string_to_utf8_bytes("removable"))
  assert_true!(store.remove(hash))
  assert_false!(store.has(hash))
  assert_eq!(store.count(), 0)
  assert_false!(store.remove(hash))
}

///|
test "deduplicate identifies duplicates" {
  let files : Map[String, Bytes] = {}
  let same = @digest.string_to_utf8_bytes("same content")
  files["a.txt"] = same
  files["b.txt"] = same
  files["c.txt"] = @digest.string_to_utf8_bytes("unique")
  let result = deduplicate(files)
  assert_eq!(result.total_files, 3)
  assert_eq!(result.unique_objects, 2)
  assert_true!(result.bytes_saved > 0)
  assert_true!(result.verify_integrity())
}

///|
test "reconstruct recovers original files" {
  let files : Map[String, Bytes] = {}
  files["x.dat"] = @digest.string_to_utf8_bytes("data-x")
  files["y.dat"] = @digest.string_to_utf8_bytes("data-y")
  let result = deduplicate(files)
  let recovered = result.reconstruct()
  assert_eq!(recovered.size(), 2)
  assert_true!(recovered.get("x.dat") is Some(_))
  assert_true!(recovered.get("y.dat") is Some(_))
}

///|
test "deduplicate result serializes to JSON" {
  let files : Map[String, Bytes] = {}
  files["file.txt"] = @digest.string_to_utf8_bytes("content")
  let result = deduplicate(files)
  let json_str = result.to_json()
  assert_true!(json_str.length() > 10)
  let _ = @json.parse(json_str)
}

///|
test "list_hashes returns all stored keys" {
  let store = ObjectStore::new()
  let _ = store.put(@digest.string_to_utf8_bytes("one"))
  let _ = store.put(@digest.string_to_utf8_bytes("two"))
  let hashes = store.list_hashes()
  assert_eq!(hashes.length(), 2)
}
