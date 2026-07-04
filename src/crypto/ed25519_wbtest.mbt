// Ed25519 signing and verification tests.
// Test vectors from RFC 8032 Section 7.1 (Ed25519).

// ---------------------------------------------------------------------------
// RFC 8032 §7.1 TEST 1 (empty message)
// ---------------------------------------------------------------------------

///|
fn rfc8032_test1_sk() -> Bytes {
  let b : Array[Byte] = [
    b'\x9d', b'\x61', b'\xb1', b'\x9d', b'\xef', b'\xfd', b'\x5a', b'\x60', b'\xba',
    b'\x84', b'\x4a', b'\xf4', b'\x92', b'\xec', b'\x2c', b'\xc4', b'\x44', b'\x49',
    b'\xc5', b'\x69', b'\x7b', b'\x32', b'\x69', b'\x19', b'\x70', b'\x3b', b'\xac',
    b'\x03', b'\x1c', b'\xae', b'\x7f', b'\x60',
  ]
  Bytes::from_array(b)
}

///|
fn rfc8032_test1_pk() -> Bytes {
  let b : Array[Byte] = [
    b'\xd7', b'\x5a', b'\x98', b'\x01', b'\x82', b'\xb1', b'\x0a', b'\xb7', b'\xd5',
    b'\x4b', b'\xfe', b'\xd3', b'\xc9', b'\x64', b'\x07', b'\x3a', b'\x0e', b'\xe1',
    b'\x72', b'\xf3', b'\xda', b'\xa6', b'\x23', b'\x25', b'\xaf', b'\x02', b'\x1a',
    b'\x68', b'\xf7', b'\x07', b'\x51', b'\x1a',
  ]
  Bytes::from_array(b)
}

///|
fn rfc8032_test1_sig() -> Bytes {
  let b : Array[Byte] = [
    b'\xe5', b'\x56', b'\x43', b'\x00', b'\xc3', b'\x60', b'\xac', b'\x72', b'\x90',
    b'\x86', b'\xe2', b'\xcc', b'\x80', b'\x6e', b'\x82', b'\x8a', b'\x84', b'\x87',
    b'\x7f', b'\x1e', b'\xb8', b'\xe5', b'\xd9', b'\x74', b'\xd8', b'\x73', b'\xe0',
    b'\x65', b'\x22', b'\x49', b'\x01', b'\x55', b'\x5f', b'\xb8', b'\x82', b'\x15',
    b'\x90', b'\xa3', b'\x3b', b'\xac', b'\xc6', b'\x1e', b'\x39', b'\x70', b'\x1c',
    b'\xf9', b'\xb4', b'\x6b', b'\xd2', b'\x5b', b'\xf5', b'\xf0', b'\x59', b'\x5b',
    b'\xbe', b'\x24', b'\x65', b'\x51', b'\x41', b'\x43', b'\x8e', b'\x7a', b'\x10',
    b'\x0b',
  ]
  Bytes::from_array(b)
}

// ---------------------------------------------------------------------------
// RFC 8032 §7.1 TEST 2 (1-byte message 0x72)
// ---------------------------------------------------------------------------

///|
fn rfc8032_test2_sk() -> Bytes {
  let b : Array[Byte] = [
    b'\x4c', b'\xcd', b'\x08', b'\x9b', b'\x28', b'\xff', b'\x96', b'\xda', b'\x9d',
    b'\xb6', b'\xc3', b'\x46', b'\xec', b'\x11', b'\x4e', b'\x0f', b'\x5b', b'\x8a',
    b'\x31', b'\x9f', b'\x35', b'\xab', b'\xa6', b'\x24', b'\xda', b'\x8c', b'\xf6',
    b'\xed', b'\x4f', b'\xb8', b'\xa6', b'\xfb',
  ]
  Bytes::from_array(b)
}

///|
fn rfc8032_test2_pk() -> Bytes {
  let b : Array[Byte] = [
    b'\x3d', b'\x40', b'\x17', b'\xc3', b'\xe8', b'\x43', b'\x89', b'\x5a', b'\x92',
    b'\xb7', b'\x0a', b'\xa7', b'\x4d', b'\x1b', b'\x7e', b'\xbc', b'\x9c', b'\x98',
    b'\x2c', b'\xcf', b'\x2e', b'\xc4', b'\x96', b'\x8c', b'\xc0', b'\xcd', b'\x55',
    b'\xf1', b'\x2a', b'\xf4', b'\x66', b'\x0c',
  ]
  Bytes::from_array(b)
}

///|
fn rfc8032_test2_msg() -> Bytes {
  Bytes::from_array([b'\x72'])
}

///|
fn rfc8032_test2_sig() -> Bytes {
  let b : Array[Byte] = [
    b'\x92', b'\xa0', b'\x09', b'\xa9', b'\xf0', b'\xd4', b'\xca', b'\xb8', b'\x72',
    b'\x0e', b'\x82', b'\x0b', b'\x5f', b'\x64', b'\x25', b'\x40', b'\xa2', b'\xb2',
    b'\x7b', b'\x54', b'\x16', b'\x50', b'\x3f', b'\x8f', b'\xb3', b'\x76', b'\x22',
    b'\x23', b'\xeb', b'\xdb', b'\x69', b'\xda', b'\x08', b'\x5a', b'\xc1', b'\xe4',
    b'\x3e', b'\x15', b'\x99', b'\x6e', b'\x45', b'\x8f', b'\x36', b'\x13', b'\xd0',
    b'\xf1', b'\x1d', b'\x8c', b'\x38', b'\x7b', b'\x2e', b'\xae', b'\xb4', b'\x30',
    b'\x2a', b'\xee', b'\xb0', b'\x0d', b'\x29', b'\x16', b'\x12', b'\xbb', b'\x0c',
    b'\x00',
  ]
  Bytes::from_array(b)
}

// ---------------------------------------------------------------------------
// RFC 8032 §7.1 TEST 3 (2-byte message 0xaf82)
// ---------------------------------------------------------------------------

///|
fn rfc8032_test3_sk() -> Bytes {
  let b : Array[Byte] = [
    b'\xc5', b'\xaa', b'\x8d', b'\xf4', b'\x3f', b'\x9f', b'\x83', b'\x7b', b'\xed',
    b'\xb7', b'\x44', b'\x2f', b'\x31', b'\xdc', b'\xb7', b'\xb1', b'\x66', b'\xd3',
    b'\x85', b'\x35', b'\x07', b'\x6f', b'\x09', b'\x4b', b'\x85', b'\xce', b'\x3a',
    b'\x2e', b'\x0b', b'\x44', b'\x58', b'\xf7',
  ]
  Bytes::from_array(b)
}

///|
fn rfc8032_test3_pk() -> Bytes {
  let b : Array[Byte] = [
    b'\xfc', b'\x51', b'\xcd', b'\x8e', b'\x62', b'\x18', b'\xa1', b'\xa3', b'\x8d',
    b'\xa4', b'\x7e', b'\xd0', b'\x02', b'\x30', b'\xf0', b'\x58', b'\x08', b'\x16',
    b'\xed', b'\x13', b'\xba', b'\x33', b'\x03', b'\xac', b'\x5d', b'\xeb', b'\x91',
    b'\x15', b'\x48', b'\x90', b'\x80', b'\x25',
  ]
  Bytes::from_array(b)
}

///|
fn rfc8032_test3_msg() -> Bytes {
  Bytes::from_array([b'\xaf', b'\x82'])
}

///|
fn rfc8032_test3_sig() -> Bytes {
  let b : Array[Byte] = [
    b'\x62', b'\x91', b'\xd6', b'\x57', b'\xde', b'\xec', b'\x24', b'\x02', b'\x48',
    b'\x27', b'\xe6', b'\x9c', b'\x3a', b'\xbe', b'\x01', b'\xa3', b'\x0c', b'\xe5',
    b'\x48', b'\xa2', b'\x84', b'\x74', b'\x3a', b'\x44', b'\x5e', b'\x36', b'\x80',
    b'\xd7', b'\xdb', b'\x5a', b'\xc3', b'\xac', b'\x18', b'\xff', b'\x9b', b'\x53',
    b'\x8d', b'\x16', b'\xf2', b'\x90', b'\xae', b'\x67', b'\xf7', b'\x60', b'\x98',
    b'\x4d', b'\xc6', b'\x59', b'\x4a', b'\x7c', b'\x15', b'\xe9', b'\x71', b'\x6e',
    b'\xd2', b'\x8d', b'\xc0', b'\x27', b'\xbe', b'\xce', b'\xea', b'\x1e', b'\xc4',
    b'\x0a',
  ]
  Bytes::from_array(b)
}

// ---------------------------------------------------------------------------
// RFC 8032 §7.1 TEST SHA(abc) (64-byte message = SHA-512("abc"))
// ---------------------------------------------------------------------------

///|
fn rfc8032_testabc_sk() -> Bytes {
  let b : Array[Byte] = [
    b'\x83', b'\x3f', b'\xe6', b'\x24', b'\x09', b'\x23', b'\x7b', b'\x9d', b'\x62',
    b'\xec', b'\x77', b'\x58', b'\x75', b'\x20', b'\x91', b'\x1e', b'\x9a', b'\x75',
    b'\x9c', b'\xec', b'\x1d', b'\x19', b'\x75', b'\x5b', b'\x7d', b'\xa9', b'\x01',
    b'\xb9', b'\x6d', b'\xca', b'\x3d', b'\x42',
  ]
  Bytes::from_array(b)
}

///|
fn rfc8032_testabc_pk() -> Bytes {
  let b : Array[Byte] = [
    b'\xec', b'\x17', b'\x2b', b'\x93', b'\xad', b'\x5e', b'\x56', b'\x3b', b'\xf4',
    b'\x93', b'\x2c', b'\x70', b'\xe1', b'\x24', b'\x50', b'\x34', b'\xc3', b'\x54',
    b'\x67', b'\xef', b'\x2e', b'\xfd', b'\x4d', b'\x64', b'\xeb', b'\xf8', b'\x19',
    b'\x68', b'\x34', b'\x67', b'\xe2', b'\xbf',
  ]
  Bytes::from_array(b)
}

///|
fn rfc8032_testabc_msg() -> Bytes {
  let b : Array[Byte] = [
    b'\xdd', b'\xaf', b'\x35', b'\xa1', b'\x93', b'\x61', b'\x7a', b'\xba', b'\xcc',
    b'\x41', b'\x73', b'\x49', b'\xae', b'\x20', b'\x41', b'\x31', b'\x12', b'\xe6',
    b'\xfa', b'\x4e', b'\x89', b'\xa9', b'\x7e', b'\xa2', b'\x0a', b'\x9e', b'\xee',
    b'\xe6', b'\x4b', b'\x55', b'\xd3', b'\x9a', b'\x21', b'\x92', b'\x99', b'\x2a',
    b'\x27', b'\x4f', b'\xc1', b'\xa8', b'\x36', b'\xba', b'\x3c', b'\x23', b'\xa3',
    b'\xfe', b'\xeb', b'\xbd', b'\x45', b'\x4d', b'\x44', b'\x23', b'\x64', b'\x3c',
    b'\xe8', b'\x0e', b'\x2a', b'\x9a', b'\xc9', b'\x4f', b'\xa5', b'\x4c', b'\xa4',
    b'\x9f',
  ]
  Bytes::from_array(b)
}

///|
fn rfc8032_testabc_sig() -> Bytes {
  let b : Array[Byte] = [
    b'\xdc', b'\x2a', b'\x44', b'\x59', b'\xe7', b'\x36', b'\x96', b'\x33', b'\xa5',
    b'\x2b', b'\x1b', b'\xf2', b'\x77', b'\x83', b'\x9a', b'\x00', b'\x20', b'\x10',
    b'\x09', b'\xa3', b'\xef', b'\xbf', b'\x3e', b'\xcb', b'\x69', b'\xbe', b'\xa2',
    b'\x18', b'\x6c', b'\x26', b'\xb5', b'\x89', b'\x09', b'\x35', b'\x1f', b'\xc9',
    b'\xac', b'\x90', b'\xb3', b'\xec', b'\xfd', b'\xfb', b'\xc7', b'\xc6', b'\x64',
    b'\x31', b'\xe0', b'\x30', b'\x3d', b'\xca', b'\x17', b'\x9c', b'\x13', b'\x8a',
    b'\xc1', b'\x7a', b'\xd9', b'\xbe', b'\xf1', b'\x17', b'\x73', b'\x31', b'\xa7',
    b'\x04',
  ]
  Bytes::from_array(b)
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

///|
// Compare two Bytes values for exact equality.
fn bytes_eq(a : Bytes, b : Bytes) -> Bool {
  if a.length() != b.length() {
    return false
  }
  let mut diff = 0
  for i in 0..<a.length() {
    diff = diff | (a[i].to_int() ^ b[i].to_int())
  }
  diff == 0
}

///|
// Add the group order l (little-endian) to the S field (bytes 32..63) of a
// 64-byte signature, modulo 2^256. Used to build a malleable (S >= l) variant.
fn add_l_to_s(sig : Bytes) -> Bytes {
  let l = group_order()
  let arr : Array[Byte] = []
  // Keep R (bytes 0..31) unchanged.
  for i in 0..<32 {
    arr.push(sig[i])
  }
  // Add l to S (bytes 32..63) with carry propagation, little-endian.
  let mut carry = 0
  for i in 0..<32 {
    let s = sig[32 + i].to_int() & 0xff
    let lv = l[i].to_int() & 0xff
    let sum = s + lv + carry
    arr.push((sum & 0xff).to_byte())
    carry = sum >> 8
  }
  Bytes::from_array(arr)
}

// ---------------------------------------------------------------------------
// Determinism / round-trip tests
// ---------------------------------------------------------------------------

///|
test "ed25519 public key is deterministic" {
  let pk1 = ed25519_public_key(rfc8032_test1_sk())
  let pk2 = ed25519_public_key(rfc8032_test1_sk())
  assert_eq(pk1.length(), 32)
  assert_eq(pk2.length(), 32)
  assert_true(bytes_eq(pk1, pk2))
}

///|
test "ed25519 sign and verify round-trip" {
  let sk = rfc8032_test1_sk()
  let msg = Bytes::make(0, b'\x00')
  let sig = ed25519_sign(sk, msg)
  assert_eq(sig.length(), 64)
  let pk = ed25519_public_key(sk)
  assert_true(ed25519_verify(pk, msg, sig))
}

///|
test "ed25519 verify rejects wrong message" {
  let sk = rfc8032_test1_sk()
  let msg = Bytes::make(0, b'\x00')
  let sig = ed25519_sign(sk, msg)
  let pk = ed25519_public_key(sk)
  let wrong_msg = Bytes::make(1, b'\x42')
  assert_false(ed25519_verify(pk, wrong_msg, sig))
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
  assert_false(ed25519_verify(pk, msg, bad_sig))
}

///|
test "point decode round-trip with base point" {
  let b = Point::base_point()
  let enc = b.encode()
  let decoded = point_decode(enc)
  match decoded {
    Some(p) => assert_true(p.eq(b))
    None => assert_true(false)
  }
}

// ---------------------------------------------------------------------------
// RFC 8032 §7.1 KAT (known-answer tests)
// Each vector asserts: public_key(sk) == pk, sign(sk, msg) == sig,
// and verify(pk, msg, sig) == true.
// ---------------------------------------------------------------------------

///|
test "RFC 8032 §7.1 TEST 1: empty message KAT" {
  let sk = rfc8032_test1_sk()
  let pk = rfc8032_test1_pk()
  let msg = Bytes::make(0, b'\x00')
  let sig = rfc8032_test1_sig()
  // (a) public key derivation
  assert_true(bytes_eq(ed25519_public_key(sk), pk))
  // (b) signature
  assert_true(bytes_eq(ed25519_sign(sk, msg), sig))
  // (c) verification
  assert_true(ed25519_verify(pk, msg, sig))
}

///|
test "RFC 8032 §7.1 TEST 2: 1-byte message KAT" {
  let sk = rfc8032_test2_sk()
  let pk = rfc8032_test2_pk()
  let msg = rfc8032_test2_msg()
  let sig = rfc8032_test2_sig()
  assert_true(bytes_eq(ed25519_public_key(sk), pk))
  assert_true(bytes_eq(ed25519_sign(sk, msg), sig))
  assert_true(ed25519_verify(pk, msg, sig))
}

///|
test "RFC 8032 §7.1 TEST 3: 2-byte message KAT" {
  let sk = rfc8032_test3_sk()
  let pk = rfc8032_test3_pk()
  let msg = rfc8032_test3_msg()
  let sig = rfc8032_test3_sig()
  assert_true(bytes_eq(ed25519_public_key(sk), pk))
  assert_true(bytes_eq(ed25519_sign(sk, msg), sig))
  assert_true(ed25519_verify(pk, msg, sig))
}

///|
test "RFC 8032 §7.1 TEST SHA(abc): 64-byte message KAT" {
  let sk = rfc8032_testabc_sk()
  let pk = rfc8032_testabc_pk()
  let msg = rfc8032_testabc_msg()
  let sig = rfc8032_testabc_sig()
  assert_true(bytes_eq(ed25519_public_key(sk), pk))
  assert_true(bytes_eq(ed25519_sign(sk, msg), sig))
  assert_true(ed25519_verify(pk, msg, sig))
}

// ---------------------------------------------------------------------------
// Malleability tests (RFC 8032 §8.4: S < l check)
// ---------------------------------------------------------------------------

///|
test "ed25519 rejects malleable signature (S + l) on RFC test 1" {
  let pk = rfc8032_test1_pk()
  let msg = Bytes::make(0, b'\x00')
  let sig = rfc8032_test1_sig()
  // Sanity: original verifies.
  assert_true(ed25519_verify(pk, msg, sig))
  // S + l is a distinct scalar that represents the same curve point, so
  // without the S < l check it would still verify. With the check it must
  // be rejected.
  let malleable = add_l_to_s(sig)
  assert_false(bytes_eq(sig, malleable))
  assert_false(ed25519_verify(pk, msg, malleable))
}

///|
test "ed25519 rejects malleable signature (S + l) on a self-signed message" {
  let sk = rfc8032_test2_sk()
  let pk = ed25519_public_key(sk)
  let msg = rfc8032_test2_msg()
  let sig = ed25519_sign(sk, msg)
  assert_true(ed25519_verify(pk, msg, sig))
  let malleable = add_l_to_s(sig)
  assert_false(ed25519_verify(pk, msg, malleable))
}

///|
test "ed25519 rejects signature whose S equals the group order l" {
  // Build a 64-byte signature whose S field (bytes 32..63) is exactly l.
  // R is taken from RFC test 1. Since S = l is not < l, verify must reject.
  let l = group_order()
  let rfc1 = rfc8032_test1_sig()
  let arr : Array[Byte] = []
  for i in 0..<32 {
    arr.push(rfc1[i])
  }
  for i in 0..<32 {
    arr.push(l[i])
  }
  let sig = Bytes::from_array(arr)
  let pk = rfc8032_test1_pk()
  let msg = Bytes::make(0, b'\x00')
  assert_false(ed25519_verify(pk, msg, sig))
}

// ---------------------------------------------------------------------------
// Low-order / non-canonical encoding tests
// ---------------------------------------------------------------------------

///|
test "ed25519 verify rejects identity-point public key with foreign signature" {
  // The identity point (0, 1) is a low-order point (order 1). Its encoding is
  // y = 1 (little-endian) with the sign bit clear: 0x01 followed by 31 zero
  // bytes. Using it as a public key with a signature produced under a
  // different key must not verify.
  let identity_pk : Array[Byte] = [
    b'\x01', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00',
    b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00',
    b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00',
    b'\x00', b'\x00', b'\x00', b'\x00', b'\x00',
  ]
  let pk = Bytes::from_array(identity_pk)
  // The identity encoding must at least decode to a point.
  assert_true(point_decode(pk) is Some(_))
  // A valid signature under test1's key must not verify under the identity pk.
  let msg = Bytes::make(0, b'\x00')
  let sig = rfc8032_test1_sig()
  assert_false(ed25519_verify(pk, msg, sig))
}

///|
test "ed25519 verify rejects non-canonical S (high-order carry into 2^256)" {
  // A 32-byte S field of all 0xff bytes represents 2^256 - 1, which is far
  // above l; it must be rejected by the S < l check.
  let rfc1 = rfc8032_test1_sig()
  let arr : Array[Byte] = []
  for i in 0..<32 {
    arr.push(rfc1[i])
  }
  for _ in 0..<32 {
    arr.push(b'\xff')
  }
  let sig = Bytes::from_array(arr)
  let pk = rfc8032_test1_pk()
  let msg = Bytes::make(0, b'\x00')
  assert_false(ed25519_verify(pk, msg, sig))
}
