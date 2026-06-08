test "canonicalize removes insignificant whitespace" {
  let canonical = canonicalize("{ \"a\" : 1, \"b\" : true }") catch {
    (_ : @json.ParseError) => panic()
  }
  inspect(canonical, content="{\"a\":1,\"b\":true}")
}

test "canonicalize reordered object fields keeps same payload" {
  assert_true(same_canonical_payload("{\"b\":2,\"a\":1}", "{\"a\":1,\"b\":2}"))
}

test "canonicalize invalid json returns none" {
  debug_inspect(canonicalize_or_none("{"), content="None")
}

test "canonicalize nested objects sorts keys recursively" {
  let canonical = canonicalize("{\"z\":{\"b\":2,\"a\":1},\"a\":[{\"d\":4,\"c\":3}]}") catch {
    (_ : @json.ParseError) => panic()
  }
  inspect(canonical, content="{\"a\":[{\"c\":3,\"d\":4}],\"z\":{\"a\":1,\"b\":2}}")
}
