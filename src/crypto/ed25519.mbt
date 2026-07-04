// Ed25519 digital signature (RFC 8032).
// sign(sk, msg) -> 64-byte signature
// verify(pk, msg, sig) -> Bool

///|
// Group order l = 2^252 + 27742317777372353535851937790883648493
// Little-endian bytes of l. Cached as a top-level constant.
let group_order_val : Bytes = Bytes::from_array([
  b'\xed', b'\xd3', b'\xf5', b'\x5c', b'\x1a', b'\x63', b'\x12', b'\x58', b'\xd6',
  b'\x9c', b'\xf7', b'\xa2', b'\xde', b'\xf9', b'\xde', b'\x14', b'\x00', b'\x00',
  b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00',
  b'\x00', b'\x00', b'\x00', b'\x00', b'\x10',
])

///|
fn group_order() -> Bytes {
  group_order_val
}

///|
fn sha512(data : Bytes) -> Bytes {
  let ctx = @digest.Sha512Ctx::new()
  ctx.update(data)
  ctx.finalize()
}

///|
fn concat_bytes(a : Bytes, b : Bytes) -> Bytes {
  let arr : Array[Byte] = []
  for i in 0..<a.length() {
    arr.push(a[i])
  }
  for i in 0..<b.length() {
    arr.push(b[i])
  }
  Bytes::from_array(arr)
}

///|
fn concat3(a : Bytes, b : Bytes, c : Bytes) -> Bytes {
  concat_bytes(concat_bytes(a, b), c)
}

///|
// Clamp the first 32 bytes of SHA-512(sk) per RFC 8032.
fn clamp_scalar(h : Bytes) -> Bytes {
  let arr : Array[Byte] = []
  for i in 0..<32 {
    arr.push(h[i])
  }
  let v0 = arr[0].to_int() & 248
  arr[0] = (v0.to_uint64() & 0xffUL).to_byte()
  let v31 = (arr[31].to_int() & 127) | 64
  arr[31] = (v31.to_uint64() & 0xffUL).to_byte()
  Bytes::from_array(arr)
}

///|
// Reduce a 64-byte hash modulo the group order l.
// Uses Barrett-like reduction: interpret the 512-bit hash as a number,
// reduce mod l via schoolbook division.
// For simplicity, we implement modular reduction of a 64-byte little-endian
// number mod l using repeated subtraction with doubling.
//
// KNOWN PERFORMANCE BOTTLENECK: this uses "multiply by 256 then subtract l
// repeatedly" to reduce. After each shift the accumulator is < l*257, so up to
// 256 subtractions may be needed per input byte, over 64 bytes -> up to ~16K
// full 33-byte subtractions per call (~500K byte ops). This is correct but
// slow compared to TweetNaCl's sc_reduce (21-bit limb, single-pass) or a true
// Barrett reduction. Correctness is prioritized here; a future optimization
// should port sc_reduce from TweetNaCl for an order-of-magnitude speedup.
fn reduce_scalar_512(h : Bytes) -> Bytes {
  // We need to reduce a 512-bit number mod l (253-bit prime order).
  // Strategy: process 64 bytes as a polynomial in 2^8, accumulate mod l.
  // result = sum_{i=0}^{63} h[i] * 256^i mod l
  // Compute from MSB: result = 0; for i=63..0: result = result*256 + h[i]
  // Each step: result mod l via big-number subtraction.
  //
  // Represent the running accumulator as 33 bytes (264 bits, enough for l*256+255).
  let acc : Array[Int] = Array::make(33, 0)
  let l = group_order()
  // Precompute l as Int bytes once (hoisted out of the hot subtract loop).
  let l_bytes : Array[Int] = Array::make(33, 0)
  for idx in 0..<32 {
    l_bytes[idx] = l[idx].to_int() & 0xff
  }
  l_bytes[32] = 0
  let mut i = 63
  while i >= 0 {
    // Multiply acc by 256 (shift left 1 byte)
    let mut j = 32
    while j >= 1 {
      acc[j] = acc[j - 1]
      j = j - 1
    }
    acc[0] = h[i].to_int() & 0xff
    // Reduce: while acc >= l, subtract l
    // To compare and subtract, treat acc and l as 33-byte little-endian numbers.
    let mut reduced = true
    while reduced {
      // Check acc >= l by comparing from MSB
      let mut cmp = 0
      let mut k = 32
      while k >= 0 {
        let a_k = acc[k]
        let l_k = l_bytes[k]
        if a_k > l_k && cmp == 0 {
          cmp = 1
        } else if a_k < l_k && cmp == 0 {
          cmp = -1
        }
        k = k - 1
      }
      if cmp >= 0 {
        // acc >= l, subtract l
        let mut borrow = 0
        for idx in 0..<33 {
          let l_v = l_bytes[idx]
          let diff = acc[idx] - l_v - borrow
          if diff < 0 {
            acc[idx] = diff + 256
            borrow = 1
          } else {
            acc[idx] = diff
            borrow = 0
          }
        }
      } else {
        reduced = false
      }
    }
    i = i - 1
  }
  let result : Array[Byte] = []
  for idx in 0..<32 {
    result.push((acc[idx].to_uint64() & 0xffUL).to_byte())
  }
  Bytes::from_array(result)
}

///|
/// Derives Ed25519 public key from 32-byte secret key.
pub fn ed25519_public_key(sk : Bytes) -> Bytes {
  let h = sha512(sk)
  let a = clamp_scalar(h)
  let pub_point = Point::base_point().scalar_mul(a)
  pub_point.encode()
}

///|
/// Signs a message with Ed25519 (RFC 8032 pure EdDSA).
/// sk: 32-byte secret key.
/// Returns 64-byte signature (R || S).
pub fn ed25519_sign(sk : Bytes, msg : Bytes) -> Bytes {
  let h = sha512(sk)
  let a = clamp_scalar(h)
  // Nonce prefix: h[32..64]
  let prefix : Array[Byte] = []
  for i in 32..<64 {
    prefix.push(h[i])
  }
  let prefix_bytes = Bytes::from_array(prefix)
  let pk = ed25519_public_key(sk)
  // r = SHA-512(prefix || msg) mod l
  let r_hash = sha512(concat_bytes(prefix_bytes, msg))
  let r = reduce_scalar_512(r_hash)
  // R = r * B
  let big_r = Point::base_point().scalar_mul(r)
  let big_r_enc = big_r.encode()
  // k = SHA-512(R || pk || msg) mod l
  let k_hash = sha512(concat3(big_r_enc, pk, msg))
  let k = reduce_scalar_512(k_hash)
  // S = (r + k * a) mod l
  let s = sc_muladd(k, a, r)
  concat_bytes(big_r_enc, s)
}

///|
// Compute (a*b + c) mod l using big-number arithmetic.
fn sc_muladd(a : Bytes, b : Bytes, c : Bytes) -> Bytes {
  // Multiply a * b into 64 bytes, add c, then reduce mod l.
  let product : Array[Int] = Array::make(64, 0)
  for i in 0..<32 {
    for j in 0..<32 {
      product[i + j] = product[i + j] +
        (a[i].to_int() & 0xff) * (b[j].to_int() & 0xff)
    }
  }
  // Add c
  for i in 0..<32 {
    product[i] = product[i] + (c[i].to_int() & 0xff)
  }
  // Carry propagation
  for i in 0..<63 {
    product[i + 1] = product[i + 1] + product[i] / 256
    product[i] = product[i] % 256
  }
  // Convert to Bytes and reduce
  let prod_bytes : Array[Byte] = []
  for i in 0..<64 {
    prod_bytes.push((product[i].to_uint64() & 0xffUL).to_byte())
  }
  reduce_scalar_512(Bytes::from_array(prod_bytes))
}

///|
// Compare a 32-byte little-endian scalar s against the group order l.
// Returns true iff s < l (RFC 8032 §8.4 canonical encoding check).
// This rejects non-canonical S values to prevent signature malleability.
fn scalar_lt_l(s : Bytes) -> Bool {
  let l = group_order()
  // Compare from the most significant byte (index 31) down to 0.
  let mut i = 31
  while i >= 0 {
    let sv = s[i].to_int() & 0xff
    let lv = l[i].to_int() & 0xff
    if sv < lv {
      return true
    } else if sv > lv {
      return false
    }
    i = i - 1
  }
  // s == l, not strictly less.
  false
}

///|
/// Verifies an Ed25519 signature.
/// pk: 32-byte public key, msg: message, sig: 64-byte signature.
pub fn ed25519_verify(pk : Bytes, msg : Bytes, sig : Bytes) -> Bool {
  if sig.length() != 64 || pk.length() != 32 {
    return false
  }
  // R = sig[0..32], S = sig[32..64]
  let r_bytes : Array[Byte] = []
  let s_bytes : Array[Byte] = []
  for i in 0..<32 {
    r_bytes.push(sig[i])
  }
  for i in 32..<64 {
    s_bytes.push(sig[i])
  }
  let r_enc = Bytes::from_array(r_bytes)
  let s_enc = Bytes::from_array(s_bytes)
  // RFC 8032 §8.4: reject non-canonical S (S >= l) to block malleability.
  if !scalar_lt_l(s_enc) {
    return false
  }
  // Decode public key point A
  let a_point = match point_decode(pk) {
    Some(p) => p
    None => return false
  }
  // Decode R
  let r_point = match point_decode(r_enc) {
    Some(p) => p
    None => return false
  }
  // k = SHA-512(R || pk || msg) mod l
  let k_hash = sha512(concat3(r_enc, pk, msg))
  let k = reduce_scalar_512(k_hash)
  // Check: S*B == R + k*A
  let sb = Point::base_point().scalar_mul(s_enc)
  let ka = a_point.scalar_mul(k)
  let rhs = r_point.add(ka)
  sb.eq(rhs)
}

///|
// sqrt(-1) mod p, needed for point decoding. Cached as a top-level constant.
let sqrt_m1_val : Fe = Fe::from_bytes(
  Bytes::from_array([
    b'\xb0', b'\xa0', b'\x0e', b'\x4a', b'\x27', b'\x1b', b'\xee', b'\xc4', b'\x78',
    b'\xe4', b'\x2f', b'\xad', b'\x06', b'\x18', b'\x43', b'\x2f', b'\xa7', b'\xd7',
    b'\xfb', b'\x3d', b'\x99', b'\x00', b'\x4d', b'\x2b', b'\x0b', b'\xdf', b'\xc1',
    b'\x4f', b'\x80', b'\x24', b'\x83', b'\x2b',
  ]),
)

///|
fn sqrt_m1() -> Fe {
  sqrt_m1_val
}

///|
// Compute a^((p+3)/8) = a^(2^252 - 2) for square root.
fn fe_pow_p_plus_3_div_8(a : Fe) -> Fe {
  let a2 = a.square()
  let a_2_1 = a2.mul(a)
  let a_4_1 = a_2_1.pow2(2).mul(a_2_1)
  let a_5_1 = a_4_1.square().mul(a)
  let a_10_1 = a_5_1.pow2(5).mul(a_5_1)
  let a_20_1 = a_10_1.pow2(10).mul(a_10_1)
  let a_40_1 = a_20_1.pow2(20).mul(a_20_1)
  let a_50_1 = a_40_1.pow2(10).mul(a_10_1)
  let a_100_1 = a_50_1.pow2(50).mul(a_50_1)
  let a_200_1 = a_100_1.pow2(100).mul(a_100_1)
  let a_250_1 = a_200_1.pow2(50).mul(a_50_1)
  // a^(2^251-1) then square gives a^(2^252-2)
  a_250_1.square().mul(a).pow2(1)
}

///|
/// Decode a 32-byte compressed Ed25519 point.
pub fn point_decode(data : Bytes) -> Point? {
  if data.length() != 32 {
    return None
  }
  // Extract sign bit and y coordinate
  let sign = (data[31].to_int() >> 7) & 1
  let y_arr : Array[Byte] = []
  for i in 0..<31 {
    y_arr.push(data[i])
  }
  y_arr.push(((data[31].to_int() & 0x7f).to_uint64() & 0xffUL).to_byte())
  let y = Fe::from_bytes(Bytes::from_array(y_arr))
  // x^2 = (y^2 - 1) / (d*y^2 + 1)
  let y2 = y.square()
  let u = y2.sub(Fe::one())
  let v = curve_d().mul(y2).add(Fe::one())
  let v_inv = v.invert()
  let x2 = u.mul(v_inv)
  // x = x2^((p+3)/8)
  let mut x = fe_pow_p_plus_3_div_8(x2)
  // Check: if x^2 != x2, multiply by sqrt(-1)
  if x.square().eq(x2) == false {
    x = x.mul(sqrt_m1())
  }
  if x.square().eq(x2) == false {
    return None
  }
  // Fix sign
  let x_bytes = x.to_bytes()
  let x_sign = x_bytes[0].to_int() & 1
  if x_sign != sign {
    x = Fe::zero().sub(x)
  }
  // Handle x = 0 with sign = 1 (invalid)
  if x.eq(Fe::zero()) && sign == 1 {
    return None
  }
  Some(Point::from_affine(x, y))
}
