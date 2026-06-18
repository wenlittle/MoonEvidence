// Tests for Curve25519 point operations.

///|
test "curve d constant is correct: d * 121666 = -121665" {
  let d = curve_d()
  let product = d.mul(Fe::from_small(121666UL))
  let expected = Fe::zero().sub(Fe::from_small(121665UL))
  assert_true!(product.eq(expected))
}

///|
test "base point is on curve: -x^2 + y^2 = 1 + d*x^2*y^2" {
  let bx = base_x()
  let by = base_y()
  let d = curve_d()
  let x2 = bx.square()
  let y2 = by.square()
  let lhs = y2.sub(x2)
  let rhs = Fe::one().add(d.mul(x2).mul(y2))
  assert_true!(lhs.eq(rhs))
}

///|
test "identity + base = base" {
  let b = Point::base_point()
  let result = Point::identity().add(b)
  assert_true!(result.eq(b))
}

///|
test "base + identity = base" {
  let b = Point::base_point()
  let result = b.add(Point::identity())
  assert_true!(result.eq(b))
}

///|
test "base + base = base.double" {
  let b = Point::base_point()
  let sum = b.add(b)
  let dbl = b.double()
  assert_true!(sum.eq(dbl))
}

///|
test "2*B via scalar_mul equals double" {
  let b = Point::base_point()
  let arr : Array[Byte] = Array::make(32, b'\x00')
  arr[0] = b'\x02'
  let result = b.scalar_mul(Bytes::from_array(arr))
  let expected = b.double()
  assert_true!(result.eq(expected))
}

///|
test "3*B = 2*B + B" {
  let b = Point::base_point()
  let b3_add = b.double().add(b)
  let arr : Array[Byte] = Array::make(32, b'\x00')
  arr[0] = b'\x03'
  let b3_mul = b.scalar_mul(Bytes::from_array(arr))
  assert_true!(b3_add.eq(b3_mul))
}
