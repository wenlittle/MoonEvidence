// Ed25519 signing and verification tests.
// Test vector from RFC 8032 Section 7.1, Test Vector 1.

///|
fn rfc8032_test1_sk() -> Bytes {
  let b : Array[Byte] = [
    b'\x9d', b'\x61', b'\xb1', b'\x9d', b'\xef', b'\xfd', b'\x5a', b'\x60',
    b'\xba', b'\x84', b'\x4a', b'\xf4', b'\x92', b'\xec', b'\x2c', b'\xc4',
    b'\x44', b'\x49', b'\xc5', b'\x69', b'\x7b', b'\x32', b'\x69', b'\x19',
    b'\x70', b'\x3b', b'\xac', b'\x03', b'\x1c', b'\xae', b'\x7f', b'\x60',
  ]
  Bytes::from_array(b)
}

///|
fn rfc8032_test1_pk() -> Bytes {
  let b : Array[Byte] = [
    b'\xd7', b'\x5a', b'\x98', b'\x01', b'\x82', b'\xb1', b'\x0a', b'\xb7',
    b'\xd5', b'\x4b', b'\xfe', b'\xd3', b'\xc9', b'\x64', b'\x07', b'\x3a',
    b'\x0e', b'\xe1', b'\x72', b'\xf3', b'\xda', b'\xa3', b'\x23', b'\x25',
    b'\x49', b'\xdc', b'\x16', b'\x89', b'\x00', b'\x00', b'\x00', b'\x00',
  ]
  Bytes::from_array(b)
}

///|
test "ed25519 public key is deterministic" {
  let pk1 = ed25519_public_key(rfc8032_test1_sk())
  let pk2 = ed25519_public_key(rfc8032_test1_sk())
  assert_eq!(pk1.length(), 32)
  assert_eq!(pk2.length(), 32)
  let mut same = true
  for i in 0..<32 {
    if pk1[i] != pk2[i] {
      same = false
    }
  }
  assert_true!(same)
}

///|
test "ed25519 sign and verify round-trip" {
  let sk = rfc8032_test1_sk()
  let msg = Bytes::make(0, b'\x00')
  let sig = ed25519_sign(sk, msg)
  assert_eq!(sig.length(), 64)
  let pk = ed25519_public_key(sk)
  assert_true!(ed25519_verify(pk, msg, sig))
}

///|
test "ed25519 verify rejects wrong message" {
  let sk = rfc8032_test1_sk()
  let msg = Bytes::make(0, b'\x00')
  let sig = ed25519_sign(sk, msg)
  let pk = ed25519_public_key(sk)
  let wrong_msg = Bytes::make(1, b'\x42')
  assert_false!(ed25519_verify(pk, wrong_msg, sig))
}

///|
test "ed25519 verify rejects tampered signature" {
  let sk = rfc8032_test1_sk()
  let msg = Bytes::make(0, b'\x00')
  let sig = ed25519_sign(sk, msg)
  let pk = ed25519_public_key(sk)
  let bad_sig_arr : Array[Byte] = []
  for i in 0..<64 {
    bad_sig_arr.push(sig[i])
  }
  let old_val = bad_sig_arr[32].to_int()
  bad_sig_arr[32] = (((old_val + 1) % 256).to_uint64() & 0xffUL).to_byte()
  let bad_sig = Bytes::from_array(bad_sig_arr)
  assert_false!(ed25519_verify(pk, msg, bad_sig))
}

///|
test "point decode round-trip with base point" {
  let b = Point::base_point()
  let enc = b.encode()
  let decoded = point_decode(enc)
  match decoded {
    Some(p) => assert_true!(p.eq(b))
    None => assert_true!(false)
  }
}
