///|
test "normalize algorithm accepts sha256 forms" {
  assert_true(is_supported_algorithm("sha256"))
  assert_true(is_supported_algorithm("SHA-256"))
  assert_false(is_supported_algorithm("md5"))
}

///|
test "normalize hex lowercases valid uppercase input" {
  let normalized = normalize_hex("A0B1C2") |> Option::unwrap()
  inspect(normalized, content="a0b1c2")
}

///|
test "normalize hex rejects empty and non hex input" {
  debug_inspect(normalize_hex(""), content="None")
  debug_inspect(normalize_hex("xyz"), content="None")
}

///|
test "parse digest normalizes algorithm and hex" {
  let digest = parse_digest("SHA-256:ABCD") |> Option::unwrap()
  inspect(digest.to_string(), content="sha256:abcd")
}

///|
test "same digest compares normalized values" {
  assert_true(same_digest("sha256:ABCD", "SHA-256:abcd"))
  assert_false(same_digest("sha256:abcd", "sha256:abce"))
}

///|
test "digest of bytes wraps the sha256 nist vector" {
  let digest = Digest::of_bytes(Sha256, b"abc")
  assert_eq(digest.algorithm, Sha256)
  inspect(
    digest.hex,
    content="ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad",
  )
}

///|
test "digest of bytes round trips through text form" {
  let digest = Digest::of_bytes(Sha256, b"abc")
  let reparsed = parse_digest(digest.to_string()) |> Option::unwrap()
  assert_eq(digest, reparsed)
  assert_true(same_digest(digest.to_string(), reparsed.to_string()))
}

///|
test "digest of bytes wraps the sha512 fips 180-4 one block vector" {
  // FIPS 180-4 one-block message example: the 3-byte ASCII string "abc".
  let digest = Digest::of_bytes(Sha512, b"abc")
  assert_eq(digest.algorithm, Sha512)
  inspect(
    digest.hex,
    content=
      "ddaf35a193617abacc417349ae20413112e6fa4e89a97ea20a9eeee64b55d39a2192992a274fc1a836ba3c23a3feebbd454d4423643ce80e2a9ac94fa54ca49f",
  )
}

///|
test "digest of bytes wraps the sha512 fips 180-4 one million a vector" {
  // FIPS 180-4 long-message example: 1,000,000 repetitions of 'a'.
  let data = Bytes::makei(1000000, _ => b'a')
  let digest = Digest::of_bytes(Sha512, data)
  assert_eq(digest.algorithm, Sha512)
  inspect(
    digest.hex,
    content=
      "e718483d0ce769644e2e42c7bc15b4638e1f98b13b2044285632a803afa973ebde0ff244877ea60a4cb0432ce577c31beb009c5c2c49aa2e4eadb217ad8cc09b",
  )
}
