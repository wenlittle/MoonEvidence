// NIST FIPS 180-4 short-message vectors (also part of the CAVP byte-oriented
// suite). Sources: FIPS 180-4 appendix examples and NIST CAVP SHA256ShortMsg.
// Each expected digest is the official lowercase hex value.

///|
test "sha256 of empty input matches NIST vector" {
  inspect(
    sha256_hex(b""),
    content="e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
  )
}

///|
test "sha256 of abc matches FIPS 180-4 example" {
  inspect(
    sha256_hex(b"abc"),
    content="ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad",
  )
}

///|
test "sha256 of 448 bit two block message matches FIPS 180-4 example" {
  // 56 bytes: forces the padding to spill into a second block.
  inspect(
    sha256_hex(b"abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq"),
    content="248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1",
  )
}

///|
test "sha256 of 896 bit message matches FIPS 180-4 example" {
  // 112 bytes: exercises multi-block scheduling across three blocks total.
  inspect(
    sha256_hex(
      b"abcdefghbcdefghicdefghijdefghijkefghijklfghijklmghijklmnhijklmnoijklmnopjklmnopqklmnopqrlmnopqrsmnopqrstnopqrstu",
    ),
    content="cf5b16a778af8380036ce59e7b0492370b249b11e8f07a51afac45037afee9d1",
  )
}

///|
test "sha256 raw output is 32 bytes" {
  assert_eq(sha256(b"abc").length(), 32)
}

// ---------------------------------------------------------------------------
// Incremental (streaming) API
// ---------------------------------------------------------------------------

///|
test "sha256 ctx with no input matches empty vector" {
  let ctx = Sha256Ctx::new()
  inspect(
    bytes_to_lower_hex(ctx.finalize()),
    content="e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
  )
}

///|
test "sha256 ctx split updates match one shot digest" {
  let ctx = Sha256Ctx::new()
  ctx.update(b"a")
  ctx.update(b"bc")
  inspect(
    bytes_to_lower_hex(ctx.finalize()),
    content="ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad",
  )
}

///|
test "sha256 ctx finalize is idempotent" {
  let ctx = Sha256Ctx::new()
  ctx.update(b"abc")
  let first = ctx.finalize()
  let second = ctx.finalize()
  assert_eq(first, second)
}

///|
test "sha256 ctx of one million a matches NIST long message vector" {
  // FIPS 180-4 long-message example: 1,000,000 repetitions of 'a'. Fed in
  // 1000-byte chunks so memory stays flat and update paths are exercised.
  let chunk = Bytes::makei(1000, _ => b'a')
  let ctx = Sha256Ctx::new()
  for _ in 0..<1000 {
    ctx.update(chunk)
  }
  inspect(
    bytes_to_lower_hex(ctx.finalize()),
    content="cdc76e5c9914fb9281a1c7e284d73e67f1809a48a497200e046d39ccc7112cd0",
  )
}

///|
test "sha256 ctx is chunk size invariant across block boundaries" {
  // 200 bytes of deterministic non-repeating data crosses three 64-byte
  // blocks; every chunking must agree with the one-shot digest.
  let data = Bytes::makei(200, index => (index % 251).to_byte())
  let expected = sha256_hex(data)
  let chunk_sizes = [1, 7, 63, 64, 65, 129]
  for size in chunk_sizes {
    let ctx = Sha256Ctx::new()
    let mut offset = 0
    while offset < data.length() {
      let take = if offset + size > data.length() {
        data.length() - offset
      } else {
        size
      }
      let base = offset
      ctx.update(Bytes::makei(take, j => data[base + j]))
      offset = offset + take
    }
    assert_eq(bytes_to_lower_hex(ctx.finalize()), expected)
  }
}
