// RFC 4231 test vectors for HMAC-SHA256.

///|
test "HMAC-SHA256 RFC 4231 test case 1" {
  // Key = 0x0b repeated 20 times, Data = "Hi There"
  let key = Bytes::make(20, b'\x0b')
  let data = b"Hi There"
  let expected = "b0344c61d8db38535ca8afceaf0bf12b881dc200c9833da726e9376c2e32cff7"
  assert_eq(hmac_sha256_hex(key, data), expected)
}

///|
test "HMAC-SHA256 RFC 4231 test case 2" {
  // Key = "Jefe", Data = "what do ya want for nothing?"
  let key = b"Jefe"
  let data = b"what do ya want for nothing?"
  let expected = "5bdcc146bf60754e6a042426089575c75a003f089d2739839dec58b964ec3843"
  assert_eq(hmac_sha256_hex(key, data), expected)
}

///|
test "HMAC-SHA256 RFC 4231 test case 3" {
  // Key = 0xaa repeated 20 times, Data = 0xdd repeated 50 times
  let key = Bytes::make(20, b'\xaa')
  let data = Bytes::make(50, b'\xdd')
  let expected = "773ea91e36800e46854db8ebd09181a72959098b3ef8c122d9635514ced565fe"
  assert_eq(hmac_sha256_hex(key, data), expected)
}

///|
test "HMAC-SHA256 RFC 4231 test case 4" {
  // Key = 0x01..0x19 (25 bytes), Data = 0xcd repeated 50 times
  let key_arr : Array[Byte] = []
  for i in 1..<=25 {
    key_arr.push(i.to_byte())
  }
  let key = Bytes::from_array(key_arr)
  let data = Bytes::make(50, b'\xcd')
  let expected = "82558a389a443c0ea4cc819899f2083a85f0faa3e578f8077a2e3ff46729665b"
  assert_eq(hmac_sha256_hex(key, data), expected)
}

///|
test "HMAC-SHA256 with key longer than block size" {
  // RFC 4231 test case 6: key = 0xaa repeated 131 times (> 64-byte block)
  let key = Bytes::make(131, b'\xaa')
  let data = b"Test Using Larger Than Block-Size Key - Hash Key First"
  let expected = "60e431591ee0b67f0d8a26aacbf5b77f8e0bc6213728c5140546040f0ee37f54"
  assert_eq(hmac_sha256_hex(key, data), expected)
}

///|
test "HMAC-SHA256 empty message" {
  let key = b"secret"
  let data = b""
  let result = hmac_sha256_hex(key, data)
  // Just verify it produces a 64-char hex string (32 bytes).
  assert_eq(result.length(), 64)
}
