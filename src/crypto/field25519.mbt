// GF(2^255-19) field arithmetic for Ed25519.
// Uses 16 limbs of 16 bits each in UInt64 (TweetNaCl-style).
// Products fit in 32 bits, accumulators in ~42 bits, all within UInt64.

///|
/// A field element in GF(2^255-19), stored as 16 limbs of ~16 bits each.
pub struct Fe {
  limbs : FixedArray[UInt64]
}

///|
/// The additive identity (0).
pub fn Fe::zero() -> Fe {
  { limbs: FixedArray::make(16, 0UL) }
}

///|
/// The multiplicative identity (1).
pub fn Fe::one() -> Fe {
  let l = FixedArray::make(16, 0UL)
  l[0] = 1UL
  { limbs: l }
}

///|
/// Creates a field element from a small integer (fits in UInt64).
pub fn Fe::from_small(n : UInt64) -> Fe {
  let l = FixedArray::make(16, 0UL)
  l[0] = n & 0xffffUL
  l[1] = (n >> 16) & 0xffffUL
  l[2] = (n >> 32) & 0xffffUL
  l[3] = (n >> 48) & 0xffffUL
  { limbs: l }
}

///|
// 2^256 ≡ 38 (mod p), so carry out of limb 15 wraps to limb 0 * 38.
fn fe_carry(o : FixedArray[UInt64]) -> Unit {
  for i in 0..<16 {
    let c = o[i] >> 16
    let factor : UInt64 = if i == 15 { 38UL } else { 1UL }
    o[(i + 1) % 16] = o[(i + 1) % 16] + c * factor
    o[i] = o[i] & 0xffffUL
  }
}

///|
/// Field addition: (a + b) mod p.
pub fn Fe::add(self : Fe, other : Fe) -> Fe {
  let r = FixedArray::make(16, 0UL)
  for i in 0..<16 {
    r[i] = self.limbs[i] + other.limbs[i]
  }
  fe_carry(r)
  { limbs: r }
}

///|
/// Field subtraction: (a - b) mod p. Uses 4p bias for unsigned safety.
pub fn Fe::sub(self : Fe, other : Fe) -> Fe {
  let r = FixedArray::make(16, 0UL)
  for i in 0..<16 {
    // 4*p bias prevents UInt64 underflow.
    // p = [0xffed, 0xffff x14, 0x7fff]
    let bias : UInt64 = if i == 0 {
      0x3FFB4UL
    } else if i == 15 {
      0x1FFFCUL
    } else {
      0x3FFFCUL
    }
    r[i] = self.limbs[i] + bias - other.limbs[i]
  }
  fe_carry(r)
  fe_carry(r)
  { limbs: r }
}

///|
/// Field multiplication: (a * b) mod p. Schoolbook 16x16 with mod-reduction.
pub fn Fe::mul(self : Fe, other : Fe) -> Fe {
  let a = self.limbs
  let b = other.limbs
  let t = FixedArray::make(31, 0UL)
  for i in 0..<16 {
    for j in 0..<16 {
      t[i + j] = t[i + j] + a[i] * b[j]
    }
  }
  // Fold: 2^(16*k) for k>=16 means 2^256 * 2^(16*(k-16)) ≡ 38 * 2^(16*(k-16))
  for i in 0..<15 {
    t[i] = t[i] + 38UL * t[i + 16]
  }
  let r = FixedArray::make(16, 0UL)
  for i in 0..<16 {
    r[i] = t[i]
  }
  fe_carry(r)
  fe_carry(r)
  { limbs: r }
}

///|
/// Field squaring: a^2 mod p.
pub fn Fe::square(self : Fe) -> Fe {
  self.mul(self)
}

///|
pub fn Fe::pow2(self : Fe, n : Int) -> Fe {
  let mut result = self
  for _i in 0..<n {
    result = result.square()
  }
  result
}

///|
/// a^(p-2) via Fermat's little theorem. p-2 = 2^255 - 21.
/// Uses the standard addition chain: build a^(2^250-1), shift left 5,
/// then multiply by a^11 to get a^(2^255-32+11) = a^(2^255-21).
pub fn Fe::invert(self : Fe) -> Fe {
  let a = self
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
  let t = a_250_1.pow2(5)
  let a4 = a2.square()
  let a8 = a4.square()
  let a11 = a8.mul(a2).mul(a)
  t.mul(a11)
}

///|
pub fn Fe::from_bytes(data : Bytes) -> Fe {
  let l = FixedArray::make(16, 0UL)
  for i in 0..<16 {
    let lo = (data[2 * i].to_int() & 0xff).to_uint64()
    let hi = (data[2 * i + 1].to_int() & 0xff).to_uint64()
    l[i] = lo | (hi << 8)
  }
  { limbs: l }
}

///|
/// Canonical reduction + serialization to 32 bytes little-endian.
/// Carries 3 times, then tentatively subtracts p twice.
pub fn Fe::to_bytes(self : Fe) -> Bytes {
  let t = self.limbs.copy()
  fe_carry(t)
  fe_carry(t)
  fe_carry(t)
  for _round in 0..<2 {
    let m = FixedArray::make(16, 0UL)
    let mut borrow = 0UL
    for i in 0..<16 {
      let p_i : UInt64 = if i == 0 {
        0xffedUL
      } else if i == 15 {
        0x7fffUL
      } else {
        0xffffUL
      }
      let v = t[i] + 0x10000UL - p_i - borrow
      m[i] = v & 0xffffUL
      borrow = 1UL - (v >> 16)
    }
    // Constant-time conditional copy: branchlessly select m[i] or keep
    // t[i] based on borrow. When borrow == 0, the subtraction was valid
    // (t >= p) so we commit m; when borrow == 1, t < p so we keep t.
    // mask = all-ones when borrow=0 (do commit), all-zeros when borrow=1 (keep t).
    let mask : UInt64 = (1UL - borrow) * 0xffffffffffffffffUL
    let inv_mask : UInt64 = 0xffffffffffffffffUL - mask
    for i in 0..<16 {
      // t[i] = (t[i] & inv_mask) | (m[i] & mask)
      t[i] = (t[i] & inv_mask) | (m[i] & mask)
    }
  }
  let output : Array[Byte] = []
  for i in 0..<16 {
    output.push((t[i] & 0xffUL).to_byte())
    output.push(((t[i] >> 8) & 0xffUL).to_byte())
  }
  Bytes::from_array(output)
}

///|
/// Equality test via canonical byte comparison.
/// Constant-time: accumulates all byte differences with XOR before testing,
/// so the control flow does not depend on secret field-element data.
pub fn Fe::eq(self : Fe, other : Fe) -> Bool {
  let a = self.to_bytes()
  let b = other.to_bytes()
  let mut diff = 0
  for i in 0..<32 {
    diff = diff | (a[i].to_int() ^ b[i].to_int())
  }
  diff == 0
}

///|
/// Constant-time conditional move for field elements.
/// Returns `true_val` when `bit == 1`, `false_val` when `bit == 0`,
/// without a secret-dependent branch. `bit` must be 0 or 1.
/// Used by scalar_mul to avoid timing side-channels on secret scalars.
fn fe_cmov(false_val : Fe, true_val : Fe, bit : Int) -> Fe {
  let b : UInt64 = (bit & 1).to_uint64()
  // mask = all 1s if b == 1, all 0s if b == 0 (branch-free).
  let mask : UInt64 = b * 0xffffffffffffffffUL
  let r = FixedArray::make(16, 0UL)
  for i in 0..<16 {
    // r = false ^ (mask & (false ^ true))
    // mask = 0  -> r = false
    // mask = -1 -> r = false ^ (false ^ true) = true
    let diff = false_val.limbs[i] ^ true_val.limbs[i]
    r[i] = false_val.limbs[i] ^ (mask & diff)
  }
  { limbs: r }
}
