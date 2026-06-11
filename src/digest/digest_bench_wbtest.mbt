// Throughput benchmarks for the pure-MoonBit SHA-256 (`moon bench`).
// Numbers feed the README performance section; methodology lives in
// docs/records/RESULTS_LOG.md (step 8 task 4).

///|
/// Deterministic pseudo-random payload (splitmix64 over 8-byte words) so
/// every run hashes identical bytes.
fn bench_payload(size : Int) -> Bytes {
  let bytes : Array[Byte] = []
  let mut state : UInt64 = 0x6469676573742d62UL // "digest-b"
  while bytes.length() < size {
    state = state + 0x9E3779B97F4A7C15UL
    let mut z = state
    z = (z ^ (z >> 30)) * 0xBF58476D1CE4E5B9UL
    z = (z ^ (z >> 27)) * 0x94D049BB133111EBUL
    z = z ^ (z >> 31)
    for shift in [0, 8, 16, 24, 32, 40, 48, 56] {
      if bytes.length() < size {
        bytes.push(((z >> shift) & 0xffUL).to_byte())
      }
    }
  }
  Bytes::from_array(bytes)
}

///|
test "bench: sha256 1 MiB" (b : @bench.T) {
  let payload = bench_payload(1024 * 1024)
  b.bench(fn() { b.keep(sha256(payload)) })
}

///|
test "bench: sha256 64 KiB" (b : @bench.T) {
  let payload = bench_payload(64 * 1024)
  b.bench(fn() { b.keep(sha256(payload)) })
}
