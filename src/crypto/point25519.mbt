// Curve25519 extended-coordinate point operations for Ed25519.
// Twisted Edwards curve: -x^2 + y^2 = 1 + d*x^2*y^2
// Uses (X:Y:Z:T) extended coordinates where x=X/Z, y=Y/Z, xy=T/Z.

///|
/// A point on the Ed25519 twisted Edwards curve in extended coordinates.
pub struct Point {
  x : Fe
  y : Fe
  z : Fe
  t : Fe
}

///|
// d = -121665/121666 mod p (little-endian 32 bytes)
fn curve_d() -> Fe {
  let b : Array[Byte] = [
    b'\xa3', b'\x78', b'\x59', b'\x13', b'\xca', b'\x4d', b'\xeb', b'\x75',
    b'\xab', b'\xd8', b'\x41', b'\x41', b'\x4d', b'\x0a', b'\x70', b'\x00',
    b'\x98', b'\xe8', b'\x79', b'\x77', b'\x79', b'\x40', b'\xc7', b'\x8c',
    b'\x73', b'\xfe', b'\x6f', b'\x2b', b'\xee', b'\x6c', b'\x03', b'\x52',
  ]
  Fe::from_bytes(Bytes::from_array(b))
}

///|
fn curve_d2() -> Fe {
  curve_d().add(curve_d())
}

///|
fn base_x() -> Fe {
  let b : Array[Byte] = [
    b'\x1a', b'\xd5', b'\x25', b'\x8f', b'\x60', b'\x2d', b'\x56', b'\xc9',
    b'\xb2', b'\xa7', b'\x25', b'\x95', b'\x60', b'\xc7', b'\x2c', b'\x69',
    b'\x5c', b'\xdc', b'\xd6', b'\xfd', b'\x31', b'\xe2', b'\xa4', b'\xc0',
    b'\xfe', b'\x53', b'\x6e', b'\xcd', b'\xd3', b'\x36', b'\x69', b'\x21',
  ]
  Fe::from_bytes(Bytes::from_array(b))
}

///|
fn base_y() -> Fe {
  let b : Array[Byte] = [
    b'\x58', b'\x66', b'\x66', b'\x66', b'\x66', b'\x66', b'\x66', b'\x66',
    b'\x66', b'\x66', b'\x66', b'\x66', b'\x66', b'\x66', b'\x66', b'\x66',
    b'\x66', b'\x66', b'\x66', b'\x66', b'\x66', b'\x66', b'\x66', b'\x66',
    b'\x66', b'\x66', b'\x66', b'\x66', b'\x66', b'\x66', b'\x66', b'\x66',
  ]
  Fe::from_bytes(Bytes::from_array(b))
}

///|
/// The neutral element (identity point) of the curve group.
pub fn Point::identity() -> Point {
  { x: Fe::zero(), y: Fe::one(), z: Fe::one(), t: Fe::zero() }
}

///|
/// Lifts affine coordinates (x, y) into extended (X:Y:Z:T) with Z=1.
pub fn Point::from_affine(x : Fe, y : Fe) -> Point {
  { x, y, z: Fe::one(), t: x.mul(y) }
}

///|
/// The Ed25519 base point B with y = 4/5 mod p.
pub fn Point::base_point() -> Point {
  Point::from_affine(base_x(), base_y())
}

///|
/// Unified addition (HWCD08 add-2008-hwcd-4).
pub fn Point::add(self : Point, other : Point) -> Point {
  let k = curve_d2()
  let a = self.y.sub(self.x).mul(other.y.sub(other.x))
  let b = self.y.add(self.x).mul(other.y.add(other.x))
  let c = self.t.mul(k).mul(other.t)
  let z1z2 = self.z.mul(other.z)
  let d = z1z2.add(z1z2)
  let e = b.sub(a)
  let f = d.sub(c)
  let g = d.add(c)
  let h = b.add(a)
  { x: e.mul(f), y: g.mul(h), z: f.mul(g), t: e.mul(h) }
}

///|
/// Dedicated doubling (dbl-2008-hwcd).
pub fn Point::double(self : Point) -> Point {
  let a = self.x.square()
  let b = self.y.square()
  let z2 = self.z.square()
  let c = z2.add(z2)
  let neg_a = Fe::zero().sub(a)
  let e = self.x.add(self.y).square().sub(a).sub(b)
  let f = neg_a.add(b)
  let g = f.sub(c)
  let h = neg_a.sub(b)
  { x: e.mul(g), y: f.mul(h), z: f.mul(g), t: e.mul(h) }
}

///|
/// Double-and-add scalar multiplication (MSB first).
/// Scalar is 32-byte little-endian.
pub fn Point::scalar_mul(self : Point, scalar : Bytes) -> Point {
  let mut q = Point::identity()
  let mut i = 31
  while i >= 0 {
    let byte_val = scalar[i].to_int() & 0xff
    let mut bit = 7
    while bit >= 0 {
      q = q.double()
      if ((byte_val >> bit) & 1) == 1 {
        q = q.add(self)
      }
      bit = bit - 1
    }
    i = i - 1
  }
  q
}

///|
/// Cross-ratio equality: P1 == P2 iff X1*Z2 == X2*Z1 and Y1*Z2 == Y2*Z1.
pub fn Point::eq(self : Point, other : Point) -> Bool {
  let lx = self.x.mul(other.z)
  let rx = other.x.mul(self.z)
  let ly = self.y.mul(other.z)
  let ry = other.y.mul(self.z)
  lx.eq(rx) && ly.eq(ry)
}

///|
pub fn Point::is_identity(self : Point) -> Bool {
  self.eq(Point::identity())
}

///|
/// Ed25519 point compression: 32 bytes = y with sign bit of x in top bit.
pub fn Point::encode(self : Point) -> Bytes {
  let zinv = self.z.invert()
  let x = self.x.mul(zinv)
  let y = self.y.mul(zinv)
  let y_bytes = y.to_bytes()
  let x_bytes = x.to_bytes()
  let sign_bit = x_bytes[0].to_int() & 1
  let arr : Array[Byte] = []
  for i in 0..<31 {
    arr.push(y_bytes[i])
  }
  let last = (y_bytes[31].to_int() & 0xff) | (sign_bit << 7)
  arr.push((last.to_uint64() & 0xffUL).to_byte())
  Bytes::from_array(arr)
}
