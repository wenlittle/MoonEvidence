// End-to-end pipeline benchmarks (`moon bench`): manifest parsing,
// canonicalization, per-file digests, and Merkle recomputation over
// synthetic packs of 1k and 10k files. Numbers feed the README performance
// section; methodology lives in docs/records/RESULTS_LOG.md (step 8 task 4).

///|
/// Builds a structurally valid pack with `count` files of `file_size` bytes
/// each: real digests, real Merkle root, deterministic content. The manifest
/// is assembled in canonical entry order so the recorded root matches what
/// the pipeline recomputes.
fn bench_pack(count : Int, file_size : Int) -> (String, Map[String, Bytes]) {
  let files : Map[String, Bytes] = {}
  let leaves : Array[Bytes] = []
  let entries = StringBuilder::new()
  for index in 0..<count {
    // Deterministic distinct payload: index header + repeating filler.
    let content : Array[Byte] = []
    content.push((index & 0xff).to_byte())
    content.push(((index >> 8) & 0xff).to_byte())
    content.push(((index >> 16) & 0xff).to_byte())
    while content.length() < file_size {
      content.push((content.length() & 0xff).to_byte())
    }
    let payload = Bytes::from_array(content)
    let path = "files/f\{index}.bin"
    files[path] = payload
    let digest_hex = @digest.sha256_hex(payload)
    // Canonical file entry (keys already in UTF-16 code unit order), the
    // spec's Merkle leaf payload.
    let entry = "{\"digest\":\"sha256:\{digest_hex}\",\"path\":\"\{path}\",\"size\":\{file_size}}"
    leaves.push(@digest.string_to_utf8_bytes(entry))
    if index > 0 {
      entries.write_char(',')
    }
    entries.write_string(entry)
  }
  let root = match @merkle.compute_root(leaves) {
    Some(root) => root
    None => abort("bench pack cannot be empty")
  }
  let root_hex = bytes_to_lower_hex(root)
  let manifest = "{\"schema\":\"moon-evidence/v0\",\"subject\":{\"id\":\"bench-pack\",\"type\":\"dataset\"},\"hash_algorithm\":\"sha256\",\"files\":[\{entries.to_string()}],\"merkle_root\":\"sha256:\{root_hex}\",\"version\":{\"id\":\"v1\",\"parent\":null}}"
  (manifest, files)
}

///|
fn assert_bench_pack_ok(report : @diag.VerifyReport) -> Unit {
  // Keep the benchmark honest: a pack that stops verifying would silently
  // benchmark the (cheaper) failure path.
  if !report.ok {
    let detail = StringBuilder::new()
    for finding in report.findings {
      detail.write_string("\n  \{finding}")
    }
    abort("bench pack no longer verifies:\{detail.to_string()}")
  }
}

///|
test "bench: verify 1k-file manifest" (b : @bench.T) {
  let (manifest, files) = bench_pack(1000, 64)
  assert_bench_pack_ok(verify_manifest(manifest, files))
  b.bench(fn() { b.keep(verify_manifest(manifest, files)) })
}

///|
test "bench: verify 10k-file manifest" (b : @bench.T) {
  let (manifest, files) = bench_pack(10000, 64)
  assert_bench_pack_ok(verify_manifest(manifest, files))
  b.bench(fn() { b.keep(verify_manifest(manifest, files)) })
}
