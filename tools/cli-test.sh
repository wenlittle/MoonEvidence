#!/usr/bin/env bash
#
# Black-box CLI tests - bash port of tools/cli-test.ps1.
#
# This is a 1:1 port: every case in cli-test.ps1 has a matching case here,
# with the same exit-code and output-pattern / finding-code assertions.
#
#   Part 1 - exit codes (0 pass / 1 fail / 2 usage-or-IO) plus key output
#            lines for every command shape, against the bundled example packs.
#   Part 2 - tamper-matrix packs under tests/fixtures/packs/ verified with
#            --json; the finding-code multiset must match EXACTLY.
#   Part 3 - manifest error-code matrix: every fixture under
#            tests/fixtures/manifest/ fed to `verify --json` so the
#            parse-layer error codes (E1001/E1002/E1003/E2001/E2002) fire at
#            the CLI boundary, with EXACT finding-code multiset assertion.
#   Part 4 - create command black-box: create -> verify closed loops plus
#            argument validation.
#   Part 5 - incremental verification: first run rehashes, second run skips,
#            JSON mode remains valid.
#
# Usage:
#   ./tools/cli-test.sh             # test the js artifact via node
#   ./tools/cli-test.sh native      # test the native executable
#
# Build the artifact first:
#   moon build --target js     (or native)
#
# Requires: bash, grep -E, jq (mandatory - the Part 2/3 JSON multiset checks
# depend on jq; if jq is missing the script errors out rather than silently
# skipping the JSON assertions).

set -u

TARGET="${1:-js}"
case "$TARGET" in
  js|native) ;;
  *)
    echo "usage: $0 [js|native]" >&2
    exit 2
    ;;
esac

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT" || exit 2

# jq is mandatory for Part 2/3 JSON multiset assertions; fail fast instead of
# silently skipping.
if ! command -v jq >/dev/null 2>&1; then
  echo "jq not found on PATH. Install jq (required for JSON multiset checks)." >&2
  exit 1
fi

# --- locate the CLI build artifact -------------------------------------------

find_cli_artifact() {
  local build_root="_build/$1"
  if [ ! -d "$build_root" ]; then
    echo "Build directory '$build_root' not found. Run: moon build --target $1" >&2
    exit 2
  fi
  local names
  if [ "$1" = "js" ]; then
    names="main.js"
  else
    names="main.exe main"
  fi
  # The documented prerequisite builds the debug artifact. Prefer it so a
  # stale release artifact from an earlier run cannot silently test old code.
  local found=""
  for name in $names; do
    local hit
    hit="$(find "$build_root" -type f -name "$name" 2>/dev/null \
           | grep -E 'src/cmd/main' | sort | head -n 1)"
    if [ -n "$hit" ]; then found="$hit"; break; fi
  done
  if [ -z "$found" ]; then
    echo "CLI artifact not found under '$build_root'. Run: moon build --target $1" >&2
    exit 2
  fi
  local debug
  debug="$(find "$build_root" -type f -name "$(basename "$found")" 2>/dev/null \
           | grep -E '/debug/' | grep -E 'src/cmd/main' | sort | head -n 1)"
  if [ -n "$debug" ]; then printf '%s' "$debug"; else printf '%s' "$found"; fi
}

find_node() {
  if command -v node >/dev/null 2>&1; then
    command -v node
    return
  fi
  # WSL on the local Windows workstation may expose Node.js as node.exe via
  # interop. CI uses plain `node`; this fallback only keeps local parity checks
  # runnable without installing a second Node inside WSL.
  if command -v node.exe >/dev/null 2>&1; then
    command -v node.exe
    return
  fi
  echo "node not found" >&2
  exit 1
}

ARTIFACT="$(find_cli_artifact "$TARGET")"
NODE=""
if [ "$TARGET" = "js" ]; then NODE="$(find_node)"; fi
echo "artifact: $ARTIFACT"

# invoke_cli <args...> -> sets INVOKE_OUT (stdout) and INVOKE_RC (exit code).
invoke_cli() {
  local out rc
  if [ "$TARGET" = "js" ]; then
    out="$("$NODE" "$ARTIFACT" "$@" 2>/dev/null)"
  else
    out="$("$ARTIFACT" "$@" 2>/dev/null)"
  fi
  rc=$?
  INVOKE_OUT="$out"
  INVOKE_RC="$rc"
}

FAILED=0
CASES_TOTAL=0
MATRIX_TOTAL=0
MANIFEST_TOTAL=0
CREATE_TOTAL=0
INCREMENTAL_TOTAL=0
MACHINE_TOTAL=0
IO_TOTAL=0

# p1_one NAME EXPECTED_EXIT "pat1|pat2" <cli args...>
# A case passes when the exit code matches AND every pipe-separated pattern
# appears in stdout (extended regex via grep -E). The pipe separator mirrors
# the PowerShell MustMatch array (each element must match = AND semantics).
p1_one() {
  local name="$1" expected="$2" pats="$3"; shift 3
  CASES_TOTAL=$((CASES_TOTAL + 1))
  invoke_cli "$@"
  local problems=""
  [ "$INVOKE_RC" = "$expected" ] || problems+="exit code: expected $expected, got $INVOKE_RC; "
  local pat
  local old_ifs="$IFS"
  IFS='|'
  set -f
  for pat in $pats; do
    printf '%s' "$INVOKE_OUT" | grep -Eq "$pat" || problems+="output missing pattern: $pat; "
  done
  set +f
  IFS="$old_ifs"
  if [ -z "$problems" ]; then
    echo "PASS  $name"
  else
    FAILED=$((FAILED + 1))
    echo "FAIL  $name"
    echo "      $problems"
    echo "      args:   $*"
    printf '      output: %s\n' "$(printf '%s' "$INVOKE_OUT" | tr -d '\r')"
  fi
}

# p2_one PACK EXPECTED_EXIT EXPECTED_OK "CODE1 CODE2 ..."
# Exact multiset comparison: sorted code lists must be identical.
p2_one() {
  local pack="$1" expected_exit="$2" expected_ok="$3" expected_codes="$4"
  MATRIX_TOTAL=$((MATRIX_TOTAL + 1))
  invoke_cli verify --json "tests/fixtures/packs/$pack"
  local problems=""
  [ "$INVOKE_RC" = "$expected_exit" ] || problems+="exit code: expected $expected_exit, got $INVOKE_RC; "
  if ! printf '%s' "$INVOKE_OUT" | jq -e . >/dev/null 2>&1; then
    problems+="output is not valid JSON; "
  else
    local ok actual sorted_expected
    ok="$(printf '%s' "$INVOKE_OUT" | jq -r '.ok')"
    [ "$ok" = "$expected_ok" ] || problems+="ok: expected $expected_ok, got $ok; "
    actual="$(printf '%s' "$INVOKE_OUT" | jq -r '(.findings // [])[].code' 2>/dev/null | tr -d '\r' | sort | paste -sd, -)"
    sorted_expected="$(printf '%s\n' $expected_codes | sort | paste -sd, -)"
    [ "$actual" = "$sorted_expected" ] || problems+="codes: expected [$sorted_expected], got [$actual]; "
  fi
  if [ -z "$problems" ]; then
    echo "PASS  matrix: $pack"
  else
    FAILED=$((FAILED + 1))
    echo "FAIL  matrix: $pack"
    echo "      $problems"
    printf '      output: %s\n' "$(printf '%s' "$INVOKE_OUT" | tr -d '\r')"
  fi
}

# p3_one FILE "CODE1 CODE2 ..."
# Every manifest fixture fails verification (parse error or, for valid.json,
# missing file bytes) so the exit code must be 1 and ok must be false.
# Exact multiset comparison: sorted code lists must be identical.
p3_one() {
  local file="$1" expected_codes="$2"
  MANIFEST_TOTAL=$((MANIFEST_TOTAL + 1))
  invoke_cli verify --json "tests/fixtures/manifest/$file"
  local problems=""
  if [ "$INVOKE_RC" != "1" ]; then
    problems+="exit code: expected 1, got $INVOKE_RC; "
  fi
  if ! printf '%s' "$INVOKE_OUT" | jq -e . >/dev/null 2>&1; then
    problems+="output is not valid JSON; "
  else
    local ok actual sorted_expected
    ok="$(printf '%s' "$INVOKE_OUT" | jq -r '.ok')"
    [ "$ok" = "false" ] || problems+="ok: expected false, got $ok; "
    actual="$(printf '%s' "$INVOKE_OUT" | jq -r '(.findings // [])[].code' 2>/dev/null | tr -d '\r' | sort | paste -sd, -)"
    sorted_expected="$(printf '%s\n' $expected_codes | sort | paste -sd, -)"
    [ "$actual" = "$sorted_expected" ] || problems+="codes: expected [$sorted_expected], got [$actual]; "
  fi
  if [ -z "$problems" ]; then
    echo "PASS  manifest: $file"
  else
    FAILED=$((FAILED + 1))
    echo "FAIL  manifest: $file"
    echo "      $problems"
    printf '      output: %s\n' "$(printf '%s' "$INVOKE_OUT" | tr -d '\r')"
  fi
}

# new_test_file DIR REL_PATH CONTENT
new_test_file() {
  local dir="$1" rel="$2" content="$3"
  local full="$dir/$rel"
  mkdir -p "$(dirname "$full")"
  printf '%s' "$content" > "$full"
}

# record_result KIND NAME PROBLEMS OUTPUT
record_result() {
  local kind="$1" name="$2" problems="$3" output="${4:-}"
  case "$kind" in
    create) CREATE_TOTAL=$((CREATE_TOTAL + 1)) ;;
    incremental) INCREMENTAL_TOTAL=$((INCREMENTAL_TOTAL + 1)) ;;
    machine) MACHINE_TOTAL=$((MACHINE_TOTAL + 1)) ;;
    io) IO_TOTAL=$((IO_TOTAL + 1)) ;;
  esac
  if [ -z "$problems" ]; then
    echo "PASS  $kind: $name"
  else
    FAILED=$((FAILED + 1))
    echo "FAIL  $kind: $name"
    echo "      $problems"
    if [ -n "$output" ]; then
      printf '      output: %s\n' "$(printf '%s' "$output" | tr -d '\r')"
    fi
  fi
}

# --- Part 1: command-shape contract ------------------------------------------
#
# Mirrors the PowerShell $cases array exactly: same args, same exit codes,
# same MustMatch patterns (multiple patterns per case are pipe-separated here;
# each must appear = AND semantics, matching the PowerShell array).

p1_one "version flag"           0 'moon-evidence [0-9]+\.[0-9]+\.[0-9]+' --version
p1_one "help flag"              0 'Usage:'                                --help
p1_one "verify valid pack dir"  0 'verification OK|merkle root verified'  verify examples/valid-pack
p1_one "verify valid manifest"  0 'verification OK'                       verify examples/valid-pack/manifest.json
p1_one "verify valid json"      0 '"ok":true'                             verify --json examples/valid-pack
p1_one "verify tampered pack"   1 'verification FAILED|\[E2003\] files/a\.txt' verify examples/tampered-pack
p1_one "verify tampered json"   1 '"ok":false|E2003'                      verify --json examples/tampered-pack
p1_one "explain tampered pack"  1 '\[E2003\]'                             explain examples/tampered-pack
p1_one "missing path"           2 '\[E5001\]'                             verify examples/no-such-pack
p1_one "verify without path"    2 'Usage:'                                verify
p1_one "unknown command"        2 'Usage:'                                frobnicate
p1_one "explain rejects --json" 2 'Usage:'                                explain --json examples/valid-pack

# --- Part 2: tamper matrix (exact finding-code multisets) --------------------
#
# Mirrors the PowerShell $matrix array exactly: same packs, exit codes, ok
# flags, and exact code multisets.

p2_one "valid"            0 "true"  ""
p2_one "valid-sha512"     0 "true"  ""
p2_one "tampered-file"    1 "false" "E2003"
p2_one "missing-file"     1 "false" "E2003"
p2_one "unlisted-file"    0 "true"  "W1001"
p2_one "bad-digest-field" 1 "false" "E2003 E3003"
p2_one "bad-merkle-root"  1 "false" "E3003"
p2_one "chain-broken"     1 "false" "E4002"
p2_one "chain-cycle"      1 "false" "E4003"
p2_one "chain-empty"      1 "false" "E4001"
p2_one "chain-fork"       1 "false" "E4004"

# --- Part 3: manifest error-code matrix --------------------------------------
#
# Mirrors the PowerShell $manifestMatrix array exactly. Each fixture is a
# single manifest file (not a pack directory); the CLI resolves pack_root to
# its parent dir, so files/ never resolves and the parse error is the only
# finding that fires. valid.json is the exception: it parses cleanly but, with
# no files/ tree on disk, surfaces E2003 per listed file plus E3003 (recomputed
# root differs from the sealed root).
#
# E3002 (proof format invalid) is intentionally absent: the CLI ships no
# proofs/ consumer in the MVP, so no manifest fixture can trigger it. It
# remains reserved in the error-code contract for a future inclusion-proof
# path; see tests/fixtures/packs/README.md for the honest coverage note.

p3_one "invalid-json.json"          "E1001"
p3_one "missing-schema.json"        "E1002"
p3_one "unsupported-schema.json"    "E1003"
p3_one "missing-subject-id.json"    "E1002"
p3_one "empty-subject-type.json"    "E1002"
p3_one "unsupported-algorithm.json" "E2001"
p3_one "files-not-array.json"       "E1002"
p3_one "duplicate-file-path.json"   "E1002"
p3_one "negative-size.json"         "E1002"
p3_one "fractional-size.json"       "E1002"
p3_one "bad-digest-format.json"     "E2002"
p3_one "uppercase-digest.json"      "E2002"
p3_one "bad-merkle-root.json"       "E2002"
p3_one "empty-version-parent.json"  "E1002"
p3_one "path-traversal.json"        "E1002"
p3_one "path-absolute.json"         "E1002"
p3_one "path-drive-letter.json"     "E1002"
p3_one "path-backslash.json"        "E1002"
p3_one "valid.json"                 "E2003 E2003 E3003"

# --- Part 4: create command black-box ----------------------------------------
#
# Mirrors the PowerShell create cases exactly. The important contract is not
# just "create exits 0"; every successful create case immediately verifies the
# produced pack or manifest so path layout, digest algorithm, and Merkle root
# agree at the real CLI boundary.

CREATE_TMP=".tmp-cli-create-$$"
rm -rf "$CREATE_TMP"
mkdir -p "$CREATE_TMP"
cleanup_create() { rm -rf "$CREATE_TMP"; }
trap cleanup_create EXIT

# Case 1: flat directory -> create -> verify
dir1="$CREATE_TMP/flat"
mkdir -p "$dir1"
new_test_file "$dir1" "a.txt" "hello"
new_test_file "$dir1" "b.txt" "world"
invoke_cli create "$dir1" --subject-id test-flat --subject-type report
problems=""
[ "$INVOKE_RC" = "0" ] || problems+="exit: expected 0, got $INVOKE_RC; "
printf '%s' "$INVOKE_OUT" | grep -Eq 'created.*2 files, sha256' || problems+="output missing: created (2 files, sha256); "
if [ -z "$problems" ]; then
  invoke_cli verify "$dir1/manifest.json"
  [ "$INVOKE_RC" = "0" ] || problems+="verify exit: expected 0, got $INVOKE_RC; "
  printf '%s' "$INVOKE_OUT" | grep -Eq 'verification OK' || problems+="verify output missing: verification OK; "
fi
record_result create "flat -> verify" "$problems" "$INVOKE_OUT"

# Case 2: nested directory -> create -> verify
dir2="$CREATE_TMP/nested"
mkdir -p "$dir2"
new_test_file "$dir2" "a.txt" "top"
new_test_file "$dir2" "sub/c.txt" "nested"
invoke_cli create "$dir2" --subject-id test-nested
problems=""
[ "$INVOKE_RC" = "0" ] || problems+="exit: expected 0, got $INVOKE_RC; "
printf '%s' "$INVOKE_OUT" | grep -Eq '2 files, sha256' || problems+="output missing: (2 files, sha256); "
if [ -z "$problems" ]; then
  invoke_cli verify "$dir2/manifest.json"
  [ "$INVOKE_RC" = "0" ] || problems+="verify exit: expected 0, got $INVOKE_RC; "
  printf '%s' "$INVOKE_OUT" | grep -Eq 'verification OK' || problems+="verify output missing: verification OK; "
fi
record_result create "nested -> verify" "$problems" "$INVOKE_OUT"

# Case 3: empty directory -> create -> verify
dir3="$CREATE_TMP/empty"
mkdir -p "$dir3"
invoke_cli create "$dir3" --subject-id test-empty
problems=""
[ "$INVOKE_RC" = "0" ] || problems+="exit: expected 0, got $INVOKE_RC; "
printf '%s' "$INVOKE_OUT" | grep -Eq '0 files, sha256' || problems+="output missing: (0 files, sha256); "
if [ -z "$problems" ]; then
  invoke_cli verify "$dir3/manifest.json"
  [ "$INVOKE_RC" = "0" ] || problems+="verify exit: expected 0, got $INVOKE_RC; "
  printf '%s' "$INVOKE_OUT" | grep -Eq 'verification OK' || problems+="verify output missing: verification OK; "
fi
record_result create "empty -> verify" "$problems" "$INVOKE_OUT"

# Case 4: missing --subject-id -> exit 2
dir4="$CREATE_TMP/no-sid"
mkdir -p "$dir4"
new_test_file "$dir4" "a.txt" "data"
invoke_cli create "$dir4"
problems=""
[ "$INVOKE_RC" = "2" ] || problems+="exit: expected 2, got $INVOKE_RC; "
record_result create "missing --subject-id" "$problems" "$INVOKE_OUT"

# Case 5: non-existent directory -> exit 2
invoke_cli create "$CREATE_TMP/no-such-dir" --subject-id x
problems=""
[ "$INVOKE_RC" = "2" ] || problems+="exit: expected 2, got $INVOKE_RC; "
printf '%s' "$INVOKE_OUT" | grep -Eq 'E5001' || problems+="output missing: E5001; "
record_result create "non-existent dir" "$problems" "$INVOKE_OUT"

# Case 6: custom output path -> create -> verify manifest file
dir6="$CREATE_TMP/custom-out"
mkdir -p "$dir6"
new_test_file "$dir6" "a.txt" "custom"
custom_manifest="$dir6/my-manifest.json"
invoke_cli create "$dir6" --subject-id test-custom -o "$custom_manifest"
problems=""
[ "$INVOKE_RC" = "0" ] || problems+="exit: expected 0, got $INVOKE_RC; "
printf '%s' "$INVOKE_OUT" | grep -Eq 'created.*my-manifest' || problems+="output missing: created my-manifest; "
if [ -z "$problems" ]; then
  invoke_cli verify "$custom_manifest"
  [ "$INVOKE_RC" = "0" ] || problems+="verify exit: expected 0, got $INVOKE_RC; "
  printf '%s' "$INVOKE_OUT" | grep -Eq 'verification OK' || problems+="verify output missing: verification OK; "
fi
record_result create "custom output -> verify" "$problems" "$INVOKE_OUT"

# Case 7: SHA-512 algorithm -> create -> verify
dir7="$CREATE_TMP/sha512"
mkdir -p "$dir7"
new_test_file "$dir7" "a.txt" "sha512-content"
invoke_cli create "$dir7" --subject-id test-sha512 --algorithm sha512
problems=""
[ "$INVOKE_RC" = "0" ] || problems+="exit: expected 0, got $INVOKE_RC; "
printf '%s' "$INVOKE_OUT" | grep -Eq '1 files, sha512' || problems+="output missing: (1 files, sha512); "
if [ -z "$problems" ]; then
  invoke_cli verify "$dir7/manifest.json"
  [ "$INVOKE_RC" = "0" ] || problems+="verify exit: expected 0, got $INVOKE_RC; "
  printf '%s' "$INVOKE_OUT" | grep -Eq 'verification OK' || problems+="verify output missing: verification OK; "
fi
record_result create "sha512 -> verify" "$problems" "$INVOKE_OUT"

# Case 8: unknown algorithm -> exit 2
dir8="$CREATE_TMP/bad-algo"
mkdir -p "$dir8"
new_test_file "$dir8" "a.txt" "x"
invoke_cli create "$dir8" --subject-id x --algorithm md5
problems=""
[ "$INVOKE_RC" = "2" ] || problems+="exit: expected 2, got $INVOKE_RC; "
printf '%s' "$INVOKE_OUT" | grep -Eq 'unknown algorithm' || problems+="output missing: unknown algorithm; "
record_result create "unknown algorithm" "$problems" "$INVOKE_OUT"

# Case 9: version chaining -> create -> verify JSON shows ok
dir9="$CREATE_TMP/versioned"
mkdir -p "$dir9"
new_test_file "$dir9" "a.txt" "v2-content"
invoke_cli create "$dir9" --subject-id test-ver --version-id v2 --version-parent abc123
problems=""
[ "$INVOKE_RC" = "0" ] || problems+="exit: expected 0, got $INVOKE_RC; "
if [ -z "$problems" ]; then
  invoke_cli verify --json "$dir9/manifest.json"
  [ "$INVOKE_RC" = "0" ] || problems+="verify exit: expected 0, got $INVOKE_RC; "
  printf '%s' "$INVOKE_OUT" | grep -Eq '"ok":true' || problems+="verify output missing: ok:true; "
fi
record_result create "version chaining -> verify" "$problems" "$INVOKE_OUT"

# Case 10: recursion depth cap must abort create instead of silently omitting files
dir10="$CREATE_TMP/too-deep"
mkdir -p "$dir10"
deep="$dir10"
for d in $(seq 0 32); do
  deep="$deep/d$d"
  mkdir -p "$deep"
done
new_test_file "$deep" "leaf.txt" "deep"
invoke_cli create "$dir10" --subject-id too-deep
problems=""
[ "$INVOKE_RC" = "2" ] || problems+="exit: expected 2, got $INVOKE_RC; "
printf '%s' "$INVOKE_OUT" | grep -Eq 'recursion depth limit' || problems+="output missing: recursion depth limit; "
[ ! -f "$dir10/manifest.json" ] || problems+="manifest should not be written after depth-cap abort; "
record_result create "depth cap aborts" "$problems" "$INVOKE_OUT"

# --- Part 5: incremental verification ---------------------------------------
#
# Mirrors the PowerShell incremental cases. The first run has no cache and
# rehashes all files; the second run uses the cache and skips unchanged files.

INC_CACHE=".tmp-cli-incremental-$$"
rm -rf "$INC_CACHE"
mkdir -p "$INC_CACHE"
cleanup_incremental() { rm -rf "$INC_CACHE"; }
trap 'cleanup_create; cleanup_incremental' EXIT

# Case 1: first run - no cache, all files rehashed
invoke_cli verify --incremental "$INC_CACHE" examples/valid-pack
problems=""
[ "$INVOKE_RC" = "0" ] || problems+="exit: expected 0, got $INVOKE_RC; "
printf '%s' "$INVOKE_OUT" | grep -Eq 'incremental:.*rehashed.*0 skipped' || problems+="first run should show 0 skipped; "
record_result incremental "first run (all rehashed)" "$problems" "$INVOKE_OUT"

# Case 2: second run - cache exists, all files skipped
invoke_cli verify --incremental "$INC_CACHE" examples/valid-pack
problems=""
[ "$INVOKE_RC" = "0" ] || problems+="exit: expected 0, got $INVOKE_RC; "
printf '%s' "$INVOKE_OUT" | grep -Eq 'incremental:.*0 rehashed.*skipped' || problems+="second run should show 0 rehashed; "
record_result incremental "second run (all skipped)" "$problems" "$INVOKE_OUT"

# Case 3: --incremental with --json
invoke_cli verify --json --incremental "$INC_CACHE" examples/valid-pack
problems=""
[ "$INVOKE_RC" = "0" ] || problems+="exit: expected 0, got $INVOKE_RC; "
printf '%s' "$INVOKE_OUT" | grep -Eq '"ok":true' || problems+="json output missing ok:true; "
record_result incremental "json mode" "$problems" "$INVOKE_OUT"

# --- Part 6: machine contract and external anchor verification --------------

MACHINE_TMP=".tmp-cli-machine-$$"
rm -rf "$MACHINE_TMP"
mkdir -p "$MACHINE_TMP"
GOLDEN_DIGEST="sha256:16bbf1e91de3acfb8bd9091233926b454045c6d96c24327baec20272af583f1e"

# Case 1: inspect emits the fixed golden manifest digest.
invoke_cli inspect --json examples/valid-pack
problems=""
[ "$INVOKE_RC" = "0" ] || problems+="exit: expected 0, got $INVOKE_RC; "
if ! printf '%s' "$INVOKE_OUT" | jq -e . >/dev/null 2>&1; then
  problems+="output is not valid JSON; "
else
  [ "$(printf '%s' "$INVOKE_OUT" | jq -r '.schema')" = "moon-evidence-inspect/v1" ] || problems+="wrong schema; "
  [ "$(printf '%s' "$INVOKE_OUT" | jq -r '.manifest_digest')" = "$GOLDEN_DIGEST" ] || problems+="wrong manifest digest; "
  [ "$(printf '%s' "$INVOKE_OUT" | jq -r '.files_total')" = "2" ] || problems+="wrong files_total; "
fi
record_result machine "inspect golden digest" "$problems" "$INVOKE_OUT"

# Case 2: matching external digest stays green.
invoke_cli verify --json --expected-manifest-digest "$GOLDEN_DIGEST" examples/valid-pack
problems=""
[ "$INVOKE_RC" = "0" ] || problems+="exit: expected 0, got $INVOKE_RC; "
[ "$(printf '%s' "$INVOKE_OUT" | jq -r '.ok' 2>/dev/null)" = "true" ] || problems+="expected ok:true; "
record_result machine "external digest match" "$problems" "$INVOKE_OUT"

# Case 3: different canonical digest produces exactly E2004.
WRONG_DIGEST="sha256:$(printf '0%.0s' {1..64})"
invoke_cli verify --json --expected-manifest-digest "$WRONG_DIGEST" examples/valid-pack
problems=""
[ "$INVOKE_RC" = "1" ] || problems+="exit: expected 1, got $INVOKE_RC; "
[ "$(printf '%s' "$INVOKE_OUT" | jq -r '(.findings // [])[].code' 2>/dev/null)" = "E2004" ] || problems+="expected only E2004; "
record_result machine "external digest mismatch" "$problems" "$INVOKE_OUT"

# Case 4: malformed digest is a usage error.
invoke_cli verify --json --expected-manifest-digest sha256:ABC examples/valid-pack
problems=""
[ "$INVOKE_RC" = "2" ] || problems+="exit: expected 2, got $INVOKE_RC; "
printf '%s' "$INVOKE_OUT" | grep -Eq 'must be canonical' || problems+="missing canonical digest guidance; "
record_result machine "malformed external digest" "$problems" "$INVOKE_OUT"

# Case 5: pack copies nested input and returns a usable digest.
source_dir="$MACHINE_TMP/source"
packed_dir="$MACHINE_TMP/packed"
mkdir -p "$source_dir"
new_test_file "$source_dir" "a.txt" "alpha"
new_test_file "$source_dir" "nested/b.txt" "beta"
new_test_file "$source_dir" "manifest.json" '{"source":true}'
invoke_cli pack "$source_dir" -o "$packed_dir" --subject-type dataset --json
problems=""
[ "$INVOKE_RC" = "0" ] || problems+="exit: expected 0, got $INVOKE_RC; "
if ! printf '%s' "$INVOKE_OUT" | jq -e . >/dev/null 2>&1; then
  problems+="output is not valid JSON; "
  pack_digest=""
else
  [ "$(printf '%s' "$INVOKE_OUT" | jq -r '.schema')" = "moon-evidence-pack-result/v1" ] || problems+="wrong schema; "
  [ "$(printf '%s' "$INVOKE_OUT" | jq -r '.subject.id')" = "source" ] || problems+="wrong default subject id; "
  [ "$(printf '%s' "$INVOKE_OUT" | jq -r '.files_total')" = "3" ] || problems+="wrong files_total; "
  pack_digest="$(printf '%s' "$INVOKE_OUT" | jq -r '.manifest_digest')"
fi
[ -f "$packed_dir/files/a.txt" ] || problems+="files/a.txt not copied; "
[ -f "$packed_dir/files/nested/b.txt" ] || problems+="nested file not copied; "
[ -f "$packed_dir/files/manifest.json" ] || problems+="source manifest.json was silently omitted; "
if [ -z "$problems" ]; then
  invoke_cli verify --json --expected-manifest-digest "$pack_digest" "$packed_dir"
  [ "$INVOKE_RC" = "0" ] || problems+="packed output did not verify; "
fi
record_result machine "pack nested source" "$problems" "$INVOKE_OUT"

# Case 6: existing output is never overwritten.
before_hash="$(sha256sum "$packed_dir/manifest.json" | awk '{print $1}')"
invoke_cli pack "$source_dir" -o "$packed_dir" --json
problems=""
[ "$INVOKE_RC" = "2" ] || problems+="exit: expected 2, got $INVOKE_RC; "
[ "$(printf '%s' "$INVOKE_OUT" | jq -r '.ok' 2>/dev/null)" = "false" ] || problems+="expected ok:false JSON; "
after_hash="$(sha256sum "$packed_dir/manifest.json" | awk '{print $1}')"
[ "$before_hash" = "$after_hash" ] || problems+="existing manifest was modified; "
record_result machine "pack overwrite refusal" "$problems" "$INVOKE_OUT"

# Case 7: seal is an exact alias.
sealed_dir="$MACHINE_TMP/sealed"
invoke_cli seal "$source_dir" -o "$sealed_dir" --subject-id alias
problems=""
[ "$INVOKE_RC" = "0" ] || problems+="exit: expected 0, got $INVOKE_RC; "
if [ -z "$problems" ]; then
  invoke_cli verify "$sealed_dir"
  [ "$INVOKE_RC" = "0" ] || problems+="sealed output did not verify; "
fi
record_result machine "seal alias" "$problems" "$INVOKE_OUT"

# Case 8: legacy create gains additive JSON metadata.
legacy_dir="$MACHINE_TMP/legacy"
mkdir -p "$legacy_dir"
new_test_file "$legacy_dir" "legacy.txt" "legacy"
invoke_cli create "$legacy_dir" --subject-id legacy --json
problems=""
[ "$INVOKE_RC" = "0" ] || problems+="exit: expected 0, got $INVOKE_RC; "
if ! printf '%s' "$INVOKE_OUT" | jq -e . >/dev/null 2>&1; then
  problems+="output is not valid JSON; "
else
  create_digest="$(printf '%s' "$INVOKE_OUT" | jq -r '.manifest_digest')"
  [ "$(printf '%s' "$INVOKE_OUT" | jq -r '.schema')" = "moon-evidence-pack-result/v1" ] || problems+="wrong schema; "
  invoke_cli verify --expected-manifest-digest "$create_digest" "$legacy_dir/manifest.json"
  [ "$INVOKE_RC" = "0" ] || problems+="create JSON digest did not verify; "
fi
record_result machine "create JSON metadata" "$problems" "$INVOKE_OUT"

rm -rf "$MACHINE_TMP"

# --- Part 7: verification IO and inventory completeness ---------------------

IO_TMP=".tmp-cli-io-$$"
rm -rf "$IO_TMP"
mkdir -p "$IO_TMP"

verify_io_failure() {
  local name="$1" pack="$2" code="$3" message_pattern="$4"
  invoke_cli verify "$pack"
  local problems=""
  [ "$INVOKE_RC" = "2" ] || problems+="exit: expected 2, got $INVOKE_RC; "
  printf '%s' "$INVOKE_OUT" | grep -Eq "\[$code\]" || problems+="output missing code: $code; "
  printf '%s' "$INVOKE_OUT" | grep -Eq "$message_pattern" || problems+="output missing pattern: $message_pattern; "
  record_result io "$name" "$problems" "$INVOKE_OUT"
}

missing_tree="$IO_TMP/missing-files-tree"
mkdir -p "$missing_tree"
cp examples/valid-pack/manifest.json "$missing_tree/manifest.json"
verify_io_failure "missing files tree" "$missing_tree" "E5001" "payload directory does not exist"

files_not_dir="$IO_TMP/files-not-directory"
mkdir -p "$files_not_dir"
cp examples/valid-pack/manifest.json "$files_not_dir/manifest.json"
new_test_file "$files_not_dir" "files" "not-a-directory"
verify_io_failure "files path is not a directory" "$files_not_dir" "E5002" "payload path is not a directory"

listed_unreadable="$IO_TMP/listed-payload-unreadable"
cp -R examples/valid-pack "$listed_unreadable"
rm "$listed_unreadable/files/a.txt"
mkdir "$listed_unreadable/files/a.txt"
verify_io_failure "listed payload is unreadable" "$listed_unreadable" "E5002" "file read failed"

chain_unreadable="$IO_TMP/version-chain-unreadable"
cp -R examples/valid-pack "$chain_unreadable"
rm "$chain_unreadable/versions/version_chain.json"
mkdir "$chain_unreadable/versions/version_chain.json"
verify_io_failure "version chain is unreadable" "$chain_unreadable" "E5002" "file read failed"

too_deep="$IO_TMP/inventory-too-deep"
cp -R examples/valid-pack "$too_deep"
deep_inventory="$too_deep/files"
for d in $(seq 0 32); do
  deep_inventory="$deep_inventory/d$d"
  mkdir -p "$deep_inventory"
done
new_test_file "$deep_inventory" "leaf.txt" "deep"
verify_io_failure "inventory depth cap" "$too_deep" "E5002" "recursion depth limit"

rm -rf "$IO_TMP"

# --- summary ----------------------------------------------------------------

TOTAL=$((CASES_TOTAL + MATRIX_TOTAL + MANIFEST_TOTAL + CREATE_TOTAL + INCREMENTAL_TOTAL + MACHINE_TOTAL + IO_TOTAL))
PASSED=$((TOTAL - FAILED))
echo ""
echo "cli-test ($TARGET): $PASSED/$TOTAL passed"
[ "$FAILED" -gt 0 ] && exit 1
exit 0
