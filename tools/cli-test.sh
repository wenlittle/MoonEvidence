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
  # Match the PowerShell ordering: pick the first src/cmd/main candidate
  # sorted by path, then prefer a release-build artifact if one exists.
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
  local release
  release="$(find "$build_root" -type f -name "$(basename "$found")" 2>/dev/null \
             | grep -E '/release/' | sort | head -n 1)"
  if [ -n "$release" ]; then printf '%s' "$release"; else printf '%s' "$found"; fi
}

find_node() {
  command -v node >/dev/null 2>&1 || { echo "node not found" >&2; exit 1; }
  command -v node
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
    actual="$(printf '%s' "$INVOKE_OUT" | jq -r '(.findings // [])[].code' 2>/dev/null | sort | paste -sd, -)"
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
    actual="$(printf '%s' "$INVOKE_OUT" | jq -r '(.findings // [])[].code' 2>/dev/null | sort | paste -sd, -)"
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

# --- summary ----------------------------------------------------------------

TOTAL=$((CASES_TOTAL + MATRIX_TOTAL + MANIFEST_TOTAL))
PASSED=$((TOTAL - FAILED))
echo ""
echo "cli-test ($TARGET): $PASSED/$TOTAL passed"
[ "$FAILED" -gt 0 ] && exit 1
exit 0
