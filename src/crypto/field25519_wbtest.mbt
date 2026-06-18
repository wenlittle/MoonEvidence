// Tests for GF(2^255-19) field arithmetic.

///|
test "fe zero + one = one" {
  let result = Fe::zero().add(Fe::one())
  assert_true!(result.eq(Fe::one()))
}

///|
test "fe one * one = one" {
  let result = Fe::one().mul(Fe::one())
  assert_true!(result.eq(Fe::one()))
}

///|
test "fe a + (-a) = 0" {
  let a = Fe::{ limbs: [42UL, 0UL, 0UL, 0UL, 0UL] }.reduce()
  let result = a.sub(a)
  assert_true!(result.eq(Fe::zero()))
}

///|
test "fe a * a^(-1) = 1 for nonzero a" {
  let a = Fe::{ limbs: [7UL, 0UL, 0UL, 0UL, 0UL] }.reduce()
  let inv = a.invert()
  let result = a.mul(inv)
  assert_true!(result.eq(Fe::one()))
}

///|
test "fe from_bytes round-trip" {
  let arr : Array[Byte] = Array::make(32, b'\x00')
  arr[0] = b'\x07'
  let bytes = Bytes::from_array(arr)
  let fe = Fe::from_bytes(bytes)
  let out = fe.to_bytes()
  assert_eq!(out[0], b'\x07')
  for i in 1..<32 {
    assert_eq!(out[i], b'\x00')
  }
}

///|
test "fe distributive law: a*(b+c) = a*b + a*c" {
  let a = Fe::{ limbs: [3UL, 0UL, 0UL, 0UL, 0UL] }
  let b = Fe::{ limbs: [5UL, 0UL, 0UL, 0UL, 0UL] }
  let c = Fe::{ limbs: [11UL, 0UL, 0UL, 0UL, 0UL] }
  let lhs = a.mul(b.add(c))
  let rhs = a.mul(b).add(a.mul(c))
  assert_true!(lhs.eq(rhs))
}
