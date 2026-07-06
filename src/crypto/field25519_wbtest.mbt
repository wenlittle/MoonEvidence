// Tests for GF(2^255-19) field arithmetic.

///|
test "fe zero + one = one" {
  let result = Fe::zero().add(Fe::one())
  assert_true(result.eq(Fe::one()))
}

///|
test "fe one * one = one" {
  let result = Fe::one().mul(Fe::one())
  assert_true(result.eq(Fe::one()))
}

///|
test "fe a + (-a) = 0" {
  let a = Fe::from_small(42UL)
  let result = a.sub(a)
  assert_true(result.eq(Fe::zero()))
}

///|
test "fe a * a^(-1) = 1 for nonzero a" {
  let a = Fe::from_small(7UL)
  let inv = a.invert()
  let result = a.mul(inv)
  assert_true(result.eq(Fe::one()))
}

///|
test "fe from_bytes round-trip" {
  let arr : Array[Byte] = Array::make(32, b'\x00')
  arr[0] = b'\x07'
  let bytes = Bytes::from_array(arr)
  let fe = Fe::from_bytes(bytes)
  let out = fe.to_bytes()
  assert_eq(out[0], b'\x07')
  for i in 1..<32 {
    assert_eq(out[i], b'\x00')
  }
}

///|
test "fe from_small serializes all uint64 limbs little endian" {
  let fe = Fe::from_small(0x0123456789abcdefUL)
  let out = fe.to_bytes()
  assert_eq(out[0], b'\xef')
  assert_eq(out[1], b'\xcd')
  assert_eq(out[2], b'\xab')
  assert_eq(out[3], b'\x89')
  assert_eq(out[4], b'\x67')
  assert_eq(out[5], b'\x45')
  assert_eq(out[6], b'\x23')
  assert_eq(out[7], b'\x01')
  for i in 8..<32 {
    assert_eq(out[i], b'\x00')
  }
}

///|
test "fe to_bytes canonically reduces p to zero" {
  let p_bytes : Array[Byte] = [
    b'\xed', b'\xff', b'\xff', b'\xff', b'\xff', b'\xff', b'\xff', b'\xff', b'\xff',
    b'\xff', b'\xff', b'\xff', b'\xff', b'\xff', b'\xff', b'\xff', b'\xff', b'\xff',
    b'\xff', b'\xff', b'\xff', b'\xff', b'\xff', b'\xff', b'\xff', b'\xff', b'\xff',
    b'\xff', b'\xff', b'\xff', b'\xff', b'\x7f',
  ]
  let reduced = Fe::from_bytes(Bytes::from_array(p_bytes)).to_bytes()
  for i in 0..<32 {
    assert_eq(reduced[i], b'\x00')
  }
}

///|
test "fe to_bytes canonically reduces p plus one to one" {
  let p_plus_one_bytes : Array[Byte] = [
    b'\xee', b'\xff', b'\xff', b'\xff', b'\xff', b'\xff', b'\xff', b'\xff', b'\xff',
    b'\xff', b'\xff', b'\xff', b'\xff', b'\xff', b'\xff', b'\xff', b'\xff', b'\xff',
    b'\xff', b'\xff', b'\xff', b'\xff', b'\xff', b'\xff', b'\xff', b'\xff', b'\xff',
    b'\xff', b'\xff', b'\xff', b'\xff', b'\x7f',
  ]
  let reduced = Fe::from_bytes(Bytes::from_array(p_plus_one_bytes)).to_bytes()
  assert_eq(reduced[0], b'\x01')
  for i in 1..<32 {
    assert_eq(reduced[i], b'\x00')
  }
}

///|
test "fe to_bytes leaves p minus one unchanged" {
  let p_minus_one_bytes : Array[Byte] = [
    b'\xec', b'\xff', b'\xff', b'\xff', b'\xff', b'\xff', b'\xff', b'\xff', b'\xff',
    b'\xff', b'\xff', b'\xff', b'\xff', b'\xff', b'\xff', b'\xff', b'\xff', b'\xff',
    b'\xff', b'\xff', b'\xff', b'\xff', b'\xff', b'\xff', b'\xff', b'\xff', b'\xff',
    b'\xff', b'\xff', b'\xff', b'\xff', b'\x7f',
  ]
  let reduced = Fe::from_bytes(Bytes::from_array(p_minus_one_bytes)).to_bytes()
  for i in 0..<32 {
    assert_eq(reduced[i], p_minus_one_bytes[i])
  }
}

///|
test "fe distributive law: a*(b+c) = a*b + a*c" {
  let a = Fe::from_small(3UL)
  let b = Fe::from_small(5UL)
  let c = Fe::from_small(11UL)
  let lhs = a.mul(b.add(c))
  let rhs = a.mul(b).add(a.mul(c))
  assert_true(lhs.eq(rhs))
}
