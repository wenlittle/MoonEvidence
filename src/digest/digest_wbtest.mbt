test "normalize algorithm accepts sha256 forms" {
  assert_true(is_supported_algorithm("sha256"))
  assert_true(is_supported_algorithm("SHA-256"))
  assert_false(is_supported_algorithm("md5"))
}

test "normalize hex lowercases valid uppercase input" {
  let normalized = normalize_hex("A0B1C2") |> Option::unwrap()
  inspect(normalized, content="a0b1c2")
}

test "normalize hex rejects empty and non hex input" {
  debug_inspect(normalize_hex(""), content="None")
  debug_inspect(normalize_hex("xyz"), content="None")
}

test "parse digest normalizes algorithm and hex" {
  let digest = parse_digest("SHA-256:ABCD") |> Option::unwrap()
  inspect(digest.to_string(), content="sha256:abcd")
}

test "same digest compares normalized values" {
  assert_true(same_digest("sha256:ABCD", "SHA-256:abcd"))
  assert_false(same_digest("sha256:abcd", "sha256:abce"))
}
