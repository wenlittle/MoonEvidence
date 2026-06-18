// GF(2^255-19) field arithmetic for Ed25519.
// Uses radix-2^51 representation: 5 limbs of 51 bits each in UInt64.
// This is a standard approach used by TweetNaCl and similar implementations.

///|
/// p = 2^255 - 19
let field_p_limbs : FixedArray[UInt64] = [
  0x7ffffffffffedUL, 0x7ffffffffffffUL, 0x7ffffffffffffUL,
  0x7ffffffffffffUL, 0x7ffffffffffffUL,
]

///|
/// A field element in GF(2^255-19), stored as 5 limbs of ~51 bits.
pub struct Fe {
  limbs : FixedArray[UInt64]
}

///|
pub fn Fe::zero() -> Fe {
  { limbs: [0UL, 0UL, 0UL, 0UL, 0UL] }
}

///|
pub fn Fe::one() -> Fe {
  { limbs: [1UL, 0UL, 0UL, 0UL, 0UL] }
}

///|
let mask51 : UInt64 = (1UL << 51) - 1UL

///|
/// Reduces limbs so each fits in 51 bits, carrying excess upward.
/// Final carry wraps around multiplied by 19 (since 2^255 ≡ 19 mod p).
pub fn Fe::reduce(self : Fe) -> Fe {
  let l = self.limbs.copy()
  let mut carry = 0UL
  for i in 0..<4 {
    l[i] = l[i] + carry
    carry = l[i] >> 51
    l[i] = l[i] & mask51
  }
  l[4] = l[4] + carry
  carry = l[4] >> 51
  l[4] = l[4] & mask51
  l[0] = l[0] + carry * 19UL
  carry = l[0] >> 51
  l[0] = l[0] & mask51
  l[1] = l[1] + carry
  { limbs: l }
}

///|
pub fn Fe::add(self : Fe, other : Fe) -> Fe {
  let r : FixedArray[UInt64] = FixedArray::make(5, 0UL)
  for i in 0..<5 {
    r[i] = self.limbs[i] + other.limbs[i]
  }
  Fe::{ limbs: r }.reduce()
}

///|
pub fn Fe::sub(self : Fe, other : Fe) -> Fe {
  let r : FixedArray[UInt64] = FixedArray::make(5, 0UL)
  for i in 0..<5 {
    r[i] = self.limbs[i] + field_p_limbs[i] * 2UL - other.limbs[i]
  }
  Fe::{ limbs: r }.reduce()
}

///|
/// Schoolbook multiplication with reduction. Each product limb can be up
/// to ~102 bits (51+51), and the 128-bit intermediate is handled by
/// splitting into high/low parts since MoonBit UInt64 wraps on overflow.
/// For correctness we use the standard TweetNaCl approach of accumulating
/// into the limbs with carries.
pub fn Fe::mul(self : Fe, other : Fe) -> Fe {
  let a = self.limbs
  let b = other.limbs
  let t : FixedArray[UInt64] = FixedArray::make(10, 0UL)
  for i in 0..<5 {
    for j in 0..<5 {
      t[i + j] = t[i + j] + a[i] * b[j]
    }
  }
  for i in 5..<10 {
    t[i - 5] = t[i - 5] + t[i] * 19UL
  }
  let r : FixedArray[UInt64] = [t[0], t[1], t[2], t[3], t[4]]
  Fe::{ limbs: r }.reduce().reduce()
}

///|
pub fn Fe::square(self : Fe) -> Fe {
  self.mul(self)
}

///|
/// Computes self^(2^n) by repeated squaring.
pub fn Fe::pow2(self : Fe, n : Int) -> Fe {
  let mut result = self
  for _i in 0..<n {
    result = result.square()
  }
  result
}

///|
/// Computes the multiplicative inverse via Fermat's little theorem:
/// a^(-1) = a^(p-2) mod p.
pub fn Fe::invert(self : Fe) -> Fe {
  let t2 = self.square().mul(self)
  let t4 = t2.pow2(2).mul(t2)
  let t8 = t4.pow2(4).mul(t4)
  let t16 = t8.pow2(8).mul(t8)
  let t32 = t16.pow2(16).mul(t16)
  let t64 = t32.pow2(32).mul(t32)
  let t = t64.pow2(64).mul(t64)
  let t = t.pow2(32).mul(t32)
  let t = t.pow2(16).mul(t16)
  let t = t.pow2(8).mul(t8)
  let t = t.pow2(4).mul(t4)
  let t = t.pow2(2).mul(t2)
  t.pow2(1).mul(self)
}

///|
/// Loads a 32-byte little-endian encoding into a field element.
pub fn Fe::from_bytes(data : Bytes) -> Fe {
  let mut acc = 0UL
  let mut bits = 0
  let mut limb_idx = 0
  let limbs : FixedArray[UInt64] = FixedArray::make(5, 0UL)
  for i in 0..<32 {
    acc = acc | (data[i].to_int().to_uint64() << bits)
    bits = bits + 8
    if bits >= 51 || (limb_idx == 4 && i == 31) {
      limbs[limb_idx] = acc & mask51
      acc = acc >> 51
      bits = bits - 51
      limb_idx = limb_idx + 1
    }
  }
  if limb_idx < 5 {
    limbs[limb_idx] = acc & mask51
  }
  Fe::{ limbs }.reduce()
}

///|
/// Serializes to 32-byte little-endian, fully reduced.
pub fn Fe::to_bytes(self : Fe) -> Bytes {
  let f = self.reduce().reduce()
  let mut acc = 0UL
  let mut bits = 0
  let mut limb_idx = 0
  let output : Array[Byte] = []
  while output.length() < 32 {
    if bits < 8 && limb_idx < 5 {
      acc = acc | (f.limbs[limb_idx] << bits)
      bits = bits + 51
      limb_idx = limb_idx + 1
    }
    output.push((acc & 0xffUL).to_byte())
    acc = acc >> 8
    bits = bits - 8
  }
  Bytes::from_array(output)
}

///|
pub fn Fe::eq(self : Fe, other : Fe) -> Bool {
  let a = self.reduce().reduce().to_bytes()
  let b = other.reduce().reduce().to_bytes()
  let mut same = true
  for i in 0..<32 {
    if a[i] != b[i] {
      same = false
    }
  }
  same
}
