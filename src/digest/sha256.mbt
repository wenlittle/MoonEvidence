// SHA-256 implemented in pure MoonBit, following NIST FIPS 180-4.
// No FFI: the same code runs on native, wasm-gc, and js backends, which is
// the cross-backend determinism guarantee MoonEvidence is built on.
//
// Layering: this file owns the raw compression algorithm only. Algorithm
// tagging (`HashAlgorithm`) and digest-string formatting stay in digest.mbt.

// ---------------------------------------------------------------------------
// Constants (FIPS 180-4 sections 4.2.2 and 5.3.3)
// ---------------------------------------------------------------------------

///|
/// First 32 bits of the fractional parts of the cube roots of the first 64
/// primes (FIPS 180-4 section 4.2.2). One constant per compression round.
let sha256_round_constants : FixedArray[UInt] = [
  0x428a2f98U, 0x71374491U, 0xb5c0fbcfU, 0xe9b5dba5U, 0x3956c25bU, 0x59f111f1U, 0x923f82a4U,
  0xab1c5ed5U, 0xd807aa98U, 0x12835b01U, 0x243185beU, 0x550c7dc3U, 0x72be5d74U, 0x80deb1feU,
  0x9bdc06a7U, 0xc19bf174U, 0xe49b69c1U, 0xefbe4786U, 0x0fc19dc6U, 0x240ca1ccU, 0x2de92c6fU,
  0x4a7484aaU, 0x5cb0a9dcU, 0x76f988daU, 0x983e5152U, 0xa831c66dU, 0xb00327c8U, 0xbf597fc7U,
  0xc6e00bf3U, 0xd5a79147U, 0x06ca6351U, 0x14292967U, 0x27b70a85U, 0x2e1b2138U, 0x4d2c6dfcU,
  0x53380d13U, 0x650a7354U, 0x766a0abbU, 0x81c2c92eU, 0x92722c85U, 0xa2bfe8a1U, 0xa81a664bU,
  0xc24b8b70U, 0xc76c51a3U, 0xd192e819U, 0xd6990624U, 0xf40e3585U, 0x106aa070U, 0x19a4c116U,
  0x1e376c08U, 0x2748774cU, 0x34b0bcb5U, 0x391c0cb3U, 0x4ed8aa4aU, 0x5b9cca4fU, 0x682e6ff3U,
  0x748f82eeU, 0x78a5636fU, 0x84c87814U, 0x8cc70208U, 0x90befffaU, 0xa4506cebU, 0xbef9a3f7U,
  0xc67178f2U,
]

///|
/// Initial hash state H(0): first 32 bits of the fractional parts of the
/// square roots of the first 8 primes (FIPS 180-4 section 5.3.3).
fn sha256_initial_state() -> FixedArray[UInt] {
  [
    0x6a09e667U, 0xbb67ae85U, 0x3c6ef372U, 0xa54ff53aU, 0x510e527fU, 0x9b05688cU,
    0x1f83d9abU, 0x5be0cd19U,
  ]
}

// ---------------------------------------------------------------------------
// Public one-shot API
// ---------------------------------------------------------------------------

///|
/// Computes the SHA-256 digest of `data` and returns the raw 32-byte value.
pub fn sha256(data : Bytes) -> Bytes {
  let ctx = Sha256Ctx::new()
  ctx.update(data)
  ctx.finalize()
}

///|
/// Computes the SHA-256 digest of `data` as a 64-character lowercase hex
/// string, the canonical digest text form used across evidence packs.
pub fn sha256_hex(data : Bytes) -> String {
  bytes_to_lower_hex(sha256(data))
}

// ---------------------------------------------------------------------------
// Streaming API
// ---------------------------------------------------------------------------

///|
/// Incremental SHA-256 context for hashing data that arrives in chunks
/// (large files, streamed IO). Equivalent chunkings always produce the same
/// digest as the one-shot `sha256`.
///
/// Fields are package-private so the FIPS 180-4 invariants cannot be broken
/// from outside; construct with `Sha256Ctx::new()`.
pub struct Sha256Ctx {
  /// Intermediate hash value H(i), eight 32-bit words.
  state : FixedArray[UInt]
  /// Staging area holding a partial block until 64 bytes accumulate.
  buffer : FixedArray[Byte]
  /// Number of valid bytes currently staged in `buffer` (0..63).
  mut buffered : Int
  /// Total message bytes absorbed so far; padding needs the exact length.
  mut total_bytes : UInt64
}

///|
/// Creates a fresh context seeded with the FIPS 180-4 initial state H(0).
pub fn Sha256Ctx::new() -> Sha256Ctx {
  {
    state: sha256_initial_state(),
    buffer: FixedArray::make(64, b'\x00'),
    buffered: 0,
    total_bytes: 0UL,
  }
}

///|
/// Absorbs `data` into the running hash. Bytes are staged into the internal
/// block buffer and compressed every time 64 bytes accumulate.
pub fn Sha256Ctx::update(self : Sha256Ctx, data : Bytes) -> Unit {
  self.total_bytes = self.total_bytes + data.length().to_uint64()
  let mut offset = 0
  while offset < data.length() {
    let available = 64 - self.buffered
    let remaining = data.length() - offset
    let take = if remaining < available { remaining } else { available }
    for index in 0..<take {
      self.buffer[self.buffered + index] = data[offset + index]
    }
    self.buffered = self.buffered + take
    offset = offset + take
    if self.buffered == 64 {
      process_block(self.state, self.buffer, 0)
      self.buffered = 0
    }
  }
}

///|
/// Returns the digest of everything absorbed so far as raw 32 bytes.
///
/// Padding (FIPS 180-4 section 5.1.1) is applied to copies of the internal
/// state, so calling `finalize` never mutates the context: it is idempotent
/// and `update` may even continue afterwards.
pub fn Sha256Ctx::finalize(self : Sha256Ctx) -> Bytes {
  let state = self.state.copy()
  // Tail = staged bytes + 0x80 marker + zero fill + 64-bit big-endian bit
  // length. One extra block is needed when fewer than 8 length bytes fit.
  let tail_blocks = if self.buffered <= 55 { 1 } else { 2 }
  let tail : FixedArray[Byte] = FixedArray::make(tail_blocks * 64, b'\x00')
  for index in 0..<self.buffered {
    tail[index] = self.buffer[index]
  }
  tail[self.buffered] = b'\x80'
  let bit_length = self.total_bytes * 8UL
  for index in 0..<8 {
    let shift = (7 - index) * 8
    tail[tail.length() - 8 + index] = ((bit_length >> shift) & 0xffUL).to_byte()
  }
  let mut offset = 0
  while offset < tail.length() {
    process_block(state, tail, offset)
    offset = offset + 64
  }
  state_to_bytes(state)
}

// ---------------------------------------------------------------------------
// Compression (FIPS 180-4 sections 4.1.2 and 6.2.2)
// ---------------------------------------------------------------------------

///|
fn rotr(value : UInt, amount : Int) -> UInt {
  (value >> amount) | (value << (32 - amount))
}

///|
/// Processes one 64-byte block starting at `offset`, updating `state` in
/// place. Callers guarantee `offset + 64 <= block.length()`.
fn process_block(
  state : FixedArray[UInt],
  block : FixedArray[Byte],
  offset : Int,
) -> Unit {
  // Message schedule W[0..63] (FIPS 180-4 section 6.2.2 step 1).
  let schedule : FixedArray[UInt] = FixedArray::make(64, 0U)
  for t in 0..<16 {
    let base = offset + t * 4
    schedule[t] = (block[base].to_uint() << 24) |
      (block[base + 1].to_uint() << 16) |
      (block[base + 2].to_uint() << 8) |
      block[base + 3].to_uint()
  }
  for t in 16..<64 {
    // sigma1(W[t-2]) + W[t-7] + sigma0(W[t-15]) + W[t-16], mod 2^32.
    let sigma0 = rotr(schedule[t - 15], 7) ^
      rotr(schedule[t - 15], 18) ^
      (schedule[t - 15] >> 3)
    let sigma1 = rotr(schedule[t - 2], 17) ^
      rotr(schedule[t - 2], 19) ^
      (schedule[t - 2] >> 10)
    schedule[t] = sigma1 + schedule[t - 7] + sigma0 + schedule[t - 16]
  }

  // Working variables a..h (FIPS 180-4 section 6.2.2 step 2).
  let mut a = state[0]
  let mut b = state[1]
  let mut c = state[2]
  let mut d = state[3]
  let mut e = state[4]
  let mut f = state[5]
  let mut g = state[6]
  let mut h = state[7]

  // 64 rounds (FIPS 180-4 section 6.2.2 step 3).
  for t in 0..<64 {
    let big_sigma1 = rotr(e, 6) ^ rotr(e, 11) ^ rotr(e, 25)
    let choose = (e & f) ^ (e.lnot() & g)
    let temp1 = h +
      big_sigma1 +
      choose +
      sha256_round_constants[t] +
      schedule[t]
    let big_sigma0 = rotr(a, 2) ^ rotr(a, 13) ^ rotr(a, 22)
    let majority = (a & b) ^ (a & c) ^ (b & c)
    let temp2 = big_sigma0 + majority
    h = g
    g = f
    f = e
    e = d + temp1
    d = c
    c = b
    b = a
    a = temp1 + temp2
  }

  // Intermediate hash accumulation (FIPS 180-4 section 6.2.2 step 4).
  state[0] = state[0] + a
  state[1] = state[1] + b
  state[2] = state[2] + c
  state[3] = state[3] + d
  state[4] = state[4] + e
  state[5] = state[5] + f
  state[6] = state[6] + g
  state[7] = state[7] + h
}

// ---------------------------------------------------------------------------
// Output encoding
// ---------------------------------------------------------------------------

///|
/// Serializes the eight 32-bit state words big-endian into 32 bytes
/// (FIPS 180-4 section 6.2.2 final step).
fn state_to_bytes(state : FixedArray[UInt]) -> Bytes {
  Bytes::makei(32, fn(index) {
    let word = state[index / 4]
    let shift = (3 - index % 4) * 8
    ((word >> shift) & 0xffU).to_byte()
  })
}

///|
let hex_digits : FixedArray[Char] = [
  '0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'a', 'b', 'c', 'd', 'e', 'f',
]

///|
fn bytes_to_lower_hex(data : Bytes) -> String {
  let builder = StringBuilder::new(size_hint=data.length() * 2)
  for byte in data {
    let value = byte.to_int()
    builder.write_char(hex_digits[value >> 4])
    builder.write_char(hex_digits[value & 0x0f])
  }
  builder.to_string()
}
