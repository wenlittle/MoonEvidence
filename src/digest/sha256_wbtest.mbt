// NIST FIPS 180-4 short-message vectors (also part of the CAVP byte-oriented
// suite). Sources: FIPS 180-4 appendix examples and NIST CAVP SHA256ShortMsg.
// Each expected digest is the official lowercase hex value.

test "sha256 of empty input matches NIST vector" {
  inspect(
    sha256_hex(b""),
    content="e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
  )
}

test "sha256 of abc matches FIPS 180-4 example" {
  inspect(
    sha256_hex(b"abc"),
    content="ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad",
  )
}

test "sha256 of 448 bit two block message matches FIPS 180-4 example" {
  // 56 bytes: forces the padding to spill into a second block.
  inspect(
    sha256_hex(b"abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq"),
    content="248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1",
  )
}

test "sha256 of 896 bit message matches FIPS 180-4 example" {
  // 112 bytes: exercises multi-block scheduling across three blocks total.
  inspect(
    sha256_hex(
      b"abcdefghbcdefghicdefghijdefghijkefghijklfghijklmghijklmnhijklmnoijklmnopjklmnopqklmnopqrlmnopqrsmnopqrstnopqrstu",
    ),
    content="cf5b16a778af8380036ce59e7b0492370b249b11e8f07a51afac45037afee9d1",
  )
}

test "sha256 raw output is 32 bytes" {
  assert_eq(sha256(b"abc").length(), 32)
}
