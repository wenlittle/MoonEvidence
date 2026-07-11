# Black-box CLI tests (master plan step 6 task 3, step 7 task 3).
#
# Part 1 runs the moon-evidence CLI against the bundled example packs and
# asserts the frozen contract: exit codes (0 pass / 1 fail / 2 usage-or-IO)
# plus key output lines for every command shape.
#
# Part 2 is the step-7 regression baseline: every tamper-matrix pack under
# tests/fixtures/packs/ is verified with --json and the finding-code
# multiset must match EXACTLY (no "at least contains" assertions).
#
# Part 3 feeds every fixture under tests/fixtures/manifest/ through
# `verify --json` so the parse-layer error codes (E1001/E1002/E1003/
# E2001/E2002) fire at the CLI boundary, not only inside model unit tests.
#
# Usage:
#   ./tools/cli-test.ps1                 # test the js artifact via node
#   ./tools/cli-test.ps1 -Target native  # test the native executable
#
# The script only tests; build the artifact first:
#   moon build --target js     (or native)

param(
  [ValidateSet("js", "native")]
  [string]$Target = "js"
)

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $repoRoot

function Find-CliArtifact {
  param([string]$BuildTarget)

  $buildRoot = Join-Path $repoRoot "_build/$BuildTarget"
  if (-not (Test-Path $buildRoot)) {
    throw "Build directory '$buildRoot' not found. Run: moon build --target $BuildTarget"
  }
  $names = if ($BuildTarget -eq "js") { @("main.js") } else { @("main.exe", "main") }
  $candidates = Get-ChildItem $buildRoot -Recurse -File |
    Where-Object { $names -contains $_.Name -and $_.FullName -match "src[\\/]cmd[\\/]main" } |
    Sort-Object FullName
  if (@($candidates).Count -eq 0) {
    throw "CLI artifact not found under '$buildRoot'. Run: moon build --target $BuildTarget"
  }
  # The documented prerequisite builds the debug artifact. Prefer it so a
  # stale release artifact from an earlier run cannot silently test old code.
  $debug = $candidates | Where-Object { $_.FullName -match "[\\/]debug[\\/]" } | Select-Object -First 1
  if ($debug) { return $debug.FullName }
  return $candidates[0].FullName
}

function Find-Node {
  # Resolve node exclusively from PATH so the script is portable across
  # machines; the previous hard-coded D:\Programming_Language\Node\node.exe
  # fallback only worked on one developer box.
  $fromPath = Get-Command node -ErrorAction SilentlyContinue
  if ($fromPath) { return $fromPath.Source }
  throw "node not found on PATH. Install Node.js or test -Target native instead."
}

$artifact = Find-CliArtifact -BuildTarget $Target
$node = if ($Target -eq "js") { Find-Node } else { $null }
Write-Host "artifact: $artifact"

function Get-TempRoot {
  if ($env:TEMP) { return $env:TEMP }
  if ($env:TMPDIR) { return $env:TMPDIR }
  return [System.IO.Path]::GetTempPath()
}

$tempRoot = Get-TempRoot

function Invoke-Cli {
  param([string[]]$CliArgs)

  # The CLI prints everything assertable to stdout; stderr is dropped so
  # PowerShell 5.1 NativeCommandError noise cannot pollute assertions.
  $oldErrorActionPreference = $ErrorActionPreference
  $ErrorActionPreference = "Continue"
  try {
    if ($Target -eq "js") {
      $output = & $node $artifact @CliArgs 2>$null | Out-String
    } else {
      $output = & $artifact @CliArgs 2>$null | Out-String
    }
  } finally {
    $ErrorActionPreference = $oldErrorActionPreference
  }
  [PSCustomObject]@{ ExitCode = $LASTEXITCODE; Output = $output }
}

$cases = @(
  @{ Name = "version flag";           CliArgs = @("--version");                                   Exit = 0; MustMatch = @("moon-evidence \d+\.\d+\.\d+") }
  @{ Name = "help flag";              CliArgs = @("--help");                                      Exit = 0; MustMatch = @("Usage:") }
  @{ Name = "verify valid pack dir";  CliArgs = @("verify", "examples/valid-pack");               Exit = 0; MustMatch = @("verification OK", "merkle root verified") }
  @{ Name = "verify valid manifest";  CliArgs = @("verify", "examples/valid-pack/manifest.json"); Exit = 0; MustMatch = @("verification OK") }
  @{ Name = "verify valid json";      CliArgs = @("verify", "--json", "examples/valid-pack");     Exit = 0; MustMatch = @('"ok":true') }
  @{ Name = "verify tampered pack";   CliArgs = @("verify", "examples/tampered-pack");            Exit = 1; MustMatch = @("verification FAILED", "\[E2003\] files/a\.txt") }
  @{ Name = "verify tampered json";   CliArgs = @("verify", "--json", "examples/tampered-pack");  Exit = 1; MustMatch = @('"ok":false', "E2003") }
  @{ Name = "explain tampered pack";  CliArgs = @("explain", "examples/tampered-pack");           Exit = 1; MustMatch = @("\[E2003\]") }
  @{ Name = "missing path";           CliArgs = @("verify", "examples/no-such-pack");             Exit = 2; MustMatch = @("\[E5001\]") }
  @{ Name = "verify without path";    CliArgs = @("verify");                                      Exit = 2; MustMatch = @("Usage:") }
  @{ Name = "unknown command";        CliArgs = @("frobnicate");                                  Exit = 2; MustMatch = @("Usage:") }
  @{ Name = "explain rejects --json"; CliArgs = @("explain", "--json", "examples/valid-pack");    Exit = 2; MustMatch = @("Usage:") }
)

$failed = 0
foreach ($case in $cases) {
  $result = Invoke-Cli -CliArgs $case.CliArgs
  $problems = @()
  if ($result.ExitCode -ne $case.Exit) {
    $problems += "exit code: expected $($case.Exit), got $($result.ExitCode)"
  }
  foreach ($pattern in $case.MustMatch) {
    if ($result.Output -notmatch $pattern) {
      $problems += "output missing pattern: $pattern"
    }
  }
  if ($problems.Count -eq 0) {
    Write-Host "PASS  $($case.Name)"
  } else {
    $failed += 1
    Write-Host "FAIL  $($case.Name)"
    foreach ($problem in $problems) { Write-Host "      $problem" }
    Write-Host "      args:   $($case.CliArgs -join ' ')"
    Write-Host "      output: $($result.Output.Trim())"
  }
}

# --- Part 2: tamper matrix (exact finding-code sets, step 7) ----------------

$matrix = @(
  @{ Pack = "valid";            Exit = 0; Ok = $true;  Codes = @() }
  @{ Pack = "tampered-file";    Exit = 1; Ok = $false; Codes = @("E2003") }
  @{ Pack = "missing-file";     Exit = 1; Ok = $false; Codes = @("E2003") }
  @{ Pack = "unlisted-file";    Exit = 0; Ok = $true;  Codes = @("W1001") }
  @{ Pack = "bad-digest-field"; Exit = 1; Ok = $false; Codes = @("E2003", "E3003") }
  @{ Pack = "bad-merkle-root";  Exit = 1; Ok = $false; Codes = @("E3003") }
  @{ Pack = "chain-broken";     Exit = 1; Ok = $false; Codes = @("E4002") }
  @{ Pack = "chain-cycle";      Exit = 1; Ok = $false; Codes = @("E4003") }
  @{ Pack = "chain-empty";      Exit = 1; Ok = $false; Codes = @("E4001") }
  @{ Pack = "chain-fork";       Exit = 1; Ok = $false; Codes = @("E4004") }
)

foreach ($case in $matrix) {
  $packPath = "tests/fixtures/packs/$($case.Pack)"
  $result = Invoke-Cli -CliArgs @("verify", "--json", $packPath)
  $problems = @()
  if ($result.ExitCode -ne $case.Exit) {
    $problems += "exit code: expected $($case.Exit), got $($result.ExitCode)"
  }
  $report = $null
  try {
    $report = $result.Output | ConvertFrom-Json
  } catch {
    $problems += "output is not valid JSON"
  }
  if ($report) {
    if ($report.ok -ne $case.Ok) {
      $problems += "ok: expected $($case.Ok), got $($report.ok)"
    }
    # Exact multiset comparison: sorted code lists must be identical.
    $actual = @($report.findings | ForEach-Object { $_.code }) | Sort-Object
    $expected = @($case.Codes) | Sort-Object
    if (($actual -join ",") -ne ($expected -join ",")) {
      $problems += "codes: expected [$($expected -join ',')], got [$($actual -join ',')]"
    }
  }
  if ($problems.Count -eq 0) {
    Write-Host "PASS  matrix: $($case.Pack)"
  } else {
    $failed += 1
    Write-Host "FAIL  matrix: $($case.Pack)"
    foreach ($problem in $problems) { Write-Host "      $problem" }
    Write-Host "      output: $($result.Output.Trim())"
  }
}

# --- Part 3: manifest error-code matrix (step 7 hardening) ----------------
#
# Part 2 only exercises the packs/ tamper matrix, so the parse-layer error
# codes (E1001/E1002/E1003/E2001/E2002) never fire from the CLI black-box
# suite. This part feeds every fixture under tests/fixtures/manifest/ to
# `verify --json` and asserts the EXACT finding-code multiset, closing the
# E1003 (unsupported schema), E2001 (unsupported algorithm) and E2002 (bad
# digest format) coverage gaps directly at the CLI boundary.
#
# Each fixture is a single manifest file (not a pack directory); the CLI
# resolves pack_root to its parent dir, so files/ never resolves and the
# parse error is the only finding that fires. valid.json is the exception:
# it parses cleanly but, with no files/ tree on disk, surfaces E2003 per
# listed file plus E3003 (recomputed root differs from the sealed root
# because the manifest fixture ships a root that does not match its own
# canonical leaf bytes - this is documented in tests/fixtures/manifest/).
#
# E3002 (proof format invalid) is intentionally absent: the CLI ships no
# proofs/ consumer in the MVP, so no manifest fixture can trigger it. It
# remains reserved in the error-code contract for a future inclusion-proof
# path; see tests/fixtures/packs/README.md for the honest coverage note.

$manifestMatrix = @(
  @{ File = "invalid-json.json";         Codes = @("E1001") }
  @{ File = "missing-schema.json";       Codes = @("E1002") }
  @{ File = "unsupported-schema.json";   Codes = @("E1003") }
  @{ File = "missing-subject-id.json";   Codes = @("E1002") }
  @{ File = "empty-subject-type.json";   Codes = @("E1002") }
  @{ File = "unsupported-algorithm.json"; Codes = @("E2001") }
  @{ File = "files-not-array.json";      Codes = @("E1002") }
  @{ File = "duplicate-file-path.json";  Codes = @("E1002") }
  @{ File = "negative-size.json";        Codes = @("E1002") }
  @{ File = "fractional-size.json";      Codes = @("E1002") }
  @{ File = "bad-digest-format.json";    Codes = @("E2002") }
  @{ File = "uppercase-digest.json";     Codes = @("E2002") }
  @{ File = "bad-merkle-root.json";      Codes = @("E2002") }
  @{ File = "empty-version-parent.json"; Codes = @("E1002") }
  @{ File = "path-traversal.json";       Codes = @("E1002") }
  @{ File = "path-absolute.json";        Codes = @("E1002") }
  @{ File = "path-drive-letter.json";    Codes = @("E1002") }
  @{ File = "path-backslash.json";       Codes = @("E1002") }
  @{ File = "valid.json";                Codes = @("E2003", "E2003", "E3003") }
)

foreach ($case in $manifestMatrix) {
  $fixturePath = "tests/fixtures/manifest/$($case.File)"
  $result = Invoke-Cli -CliArgs @("verify", "--json", $fixturePath)
  $problems = @()
  # Every manifest fixture fails verification (parse error or, for valid.json,
  # missing file bytes) so the exit code must be 1.
  if ($result.ExitCode -ne 1) {
    $problems += "exit code: expected 1, got $($result.ExitCode)"
  }
  $report = $null
  try {
    $report = $result.Output | ConvertFrom-Json
  } catch {
    $problems += "output is not valid JSON"
  }
  if ($report) {
    if ($report.ok -ne $false) {
      $problems += "ok: expected false, got $($report.ok)"
    }
    # Exact multiset comparison: sorted code lists must be identical.
    $actual = @($report.findings | ForEach-Object { $_.code }) | Sort-Object
    $expected = @($case.Codes) | Sort-Object
    if (($actual -join ",") -ne ($expected -join ",")) {
      $problems += "codes: expected [$($expected -join ',')], got [$($actual -join ',')]"
    }
  }
  if ($problems.Count -eq 0) {
    Write-Host "PASS  manifest: $($case.File)"
  } else {
    $failed += 1
    Write-Host "FAIL  manifest: $($case.File)"
    foreach ($problem in $problems) { Write-Host "      $problem" }
    Write-Host "      output: $($result.Output.Trim())"
  }
}

# --- Part 4: create command black-box (round 4 phase 2) -------------------
#
# The create command had zero black-box coverage and a path-prefix bug:
# it prepended "files/" to every collected path, but the actual files
# sat at the directory root — so create→verify always failed. These
# tests exercise the create→verify closed loop with flat, nested, and
# empty directory layouts, plus argument validation.

$createTmp = Join-Path $tempRoot "moon-evidence-cli-test-creation"
if (Test-Path $createTmp) { Remove-Item $createTmp -Recurse -Force }
New-Item -ItemType Directory -Path $createTmp -Force | Out-Null

# Helper: create a file with content under a temp dir.
function New-TestFile($Dir, $RelPath, $Content) {
  $full = Join-Path $Dir $RelPath
  $parent = Split-Path -Parent $full
  if (-not (Test-Path $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
  Set-Content -Path $full -Value $Content -NoNewline -Encoding UTF8
}

# Case 1: flat directory → create → verify
$dir1 = Join-Path $createTmp "flat"
New-Item -ItemType Directory -Path $dir1 -Force | Out-Null
New-TestFile $dir1 "a.txt" "hello"
New-TestFile $dir1 "b.txt" "world"
$r = Invoke-Cli -CliArgs @("create", $dir1, "--subject-id", "test-flat", "--subject-type", "report")
$p = @()
if ($r.ExitCode -ne 0) { $p += "exit: expected 0, got $($r.ExitCode)" }
if ($r.Output -notmatch 'created.*2 files, sha256') { $p += "output missing: created (2 files, sha256)" }
if ($p.Count -eq 0) {
  $r2 = Invoke-Cli -CliArgs @("verify", $dir1)
  $p2 = @()
  if ($r2.ExitCode -ne 0) { $p2 += "verify exit: expected 0, got $($r2.ExitCode)" }
  if ($r2.Output -notmatch 'verification OK') { $p2 += "verify output missing: verification OK" }
  if ($p2.Count -eq 0) { Write-Host "PASS  create: flat → verify" }
  else { $failed += 1; Write-Host "FAIL  create: flat → verify"; $p2 | ForEach-Object { Write-Host "      $_" } }
} else {
  $failed += 1; Write-Host "FAIL  create: flat"; $p | ForEach-Object { Write-Host "      $_" }
  Write-Host "      output: $($r.Output.Trim())"
}

# Case 2: nested directory → create → verify
$dir2 = Join-Path $createTmp "nested"
New-Item -ItemType Directory -Path $dir2 -Force | Out-Null
New-TestFile $dir2 "a.txt" "top"
New-TestFile $dir2 "sub/c.txt" "nested"
$r = Invoke-Cli -CliArgs @("create", $dir2, "--subject-id", "test-nested")
$p = @()
if ($r.ExitCode -ne 0) { $p += "exit: expected 0, got $($r.ExitCode)" }
if ($r.Output -notmatch '2 files, sha256') { $p += "output missing: (2 files, sha256)" }
if ($p.Count -eq 0) {
  $r2 = Invoke-Cli -CliArgs @("verify", $dir2)
  $p2 = @()
  if ($r2.ExitCode -ne 0) { $p2 += "verify exit: expected 0, got $($r2.ExitCode)" }
  if ($r2.Output -notmatch 'verification OK') { $p2 += "verify output missing: verification OK" }
  if ($p2.Count -eq 0) { Write-Host "PASS  create: nested → verify" }
  else { $failed += 1; Write-Host "FAIL  create: nested → verify"; $p2 | ForEach-Object { Write-Host "      $_" } }
} else {
  $failed += 1; Write-Host "FAIL  create: nested"; $p | ForEach-Object { Write-Host "      $_" }
  Write-Host "      output: $($r.Output.Trim())"
}

# Case 3: empty directory → create → verify
$dir3 = Join-Path $createTmp "empty"
New-Item -ItemType Directory -Path $dir3 -Force | Out-Null
$r = Invoke-Cli -CliArgs @("create", $dir3, "--subject-id", "test-empty")
$p = @()
if ($r.ExitCode -ne 0) { $p += "exit: expected 0, got $($r.ExitCode)" }
if ($r.Output -notmatch '0 files, sha256') { $p += "output missing: (0 files, sha256)" }
if ($p.Count -eq 0) {
  $r2 = Invoke-Cli -CliArgs @("verify", $dir3)
  $p2 = @()
  if ($r2.ExitCode -ne 0) { $p2 += "verify exit: expected 0, got $($r2.ExitCode)" }
  if ($r2.Output -notmatch 'verification OK') { $p2 += "verify output missing: verification OK" }
  if ($p2.Count -eq 0) { Write-Host "PASS  create: empty → verify" }
  else { $failed += 1; Write-Host "FAIL  create: empty → verify"; $p2 | ForEach-Object { Write-Host "      $_" } }
} else {
  $failed += 1; Write-Host "FAIL  create: empty"; $p | ForEach-Object { Write-Host "      $_" }
  Write-Host "      output: $($r.Output.Trim())"
}

# Case 4: missing --subject-id → exit 2
$dir4 = Join-Path $createTmp "no-sid"
New-Item -ItemType Directory -Path $dir4 -Force | Out-Null
New-TestFile $dir4 "a.txt" "data"
$r = Invoke-Cli -CliArgs @("create", $dir4)
$p = @()
if ($r.ExitCode -ne 2) { $p += "exit: expected 2, got $($r.ExitCode)" }
if ($p.Count -eq 0) { Write-Host "PASS  create: missing --subject-id" }
else { $failed += 1; Write-Host "FAIL  create: missing --subject-id"; $p | ForEach-Object { Write-Host "      $_" } }

# Case 5: non-existent directory → exit 2
$r = Invoke-Cli -CliArgs @("create", "$createTmp/no-such-dir", "--subject-id", "x")
$p = @()
if ($r.ExitCode -ne 2) { $p += "exit: expected 2, got $($r.ExitCode)" }
if ($r.Output -notmatch 'E5001') { $p += "output missing: E5001" }
if ($p.Count -eq 0) { Write-Host "PASS  create: non-existent dir" }
else { $failed += 1; Write-Host "FAIL  create: non-existent dir"; $p | ForEach-Object { Write-Host "      $_" } }

# Case 6: custom output path → create → verify manifest file
$dir6 = Join-Path $createTmp "custom-out"
New-Item -ItemType Directory -Path $dir6 -Force | Out-Null
New-TestFile $dir6 "a.txt" "custom"
$customManifest = Join-Path $dir6 "my-manifest.json"
$r = Invoke-Cli -CliArgs @("create", $dir6, "--subject-id", "test-custom", "-o", $customManifest)
$p = @()
if ($r.ExitCode -ne 0) { $p += "exit: expected 0, got $($r.ExitCode)" }
if ($r.Output -notmatch 'created.*my-manifest') { $p += "output missing: created my-manifest" }
if ($p.Count -eq 0) {
  # Verify the custom manifest file (not the default manifest.json)
  $r2 = Invoke-Cli -CliArgs @("verify", $customManifest)
  $p2 = @()
  if ($r2.ExitCode -ne 0) { $p2 += "verify exit: expected 0, got $($r2.ExitCode)" }
  if ($r2.Output -notmatch 'verification OK') { $p2 += "verify output missing: verification OK" }
  if ($p2.Count -eq 0) { Write-Host "PASS  create: custom output → verify" }
  else { $failed += 1; Write-Host "FAIL  create: custom output → verify"; $p2 | ForEach-Object { Write-Host "      $_" } }
} else {
  $failed += 1; Write-Host "FAIL  create: custom output"; $p | ForEach-Object { Write-Host "      $_" }
  Write-Host "      output: $($r.Output.Trim())"
}

# Case 7: SHA-512 algorithm → create → verify
$dir7 = Join-Path $createTmp "sha512"
New-Item -ItemType Directory -Path $dir7 -Force | Out-Null
New-TestFile $dir7 "a.txt" "sha512-content"
$r = Invoke-Cli -CliArgs @("create", $dir7, "--subject-id", "test-sha512", "--algorithm", "sha512")
$p = @()
if ($r.ExitCode -ne 0) { $p += "exit: expected 0, got $($r.ExitCode)" }
if ($r.Output -notmatch '1 files, sha512') { $p += "output missing: (1 files, sha512)" }
if ($p.Count -eq 0) {
  $r2 = Invoke-Cli -CliArgs @("verify", $dir7)
  $p2 = @()
  if ($r2.ExitCode -ne 0) { $p2 += "verify exit: expected 0, got $($r2.ExitCode)" }
  if ($r2.Output -notmatch 'verification OK') { $p2 += "verify output missing: verification OK" }
  if ($p2.Count -eq 0) { Write-Host "PASS  create: sha512 → verify" }
  else { $failed += 1; Write-Host "FAIL  create: sha512 → verify"; $p2 | ForEach-Object { Write-Host "      $_" } }
} else {
  $failed += 1; Write-Host "FAIL  create: sha512"; $p | ForEach-Object { Write-Host "      $_" }
  Write-Host "      output: $($r.Output.Trim())"
}

# Case 8: unknown algorithm → exit 2
$dir8 = Join-Path $createTmp "bad-algo"
New-Item -ItemType Directory -Path $dir8 -Force | Out-Null
New-TestFile $dir8 "a.txt" "x"
$r = Invoke-Cli -CliArgs @("create", $dir8, "--subject-id", "x", "--algorithm", "md5")
$p = @()
if ($r.ExitCode -ne 2) { $p += "exit: expected 2, got $($r.ExitCode)" }
if ($r.Output -notmatch 'unknown algorithm') { $p += "output missing: unknown algorithm" }
if ($p.Count -eq 0) { Write-Host "PASS  create: unknown algorithm" }
else { $failed += 1; Write-Host "FAIL  create: unknown algorithm"; $p | ForEach-Object { Write-Host "      $_" } }

# Case 9: version chaining → create → verify JSON shows version fields
$dir9 = Join-Path $createTmp "versioned"
New-Item -ItemType Directory -Path $dir9 -Force | Out-Null
New-TestFile $dir9 "a.txt" "v2-content"
$r = Invoke-Cli -CliArgs @("create", $dir9, "--subject-id", "test-ver", "--version-id", "v2", "--version-parent", "abc123")
$p = @()
if ($r.ExitCode -ne 0) { $p += "exit: expected 0, got $($r.ExitCode)" }
if ($p.Count -eq 0) {
  $r2 = Invoke-Cli -CliArgs @("verify", "--json", $dir9)
  $p2 = @()
  if ($r2.ExitCode -ne 0) { $p2 += "verify exit: expected 0, got $($r2.ExitCode)" }
  if ($r2.Output -notmatch '"ok":true') { $p2 += "verify output missing: ok:true" }
  if ($p2.Count -eq 0) { Write-Host "PASS  create: version chaining → verify" }
  else { $failed += 1; Write-Host "FAIL  create: version chaining → verify"; $p2 | ForEach-Object { Write-Host "      $_" } }
} else {
  $failed += 1; Write-Host "FAIL  create: version chaining"; $p | ForEach-Object { Write-Host "      $_" }
  Write-Host "      output: $($r.Output.Trim())"
}

# Case 10: recursion depth cap must abort create instead of silently omitting files
$dir10 = Join-Path $createTmp "too-deep"
New-Item -ItemType Directory -Path $dir10 -Force | Out-Null
$deep = $dir10
for ($d = 0; $d -lt 33; $d++) {
  $deep = Join-Path $deep "d$d"
  New-Item -ItemType Directory -Path $deep -Force | Out-Null
}
New-TestFile $deep "leaf.txt" "deep"
$r = Invoke-Cli -CliArgs @("create", $dir10, "--subject-id", "too-deep")
$p = @()
if ($r.ExitCode -ne 2) { $p += "exit: expected 2, got $($r.ExitCode)" }
if ($r.Output -notmatch 'recursion depth limit') { $p += "output missing: recursion depth limit" }
if (Test-Path (Join-Path $dir10 "manifest.json")) { $p += "manifest should not be written after depth-cap abort" }
if ($p.Count -eq 0) { Write-Host "PASS  create: depth cap aborts" }
else {
  $failed += 1; Write-Host "FAIL  create: depth cap aborts"; $p | ForEach-Object { Write-Host "      $_" }
  Write-Host "      output: $($r.Output.Trim())"
}

# Cleanup
Remove-Item $createTmp -Recurse -Force -ErrorAction SilentlyContinue

# --- Part 5: incremental verification (round 4 phase 1) --------------------
#
# The --incremental flag caches file digests between runs. The first run
# rehashes everything; the second run should skip all unchanged files.
# The Merkle root is always recomputed, so security is identical to full
# verification.

$incCache = Join-Path $tempRoot "moon-evidence-cli-test-incremental"
if (Test-Path $incCache) { Remove-Item $incCache -Recurse -Force }
New-Item -ItemType Directory -Path $incCache -Force | Out-Null

# Case 1: first run — no cache, all files rehashed
$r = Invoke-Cli -CliArgs @("verify", "--incremental", $incCache, "examples/valid-pack")
$p = @()
if ($r.ExitCode -ne 0) { $p += "exit: expected 0, got $($r.ExitCode)" }
if ($r.Output -notmatch 'incremental:.*rehashed.*0 skipped') { $p += "first run should show 0 skipped, got: $($r.Output)" }
if ($p.Count -eq 0) {
  Write-Host "PASS  incremental: first run (all rehashed)"
} else {
  $failed += 1; Write-Host "FAIL  incremental: first run"; $p | ForEach-Object { Write-Host "      $_" }
}

# Case 2: second run — cache exists, all files skipped
$r = Invoke-Cli -CliArgs @("verify", "--incremental", $incCache, "examples/valid-pack")
$p = @()
if ($r.ExitCode -ne 0) { $p += "exit: expected 0, got $($r.ExitCode)" }
if ($r.Output -notmatch 'incremental:.*0 rehashed.*skipped') { $p += "second run should show 0 rehashed, got: $($r.Output)" }
if ($p.Count -eq 0) {
  Write-Host "PASS  incremental: second run (all skipped)"
} else {
  $failed += 1; Write-Host "FAIL  incremental: second run"; $p | ForEach-Object { Write-Host "      $_" }
}

# Case 3: --incremental with --json (should not crash)
$r = Invoke-Cli -CliArgs @("verify", "--json", "--incremental", $incCache, "examples/valid-pack")
$p = @()
if ($r.ExitCode -ne 0) { $p += "exit: expected 0, got $($r.ExitCode)" }
if ($r.Output -notmatch '"ok":true') { $p += "json output missing ok:true" }
if ($p.Count -eq 0) {
  Write-Host "PASS  incremental: json mode"
} else {
  $failed += 1; Write-Host "FAIL  incremental: json mode"; $p | ForEach-Object { Write-Host "      $_" }
}

# Cleanup
Remove-Item $incCache -Recurse -Force -ErrorAction SilentlyContinue

# --- Part 6: machine contract and external anchor verification --------------

$machineTmp = Join-Path $tempRoot "moon-evidence-cli-test-machine"
if (Test-Path $machineTmp) { Remove-Item $machineTmp -Recurse -Force }
New-Item -ItemType Directory -Path $machineTmp -Force | Out-Null
$goldenDigest = "sha256:16bbf1e91de3acfb8bd9091233926b454045c6d96c24327baec20272af583f1e"
$machineTotal = 8

# Case 1: inspect emits the independently fixed golden manifest digest.
$r = Invoke-Cli -CliArgs @("inspect", "--json", "examples/valid-pack")
$p = @()
if ($r.ExitCode -ne 0) { $p += "exit: expected 0, got $($r.ExitCode)" }
$inspect = $null
try { $inspect = $r.Output | ConvertFrom-Json } catch { $p += "output is not valid JSON" }
if ($inspect) {
  if ($inspect.schema -ne "moon-evidence-inspect/v1") { $p += "wrong schema: $($inspect.schema)" }
  if ($inspect.manifest_digest -ne $goldenDigest) { $p += "wrong manifest digest: $($inspect.manifest_digest)" }
  if ($inspect.files_total -ne 2) { $p += "files_total: expected 2, got $($inspect.files_total)" }
}
if ($p.Count -eq 0) { Write-Host "PASS  machine: inspect golden digest" }
else { $failed += 1; Write-Host "FAIL  machine: inspect golden digest"; $p | ForEach-Object { Write-Host "      $_" } }

# Case 2: an exact external digest keeps verification green.
$r = Invoke-Cli -CliArgs @("verify", "--json", "--expected-manifest-digest", $goldenDigest, "examples/valid-pack")
$p = @()
if ($r.ExitCode -ne 0) { $p += "exit: expected 0, got $($r.ExitCode)" }
try {
  $report = $r.Output | ConvertFrom-Json
  if ($report.ok -ne $true) { $p += "expected ok:true" }
} catch { $p += "output is not valid JSON" }
if ($p.Count -eq 0) { Write-Host "PASS  machine: external digest match" }
else { $failed += 1; Write-Host "FAIL  machine: external digest match"; $p | ForEach-Object { Write-Host "      $_" } }

# Case 3: a different but well-formed external digest produces only E2004.
$wrongDigest = "sha256:" + ("0" * 64)
$r = Invoke-Cli -CliArgs @("verify", "--json", "--expected-manifest-digest", $wrongDigest, "examples/valid-pack")
$p = @()
if ($r.ExitCode -ne 1) { $p += "exit: expected 1, got $($r.ExitCode)" }
try {
  $report = $r.Output | ConvertFrom-Json
  $codes = @($report.findings | ForEach-Object { $_.code })
  if (($codes -join ",") -ne "E2004") { $p += "codes: expected [E2004], got [$($codes -join ',')]" }
} catch { $p += "output is not valid JSON" }
if ($p.Count -eq 0) { Write-Host "PASS  machine: external digest mismatch" }
else { $failed += 1; Write-Host "FAIL  machine: external digest mismatch"; $p | ForEach-Object { Write-Host "      $_" } }

# Case 4: malformed anchors are usage errors, not comparison findings.
$r = Invoke-Cli -CliArgs @("verify", "--json", "--expected-manifest-digest", "sha256:ABC", "examples/valid-pack")
$p = @()
if ($r.ExitCode -ne 2) { $p += "exit: expected 2, got $($r.ExitCode)" }
if ($r.Output -notmatch "must be canonical") { $p += "output missing canonical digest guidance" }
if ($p.Count -eq 0) { Write-Host "PASS  machine: malformed external digest" }
else { $failed += 1; Write-Host "FAIL  machine: malformed external digest"; $p | ForEach-Object { Write-Host "      $_" } }

# Case 5: pack copies a nested source into files/ and emits one JSON object.
$source = Join-Path $machineTmp "source"
$packed = Join-Path $machineTmp "packed"
New-Item -ItemType Directory -Path $source -Force | Out-Null
New-TestFile $source "a.txt" "alpha"
New-TestFile $source "nested/b.txt" "beta"
New-TestFile $source "manifest.json" '{"source":true}'
$r = Invoke-Cli -CliArgs @("pack", $source, "-o", $packed, "--subject-type", "dataset", "--json")
$p = @()
if ($r.ExitCode -ne 0) { $p += "exit: expected 0, got $($r.ExitCode)" }
$packResult = $null
try { $packResult = $r.Output | ConvertFrom-Json } catch { $p += "output is not valid JSON" }
if ($packResult) {
  if ($packResult.schema -ne "moon-evidence-pack-result/v1") { $p += "wrong schema" }
  if ($packResult.subject.id -ne "source") { $p += "default subject id should be source basename" }
  if ($packResult.files_total -ne 3) { $p += "files_total: expected 3, got $($packResult.files_total)" }
}
if (-not (Test-Path (Join-Path $packed "files/a.txt"))) { $p += "files/a.txt not copied" }
if (-not (Test-Path (Join-Path $packed "files/nested/b.txt"))) { $p += "nested file not copied" }
if (-not (Test-Path (Join-Path $packed "files/manifest.json"))) { $p += "source manifest.json was silently omitted" }
if ($p.Count -eq 0 -and $packResult) {
  $r2 = Invoke-Cli -CliArgs @("verify", "--json", "--expected-manifest-digest", $packResult.manifest_digest, $packed)
  if ($r2.ExitCode -ne 0) { $p += "packed output did not verify: exit $($r2.ExitCode)" }
}
if ($p.Count -eq 0) { Write-Host "PASS  machine: pack nested source" }
else { $failed += 1; Write-Host "FAIL  machine: pack nested source"; $p | ForEach-Object { Write-Host "      $_" } }

# Case 6: pack refuses to overwrite and leaves the existing manifest unchanged.
$packedManifest = Join-Path $packed "manifest.json"
$beforeHash = if (Test-Path $packedManifest) {
  (Get-FileHash $packedManifest -Algorithm SHA256).Hash
} else {
  ""
}
$r = Invoke-Cli -CliArgs @("pack", $source, "-o", $packed, "--json")
$p = @()
if (-not $beforeHash) { $p += "precondition missing: packed manifest" }
if ($r.ExitCode -ne 2) { $p += "exit: expected 2, got $($r.ExitCode)" }
try {
  $errorResult = $r.Output | ConvertFrom-Json
  if ($errorResult.ok -ne $false) { $p += "expected ok:false" }
} catch { $p += "output is not valid JSON" }
$afterHash = if (Test-Path $packedManifest) {
  (Get-FileHash $packedManifest -Algorithm SHA256).Hash
} else {
  ""
}
if ($beforeHash -and $beforeHash -ne $afterHash) { $p += "existing manifest was modified" }
if ($p.Count -eq 0) { Write-Host "PASS  machine: pack overwrite refusal" }
else { $failed += 1; Write-Host "FAIL  machine: pack overwrite refusal"; $p | ForEach-Object { Write-Host "      $_" } }

# Case 7: seal is an exact pack alias.
$sealed = Join-Path $machineTmp "sealed"
$r = Invoke-Cli -CliArgs @("seal", $source, "-o", $sealed, "--subject-id", "alias")
$p = @()
if ($r.ExitCode -ne 0) { $p += "exit: expected 0, got $($r.ExitCode)" }
if ($p.Count -eq 0) {
  $r2 = Invoke-Cli -CliArgs @("verify", $sealed)
  if ($r2.ExitCode -ne 0) { $p += "sealed output did not verify" }
}
if ($p.Count -eq 0) { Write-Host "PASS  machine: seal alias" }
else { $failed += 1; Write-Host "FAIL  machine: seal alias"; $p | ForEach-Object { Write-Host "      $_" } }

# Case 8: legacy create gains additive JSON metadata without changing layout.
$legacy = Join-Path $machineTmp "legacy"
New-Item -ItemType Directory -Path $legacy -Force | Out-Null
New-TestFile $legacy "legacy.txt" "legacy"
$r = Invoke-Cli -CliArgs @("create", $legacy, "--subject-id", "legacy", "--json")
$p = @()
if ($r.ExitCode -ne 0) { $p += "exit: expected 0, got $($r.ExitCode)" }
try {
  $createResult = $r.Output | ConvertFrom-Json
  if ($createResult.schema -ne "moon-evidence-pack-result/v1") { $p += "wrong schema" }
  $r2 = Invoke-Cli -CliArgs @("verify", "--expected-manifest-digest", $createResult.manifest_digest, $legacy)
  if ($r2.ExitCode -ne 0) { $p += "create JSON digest did not verify" }
} catch { $p += "output is not valid JSON" }
if ($p.Count -eq 0) { Write-Host "PASS  machine: create JSON metadata" }
else { $failed += 1; Write-Host "FAIL  machine: create JSON metadata"; $p | ForEach-Object { Write-Host "      $_" } }

Remove-Item $machineTmp -Recurse -Force -ErrorAction SilentlyContinue

$total = @($cases).Count + @($matrix).Count + @($manifestMatrix).Count + 10 + 3 + $machineTotal
Write-Host ""
Write-Host "cli-test ($Target): $($total - $failed)/$total passed"
if ($failed -gt 0) { exit 1 }
exit 0
