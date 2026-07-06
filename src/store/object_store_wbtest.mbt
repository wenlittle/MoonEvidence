// Tests for content-addressable object store.

///|
test "empty store has zero count" {
  let store = ObjectStore::new()
  assert_eq(store.count(), 0)
}

///|
test "put and get round-trip" {
  let store = ObjectStore::new()
  let content = @digest.string_to_utf8_bytes("hello world")
  let hash = store.put(content)
  assert_true(hash.has_prefix("sha256:"))
  let retrieved = store.get(hash)
  match retrieved {
    Some(data) => {
      // Byte-by-byte comparison: length alone does not prove content
      // integrity — a corrupted store could return same-length garbage.
      assert_eq(data.length(), content.length())
      for index in 0..<data.length() {
        assert_eq(data[index], content[index])
      }
    }
    None => fail("expected to retrieve stored content")
  }
}

///|
test "duplicate content stored once" {
  let store = ObjectStore::new()
  let content = @digest.string_to_utf8_bytes("duplicate")
  let h1 = store.put(content)
  let h2 = store.put(content)
  assert_eq(h1, h2)
  assert_eq(store.count(), 1)
}

///|
test "different content gets different hashes" {
  let store = ObjectStore::new()
  let h1 = store.put(@digest.string_to_utf8_bytes("alpha"))
  let h2 = store.put(@digest.string_to_utf8_bytes("beta"))
  assert_true(h1 != h2)
  assert_eq(store.count(), 2)
}

///|
test "has returns true for stored objects" {
  let store = ObjectStore::new()
  let hash = store.put(@digest.string_to_utf8_bytes("test"))
  assert_true(store.has(hash))
  assert_false(store.has("sha256:nonexistent"))
}

///|
test "remove deletes object" {
  let store = ObjectStore::new()
  let hash = store.put(@digest.string_to_utf8_bytes("removable"))
  assert_true(store.remove(hash))
  assert_false(store.has(hash))
  assert_eq(store.count(), 0)
  assert_false(store.remove(hash))
}

///|
test "deduplicate identifies duplicates" {
  let files : Map[String, Bytes] = {}
  let same = @digest.string_to_utf8_bytes("same content")
  files["a.txt"] = same
  files["b.txt"] = same
  files["c.txt"] = @digest.string_to_utf8_bytes("unique")
  let result = deduplicate(files)
  assert_eq(result.total_files, 3)
  assert_eq(result.unique_objects, 2)
  assert_true(result.bytes_saved > 0L)
  assert_true(result.verify_integrity())
}

///|
test "reconstruct recovers original files" {
  let files : Map[String, Bytes] = {}
  files["x.dat"] = @digest.string_to_utf8_bytes("data-x")
  files["y.dat"] = @digest.string_to_utf8_bytes("data-y")
  let result = deduplicate(files)
  let recovered = result.reconstruct()
  assert_eq(recovered.length(), 2)
  assert_true(recovered.get("x.dat") is Some(_))
  assert_true(recovered.get("y.dat") is Some(_))
}

///|
test "deduplicate result serializes to JSON" {
  let files : Map[String, Bytes] = {}
  files["file.txt"] = @digest.string_to_utf8_bytes("content")
  let result = deduplicate(files)
  let json_str = result.to_json()
  assert_true(json_str.length() > 10)
  let _ = @json.parse(json_str)
}

///|
test "list_hashes returns all stored keys" {
  let store = ObjectStore::new()
  let _ = store.put(@digest.string_to_utf8_bytes("one"))
  let _ = store.put(@digest.string_to_utf8_bytes("two"))
  let hashes = store.list_hashes()
  assert_eq(hashes.length(), 2)
}

// ===========================================================================
// Independent-oracle tests for verify_integrity and reconstruct_strict.
//
// The existing test "deduplicate identifies duplicates" calls
// verify_integrity() but only asserts true — it never tests the false path
// (tampered content). Worse, deduplicate() uses put() which calls our own
// sha256_hex, and verify_integrity() also calls sha256_hex — so both sides
// use the same function. If sha256_hex has a bug (e.g., returns a constant),
// both sides agree and the test still passes.
//
// These tests break that cycle by using KNOWN SHA-256 values from the golden
// manifest (computed by Node.js's independent crypto module). The hash keys
// are hardcoded constants, not computed by our code. If our SHA-256 is buggy,
// verify_integrity's recomputed hash will NOT match the hardcoded key, and
// the test will catch it.
//
// Known values (from golden_manifest in verify_wbtest.mbt, Node-computed):
//   SHA-256("hello world\n") = a948904f2f0f479b8f8197694b30184b0d2ed1c1cd2a1ec0fb85d299a192a447
//   SHA-256("")              = e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855
// ===========================================================================

///|
/// Known SHA-256 of "hello world\n" — from golden_manifest, Node-computed.
let known_sha256_hello_world : String = "sha256:a948904f2f0f479b8f8197694b30184b0d2ed1c1cd2a1ec0fb85d299a192a447"

///|
/// Known SHA-256 of empty string — from golden_manifest, Node-computed.
let known_sha256_empty : String = "sha256:e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"

///|
/// Helper: build a DeduplicateResult with hardcoded hash keys (independent
/// oracle), bypassing put()/sha256_hex entirely.
fn build_oracle_result() -> DeduplicateResult {
  let store = ObjectStore::new()
  // Store content directly via the internal map — do NOT use put(), which
  // would compute the hash with our own (potentially buggy) SHA-256.
  store.objects[known_sha256_hello_world] = @digest.string_to_utf8_bytes(
    "hello world\n",
  )
  store.objects[known_sha256_empty] = b""
  let index : Map[String, String] = {
    "files/a.txt": known_sha256_hello_world,
    "files/b.bin": known_sha256_empty,
  }
  {
    index,
    store,
    total_files: 2,
    unique_objects: 2,
    bytes_saved: 0L,
  }
}

///|
/// Q1 independent positive oracle: verify_integrity returns true when content
/// matches the hardcoded hash keys. Our SHA-256 recomputation must agree with
/// the Node-computed values — if not, this test fails.
test "verify_integrity returns true for untampered store (independent oracle)" {
  let result = build_oracle_result()
  assert_true(result.verify_integrity())
}

///|
/// Q2 independent negative oracle: verify_integrity returns false when store
/// content is tampered. The hash key is a fixed constant (Node-computed), so
/// SHA-256(tampered_content) will not match — regardless of whether our
/// SHA-256 is correct. This proves the integrity check actually compares
/// recomputed hashes against stored keys (not just key existence).
test "verify_integrity returns false when content is tampered (independent oracle)" {
  let result = build_oracle_result()
  // Sanity: before tampering, integrity holds.
  assert_true(result.verify_integrity())
  // Tamper: replace content with different bytes, keeping the same hash key.
  result.store.objects[known_sha256_hello_world] = @digest.string_to_utf8_bytes(
    "TAMPERED\n",
  )
  // The recomputed SHA-256("TAMPERED\n") must not match known_sha256_hello_world.
  assert_false(result.verify_integrity())
}

///|
/// Q2 independent negative oracle: verify_integrity returns false when content
/// is missing from the store (None branch, object_store.mbt L136).
test "verify_integrity returns false when content is missing (independent oracle)" {
  let result = build_oracle_result()
  assert_true(result.verify_integrity())
  // Remove content from store — the hash key remains in index but store has no content.
  let _ = result.store.remove(known_sha256_hello_world)
  assert_false(result.verify_integrity())
}

///|
/// Q2 independent negative oracle: reconstruct_strict returns Err when content
/// is missing. This tests the strict variant's error path (object_store.mbt
/// L176-180), which was previously untested.
test "reconstruct_strict returns Err when content is missing (independent oracle)" {
  let result = build_oracle_result()
  // Remove one file's content.
  let _ = result.store.remove(known_sha256_hello_world)
  match result.reconstruct_strict() {
    Err(missing) => {
      assert_eq(missing.length(), 1)
      assert_true(missing.contains("files/a.txt"))
    }
    Ok(_) => fail("reconstruct_strict should fail when content is missing")
  }
}

///|
/// Q2 independent negative oracle: reconstruct_strict returns Err with ALL
/// missing paths when multiple files are absent. Tests the accumulation logic
/// (object_store.mbt L173-180: missing.push(path) for each None).
test "reconstruct_strict returns Err with all missing paths when multiple files absent (independent oracle)" {
  let result = build_oracle_result()
  let _ = result.store.remove(known_sha256_hello_world)
  let _ = result.store.remove(known_sha256_empty)
  match result.reconstruct_strict() {
    Err(missing) => {
      assert_eq(missing.length(), 2)
      assert_true(missing.contains("files/a.txt"))
      assert_true(missing.contains("files/b.bin"))
    }
    Ok(_) => fail("reconstruct_strict should fail when all content is missing")
  }
}

///|
/// Q1 independent positive oracle: reconstruct_strict returns Ok with correct
/// content when all entries are present. The recovered content must match the
/// original byte-for-byte — not just be Some(_).
test "reconstruct_strict returns Ok with correct content (independent oracle)" {
  let result = build_oracle_result()
  match result.reconstruct_strict() {
    Ok(recovered) => {
      // Byte-for-byte comparison, not just key existence.
      match recovered.get("files/a.txt") {
        Some(content) => {
          let expected = @digest.string_to_utf8_bytes("hello world\n")
          assert_eq(content.length(), expected.length())
          for i in 0..<content.length() {
            assert_eq(content[i], expected[i])
          }
        }
        None => fail("files/a.txt should be in recovered map")
      }
      match recovered.get("files/b.bin") {
        Some(content) => assert_eq(content.length(), 0)
        None => fail("files/b.bin should be in recovered map")
      }
    }
    Err(_) => fail("reconstruct_strict should succeed but returned Err")
  }
}
