// Table-driven manifest validation tests. Each invalid sample violates
// exactly one rule and asserts the exact frozen error code plus field-path
// context. Samples mirror tests/fixtures/manifest/ (single source of truth
// for the step-7 CLI black-box suite).

///|
fn parse_error(input : String) -> ModelError raise {
  try Manifest::parse(input) catch {
    error => error
  } noraise {
    _ => fail("expected ModelError, manifest parsed successfully")
  }
}

// ---------------------------------------------------------------------------
// Valid sample
// ---------------------------------------------------------------------------

///|
let valid_manifest : String =
  #|{
  #|  "schema": "moon-evidence/v0",
  #|  "subject": { "id": "example-pack", "type": "dataset" },
  #|  "hash_algorithm": "sha256",
  #|  "files": [
  #|    {
  #|      "path": "files/a.txt",
  #|      "size": 12,
  #|      "digest": "sha256:2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824"
  #|    },
  #|    {
  #|      "path": "files/b.bin",
  #|      "size": 0,
  #|      "digest": "sha256:e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
  #|    }
  #|  ],
  #|  "merkle_root": "sha256:60a53eed0de87a90c8e59427c59c46253c33a76a09502a51801300927b7e6bdc",
  #|  "version": { "id": "v1", "parent": null }
  #|}

///|
test "valid manifest parses with every field populated" {
  let manifest = Manifest::parse(valid_manifest) catch {
    error => fail("unexpected: \{error}")
  }
  assert_eq(manifest.schema, "moon-evidence/v0")
  assert_eq(manifest.subject.id, "example-pack")
  assert_eq(manifest.subject.kind, "dataset")
  assert_true(manifest.algorithm == @digest.HashAlgorithm::Sha256)
  assert_eq(manifest.files.length(), 2)
  assert_eq(manifest.files[0].path, "files/a.txt")
  assert_eq(manifest.files[0].size, 12L)
  assert_eq(
    manifest.files[0].digest.hex,
    "2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824",
  )
  assert_true(manifest.merkle_root is Some(_))
  assert_eq(manifest.version.id, "v1")
  assert_true(manifest.version.parent is None)
}

///|
test "valid manifest without merkle root parses to none" {
  // merkle_root presence rules against files[] are verify semantics (E3001),
  // so the model accepts its absence.
  let input =
    #|{
    #|  "schema": "moon-evidence/v0",
    #|  "subject": { "id": "p", "type": "dataset" },
    #|  "hash_algorithm": "sha256",
    #|  "files": [],
    #|  "version": { "id": "v1" }
    #|}
  let manifest = Manifest::parse(input) catch {
    error => fail("unexpected: \{error}")
  }
  assert_true(manifest.merkle_root is None)
  assert_eq(manifest.files.length(), 0)
  assert_true(manifest.version.parent is None)
}

// ---------------------------------------------------------------------------
// Invalid samples: one rule violated each (codes are the frozen contract)
// ---------------------------------------------------------------------------

///|
test "invalid json reports e1001" {
  let error = parse_error("{ \"schema\": \"moon-evidence/v0\", ")
  assert_eq(error.error_code(), "E1001")
}

///|
test "missing schema reports e1002 with path" {
  let input =
    #|{
    #|  "subject": { "id": "p", "type": "dataset" },
    #|  "hash_algorithm": "sha256",
    #|  "files": [],
    #|  "version": { "id": "v1" }
    #|}
  let error = parse_error(input)
  assert_eq(error.error_code(), "E1002")
  inspect(error, content="[E1002] schema: required field missing or empty")
}

///|
test "unsupported schema reports e1003" {
  let error = parse_error(
    valid_manifest.replace(old="moon-evidence/v0", new="moon-evidence/v9"),
  )
  assert_eq(error.error_code(), "E1003")
  inspect(
    error,
    content="[E1003] schema: unsupported schema \"moon-evidence/v9\" (expected moon-evidence/v0)",
  )
}

///|
test "missing subject id reports e1002 with nested path" {
  let error = parse_error(
    valid_manifest.replace(old="\"id\": \"example-pack\", ", new=""),
  )
  assert_eq(error.error_code(), "E1002")
  inspect(error, content="[E1002] subject.id: required field missing or empty")
}

///|
test "empty subject type reports e1002" {
  let error = parse_error(
    valid_manifest.replace(old="\"type\": \"dataset\"", new="\"type\": \"\""),
  )
  assert_eq(error.error_code(), "E1002")
  inspect(
    error,
    content="[E1002] subject.type: required field missing or empty",
  )
}

///|
test "unsupported algorithm reports e2001" {
  let error = parse_error(
    valid_manifest.replace(old="\"sha256\"", new="\"md5\""),
  )
  assert_eq(error.error_code(), "E2001")
  inspect(
    error,
    content="[E2001] hash_algorithm: unsupported hash algorithm \"md5\"",
  )
}

///|
test "files not an array reports e1002 invalid field" {
  let input =
    #|{
    #|  "schema": "moon-evidence/v0",
    #|  "subject": { "id": "p", "type": "dataset" },
    #|  "hash_algorithm": "sha256",
    #|  "files": {},
    #|  "version": { "id": "v1" }
    #|}
  let error = parse_error(input)
  assert_eq(error.error_code(), "E1002")
  inspect(error, content="[E1002] files: expected an array")
}

///|
test "duplicate file path reports e1002 with index context" {
  let error = parse_error(
    valid_manifest.replace(old="files/b.bin", new="files/a.txt"),
  )
  assert_eq(error.error_code(), "E1002")
  inspect(
    error,
    content="[E1002] files[1].path: duplicate path \"files/a.txt\"",
  )
}

///|
test "negative size reports e1002" {
  let error = parse_error(
    valid_manifest.replace(old="\"size\": 12", new="\"size\": -1"),
  )
  assert_eq(error.error_code(), "E1002")
  inspect(error, content="[E1002] files[0].size: size must be >= 0")
}

///|
test "fractional size reports e1002" {
  let error = parse_error(
    valid_manifest.replace(old="\"size\": 12", new="\"size\": 3.5"),
  )
  assert_eq(error.error_code(), "E1002")
  inspect(error, content="[E1002] files[0].size: size must be an integer")
}

///|
test "bad digest format reports e2002" {
  let error = parse_error(
    valid_manifest.replace(
      old="sha256:2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824",
      new="sha256-no-colon",
    ),
  )
  assert_eq(error.error_code(), "E2002")
}

///|
test "uppercase digest hex reports e2002 canonical form required" {
  let error = parse_error(
    valid_manifest.replace(
      old="2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824",
      new="2CF24DBA5FB0A30E26E83B2AC5B9E29E1B161E5C1FA7425E73043362938B9824",
    ),
  )
  assert_eq(error.error_code(), "E2002")
}

///|
test "bad merkle root reports e2002 with path" {
  let error = parse_error(
    valid_manifest.replace(
      old="sha256:60a53eed0de87a90c8e59427c59c46253c33a76a09502a51801300927b7e6bdc",
      new="sha256:not-hex",
    ),
  )
  assert_eq(error.error_code(), "E2002")
  inspect(
    error,
    content="[E2002] merkle_root: expected <algo>:<lowercase-hex>, got \"sha256:not-hex\"",
  )
}

///|
test "empty version parent reports e1002 invalid field" {
  let error = parse_error(
    valid_manifest.replace(old="\"parent\": null", new="\"parent\": \"\""),
  )
  assert_eq(error.error_code(), "E1002")
  inspect(
    error,
    content="[E1002] version.parent: must not be empty when present",
  )
}

// ---------------------------------------------------------------------------
// Path traversal hardening (step 7): entry paths are pack-relative, "/" only
// ---------------------------------------------------------------------------

///|
test "parent traversal path segment reports e1002" {
  let error = parse_error(
    valid_manifest.replace(old="files/a.txt", new="files/../../etc/passwd"),
  )
  assert_eq(error.error_code(), "E1002")
  inspect(
    error,
    content="[E1002] files[0].path: path segment \"..\" is not allowed",
  )
}

///|
test "absolute path reports e1002" {
  let error = parse_error(
    valid_manifest.replace(old="files/a.txt", new="/etc/passwd"),
  )
  assert_eq(error.error_code(), "E1002")
  inspect(
    error,
    content="[E1002] files[0].path: absolute paths are not allowed",
  )
}

///|
test "drive letter path reports e1002" {
  let error = parse_error(
    valid_manifest.replace(old="files/a.txt", new="C:/secret.txt"),
  )
  assert_eq(error.error_code(), "E1002")
  inspect(error, content="[E1002] files[0].path: \":\" is not allowed in paths")
}

///|
test "backslash separator reports e1002" {
  let error = parse_error(
    valid_manifest.replace(old="files/a.txt", new="files\\\\a.txt"),
  )
  assert_eq(error.error_code(), "E1002")
  inspect(
    error,
    content="[E1002] files[0].path: backslash separators are not allowed (use \"/\")",
  )
}

///|
test "single dot path segment reports e1002" {
  let error = parse_error(
    valid_manifest.replace(old="files/a.txt", new="files/./a.txt"),
  )
  assert_eq(error.error_code(), "E1002")
  inspect(
    error,
    content="[E1002] files[0].path: path segment \".\" is not allowed",
  )
}

///|
test "empty path segment reports e1002" {
  let error = parse_error(
    valid_manifest.replace(old="files/a.txt", new="files//a.txt"),
  )
  assert_eq(error.error_code(), "E1002")
  inspect(
    error,
    content="[E1002] files[0].path: empty path segment is not allowed",
  )
  // Trailing separators produce an empty final segment: same rule.
  let trailing = parse_error(
    valid_manifest.replace(old="files/a.txt", new="files/a.txt/"),
  )
  assert_eq(trailing.error_code(), "E1002")
}

///|
test "size at the double precision limit parses and beyond is rejected" {
  let ok = Manifest::parse(
    valid_manifest.replace(old="\"size\": 12", new="\"size\": 9007199254740991"),
  ) catch {
    error => fail("unexpected: \{error}")
  }
  assert_eq(ok.files[0].size, 9007199254740991L)
  let error = parse_error(
    valid_manifest.replace(old="\"size\": 12", new="\"size\": 9007199254740993"),
  )
  assert_eq(error.error_code(), "E1002")
}
