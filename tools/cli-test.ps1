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
  $release = $candidates | Where-Object { $_.FullName -match "[\\/]release[\\/]" } | Select-Object -First 1
  if ($release) { return $release.FullName }
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

function Invoke-Cli {
  param([string[]]$CliArgs)

  # The CLI prints everything assertable to stdout; stderr is dropped so
  # PowerShell 5.1 NativeCommandError noise cannot pollute assertions.
  if ($Target -eq "js") {
    $output = & $node $artifact @CliArgs 2>$null | Out-String
  } else {
    $output = & $artifact @CliArgs 2>$null | Out-String
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

$total = @($cases).Count + @($matrix).Count + @($manifestMatrix).Count
Write-Host ""
Write-Host "cli-test ($Target): $($total - $failed)/$total passed"
if ($failed -gt 0) { exit 1 }
exit 0
