// Pure MoonBit SHA-512 implementation (FIPS 180-4, section 6.4).
// Mirrors the SHA-256 code structure but uses 64-bit words, 128-byte
// blocks, 80 rounds, and produces a 64-byte (512-bit) digest.

///|
let sha512_k : FixedArray[UInt64] = [
  0x428a2f98d728ae22UL, 0x7137449123ef65cdUL, 0xb5c0fbcfec4d3b2fUL, 0xe9b5dba58189dbbcUL,
  0x3956c25bf348b538UL, 0x59f111f1b605d019UL, 0x923f82a4af194f9bUL, 0xab1c5ed5da6d8118UL,
  0xd807aa98a3030242UL, 0x12835b0145706fbeUL, 0x243185be4ee4b28cUL, 0x550c7dc3d5ffb4e2UL,
  0x72be5d74f27b896fUL, 0x80deb1fe3b1696b1UL, 0x9bdc06a725c71235UL, 0xc19bf174cf692694UL,
  0xe49b69c19ef14ad2UL, 0xefbe4786384f25e3UL, 0x0fc19dc68b8cd5b5UL, 0x240ca1cc77ac9c65UL,
  0x2de92c6f592b0275UL, 0x4a7484aa6ea6e483UL, 0x5cb0a9dcbd41fbd4UL, 0x76f988da831153b5UL,
  0x983e5152ee66dfabUL, 0xa831c66d2db43210UL, 0xb00327c898fb213fUL, 0xbf597fc7beef0ee4UL,
  0xc6e00bf33da88fc2UL, 0xd5a79147930aa725UL, 0x06ca6351e003826fUL, 0x142929670a0e6e70UL,
  0x27b70a8546d22ffcUL, 0x2e1b21385c26c926UL, 0x4d2c6dfc5ac42aedUL, 0x53380d139d95b3dfUL,
  0x650a73548baf63deUL, 0x766a0abb3c77b2a8UL, 0x81c2c92e47edaee6UL, 0x92722c851482353bUL,
  0xa2bfe8a14cf10364UL, 0xa81a664bbc423001UL, 0xc24b8b70d0f89791UL, 0xc76c51a30654be30UL,
  0xd192e819d6ef5218UL, 0xd69906245565a910UL, 0xf40e35855771202aUL, 0x106aa07032bbd1b8UL,
  0x19a4c116b8d2d0c8UL, 0x1e376c085141ab53UL, 0x2748774cdf8eeb99UL, 0x34b0bcb5e19b48a8UL,
  0x391c0cb3c5c95a63UL, 0x4ed8aa4ae3418acbUL, 0x5b9cca4f7763e373UL, 0x682e6ff3d6b2b8a3UL,
  0x748f82ee5defb2fcUL, 0x78a5636f43172f60UL, 0x84c87814a1f0ab72UL, 0x8cc702081a6439ecUL,
  0x90befffa23631e28UL, 0xa4506cebde82bde9UL, 0xbef9a3f7b2c67915UL, 0xc67178f2e372532bUL,
  0xca273eceea26619cUL, 0xd186b8c721c0c207UL, 0xeada7dd6cde0eb1eUL, 0xf57d4f7fee6ed178UL,
  0x06f067aa72176fbaUL, 0x0a637dc5a2c898a6UL, 0x113f9804bef90daeUL, 0x1b710b35131c471bUL,
  0x28db77f523047d84UL, 0x32caab7b40c72493UL, 0x3c9ebe0a15c9bebcUL, 0x431d67c49c100d4cUL,
  0x4cc5d4becb3e42b6UL, 0x597f299cfc657e2aUL, 0x5fcb6fab3ad6faecUL, 0x6c44198c4a475817UL,
]

///|
pub struct Sha512Ctx {
  state : FixedArray[UInt64]
  buffer : FixedArray[Byte]
  mut buffered : Int
  mut total_bytes : UInt64
}

///|
pub fn Sha512Ctx::new() -> Sha512Ctx {
  {
    state: [
      0x6a09e667f3bcc908UL, 0xbb67ae8584caa73bUL,
      0x3c6ef372fe94f82bUL, 0xa54ff53a5f1d36f1UL,
      0x510e527fade682d1UL, 0x9b05688c2b3e6c1fUL,
      0x1f83d9abfb41bd6bUL, 0x5be0cd19137e2179UL,
    ],
    buffer: FixedArray::make(128, b'\x00'),
    buffered: 0,
    total_bytes: 0UL,
  }
}

///|
pub fn Sha512Ctx::update(self : Sha512Ctx, data : Bytes) -> Unit {
  self.total_bytes = self.total_bytes + data.length().to_uint64()
  let mut offset = 0
  while offset < data.length() {
    let available = 128 - self.buffered
    let remaining = data.length() - offset
    let take = if remaining < available { remaining } else { available }
    for index in 0..<take {
      self.buffer[self.buffered + index] = data[offset + index]
    }
    self.buffered = self.buffered + take
    offset = offset + take
    if self.buffered == 128 {
      process_block_512(self.state, self.buffer, 0)
      self.buffered = 0
    }
  }
}

///|
pub fn Sha512Ctx::finalize(self : Sha512Ctx) -> Bytes {
  let state = self.state.copy()
  let tail_blocks = if self.buffered <= 111 { 1 } else { 2 }
  let tail : FixedArray[Byte] = FixedArray::make(tail_blocks * 128, b'\x00')
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
    process_block_512(state, tail, offset)
    offset = offset + 128
  }
  state_to_bytes_512(state)
}

///|
fn rotr64(x : UInt64, n : Int) -> UInt64 {
  (x >> n) | (x << (64 - n))
}

///|
fn process_block_512(
  state : FixedArray[UInt64],
  block : FixedArray[Byte],
  offset : Int,
) -> Unit {
  let w : FixedArray[UInt64] = FixedArray::make(80, 0UL)
  for t in 0..<16 {
    let base = offset + t * 8
    w[t] = (block[base].to_int().to_uint64() << 56)
      | (block[base + 1].to_int().to_uint64() << 48)
      | (block[base + 2].to_int().to_uint64() << 40)
      | (block[base + 3].to_int().to_uint64() << 32)
      | (block[base + 4].to_int().to_uint64() << 24)
      | (block[base + 5].to_int().to_uint64() << 16)
      | (block[base + 6].to_int().to_uint64() << 8)
      | block[base + 7].to_int().to_uint64()
  }
  for t in 16..<80 {
    let s0 = rotr64(w[t - 15], 1) ^ rotr64(w[t - 15], 8) ^ (w[t - 15] >> 7)
    let s1 = rotr64(w[t - 2], 19) ^ rotr64(w[t - 2], 61) ^ (w[t - 2] >> 6)
    w[t] = w[t - 16] + s0 + w[t - 7] + s1
  }
  let mut a = state[0]
  let mut b = state[1]
  let mut c = state[2]
  let mut d = state[3]
  let mut e = state[4]
  let mut f = state[5]
  let mut g = state[6]
  let mut h = state[7]
  for t in 0..<80 {
    let big_s1 = rotr64(e, 14) ^ rotr64(e, 18) ^ rotr64(e, 41)
    let ch = (e & f) ^ (e.lnot() & g)
    let temp1 = h + big_s1 + ch + sha512_k[t] + w[t]
    let big_s0 = rotr64(a, 28) ^ rotr64(a, 34) ^ rotr64(a, 39)
    let maj = (a & b) ^ (a & c) ^ (b & c)
    let temp2 = big_s0 + maj
    h = g; g = f; f = e; e = d + temp1
    d = c; c = b; b = a; a = temp1 + temp2
  }
  state[0] = state[0] + a; state[1] = state[1] + b
  state[2] = state[2] + c; state[3] = state[3] + d
  state[4] = state[4] + e; state[5] = state[5] + f
  state[6] = state[6] + g; state[7] = state[7] + h
}

///|
fn state_to_bytes_512(state : FixedArray[UInt64]) -> Bytes {
  let output : Array[Byte] = []
  for i in 0..<8 {
    let v = state[i]
    for j in 0..<8 {
      let shift = (7 - j) * 8
      output.push(((v >> shift) & 0xffUL).to_byte())
    }
  }
  Bytes::from_array(output)
}

///|
pub fn sha512_hex(data : Bytes) -> String {
  let ctx = Sha512Ctx::new()
  ctx.update(data)
  bytes_to_lower_hex(ctx.finalize())
}
