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
// Returns 1 iff a > b for byte-sized Int values, else 0.
fn byte_gt_mask(a : Int, b : Int) -> Int {
  ((b - a) >> 31) & 1
}

///|
// Returns 1 iff a < b for byte-sized Int values, else 0.
fn byte_lt_mask(a : Int, b : Int) -> Int {
  ((a - b) >> 31) & 1
}

///|
/// Reduce a 64-byte hash modulo the group order l using binary quotient
/// decomposition. Process 64 bytes from MSB to LSB:
/// result = result*256 + h[i], then reduce mod l.
///
/// After each shift, acc < l*257. Instead of subtracting l up to 256 times
/// (the old approach, ~500K byte-ops), we precompute l*2^k for k=0..8 and
/// subtract the appropriate multiples in 9 steps — each step halves the
/// maximum remainder. This gives ~9 comparisons + ~9 subtractions per byte
/// (~600 byte-ops total), a ~800x improvement over the old single-subtraction
/// loop while remaining straightforward and provably correct.
fn reduce_scalar_512(h : Bytes) -> Bytes {
  let l = group_order()
  // Precompute l as 34-byte Int array (extra byte for shift overflow).
  let l_bytes : Array[Int] = Array::make(34, 0)
  for idx in 0..<32 {
    l_bytes[idx] = l[idx].to_int() & 0xff
  }
  // Precompute mul[k] = l * 2^k for k=0..8 (each 34-byte little-endian).
  // After shift+add, acc < l*257. Subtracting l*2^k for k=8..0 reduces to < l.
  // Each element must be an independent array (Array::make aliases mutable defaults).
  let mul : Array[Array[Int]] = []
  for _ in 0..<9 {
    mul.push(Array::make(34, 0))
  }
  for idx in 0..<32 {
    mul[0][idx] = l_bytes[idx]
  }
  for k in 1..<9 {
    let mut carry = 0
    for idx in 0..<34 {
      let val = mul[k - 1][idx] * 2 + carry
      mul[k][idx] = val & 0xff
      carry = val >> 8
    }
  }
  let acc : Array[Int] = Array::make(34, 0)
  let mut i = 63
  while i >= 0 {
    // Shift acc left by 1 byte (multiply by 256).
    let mut j = 33
    while j >= 1 {
      acc[j] = acc[j - 1]
      j = j - 1
    }
    acc[0] = h[i].to_int() & 0xff
    // Reduce: subtract l*2^k for k=8 downto 0. Each step halves max remainder.
    let mut k = 8
    while k >= 0 {
      // Compare acc vs mul[k] from MSB. The greater/less flags are built with
      // arithmetic masks so the source has no secret-dependent compare branch.
      let mut gt = 0
      let mut lt = 0
      let mut idx = 33
      while idx >= 0 {
        let a = acc[idx]
        let m = mul[k][idx]
        let undecided = 1 - (gt | lt)
        gt = gt | (byte_gt_mask(a, m) * undecided)
        lt = lt | (byte_lt_mask(a, m) * undecided)
        idx = idx - 1
      }
      // Branchless conditional subtraction: compute diff into a temp
      // buffer, then cmov select diff or original based on acc >= mul[k].
      let do_sub = 1 - lt
      let mut borrow = 0
      for idx in 0..<34 {
        let diff = acc[idx] - mul[k][idx] - borrow
        let next_borrow = (diff >> 31) & 1
        let reduced = diff + next_borrow * 256
        acc[idx] = acc[idx] * (1 - do_sub) + reduced * do_sub
        borrow = next_borrow
      }
      k = k - 1
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
  // RFC 8032 §5.1.3: reject the identity point as a public key.
  // The identity (0, 1) has order 1; accepting it would allow forgery
  // via malleability: any signature with R = S*B would verify.
  if a_point.is_identity() {
    return false
  }
  // Reject all 8 small-order points (cofactor=8 subgroup torsion).
  // 8*A = A.double().double().double(); if the result is the identity,
  // A is in the torsion subgroup (order 1/2/4/8) and must be rejected.
  // Without this check, an attacker using a low-order public key can
  // forge signatures with ~50% success probability per attempt.
  let a_doubled = a_point.double().double().double()
  if a_doubled.is_identity() {
    return false
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
  // Reject non-canonical y (y >= p). RFC 8032 §5.1.3 requires y in [0, p-1].
  // Fe::to_bytes() performs canonical reduction, so if the round-trip
  // differs from the input bytes, the encoding was non-canonical.
  let y_original = Bytes::from_array(y_arr)
  if y_original != y.to_bytes() {
    return None
  }
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
