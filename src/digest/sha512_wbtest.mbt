// NIST FIPS 180-4 test vectors for SHA-512.

///|
test "SHA-512 empty string" {
  let expected = "cf83e1357eefb8bdf1542850d66d8007d620e4050b5715dc83f4a921d36ce9ce47d0d13c5d85f2b0ff8318d2877eec2f63b931bd47417a81a538327af927da3e"
  assert_eq(sha512_hex(b""), expected)
}

///|
test "SHA-512 abc" {
  let expected = "ddaf35a193617abacc417349ae20413112e6fa4e89a97ea20a9eeee64b55d39a2192992a274fc1a836ba3c23a3feebbd454d4423643ce80e2a9ac94fa54ca49f"
  assert_eq(sha512_hex(b"abc"), expected)
}

///|
test "SHA-512 448-bit message" {
  let expected = "204a8fc6dda82f0a0ced7beb8e08a41657c16ef468b228a8279be331a703c33596fd15c13b1b07f9aa1d3bea57789ca031ad85c7a71dd70354ec631238ca3445"
  assert_eq(
    sha512_hex(b"abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq"),
    expected,
  )
}

///|
test "SHA-512 digest produces 64 bytes" {
  let ctx = Sha512Ctx::new()
  ctx.update(b"test")
  let digest = ctx.finalize()
  assert_eq(digest.length(), 64)
}

///|
test "SHA-512 incremental update matches single-shot" {
  let single = sha512_hex(b"hello world")
  let ctx = Sha512Ctx::new()
  ctx.update(b"hello ")
  ctx.update(b"world")
  let incremental = bytes_to_lower_hex(ctx.finalize())
  assert_eq(single, incremental)
}

///|
test "Digest::of_bytes with Sha512" {
  let digest = Digest::of_bytes(Sha512, b"abc")
  assert_eq(digest.algorithm, Sha512)
  assert_eq(digest.hex.length(), 128)
}
